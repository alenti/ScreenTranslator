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
                self?.coordinator.showResult(result)
            },
            onFailed: { [weak self] error in
                self?.coordinator.showError(error)
            }
        )
    }

    static func bootstrap() -> AppEnvironment {
        AppEnvironment(container: AppContainer())
    }

    func consumePendingScreenshotIfNeeded() async {
        do {
            guard let input = try await container.temporaryImageStore.consumeLatestInput() else {
                return
            }

            let job = ProcessingJob(input: input)
            processingViewModel.handleIncomingScreenshot(job)

            switch container.intentResultRouter.routeForIncomingScreenshot(input) {
            case .processing:
                coordinator.showProcessing(job: job)
            case .error:
                coordinator.showError(.intentInputFailure)
            default:
                coordinator.showProcessing(job: job)
            }
        } catch {
            coordinator.showError(.intentInputFailure)
        }
    }
}
