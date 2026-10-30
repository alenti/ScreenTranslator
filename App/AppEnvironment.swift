import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let temporaryImageStore = TemporaryImageStore.shared
    let coordinator: AppCoordinator
    let processingViewModel: ProcessingViewModel
    let settingsViewModel: SettingsViewModel
    let engine: HyMTTranslator
    var isActive = false
    private var draining = false
    private var drainAgain = false

    init() {
        engine = HyMTTranslator.shared
        processingViewModel = ProcessingViewModel(engine: engine)
        settingsViewModel = SettingsViewModel()
        coordinator = AppCoordinator()
        processingViewModel.onLocalCompleted = { [weak self] result in
            guard let self else { return }
            self.coordinator.showProcessedResult(result, floating: self.coordinator.activeLaunchBehavior == .floatingPreview)
        }
        processingViewModel.onFailed = { [weak self] error in
            self?.coordinator.showError(error)
        }
    }

    static func bootstrap() -> AppEnvironment { AppEnvironment() }

    /// Starts an in-app translation (Photos picker or retry) through the same pipeline as Shortcuts.
    func translate(_ input: ScreenshotInput) {
        let job = ProcessingJob(id: input.id, input: input)
        processingViewModel.diagnosticRoute = "app"
        coordinator.showProcessing(job: job)
        processingViewModel.handleIncomingScreenshot(job, localTarget: settingsViewModel.localTarget)
    }

    func retryLastJob() {
        guard let job = coordinator.activeJob else { return }
        if coordinator.route == .floatingPreview { coordinator.showFloatingPreview(job: job) }
        else { coordinator.showProcessing(job: job) }
        processingViewModel.handleIncomingScreenshot(job, localTarget: settingsViewModel.localTarget)
    }

    func closeTranslation() {
        if !processingViewModel.state.isTerminal { processingViewModel.cancelCurrentJob() }
        processingViewModel.resetToPlaceholderState()
        coordinator.returnHome()
    }

    func consumePendingScreenshotIfNeeded() async {
        guard isActive else { return }
        if draining { drainAgain = true; return }
        draining = true
        defer { draining = false }
        do {
            repeat {
                drainAgain = false
                while isActive, let request = try await temporaryImageStore.consumeLatestRequest() {
                    let job = ProcessingJob(id: request.screenshot.id, input: request.screenshot)
                    processingViewModel.diagnosticRoute = request.launchBehavior == .floatingPreview ? "B" : "A"
                    switch request.launchBehavior {
                    case .openInApp:
                        coordinator.showProcessing(job: job, launchBehavior: .openInApp)
                    case .floatingPreview:
                        coordinator.showFloatingPreview(job: job)
                    }
                    processingViewModel.handleIncomingScreenshot(job, localTarget: settingsViewModel.localTarget)
                }
            } while isActive && drainAgain
        } catch {
            coordinator.showProcessing()
            coordinator.showError(.intentInputFailure)
        }
    }

    func setActive(_ active: Bool) async {
        isActive = active
        processingViewModel.isAppActive = active
        if active {
            settingsViewModel.refreshModelState()
            await consumePendingScreenshotIfNeeded()
        } else {
            await processingViewModel.suspendLocalProcessing()
        }
    }

    func memoryWarningReceived() async {
        await processingViewModel.memoryWarningReceived()
        coordinator.releaseLastResult()
    }

    func openFullViewer() {
        #if DEBUG
        Task { await openFullViewerRecordingReuse() }
        #else
        coordinator.openFullViewer()
        #endif
    }

    #if DEBUG
    private func openFullViewerRecordingReuse() async {
        guard let result = coordinator.processedScreenshot else { return }
        let before = await engine.diagnosticCounters
        coordinator.openFullViewer()
        let after = await engine.diagnosticCounters
        let same = coordinator.processedScreenshot?.renderedImage === result.renderedImage
        let folder = documents.appendingPathComponent("Acceptance")
        try? FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let proof: [String:Any] = ["requestID":result.requestID.uuidString,"before":before,"after":after,
            "sameRenderedImage":same,"sameRequestID":coordinator.processedScreenshot?.requestID == result.requestID,
            "route":String(describing:coordinator.route),"noAdditionalProcessing":before == after,"timestamp":Date().timeIntervalSince1970]
        try? writeJSON(proof,to:folder.appendingPathComponent("viewer-reuse-\(result.requestID.uuidString).json"))
        print("ACCEPTANCE viewer-reuse \(result.requestID) sameImage=\(same) countersUnchanged=\(before == after)")
    }
    #endif
}
