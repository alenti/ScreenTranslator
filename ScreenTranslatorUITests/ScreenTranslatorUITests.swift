import XCTest

final class ScreenTranslatorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor func testOnboardingWalkthroughReachesHome() throws {
        let app = XCUIApplication()
        app.launchArguments += english + ["-onboardingCompleted", "NO", "-onboardingStep", "0"]
        app.launch()
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        attach(app, "onboarding-welcome")
        for page in 1...5 {
            next.tap()
            attach(app, "onboarding-\(page)")
        }
        next.tap()
        XCTAssertTrue(app.buttons["home.translateImage"].waitForExistence(timeout: 10))
        attach(app, "home")
    }

    @MainActor func testSettingsShowsModesAndModel() throws {
        let app = launchedApp()
        app.buttons["home.settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))
        attach(app, "settings")
        app.buttons["Action Button Setup"].tap()
        XCTAssertTrue(app.staticTexts["Quick Preview"].waitForExistence(timeout: 10))
        attach(app, "action-button-setup")
    }

    @MainActor func testFloatingCancelRetry() throws {
        let app = launchedApp(mode: "ui")
        let cancel = app.buttons["floating.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 30))
        attach(app, "floating-progress")
        cancel.tap()
        let retry = app.buttons["floating.retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10)); retry.tap()
        XCTAssertTrue(cancel.waitForExistence(timeout: 10)); cancel.tap()
        app.buttons["floating.dismiss"].tap()
        XCTAssertTrue(app.buttons["home.translateImage"].waitForExistence(timeout: 10))
        attach(app, "floating-cancel-retry-dismiss")
    }

    @MainActor func testFloatingRecordedResultFullViewer() throws {
        let app = launchedApp(mode: "presentation")
        let full = app.buttons["floating.openFullViewer"]
        XCTAssertTrue(full.waitForExistence(timeout: 30))
        attach(app, "floating-recorded-completed"); full.tap()
        XCTAssertTrue(app.buttons["Original"].waitForExistence(timeout: 10))
        attach(app, "full-viewer-reused")
        app.buttons["viewer.close"].tap()
        XCTAssertTrue(app.buttons["home.translateImage"].waitForExistence(timeout: 10))
        attach(app, "home-with-last-translation")
    }

    @MainActor func testFloatingDismissal() throws {
        let app = launchedApp(mode: "presentation")
        XCTAssertTrue(app.buttons["floating.dismiss"].waitForExistence(timeout: 30))
        app.buttons["floating.dismiss"].tap()
        XCTAssertTrue(app.buttons["home.translateImage"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["floating.openFullViewer"].exists)
        attach(app, "floating-dismissed")
    }

    /// Text queries below are English; the simulator may run in another language.
    private let english = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]

    @MainActor private func launchedApp(mode: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += english + ["-onboardingCompleted", "YES"]
        if let mode { app.launchEnvironment["PHASE2_MODE"] = mode }
        app.launch()
        return app
    }

    @MainActor private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
