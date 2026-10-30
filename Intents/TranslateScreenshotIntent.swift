import AppIntents
import UniformTypeIdentifiers
import UIKit

struct TranslateScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate Screenshot in App"
    static var description = IntentDescription("Opens the screenshot in the app and shows the translation in the full viewer.")
    static var openAppWhenRun: Bool = true
    static var supportedModes: IntentModes { [.foreground] }

    @Parameter(
        title: "Screenshot",
        supportedContentTypes: [.image],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult {
        try await ShortcutIntentExecutor().storeScreenshot(
            screenshot,
            launchBehavior: .openInApp
        )

        return .result()
    }
}

struct QuickLookTranslateScreenshotIntent: AppIntent {
    static var isDiscoverable: Bool = false
    static var supportedModes: IntentModes { [.background] }
    static var title: LocalizedStringResource = "Quick Look Translate Screenshot"
    static var description = IntentDescription(
        "Accepts a screenshot from Shortcuts and returns a PNG file for the Shortcuts Quick Look action."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Screenshot",
        supportedContentTypes: [.image],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        if #available(iOS 26.4, *) {
            return .result(value: try await QuickLookScreenshotTranslation.run(screenshot, intent: self))
        }
        return .result(value: try await QuickLookScreenshotTranslation.run(screenshot))
    }
}

// Hidden but kept: already-installed shortcuts still run this action.
struct FloatingScreenTranslateIntent: AppIntent {
    static var isDiscoverable: Bool = false
    static var title: LocalizedStringResource = "Floating Screen Translator"
    static var openAppWhenRun: Bool = true
    static var supportedModes: IntentModes { [.foreground] }

    @Parameter(
        title: "Screenshot",
        supportedContentTypes: [.image],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult {
        try await ShortcutIntentExecutor().storeScreenshot(
            screenshot,
            launchBehavior: .floatingPreview
        )

        return .result()
    }
}

private struct ShortcutIntentExecutor {
    func storeScreenshot(
        _ screenshot: IntentFile,
        launchBehavior: IntentHandoffRequest.LaunchBehavior
    ) async throws {
        let decoder = IntentInputDecoder()
        let temporaryImageStore = TemporaryImageStore.shared
        let decodedScreenshot = try decoder.decode(screenshot)

        try await temporaryImageStore.store(
            IntentHandoffRequest(
                screenshot: decodedScreenshot,
                launchBehavior: launchBehavior
            )
        )
        await MainActor.run {
            NotificationCenter.default.post(name: TemporaryImageStore.requestStored, object: nil)
        }
    }
}

// Keep this identity: installed Fast7B Quick Look shortcuts already refer to it.
struct FastTranslateScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate Screenshot for Quick Look"
    static var description = IntentDescription("Translates the screenshot on this iPhone and returns an image. Add the Quick Look action after it.")
    static var openAppWhenRun: Bool = false
    static var supportedModes: IntentModes { [.background] }

    @Parameter(title: "Screenshot", supportedContentTypes: [.image], inputConnectionBehavior: .connectToPreviousIntentResult)
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        if #available(iOS 26.4, *) {
            return .result(value: try await QuickLookScreenshotTranslation.run(screenshot, intent: self))
        }
        return .result(value: try await QuickLookScreenshotTranslation.run(screenshot))
    }
}

@available(iOS 26.4, *)
extension FastTranslateScreenshotIntent: CancellableIntent {}
@available(iOS 26.4, *)
extension QuickLookTranslateScreenshotIntent: CancellableIntent {}

