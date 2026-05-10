import Foundation

struct IntentHandoffRequest: Equatable, Sendable, Codable {
    enum LaunchBehavior: String, CaseIterable, Sendable, Codable {
        case floatingPreview
        case openInApp
    }

    let screenshot: ScreenshotInput
    let launchBehavior: LaunchBehavior
}

struct IntentResultRouter {
    func routeForIncomingRequest(_ request: IntentHandoffRequest) -> AppRoute? {
        switch request.launchBehavior {
        case .floatingPreview:
            return .floatingPreview
        case .openInApp:
            return .processing
        }
    }

    func routeForIncomingScreenshot(_ input: ScreenshotInput) -> AppRoute {
        _ = input
        return routeForIncomingRequest(
            IntentHandoffRequest(
                screenshot: input,
                launchBehavior: .openInApp
            )
        ) ?? .processing
    }
}
