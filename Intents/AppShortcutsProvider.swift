import AppIntents

struct ScreenTranslatorShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TranslateScreenshotIntent(),
            phrases: [
                "Translate screenshot with \(.applicationName)",
                "Process screenshot with \(.applicationName)",
                "Open \(.applicationName) from screenshot"
            ],
            shortTitle: "Translate Screenshot",
            systemImageName: "text.viewfinder"
        )
    }
}
