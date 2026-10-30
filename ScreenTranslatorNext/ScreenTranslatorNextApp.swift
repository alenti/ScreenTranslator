import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

@main struct ScreenTranslatorNextApp: App {
    var body: some Scene { WindowGroup { TranslatorView() } }
}

struct TranslatorView: View {
    @State private var engine = HyMTTranslator()
    @State private var selection: PhotosPickerItem?
    @State private var original: UIImage?
    @State private var result: UIImage?
    @State private var target: TargetLanguage = .english
    @State private var showOriginal = false
    @State private var busy = false
    @State private var status = "Select a screenshot. The pinned GGUF stays on this device."
    @State private var diagnostics = ""
    @State private var outputURL: URL?
    @State private var importModel = false
    @State private var job: Task<Void, Never>?
    @State private var memoryWarnings = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PhotosPicker(selection: $selection, matching: .images) { Label("Select Screenshot", systemImage: "photo") }
                        .disabled(busy)
                    Picker("Target", selection: $target) {
                        ForEach(TargetLanguage.allCases, id: \.self) { Text($0.title).tag($0) }
                    }.pickerStyle(.segmented).disabled(busy)
                    HStack {
                        Button("Translate", action: translate).buttonStyle(.borderedProminent).disabled(original == nil || busy)
                        if busy { Button("Cancel") { job?.cancel() } }
                        Button("Import GGUF") { importModel = true }.disabled(busy)
                    }
                    Text(status).font(.callout).accessibilityIdentifier("status")
                    if busy { ProgressView() }
                    if let result {
                        if original != nil { Toggle("Show Original", isOn: $showOriginal) }
                        preview(showOriginal ? (original ?? result) : result)
                    }
                    else if let original { preview(original) }
                    if let outputURL { ShareLink("Share Result PNG", item: outputURL) }
                    if !diagnostics.isEmpty { Text(diagnostics).font(.system(.caption,design: .monospaced)).textSelection(.enabled) }
                }.padding()
            }.navigationTitle("ScreenTranslator Next")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in memoryWarnings += 1 }
        .onChange(of: selection) { _, item in
            job = Task {
                do {
                    guard let data = try await item?.loadTransferable(type: Data.self), let image = UIImage(data: data) else { throw failure("Unable to read image") }
                    original = image; result = nil; outputURL = nil; diagnostics = ""; status = "Ready"
                } catch { status = error.localizedDescription }
            }
        }
        .fileImporter(isPresented: $importModel, allowedContentTypes: [.data]) { selection in
            job = Task {
                busy = true; defer { busy = false }
                do { try await engine.importModel(selection.get()); status = "Pinned model imported and SHA256 verified." }
                catch { status = error.localizedDescription }
            }
        }
        .task {
            #if DEBUG
            if ["1","checks"].contains(ProcessInfo.processInfo.environment["PERF_MODE"] ?? "") {
                guard job == nil else { return }
                busy=true
                job = Task {
                    await PerformanceSprint.run(engine:engine,warnings:{memoryWarnings}) { message,image in status=message;if let image { result=image } }
                    busy=false
                }
                return
            }
            #endif
            if ProcessInfo.processInfo.environment["NEXT_AUTORUN"] == "1" {
                job = Task {
                    busy = true
                    await DeviceBenchmark.run(engine: engine, warnings: { memoryWarnings }) { message, image in
                        status = message
                        if let image { result = image; showOriginal = false }
                    }
                    busy = false
                }
            }
        }
        .onChange(of: busy) { _, value in
            #if DEBUG
            UIApplication.shared.isIdleTimerDisabled = value || ProcessInfo.processInfo.environment["PERF_MODE"] == "1"
            #else
            UIApplication.shared.isIdleTimerDisabled = value
            #endif
        }
    }

    private func preview(_ image: UIImage) -> some View {
        Image(uiImage: image).resizable().scaledToFit().accessibilityLabel(showOriginal ? "Original screenshot" : "Screenshot preview")
    }

    private func translate() {
        guard let original else { return }
        let language = target
        job = Task {
            busy = true; result = nil; status = "Running OCR and local Hy-MT…"
            defer { busy = false }
            do {
                let processed = try await ScreenshotProcessor.process(original,to: language,engine: engine)
                result = processed.image; showOriginal = false
                let errors = (processed.report["blocks"] as? [[String:Any]])?.filter { $0["error"] != nil }.count ?? 0
                let renderErrors = (processed.report["renderErrors"] as? [String])?.count ?? 0
                status = errors+renderErrors == 0 ? "Complete" : "\(errors) translation / \(renderErrors) render errors. Red outlines show failed blocks."
                let folder = documents.appendingPathComponent("RebootReports/\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: folder,withIntermediateDirectories:true)
                let file = folder.appendingPathComponent("result.png")
                try savePNG(processed.image,to:file)
                try savePNG(processed.original,to:folder.appendingPathComponent("original.png"))
                var report = processed.report; report["load"] = try await engine.prepare(); report["memoryWarnings"] = memoryWarnings
                try writeJSON(report,to:folder.appendingPathComponent("report.json")); outputURL = file
                diagnostics = ["ocrMs","translationMs","renderMs","totalMs","translationBlocks","memory","thermal","lowPowerMode"].map { "\($0): \(report[$0] ?? "?")" }.joined(separator:"\n")
            } catch { status = error.localizedDescription }
        }
    }
}
