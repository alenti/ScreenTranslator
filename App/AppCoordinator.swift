import Foundation

@MainActor
final class AppCoordinator: ObservableObject {
    @Published private(set) var route: AppRoute
    @Published private(set) var activeError: AppError?
    @Published private(set) var activeJob: ProcessingJob?
    @Published private(set) var latestResult: OverlayRenderResult

    init(
        route: AppRoute = .idle,
        activeError: AppError? = nil,
        activeJob: ProcessingJob? = nil,
        latestResult: OverlayRenderResult = .placeholder()
    ) {
        self.route = route
        self.activeError = activeError
        self.activeJob = activeJob
        self.latestResult = latestResult
    }

    func showProcessing(job: ProcessingJob? = nil) {
        activeJob = job
        activeError = nil
        route = .processing
    }

    func showResult(_ result: OverlayRenderResult? = nil) {
        if let result {
            latestResult = result
        }

        activeError = nil
        route = .result
    }

    func showError(_ error: AppError) {
        activeError = error
        route = .error
    }

    func showSettings() {
        route = .settings
    }

    func showDebug() {
        route = .debug
    }

    func returnToProcessing() {
        route = activeJob == nil ? .idle : .processing
    }
}
