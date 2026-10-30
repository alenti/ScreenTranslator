import Foundation

@MainActor
final class AppCoordinator: ObservableObject {
    @Published private(set) var route: AppRoute
    @Published private(set) var activeError: AppError?
    @Published private(set) var activeJob: ProcessingJob?
    /// Kept after the viewer closes so Home can reopen it without another translation.
    @Published private(set) var processedScreenshot: ProcessedScreenshot?
    @Published private(set) var activeLaunchBehavior: IntentHandoffRequest.LaunchBehavior?
    @Published var showingSettings = false

    init(route: AppRoute = .idle) {
        self.route = route
    }

    func showProcessing(
        job: ProcessingJob? = nil,
        launchBehavior: IntentHandoffRequest.LaunchBehavior = .openInApp
    ) {
        activeJob = job
        activeError = nil
        activeLaunchBehavior = launchBehavior
        processedScreenshot = nil
        showingSettings = false
        route = .processing
    }

    func showFloatingPreview(job: ProcessingJob? = nil) {
        activeJob = job
        activeError = nil
        activeLaunchBehavior = .floatingPreview
        processedScreenshot = nil
        showingSettings = false
        route = .floatingPreview
    }

    func showProcessedResult(_ result: ProcessedScreenshot, floating: Bool = false) {
        processedScreenshot = result
        activeError = nil
        activeLaunchBehavior = floating ? .floatingPreview : .openInApp
        route = floating ? .floatingPreview : .result
    }

    /// Reuses the completed result object; never starts processing.
    func openFullViewer() {
        guard processedScreenshot != nil else { return }
        activeLaunchBehavior = .openInApp
        route = .result
    }

    func showError(_ error: AppError) {
        activeError = error
        if activeLaunchBehavior == nil { activeLaunchBehavior = .openInApp }
        route = activeLaunchBehavior == .floatingPreview ? .floatingPreview : .processing
    }

    /// Back to Home. The last result stays available until a new job or a memory warning replaces it.
    func returnHome() {
        activeError = nil
        activeLaunchBehavior = nil
        if processedScreenshot == nil { activeJob = nil }
        route = .idle
    }

    func openModelSettings() {
        returnHome()
        showingSettings = true
    }

    func releaseLastResult() {
        guard route == .idle else { return }
        processedScreenshot = nil
        activeJob = nil
    }
}
