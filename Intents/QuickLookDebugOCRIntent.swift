import AppIntents
import UniformTypeIdentifiers

struct QuickLookDebugOCRIntent: AppIntent {
    static var title: LocalizedStringResource = "Debug Quick Look OCR"
    static var description = IntentDescription(
        "Accepts a screenshot from Shortcuts and returns a diagnostic OCR PNG for the Shortcuts Quick Look action."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Screenshot",
        supportedContentTypes: [.image],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let output = await QuickLookIntentRunner().run(
            screenshot: screenshot,
            mode: .debug
        )
        QuickLookIntentReturnLogger().logReturnStart(output)

        return .result(value: output.file)
    }
}
