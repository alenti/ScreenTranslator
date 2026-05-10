import SwiftUI
import Translation

@main
struct ScreenTranslatorApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var environment = AppEnvironment.bootstrap()

    var body: some Scene {
        WindowGroup {
            ScreenTranslatorRootView()
                .background {
                    TranslationSessionHostView(
                        broker: environment.container.translationSessionBroker
                    )
                }
                .environmentObject(environment)
                .environmentObject(environment.coordinator)
                .task(id: scenePhase) {
                    guard scenePhase == .active else {
                        return
                    }

                    await environment.consumePendingScreenshotIfNeeded()
                }
        }
    }
}

private struct TranslationSessionHostView: View {
    let broker: TranslationSessionBroker

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .translationTask(
                source: TranslationSessionBroker.sourceLanguage,
                target: TranslationSessionBroker.targetLanguage
            ) { session in
                await broker.run(with: session)
            }
    }
}

private struct ScreenTranslatorRootView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        switch coordinator.route {
        case .idle, .processing:
            ProcessingView(viewModel: environment.processingViewModel)
        case .floatingPreview:
            FloatingPreviewFlowView(viewModel: environment.processingViewModel)
        case .result:
            ResultOverlayView(
                viewModel: environment.container.makeResultOverlayViewModel(
                    result: coordinator.latestResult
                )
            )
        case .error:
            ErrorView(
                viewModel: environment.container.makeErrorViewModel(
                    error: coordinator.activeError
                )
            )
        case .settings:
            SettingsView(viewModel: environment.settingsViewModel)
        case .debug:
            DebugView(
                viewModel: environment.container.makeDebugViewModel(
                    result: coordinator.latestResult,
                    activeJob: coordinator.activeJob
                )
            )
        }
    }
}
