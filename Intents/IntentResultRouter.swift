import Foundation

struct IntentResultRouter {
    func routeForIncomingScreenshot(_ input: ScreenshotInput) -> AppRoute {
        _ = input
        return .processing
    }
}
