import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let container: AppContainer
    let coordinator: AppCoordinator
    let processingViewModel: ProcessingViewModel
    let settingsViewModel: SettingsViewModel

    init(container: AppContainer) {
        let processingViewModel = container.makeProcessingViewModel()
        let settingsViewModel = container.makeSettingsViewModel()
        let placeholderResult = OverlayRenderResult.placeholder(
            style: settingsViewModel.settings.overlayStyle
        )

        self.container = container
        self.processingViewModel = processingViewModel
        self.settingsViewModel = settingsViewModel
        self.coordinator = AppCoordinator(latestResult: placeholderResult)

        self.processingViewModel.configure(
            onCompleted: { [weak self] result in
                guard let self else {
                    return
                }

                switch self.coordinator.activeLaunchBehavior {
                case .floatingPreview:
                    self.coordinator.retainFloatingPreviewResult(result)
                case .openInApp, nil:
                    self.coordinator.showResult(result)
                }
            },
            onFailed: { [weak self] error in
                guard let self else {
                    return
                }

                switch self.coordinator.activeLaunchBehavior {
                case .floatingPreview:
                    self.coordinator.retainFloatingPreviewError(error)
                case .openInApp, nil:
                    self.coordinator.showError(error)
                }
            }
        )
    }

    static func bootstrap() -> AppEnvironment {
        AppEnvironment(container: AppContainer())
    }

    func consumePendingScreenshotIfNeeded() async {
        do {
            guard let request = try await container.temporaryImageStore.consumeLatestRequest() else {
                return
            }

            guard let route = container.intentResultRouter.routeForIncomingRequest(request) else {
                return
            }

            let job = ProcessingJob(input: request.screenshot)

            switch route {
            case .processing:
                coordinator.showProcessing(
                    job: job,
                    launchBehavior: request.launchBehavior
                )
                processingViewModel.handleIncomingScreenshot(job)
            case .floatingPreview:
                coordinator.showFloatingPreview(job: job)
                processingViewModel.handleIncomingScreenshot(job)
            case .error:
                coordinator.showError(.intentInputFailure)
            default:
                coordinator.showProcessing(
                    job: job,
                    launchBehavior: request.launchBehavior
                )
                processingViewModel.handleIncomingScreenshot(job)
            }
        } catch {
            coordinator.showError(.intentInputFailure)
        }
    }
}
