import UIKit
import Vision
import CryptoKit

struct ProcessingWarning: Equatable, Sendable {
    enum Stage: String, Sendable { case translation, rendering }
    let blockID: Int
    let stage: Stage
    let message: String
}

struct ProcessedBlock: Identifiable, Equatable, Sendable {
    let id: Int
    let sourceText: String
    var translatedText: String?
    let sourceRect: CGRect
    var renderedRect: CGRect?
    var failure: ProcessingWarning?

    mutating func restoreTranslation(_ raw: String, using spans: ProtectedSpans) -> String? {
        do {
            let output = try spans.restore(raw)
            guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw NSError(domain: "ScreenTranslatorNext", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty translation"]) }
            translatedText = output
            failure = nil
            return output
        } catch {
            translatedText = nil
            failure = ProcessingWarning(blockID: id, stage: .translation, message: error.localizedDescription)
            return nil
        }
    }

}

enum ScreenshotProgress: Sendable {
    case readingText, grouping, preparingModel, translating(Int, Int), rendering
}

struct ProcessedScreenshot {
    let requestID: UUID
    let targetLanguage: TargetLanguage
    let originalImage: UIImage
    let renderedImage: UIImage
    let blocks: [ProcessedBlock]
    let warnings: [ProcessingWarning]
    // Detailed diagnostic export, never the viewer's data contract.
    var report: [String: Any]
    var original: UIImage { originalImage }
    var image: UIImage { renderedImage }
    var isPartial: Bool { !warnings.isEmpty }
}

// A replacement cancels only its predecessor and joins it before touching shared native state.
final class ScreenshotJobGate: @unchecked Sendable {
    private let lock = NSLock()
    private var tail: Task<Void, Never>?
    private var ticket: UUID?
    private var receivedAt: TimeInterval = 0
    private var cancellation: (() -> Void)?

    var isIdle: Bool { lock.lock(); defer { lock.unlock() }; return cancellation == nil }
    func isCurrent(_ id: UUID) -> Bool { lock.lock(); defer { lock.unlock() }; return ticket == id }

    func start<T>(id: UUID, receivedAt: TimeInterval = ProcessInfo.processInfo.systemUptime, cancelNative: @escaping () -> Void, operation: @escaping () async throws -> T) -> Task<T, Error> {
        lock.lock(); defer { lock.unlock() }
        guard receivedAt >= self.receivedAt else { return Task { throw CancellationError() } }
        self.receivedAt = receivedAt
        cancellation?()
        let previous = tail
        ticket = id
        let task = Task {
            await previous?.value
            defer { self.finish(id) }
            try Task.checkCancellation()
            let value = try await operation()
            try Task.checkCancellation()
            guard self.isCurrent(id) else { throw CancellationError() }
            return value
        }
        cancellation = { task.cancel(); cancelNative() }
        tail = Task { _ = await task.result }
        return task
    }

    func cancel(_ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        if ticket == id { cancellation?() }
    }
    func cancelAll() -> Task<Void, Never>? {
        lock.lock(); defer { lock.unlock() }
        cancellation?()
        return tail
    }
    private func finish(_ id: UUID) {
        lock.lock(); defer { lock.unlock() }
        if ticket == id { cancellation = nil; tail = nil }
    }
}

struct ExactTranslationMemory {
    private var values: [String:String] = [:]
    private var order: [String] = []
    private var bytes = 0
    let maximumEntries: Int
    let maximumBytes: Int
    init(maximumEntries: Int = 256, maximumBytes: Int = 1_048_576) {
        self.maximumEntries = max(0,maximumEntries); self.maximumBytes = max(0,maximumBytes)
    }
    static func key(source: String, language: TargetLanguage, manifest: [String:Any], template: String) throws -> String {
        let data=try JSONSerialization.data(withJSONObject:["model":manifest,"template":template,
            "prompt":"将以下文本翻译为\(language.promptName)，注意只需要输出翻译后的结果，不要额外解释：\n",
            "source":source.precomposedStringWithCanonicalMapping],options:.sortedKeys)
        return SHA256.hash(data:data).map { String(format:"%02x",$0) }.joined()
    }
    func value(for key: String) -> String? { values[key] }
    mutating func insert(_ raw: String, source: String, key: String) throws {
        let restored=try ProtectedSpans(source).restore(raw)
        guard !restored.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw failure("Empty cached translation") }
        let size=key.utf8.count+raw.utf8.count
        guard maximumEntries>0,size<=maximumBytes else { return }
        if let old=values[key] { bytes-=key.utf8.count+old.utf8.count }
        else { order.append(key) }
        values[key]=raw;bytes+=size
        while order.count>maximumEntries || bytes>maximumBytes {
            let oldest=order.removeFirst()
            if let old=values.removeValue(forKey:oldest) { bytes-=oldest.utf8.count+old.utf8.count }
        }
    }
    mutating func clear() { values.removeAll();order.removeAll();bytes=0 }
}

