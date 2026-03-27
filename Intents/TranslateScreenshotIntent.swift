import AppIntents

struct TranslateScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "Translate Screenshot"
    static var description = IntentDescription(
        "Accepts a screenshot from Shortcuts, stores it safely, and opens ScreenTranslator on the processing flow."
    )
    static var openAppWhenRun: Bool = true

    @Parameter(
        title: "Screenshot",
        supportedTypeIdentifiers: ["public.image"],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult {
        let decoder = IntentInputDecoder()
        let temporaryImageStore = TemporaryImageStore()

        let decodedScreenshot = try decoder.decode(screenshot)
        try await temporaryImageStore.store(decodedScreenshot)

        return .result()
    }
}