private enum QuickLookScreenshotTranslation {
    @available(iOS 26.4, *)
    static func run(_ screenshot: IntentFile, intent: some CancellableIntent) async throws -> IntentFile {
        let id = UUID(), receivedAt = ProcessInfo.processInfo.systemUptime
        let work = Task { try await run(screenshot, id: id, receivedAt: receivedAt) }
        return try await intent.withIntentCancellationHandler {
            try await withTaskCancellationHandler { try await work.value } onCancel: { work.cancel() }
        } onCancel: { reason in
            print("QUICKLOOK \(id) OS cancellation: \(reason.debugDescription)")
            work.cancel()
        }
    }
    static func run(_ screenshot: IntentFile, id: UUID = UUID(), receivedAt: TimeInterval = ProcessInfo.processInfo.systemUptime) async throws -> IntentFile {
        let start = Date()
        let root = diagnosticsDirectory.appendingPathComponent("ReleaseQuickLook/\(id.uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let state = await MainActor.run { UIApplication.shared.applicationState.rawValue }
        let engine = HyMTTranslator.shared
        try writeJSON(["stage":"received", "requestID":id.uuidString, "timestamp":start.timeIntervalSince1970,
                       "applicationState":state, "pid":ProcessInfo.processInfo.processIdentifier],
                      to: root.appendingPathComponent("received.json"))
        #if DEBUG
        var ownedInput: Data?
        #endif
        do {
            let input = try IntentInputDecoder().decode(screenshot)
            guard let image = UIImage(data: input.imageData) else { throw AppError.unsupportedImage }
            #if DEBUG
            ownedInput = input.imageData
            try input.imageData.write(to: root.appendingPathComponent("input.png"), options: .atomic)
            #endif
            let target = TargetLanguage(rawValue: UserDefaults.standard.string(forKey: "localTarget") ?? "russian") ?? .russian
            let result = try await ScreenshotProcessor.process(image, to: target, engine: engine, requestID: id, receivedAt: receivedAt) { progress in
                print("QUICKLOOK \(id) \(progress)")
            }
            try Task.checkCancellation()
            guard result.requestID == id, let png = quickLookPreviewImage(result).pngData() else { throw failure("Quick Look result identity or PNG encoding failed") }
            var report = result.report
            report["receivedAt"] = start.timeIntervalSince1970
            report["returningAt"] = Date().timeIntervalSince1970
            report["intentElapsedMs"] = Date().timeIntervalSince(start) * 1000
            report["initialApplicationState"] = state
            report["afterCounters"] = result.report["engineCounters"]
            #if DEBUG
            try png.write(to: root.appendingPathComponent("result.png"), options: .atomic)
            #else
            // Release keeps local timing/geometry evidence, never screenshot text or pixels.
            for key in ["ocr", "blocks", "groups", "overlayLayouts"] { report.removeValue(forKey: key) }
            #endif
            try writeJSON(report, to: root.appendingPathComponent("report.json"))
            try writeJSON(["stage":"returningPNG", "timestamp":Date().timeIntervalSince1970, "bytes":png.count],
                          to: root.appendingPathComponent("status.json"))
            #if !DEBUG
            pruneReports()
            #endif
            print("QUICKLOOK \(id) returning PNG")
            return IntentFile(data: png, filename: "translated.png", type: .png)
        } catch {
            #if DEBUG
            if let ownedInput { try? ownedInput.write(to: root.appendingPathComponent("failed-input.png"), options: .atomic) }
            #endif
            try? writeJSON(["stage":"failed", "error":error.localizedDescription, "timestamp":Date().timeIntervalSince1970],
                           to: root.appendingPathComponent("status.json"))
            if error is CancellationError || Task.isCancelled { throw error }
            // Shortcuts shows this text in its alert; never surface raw native messages there.
            throw AppError(error)
        }
    }

    #if !DEBUG
    /// Release keeps only recent numeric reports.
    static func pruneReports() {
        let root = diagnosticsDirectory.appendingPathComponent("ReleaseQuickLook")
        let folders = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        let ordered = folders.sorted {
            ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) >
            ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast)
        }
        for folder in ordered.dropFirst(32) { try? FileManager.default.removeItem(at: folder) }
    }
    #endif
}

// Quick Look has no in-app warning banner; append the notice outside the original screenshot.
// Written in the target language, since that is what the reader of the result reads.
func quickLookPreviewImage(_ result: ProcessedScreenshot) -> UIImage {
    let count = result.translationFailureCount
    guard count > 0 else { return result.renderedImage }
    let image = result.renderedImage, scale = image.size.width / 1170
    let padding = 28 * scale
    let text = result.targetLanguage == .russian
        ? "⚠︎ Часть текста (\(count)) не удалось надёжно перевести — она показана в оригинале."
        : "⚠︎ \(count) text block\(count == 1 ? "" : "s") couldn’t be translated reliably and \(count == 1 ? "is" : "are") shown in the original."
    let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 30 * scale, weight: .medium),
                                                     .foregroundColor: UIColor(white: 0.2, alpha: 1)]
    let measured = (text as NSString).boundingRect(with: CGSize(width: image.size.width - padding * 2, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
    let height = ceil(measured.height) + padding * 2
    let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
    return UIGraphicsImageRenderer(size: CGSize(width: image.size.width, height: image.size.height + height), format: format).image { context in
        image.draw(at: .zero)
        UIColor(red: 1, green: 0.96, blue: 0.86, alpha: 1).setFill()
        context.cgContext.fill(CGRect(x: 0, y: image.size.height, width: image.size.width, height: height))
        (text as NSString).draw(with: CGRect(x: padding, y: image.size.height + padding, width: image.size.width - padding * 2, height: height - padding * 2), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
    }
}
