import AppIntents
import UniformTypeIdentifiers

struct TranslateScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "Open in App Translator"
    static var description = IntentDescription(
        "Accepts a screenshot from Shortcuts, stores it safely, and opens ScreenTranslator in the existing fullscreen processing flow."
    )
    static var openAppWhenRun: Bool = true

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
        let output = await QuickLookIntentRunner().run(
            screenshot: screenshot,
            mode: .translated
        )
        QuickLookIntentReturnLogger().logReturnStart(output)

        return .result(value: output.file)
    }
}

struct FloatingScreenTranslateIntent: AppIntent {
    static var title: LocalizedStringResource = "Floating Screen Translator"
    static var description = IntentDescription(
        "Accepts a screenshot from Shortcuts, stores it safely, and opens ScreenTranslator in the lightweight floating preview flow."
    )
    static var openAppWhenRun: Bool = true

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
        let temporaryImageStore = TemporaryImageStore()
        let decodedScreenshot = try decoder.decode(screenshot)

        try await temporaryImageStore.store(
            IntentHandoffRequest(
                screenshot: decodedScreenshot,
                launchBehavior: launchBehavior
            )
        )
    }
}
