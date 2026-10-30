import SwiftUI

@main
struct ScreenTranslatorApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var environment = AppEnvironment.bootstrap()

    var body: some Scene {
        WindowGroup {
            ScreenTranslatorRootView()
                .environmentObject(environment)
                .environmentObject(environment.coordinator)
                .environmentObject(environment.settingsViewModel)
                #if DEBUG
                .task {
                    UIDevice.current.isBatteryMonitoringEnabled = true
                    if let mode = ProcessInfo.processInfo.environment["PHASE2_MODE"] {
                        await Phase2Checks.run(environment:environment, mode:mode)
                    }
                    if ProcessInfo.processInfo.environment["PHASE1_CHECKS"] == "1" {
                        do { try await Phase1Checks.run(engine: environment.engine) }
                        catch { try? writeJSON(["passed":false,"error":error.localizedDescription], to: documents.appendingPathComponent("phase1-checks.json")) }
                    }
                }
                #endif
                .task(id: scenePhase) {
                    await environment.setActive(scenePhase == .active)
                }
                .onReceive(NotificationCenter.default.publisher(for: TemporaryImageStore.requestStored)) { _ in
                    Task { await environment.consumePendingScreenshotIfNeeded() }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    Task { await environment.memoryWarningReceived() }
                }
        }
    }
}

private struct ScreenTranslatorRootView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var coordinator: AppCoordinator
    @EnvironmentObject private var settings: SettingsViewModel

    var body: some View {
        Group {
            switch coordinator.route {
            case .idle:
                HomeView()
            case .processing:
                TranslationProgressView(viewModel: environment.processingViewModel)
            case .floatingPreview:
                FloatingPreviewFlowView(viewModel: environment.processingViewModel)
            case .result:
                if let processed = coordinator.processedScreenshot {
                    ResultOverlayView(viewModel: ResultOverlayViewModel(result: processed))
                        .id(processed.requestID)
                } else {
                    HomeView()
                }
            }
        }
        .animation(.default, value: coordinator.route)
        // A Shortcut handoff takes priority; onboarding resumes at the saved step afterwards.
        .fullScreenCover(isPresented: Binding(
            get: { !settings.onboardingCompleted && coordinator.route == .idle && !isRunningChecks },
            set: { _ in }
        )) {
            OnboardingView()
                .environmentObject(environment)
                .environmentObject(settings)
        }
    }

    private var isRunningChecks: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["PHASE2_MODE"] != nil || ProcessInfo.processInfo.environment["UITEST_SKIP_ONBOARDING"] == "1"
        #else
        false
        #endif
    }
}