actor HyMTTranslator {
    static let shared = HyMTTranslator()
    nonisolated private let native = HyMTNative()
    nonisolated let jobs = ScreenshotJobGate()
    private var loaded = false
    private var loadReport: [String: Any] = [:]
    private var exactTranslations = ExactTranslationMemory()
    private var memoryWarnings = 0
    #if os(iOS)
    private var memoryObserver: NSObjectProtocol?
    private func observeMemoryWarnings() {
        guard memoryObserver == nil else { return }
        memoryObserver = NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            // The observer also exists when an intent starts without an application scene.
            let exit = self.jobs.cancelAll()
            Task { await exit?.value; await self.handleMemoryWarning() }
        }
    }
    deinit { if let memoryObserver { NotificationCenter.default.removeObserver(memoryObserver) } }
    private func handleMemoryWarning() { memoryWarnings += 1; unloadIfIdle() }
    #endif
    private var requestCount = 0, generationCount = 0, loadCount = 0
    private var stageCounts: [String:Int] = ["ocr":0,"grouping":0,"rendering":0]
    var diagnosticCounters: [String:Int] { stageCounts.merging(["requests":requestCount,"generations":generationCount,"loads":loadCount,"memoryWarnings":memoryWarnings]) { _,new in new } }
    func recordDiagnosticStage(_ stage: String) { stageCounts[stage,default:0] += 1 }
    #if DEBUG
    func clearTranslationMemoryForChecks() { exactTranslations.clear() }
    func benchmarkLoad(_ path: URL, manifest: [String:Any]) throws -> [String:Any] {
        unload(); native.beginRequest()
        let t=Date();try verifyModel(path,manifest:manifest)
        let verifyMs=Date().timeIntervalSince(t)*1000
        loadReport=try checked(native.load(path.path));loadReport["verifyMs"]=verifyMs
        loadReport["model"]=manifest
        loadReport["warmup"]=try checked(native.generate("将以下文本翻译为英语，注意只需要输出翻译后的结果，不要额外解释：\n加入购物车"))
        loaded=true;return loadReport
    }
    func benchmarkContext(_ parallel: Int) throws -> [String:Any] { try checked(native.benchmarkContext(parallel)) }
    func benchmarkGenerate(_ messages: [String], options: [String:Any]) throws -> [String:Any] {
        native.beginRequest();return try checked(native.benchmarkGenerate(messages,options:options))
    }
    #endif

    func beginRequest() throws {
        #if os(iOS)
        observeMemoryWarnings()
        #endif
        try Task.checkCancellation()
        native.beginRequest()
        requestCount += 1
        try Task.checkCancellation()
    }

    var isLoaded: Bool { loaded }

    func verifyInstalledModel() throws {
        if !loaded { let manifest = try modelManifest(); try verifyModel(modelFileURL(manifest), manifest: manifest) }
    }

    func prepare() throws -> [String: Any] {
        try Task.checkCancellation()
        if loaded { return loadReport }
        let manifest = try modelManifest()
        let start = Date()
        let url = try modelFileURL(manifest)
        try writeJSON(["stage":"verify","memory":HyMTNative.memory()],to:diagnosticsDirectory.appendingPathComponent("prepare.json"))
        try verifyModel(url, manifest: manifest)
        try Task.checkCancellation()
        let verifyMs = Date().timeIntervalSince(start) * 1000
        try writeJSON(["stage":"load","verifyMs":verifyMs,"memory":HyMTNative.memory()],to:diagnosticsDirectory.appendingPathComponent("prepare.json"))
        loadReport = try checked(native.load(url.path))
        loadCount += 1
        try Task.checkCancellation()
        loadReport["model"] = manifest
        loadReport["modelPath"] = url.path
        loadReport["verifyMs"] = verifyMs
        try writeJSON(["stage":"warmup","load":loadReport],to:diagnosticsDirectory.appendingPathComponent("prepare.json"))
        try Task.checkCancellation()
        let warmup = try checked(native.generateBatch([["id":0,"message":"将以下文本翻译为英语，注意只需要输出翻译后的结果，不要额外解释：\n加入购物车"]],progress:nil))
        // Rows without EOG no longer fail the batch, but a warmup without EOG still means a broken load.
        guard (warmup["rows"] as? [[String:Any]])?.first?["eog"] as? Bool == true else { unload(); throw failure("Model warmup produced no EOG") }
        try Task.checkCancellation()
        loadReport["warmup"] = warmup
        loaded = true
        try writeJSON(["stage":"ready","load":loadReport],to:diagnosticsDirectory.appendingPathComponent("prepare.json"))
        return loadReport
    }

    #if DEBUG
    func translate(_ source: String, to language: TargetLanguage) throws -> [String: Any] {
        _ = try prepare()
        try Task.checkCancellation()
        #if DEBUG
        generationCount += 1
        #endif
        return try checked(native.generate("将以下文本翻译为\(language.promptName)，注意只需要输出翻译后的结果，不要额外解释：\n\(source)"))
    }
    #endif

    func translateBatch(_ sources: [(id: Int, source: String)], to language: TargetLanguage, onProgress: @escaping @Sendable (Int) async -> Void) async throws -> [String:Any] {
        try Task.checkCancellation()
        guard loaded else { throw failure("Model is not prepared") }
        let requests = sources.map { ["id":$0.id,"message":"将以下文本翻译为\(language.promptName)，注意只需要输出翻译后的结果，不要额外解释：\n\($0.source)"] as [String:Any] }
        generationCount += sources.count
        var update: Task<Void,Never>?
        // Native progress is synchronous on this actor; join UI delivery before rendering.
        let result = native.generateBatch(requests,progress: { completed in
            let previous = update
            update = Task.detached { await previous?.value; await onProgress(completed) }
        })
        await update?.value
        // A backend decode error can leave the context unusable; cooperative cancellation keeps the model warm.
        if result["error"] != nil, result["cancelled"] as? Bool != true { unload() }
        try Task.checkCancellation()
        return try checked(result)
    }

    nonisolated func cancel() { native.cancel() }
    private func translationKey(_ source: String, _ language: TargetLanguage) throws -> String {
        guard loaded,let manifest=loadReport["model"] as? [String:Any],let template=loadReport["embeddedChatTemplate"] as? String else { throw failure("Cache requires a verified loaded model/template") }
        return try ExactTranslationMemory.key(source:source,language:language,manifest:manifest,template:template)
    }
    func cachedTranslations(_ sources: [(id:Int,source:String)], to language: TargetLanguage) throws -> [Int:String] {
        var hits:[Int:String]=[:]
        for item in sources { if let raw=exactTranslations.value(for:try translationKey(item.source,language)) { hits[item.id]=raw } }
        return hits
    }
    func rememberTranslation(_ raw: String, source: String, to language: TargetLanguage) throws {
        try exactTranslations.insert(raw,source:source,key:translationKey(source,language))
    }
    func unloadIfIdle() { if jobs.isIdle { unload() } }
    func unload() { native.unload(); loaded = false; loadReport = [:];exactTranslations.clear() }

    func importModel(_ source: URL) throws {
        guard jobs.isIdle else { throw failure("Cancel the current translation before importing a model.") }
        unload()
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let temporary = documents.appendingPathComponent("model-import.gguf")
        if FileManager.default.fileExists(atPath: temporary.path) { try FileManager.default.removeItem(at: temporary) }
        try FileManager.default.copyItem(at: source, to: temporary)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let manifest = try modelManifest()
        try verifyModel(temporary, manifest: manifest)
        let destination = try modelFileURL(manifest)
        if FileManager.default.fileExists(atPath: destination.path) {
            if (try? verifyModel(destination, manifest: manifest)) != nil { return } // Never rewrite a verified installed model.
            try FileManager.default.removeItem(at: destination) // Damaged: replace it with the verified import.
        }
        try FileManager.default.moveItem(at: temporary, to: destination)
    }
}

