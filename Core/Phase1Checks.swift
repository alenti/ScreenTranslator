#if DEBUG
import UIKit

enum Phase1Checks {
    @MainActor static func run(engine: HyMTTranslator) async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { _ in UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 100, height: 100)) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TemporaryImageStore(baseDirectoryURL: directory)
        let input = ScreenshotInputBuilder().build(imageData: image.pngData()!, size: image.size)
        let request = IntentHandoffRequest(screenshot: input, launchBehavior: .openInApp)
        try await store.store(request)
        let first = try await store.consumeLatestRequest()
        assert(first?.screenshot.id == input.id)
        try await store.store(request)
        let duplicate = try await store.consumeLatestRequest()
        assert(duplicate == nil)
        let newer = ScreenshotInputBuilder().build(imageData: image.pngData()!, size: image.size)
        try await store.store(ScreenshotInputBuilder().build(imageData: image.pngData()!, size: image.size))
        try await store.store(newer)
        let latest = try await store.consumeLatestRequest()
        assert(latest?.screenshot.id == newer.id)

        let spans = try ProtectedSpans("测试 USB-C 54W ¥135")
        let restored = try spans.restore(spans.input)
        assert(restored == "测试 USB-C 54W ¥135")
        do { _ = try spans.restore("[[P0]]"); throw failure("Corrupt spans accepted") } catch { assert(!(error.localizedDescription == "Corrupt spans accepted")) }
        let source = CGRect(x: 10, y: 10, width: 20, height: 10)
        let rendered = CGRect(x: 4, y: 4, width: 80, height: 40)
        let warning = ProcessingWarning(blockID: 7, stage: .translation, message: "test failure")
        let block = ProcessedBlock(id: 7, sourceText: "测试", sourceRect: source, renderedRect: rendered, failure: warning)
        for target in TargetLanguage.allCases {
            let result = ProcessedScreenshot(requestID: input.id, targetLanguage: target, originalImage: image, renderedImage: image, blocks: [block], warnings: [warning], report: [:])
            let viewer = ResultOverlayViewModel(result: result)
            assert(result.isPartial && result.blocks[0].translatedText == nil)
            assert(viewer.hotspots(in: .original)[0].frame == source)
            assert(viewer.hotspots(in: .overlay)[0].frame == rendered)
            assert(viewer.hotspots(in: .overlay)[0].id == block.hotspotID)
            assert(viewer.translationFailureCount == 1 && viewer.note(for: block) != nil && result.targetLanguage == target)
            let layout = ProcessingWarning(blockID: 7, stage: .rendering, message: "does not fit")
            let partial = ProcessedScreenshot(requestID: input.id, targetLanguage: target, originalImage: image, renderedImage: image, blocks: [block], warnings: [layout], report: [:])
            assert(ResultOverlayViewModel(result: partial).translationFailureCount == 0)
            var translated = block
            translated.translatedText = "Test translation"
            translated.failure = layout
            assert(viewer.translationText(for: translated).contains("Test translation"))
        }
        let groups = groupText([OCRBlock(id: 7, text: "测试", rect: source, observations: [7]), OCRBlock(id: 9, text: "按钮", rect: CGRect(x: 80, y: 80, width: 10, height: 10), observations: [9])])
        assert(groups.map(\.id) == [7, 9])
        let manifest = try modelManifest()
        do { try verifyModel(directory.appendingPathComponent("missing.gguf"), manifest: manifest); throw failure("Missing model accepted") }
        catch { assert(error.localizedDescription.contains("Model missing")) }
        let wrong = directory.appendingPathComponent("wrong.gguf")
        try Data([1]).write(to: wrong)
        do { try verifyModel(wrong, manifest: manifest); throw failure("Wrong size accepted") }
        catch { assert(error.localizedDescription.contains("incorrect model")) }
        do { try verifyModel(wrong, manifest: ["bytes":1,"sha256":String(repeating:"0",count:64)]); throw failure("Wrong hash accepted") }
        catch { assert(error.localizedDescription.contains("SHA256")) }
        let cancelled = Task { try await ScreenshotProcessor.process(image, to: .english, engine: engine) }
        cancelled.cancel()
        do { _ = try await cancelled.value; throw failure("Cancelled request completed") }
        catch is CancellationError {} catch { throw error }
        let loaded = await engine.isLoaded
        assert(!loaded)
        try await engine.beginRequest()
        let warningCount = await engine.diagnosticCounters["memoryWarnings", default: 0]
        NotificationCenter.default.post(name: UIApplication.didReceiveMemoryWarningNotification, object: nil)
        for _ in 0..<100 {
            if await engine.diagnosticCounters["memoryWarnings", default: 0] > warningCount { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let delivered = await engine.diagnosticCounters["memoryWarnings", default: 0]
        assert(delivered == warningCount + 1 && engine.jobs.isIdle)
        let pending = engine.jobs.start(id: UUID(), cancelNative: { engine.cancel() }) { try await Task.sleep(for: .seconds(30)) }
        do { try await engine.importModel(wrong); throw failure("Model import raced active processing") }
        catch { assert(error.localizedDescription.contains("Cancel the current translation")) }
        await engine.jobs.cancelAll()?.value
        await engine.unloadIfIdle()
        _ = await pending.result
        try writeJSON(["passed":true,"checks":["claim once","latest wins","stable IDs","source/rendered geometry","protected spans","missing model","wrong size/hash","cancel before load","partial failure","EN/RU","memory-warning delivery","import blocked during processing"]], to: documents.appendingPathComponent("phase1-checks.json"))
    }
}
#endif
