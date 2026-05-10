import AppIntents
import UniformTypeIdentifiers

struct QuickLookEchoScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "Debug Echo Screenshot"
    static var description = IntentDescription(
        "Accepts a screenshot from Shortcuts and returns it as a PNG file without OCR or overlay rendering."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Screenshot",
        supportedContentTypes: [.image],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let output = await QuickLookIntentRunner().runEcho(
            screenshot: screenshot
        )
        QuickLookIntentReturnLogger().logReturnStart(output)

        return .result(value: output.file)
    }
}