func modelManifest() throws -> [String:Any] {
    guard let url = Bundle.main.url(forResource:"model",withExtension:"json"),
          let manifest = try JSONSerialization.jsonObject(with:Data(contentsOf:url)) as? [String:Any] else { throw failure("Missing bundled model manifest") }
    return manifest
}
func modelFileURL(_ manifest: [String:Any], root: URL = documents) throws -> URL {
    guard let path = manifest["localPath"] as? String else { throw failure("Missing installed model path") }
    guard !path.isEmpty, !path.hasPrefix("/"), !path.split(separator:"/").contains("..") else { throw failure("Invalid installed model path") }
    return root.appendingPathComponent(path)
}
var activeModelName: String { ((try? modelManifest()["filename"] as? String) ?? "Hy-MT2").replacingOccurrences(of:".gguf",with:"") }
func verifyModel(_ url: URL, manifest: [String:Any]) throws {
    let name = manifest["filename"] as? String ?? "the pinned model"
    guard FileManager.default.fileExists(atPath: url.path) else { throw failure("Model missing. Import \(name) in Settings before translating.") }
    guard try url.resourceValues(forKeys:[.fileSizeKey]).fileSize == (manifest["bytes"] as? NSNumber)?.intValue else {
        throw failure("Missing or incorrect model \(name). Import the pinned model with Files.")
    }
    guard let stream = InputStream(url:url) else { throw failure("Model cannot be opened") }
    stream.open(); defer { stream.close() }
    let bufferSize = 4*1024*1024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity:bufferSize)
    defer { buffer.deallocate() }
    var hash = SHA256()
    while true {
        try Task.checkCancellation()
        let count = stream.read(buffer,maxLength:bufferSize)
        if count < 0 { throw stream.streamError ?? failure("Model read failed") }
        if count == 0 { break }
        hash.update(bufferPointer:UnsafeRawBufferPointer(start:buffer,count:count))
    }
    guard hash.finalize().map({String(format:"%02x",$0)}).joined() == manifest["sha256"] as? String else { throw failure("Model SHA256 does not match pinned model") }
}
func savePNG(_ image: UIImage, to url: URL) throws {
    guard let data = image.pngData() else { throw failure("PNG encoding failed") }
    try data.write(to:url,options:.atomic)
}

