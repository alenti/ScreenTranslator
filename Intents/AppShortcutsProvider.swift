import AppIntents

// FloatingScreenTranslateIntent is intentionally not listed: it stays runnable for installed shortcuts only.
struct ScreenTranslatorShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FastTranslateScreenshotIntent(),
            phrases: [
                "Quick Look translate screenshot with \(.applicationName)",
                "Preview screenshot in Quick Look with \(.applicationName)",
                "Quick Look screen translator with \(.applicationName)"
            ],
            shortTitle: "Quick Preview",
            systemImageName: "eye"
        )

        AppShortcut(
            intent: TranslateScreenshotIntent(),
            phrases: [
                "Open in app translator with \(.applicationName)",
                "Open translated screenshot in \(.applicationName)",
                "Translate screenshot in app with \(.applicationName)"
            ],
            shortTitle: "Open in App",
            systemImageName: "arrow.up.forward.app"
        )
    }
}
