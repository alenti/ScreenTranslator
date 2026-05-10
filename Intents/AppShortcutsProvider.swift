import AppIntents

struct ScreenTranslatorShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TranslateScreenshotIntent(),
            phrases: [
                "Open in app translator with \(.applicationName)",
                "Open translated screenshot in \(.applicationName)",
                "Translate screenshot in app with \(.applicationName)"
            ],
            shortTitle: "Open in App Translator",
            systemImageName: "text.viewfinder"
        )

        AppShortcut(
            intent: FloatingScreenTranslateIntent(),
            phrases: [
                "Floating screen translator with \(.applicationName)",
                "Preview translated screen with \(.applicationName)",
                "Quick translate screenshot with \(.applicationName)"
            ],
            shortTitle: "Floating Screen Translator",
            systemImageName: "rectangle.on.rectangle"
        )

        AppShortcut(
            intent: QuickLookTranslateScreenshotIntent(),
            phrases: [
                "Quick Look translate screenshot with \(.applicationName)",
                "Preview screenshot in Quick Look with \(.applicationName)",
                "Quick Look screen translator with \(.applicationName)"
            ],
            shortTitle: "Quick Look Translate Screenshot",
            systemImageName: "doc.viewfinder"
        )

        AppShortcut(
            intent: QuickLookDebugOCRIntent(),
            phrases: [
                "Debug Quick Look OCR with \(.applicationName)",
                "Inspect Quick Look OCR with \(.applicationName)",
                "Show Quick Look OCR diagnostics with \(.applicationName)"
            ],
            shortTitle: "Debug Quick Look OCR",
            systemImageName: "ladybug"
        )

        AppShortcut(
            intent: QuickLookEchoScreenshotIntent(),
            phrases: [
                "Debug echo screenshot with \(.applicationName)",
                "Echo screenshot to Quick Look with \(.applicationName)",
                "Test Quick Look screenshot return with \(.applicationName)"
            ],
            shortTitle: "Debug Echo Screenshot",
            systemImageName: "doc"
        )

        AppShortcut(
            intent: QuickLookDirectEchoScreenshotIntent(),
            phrases: [
                "Debug direct echo screenshot with \(.applicationName)",
                "Direct echo screenshot to Quick Look with \(.applicationName)",
                "Test direct screenshot return with \(.applicationName)"
            ],
            shortTitle: "Debug Direct Echo Screenshot",
            systemImageName: "doc.on.doc"
        )

        AppShortcut(
            intent: QuickLookTinyPNGIntent(),
            phrases: [
                "Debug tiny PNG with \(.applicationName)",
                "Test tiny PNG Quick Look with \(.applicationName)",
                "Return tiny PNG with \(.applicationName)"
            ],
            shortTitle: "Debug Tiny PNG",
            systemImageName: "photo"
        )
    }
}