func checked(_ value: [String: Any]) throws -> [String: Any] {
    if let message = value["error"] as? String { throw failure(message) }
    return value
}

var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
/// DEBUG keeps evidence in Documents for device export; Release keeps numeric diagnostics out of the user's Files view.
var diagnosticsDirectory: URL {
    #if DEBUG
    return documents
    #else
    let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Diagnostics")
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
    #endif
}
func writeJSON(_ value: Any, to url: URL) throws {
    try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: url, options: .atomic)
}

func writeProcessingMetrics(_ result: ProcessedScreenshot, extra: [String:Any] = [:]) {
    let keys = ["requestID", "modelReused", "target", "ocrObservations", "translationBlocks", "groupingMetrics",
                "layoutMetrics", "ocrMs", "groupingMs", "modelPreparationMs", "nativeBatch", "translationMs",
                "renderMs", "totalMs", "engineCounters", "renderErrors", "translatedBlockCount", "translationFailureCount", "memory", "thermal", "thermalBefore", "lowPowerMode"]
    var report = result.report.filter { keys.contains($0.key) }
    report.merge(extra) { _,new in new }
    let root = diagnosticsDirectory.appendingPathComponent("ProcessingMetrics")
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try? writeJSON(report, to: root.appendingPathComponent("\(result.requestID.uuidString)-\(UUID().uuidString).json"))
    // These are bounded, app-owned numeric diagnostics; user images/models/history are untouched.
    let files = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
    let ordered = files.filter { $0.pathExtension == "json" }.sorted {
        ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) >
        ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
    }
    for file in ordered.dropFirst(32) { try? FileManager.default.removeItem(at: file) }
}

