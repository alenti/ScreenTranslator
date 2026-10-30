import XCTest

/// Captures the Shortcuts and Action Button screenshots shown in the app's setup guide.
/// Skipped in normal runs; set CAPTURE_SETUP_GUIDE=1 (TEST_RUNNER_CAPTURE_SETUP_GUIDE=1 via xcodebuild) on an erased simulator.
/// The Setup* assets are 660px-wide crops of "shortcut-quick-preview" (y 200, h 1220), "shortcut-open-in-app" (y 200, h 760)
/// and "action-button-done" (y 790, h 1370) from the iPhone 17 Pro Max captures.
final class SetupGuideCaptureTests: XCTestCase {
    private struct Labels {
        let language: [String]
        let createShortcut: String
        let takeScreenshot: (search: String, cell: String)
        let quickLook: (search: String, cell: String)
        let shortcutPage: String
        let chooseShortcut: String
        let translateForQuickLook: String
        let translateInApp: String
    }

    private let russian = Labels(language: ["-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"],
                                 createShortcut: "Создать быструю команду",
                                 takeScreenshot: ("снимок экрана", "Сделать снимок экрана"),
                                 quickLook: ("Быстро просмотреть", "Быстро просмотреть"),
                                 shortcutPage: "Быстрая команда",
                                 chooseShortcut: "Выбрать команду…",
                                 translateForQuickLook: "Перевести скриншот для просмотра",
                                 translateInApp: "Перевести скриншот в приложении")

    private let english = Labels(language: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"],
                                 createShortcut: "Create Shortcut",
                                 takeScreenshot: ("screenshot", "Take Screenshot"),
                                 quickLook: ("Quick Look", "Quick Look"),
                                 shortcutPage: "Shortcut",
                                 chooseShortcut: "Choose a Shortcut…",
                                 translateForQuickLook: "Translate Screenshot for Quick Look",
                                 translateInApp: "Translate Screenshot in App")

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CAPTURE_SETUP_GUIDE"] == "1")
        continueAfterFailure = false
    }

    @MainActor func testCaptureRussian() throws { try capture(russian) }
    @MainActor func testCaptureEnglish() throws { try capture(english) }

    /// Review shots of the app's own Home, Settings and setup guide in both languages.
    @MainActor func testCaptureAppScreens() throws {
        for labels in [english, russian] {
            let app = XCUIApplication()
            app.launchArguments = labels.language + ["-onboardingCompleted", "YES"]
            app.launch()
            let tag = labels.language == english.language ? "en" : "ru"
            dump(app, "home-\(tag)")
            app.buttons["home.settings"].tap()
            sleep(1)
            dump(app, "settings-\(tag)")
            app.buttons.matching(NSPredicate(format: "label IN %@", ["Action Button Setup", "Настройка кнопки действия"])).firstMatch.tap()
            sleep(1)
            dump(app, "setup-\(tag)-1")
            app.swipeUp(); sleep(1)
            dump(app, "setup-\(tag)-2")
            app.swipeUp(); sleep(1)
            dump(app, "setup-\(tag)-3")
            app.terminate()
        }
    }

    @MainActor private func capture(_ labels: Labels) throws {
        // Shortcuts lists the app's actions only after the app has run once.
        let app = XCUIApplication()
        app.launchArguments = labels.language
        app.launch(); sleep(3); app.terminate()
        let shortcuts = XCUIApplication(bundleIdentifier: "com.apple.shortcuts")
        shortcuts.launchArguments = labels.language
        shortcuts.launch()
        dismissWelcome(shortcuts)
        dump(shortcuts, "library")
        shortcuts.buttons[labels.createShortcut].tap()
        dismissWelcome(shortcuts)
        addAction(shortcuts, labels.takeScreenshot)
        addAction(shortcuts, ("ChinaTap", labels.translateForQuickLook))
        addAction(shortcuts, labels.quickLook)
        dump(shortcuts, "shortcut-quick-preview")
        shortcuts.buttons["BackButton"].firstMatch.tap() // Leaving the editor saves the shortcut.
        shortcuts.buttons[labels.createShortcut].tap()
        addAction(shortcuts, labels.takeScreenshot)
        addAction(shortcuts, ("ChinaTap", labels.translateInApp))
        dump(shortcuts, "shortcut-open-in-app")
        shortcuts.buttons["BackButton"].firstMatch.tap()

        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launchArguments = labels.language
        settings.launch()
        settings.buttons["com.apple.settings.actionButton"].tap()
        sleep(2)
        var seen: [String] = []
        for _ in 0..<14 where !settings.staticTexts[labels.shortcutPage].exists {
            seen.append(settings.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " | "))
            settings.swipeLeft(); sleep(1)
        }
        let pages = XCTAttachment(string: seen.joined(separator: "\n")); pages.lifetime = .keepAlways; add(pages)
        dump(settings, "action-button")
        settings.buttons[labels.chooseShortcut].tap()
        sleep(2)
        dump(settings, "choose-shortcut")
        // iOS names a new shortcut after one of its actions, and which one differs by language.
        settings.staticTexts.matching(NSPredicate(format: "label IN %@", [labels.quickLook.cell, labels.translateForQuickLook])).firstMatch.tap()
        sleep(2)
        dump(settings, "action-button-done")
    }

    @MainActor private func dismissWelcome(_ app: XCUIApplication) {
        for label in ["Продолжить", "Continue", "Не сейчас", "Not Now"] where app.buttons[label].waitForExistence(timeout: 1) {
            app.buttons[label].tap()
        }
    }

    @MainActor private func addAction(_ app: XCUIApplication, _ action: (search: String, cell: String)) {
        let field = app.searchFields.matching(NSPredicate(format: "placeholderValue IN %@", ["Поиск действий", "Search for actions", "Search Actions"])).firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        dismissWelcome(app)
        app.typeText(action.search)
        let result = app.cells[action.cell].firstMatch
        // A freshly installed app's actions reach Shortcuts search after a short indexing delay.
        for _ in 0..<12 where !result.waitForExistence(timeout: 5) {
            app.typeText(XCUIKeyboardKey.delete.rawValue); app.typeText(String(action.search.last!))
        }
        XCTAssertTrue(result.exists, "No action \(action.cell)")
        result.tap()
        sleep(1)
    }

    @MainActor private func dump(_ app: XCUIApplication, _ name: String) {
        let tree = XCTAttachment(string: app.debugDescription); tree.name = name + "-tree"; tree.lifetime = .keepAlways; add(tree)
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)
    }
}
