import Foundation

@MainActor
final class AppCoordinator: ObservableObject {
    @Published private(set) var route: AppRoute
    @Published private(set) var activeError: AppError?
    @Published private(set) var activeJob: ProcessingJob?
    @Published private(set) var latestResult: OverlayRenderResult
    @Published private(set) var activeLaunchBehavior: IntentHandoffRequest.LaunchBehavior?

    init(
        route: AppRoute = .idle,
        activeError: AppError? = nil,
        activeJob: ProcessingJob? = nil,
        latestResult: OverlayRenderResult = .placeholder(),
        activeLaunchBehavior: IntentHandoffRequest.LaunchBehavior? = nil
    ) {
        self.route = route
        self.activeError = activeError
        self.activeJob = activeJob
        self.latestResult = latestResult
        self.activeLaunchBehavior = activeLaunchBehavior
    }

    func showProcessing(
        job: ProcessingJob? = nil,
        launchBehavior: IntentHandoffRequest.LaunchBehavior = .openInApp
    ) {
        activeJob = job
        activeError = nil
        activeLaunchBehavior = launchBehavior
        route = .processing
    }

    func showFloatingPreview(job: ProcessingJob? = nil) {
        activeJob = job
        activeError = nil
        activeLaunchBehavior = .floatingPreview
        route = .floatingPreview
    }

    func showResult(_ result: OverlayRenderResult? = nil) {
        if let result {
            latestResult = result
        }

        activeError = nil
        activeLaunchBehavior = .openInApp
        route = .result
    }

    func retainFloatingPreviewResult(_ result: OverlayRenderResult? = nil) {
        if let result {
            latestResult = result
        }

        activeError = nil
        activeLaunchBehavior = .floatingPreview
        route = .floatingPreview
    }

    func showError(_ error: AppError) {
        activeError = error
        activeLaunchBehavior = .openInApp
        route = .error
    }

    func retainFloatingPreviewError(_ error: AppError) {
        activeError = error
        activeLaunchBehavior = .floatingPreview
        route = .floatingPreview
    }

    func showSettings() {
        route = .settings
    }

    func showDebug() {
        route = .debug
    }

    func returnToProcessing() {
        guard activeJob != nil else {
            route = .idle
            return
        }

        switch activeLaunchBehavior {
        case .floatingPreview:
            route = .floatingPreview
        case .openInApp, nil:
            route = .processing
        }
    }
}