enum ScreenshotProcessor {
    static func process(_ input: UIImage, to language: TargetLanguage, engine: HyMTTranslator, requestID: UUID = UUID(), receivedAt: TimeInterval = ProcessInfo.processInfo.systemUptime, onProgress: @escaping @Sendable (ScreenshotProgress) async -> Void = { _ in }) async throws -> ProcessedScreenshot {
        try Task.checkCancellation()
        let ticket = UUID() // Retries of the same screenshot still have distinct native ownership.
        let task = engine.jobs.start(id: ticket, receivedAt: receivedAt, cancelNative: { engine.cancel() }) {
            try await engine.beginRequest()
            return try await run(input, to: language, engine: engine, requestID: requestID, onProgress: onProgress)
        }
        return try await withTaskCancellationHandler {
            if Task.isCancelled { engine.jobs.cancel(ticket) }
            let result = try await task.value
            try Task.checkCancellation()
            guard engine.jobs.isCurrent(ticket) else { throw CancellationError() }
            return result
        } onCancel: { engine.jobs.cancel(ticket) }
    }

    private static func run(_ input: UIImage, to language: TargetLanguage, engine: HyMTTranslator, requestID: UUID, onProgress: @escaping @Sendable (ScreenshotProgress) async -> Void) async throws -> ProcessedScreenshot {
        let start = Date()
        let thermalBefore = ProcessInfo.processInfo.thermalState.rawValue
        let memoryBefore = HyMTNative.memory()
        await onProgress(.readingText)
        try Task.checkCancellation()
        // Redraw pixel bytes once. Both OCR and overlay see the same upright pixels, including mirrored EXIF.
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let size = CGSize(width: input.size.width * input.scale, height: input.size.height * input.scale)
        guard size.width > 0, size.height > 0, size.width * size.height <= 40_000_000 else { throw failure("Image dimensions are invalid or exceed 40 megapixels") }
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in input.draw(in: CGRect(origin: .zero, size: size)) }
        guard let cgImage = image.cgImage else { throw failure("Image cannot be decoded") }
        let ocrStart = Date()
        await engine.recordDiagnosticStage("ocr")
        let observations = classifyScreenshotText(try readScreenshotText(cgImage), size:size)
        let ocrMs = Date().timeIntervalSince(ocrStart) * 1000
        let groupingStart = Date()
        await onProgress(.grouping)
        await engine.recordDiagnosticStage("grouping")
        let blocks = groupText(observations)
        let groupingMs = Date().timeIntervalSince(groupingStart) * 1000
        guard !blocks.isEmpty else { throw failure("No Chinese text was recognized in the supplied screenshot. Check the screenshot; if using iPhone Mirroring, repeat on the unlocked iPhone.") }
        let preparationStart = Date()
        await onProgress(.preparingModel)
        let reusedModel = await engine.isLoaded
        _ = try await engine.prepare()
        let preparationMs = Date().timeIntervalSince(preparationStart)*1000
        let translationStart = Date()
        var rows: [[String: Any]] = []
        var outputs: [Int: String] = [:]
        var processedBlocks = blocks.map { ProcessedBlock(id: $0.id, sourceText: $0.text, sourceRect: $0.rect) }
        var warnings: [ProcessingWarning] = []
        let spans = try blocks.map { try ProtectedSpans($0.text) }
        await onProgress(.translating(0, blocks.count))
        let cached=try await engine.cachedTranslations(blocks.map { (id:$0.id,source:$0.text) },to:language)
        let pending=blocks.indices.filter { cached[blocks[$0].id] == nil }
        var nativeBatch:[String:Any]=["totalMs":0,"inputTokens":0,"outputTokens":0,"cacheOnly":true]
        var generatedByID:[Int:[String:Any]]=[:]
        if !pending.isEmpty {
            nativeBatch = try await engine.translateBatch(pending.map { (id:blocks[$0].id,source:spans[$0].input) },to:language) { completed in
                await onProgress(.translating(cached.count+completed,blocks.count))
            }
            guard let generations = nativeBatch.removeValue(forKey:"rows") as? [[String:Any]], generations.count == pending.count else { throw failure("Sequence/result count mismatch") }
            for (position,index) in pending.enumerated() {
                let generated=generations[position]
                guard generated["id"] as? Int == blocks[index].id,generated["index"] as? Int == position,generated["eog"] is Bool,generated["text"] is String else { throw failure("Invalid sequence/result ID mapping or EOG") }
                generatedByID[blocks[index].id]=generated
            }
        }
        nativeBatch["cacheHits"]=cached.count;nativeBatch["cacheMisses"]=pending.count
        await onProgress(.translating(blocks.count,blocks.count))
        for (index, block) in blocks.enumerated() {
            try Task.checkCancellation()
            var row: [String: Any] = ["id":block.id, "observations":block.observations, "source":block.text,
                                     "rect":[block.rect.minX,block.rect.minY,block.rect.width,block.rect.height]]
            row["maskedSource"] = spans[index].input
            row["protectedSpans"] = spans[index].spans
            let raw: String
            if let hit=cached[block.id] { raw=hit;row["cacheHit"]=true }
            else {
                guard let generated=generatedByID[block.id],let text=generated["text"] as? String else { throw failure("Missing native output for source ID") }
                // Output without EOG is rejected for this block only; the others still render.
                raw=generated["eog"] as? Bool == true ? text : "";row["generation"]=generated;row["cacheHit"]=false
            }
            guard let output = processedBlocks[index].restoreTranslation(raw, using: spans[index]) else {
                let warning = processedBlocks[index].failure!
                warnings.append(warning)
                row["error"] = warning.message
                rows.append(row)
                #if DEBUG
                let folder = documents.appendingPathComponent("ProcessingFailures/\(requestID.uuidString)")
                try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try? writeJSON(["requestID":requestID.uuidString,"blockID":block.id,"target":language.rawValue,
                                "source":block.text,"maskedSource":spans[index].input,"protectedSpans":spans[index].spans,
                                "rawTranslation":raw,"generation":generatedByID[block.id] ?? [:],"error":warning.message],
                               to: folder.appendingPathComponent("span-failure-\(block.id).json"))
                #endif
                continue // Reject this output; no panel is drawn over its original pixels.
            }
            outputs[block.id] = output
            if cached[block.id] == nil { try await engine.rememberTranslation(raw,source:block.text,to:language) }
            processedBlocks[index].translatedText = output
            row["translation"] = output
            rows.append(row)
        }
        guard !outputs.isEmpty else { throw failure("No block produced a valid translation; original screenshot retained.") }
        let translationMs = Date().timeIntervalSince(translationStart) * 1000
        let renderStart = Date()
        await onProgress(.rendering)
        await engine.recordDiagnosticStage("rendering")
        try Task.checkCancellation()
        let placements = layoutScreenshotOverlays(blocks, observations:observations, outputs:outputs, size:size)
        let result = renderScreenshotOverlays(image, placements:placements, outputs:outputs)
        var renderErrors: [String] = []
        for panel in placements {
            guard let index = processedBlocks.firstIndex(where: { $0.id == panel.id }) else { continue }
            processedBlocks[index].renderedRect = panel.rect
            if let message = panel.warning {
                renderErrors.append("Block \(panel.id): \(message)")
                let warning = ProcessingWarning(blockID:panel.id,stage:.rendering,message:message)
                processedBlocks[index].failure = warning; warnings.append(warning)
            }
        }
        let metrics = overlayMetrics(placements, observations:observations, blocks:blocks, size:size)
        let layouts = metrics["placements"] as? [[String:Any]] ?? []
        let renderMs = Date().timeIntervalSince(renderStart) * 1000
        let ocrRows = observations.map(\.diagnostic)
        let counters = await engine.diagnosticCounters
        try Task.checkCancellation()
        return ProcessedScreenshot(requestID: requestID, targetLanguage: language, originalImage: image, renderedImage: result, blocks: processedBlocks, warnings: warnings, report: ["requestID":requestID.uuidString,"engineCounters":counters,"modelReused":reusedModel,"target":language.rawValue,"ocrObservations":observations.count,
            "translationBlocks":blocks.count,"translatedBlockCount":outputs.count,"translationFailureCount":warnings.filter { $0.stage == .translation }.count,"ocr":ocrRows,"blocks":rows,"groups":blocks.map(\.diagnostic),
            "groupingMetrics":groupingMetrics(observations,blocks:blocks),"layoutMetrics":metrics,"ocrMs":ocrMs,"groupingMs":groupingMs,
            "modelPreparationMs":preparationMs,"nativeBatch":nativeBatch,"translationMs":translationMs,"renderMs":renderMs,"totalMs":Date().timeIntervalSince(start)*1000,
            "renderErrors":renderErrors,"overlayLayouts":layouts,"memory":HyMTNative.memory(),"thermal":ProcessInfo.processInfo.thermalState.rawValue,
            "thermalBefore":thermalBefore,"memoryBefore":memoryBefore,"lowPowerMode":ProcessInfo.processInfo.isLowPowerModeEnabled])
    }
}
