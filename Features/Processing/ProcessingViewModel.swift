import Foundation

@MainActor
final class ProcessingViewModel: ObservableObject {
    @Published private(set) var state: ProcessingState
    @Published private(set) var statusMessage: String
    @Published private(set) var detailMessage: String
    @Published private(set) var activeJob: ProcessingJob?
    @Published private(set) var latestResult: OverlayRenderResult?
    @Published private(set) var activeError: AppError?

    private let orchestrator: ProcessingOrchestrator
    private var processingTask: Task<Void, Never>?
    private var activeRunID: UUID?
    private var onCompleted: ((OverlayRenderResult) -> Void)?
    private var onFailed: ((AppError) -> Void)?

    init(orchestrator: ProcessingOrchestrator) {
        self.orchestrator = orchestrator
        self.activeJob = nil
        self.latestResult = nil
        self.activeError = nil
        self.state = .idle
        self.statusMessage = "Waiting for screenshot input."
        self.detailMessage = "The app will start processing as soon as a screenshot is handed off from Shortcuts."
    }

    func configure(
        onCompleted: @escaping (OverlayRenderResult) -> Void,
        onFailed: @escaping (AppError) -> Void
    ) {
        self.onCompleted = onCompleted
        self.onFailed = onFailed
    }

    func resetToPlaceholderState() {
        processingTask?.cancel()
        processingTask = nil
        activeRunID = nil
        activeJob = nil
        latestResult = nil
        activeError = nil
        state = .idle
        statusMessage = "Waiting for screenshot input."
        detailMessage = "The processing pipeline is idle and ready for the next screenshot."
    }

    func handleIncomingScreenshot(_ job: ProcessingJob) {
        processingTask?.cancel()
        let runID = UUID()
        activeRunID = runID
        activeJob = job
        latestResult = nil
        activeError = nil
        state = .receivedInput
        statusMessage = "Screenshot received from Shortcuts."
        detailMessage = "Starting the processing pipeline for this screenshot."

        processingTask = Task { [weak self] in
            await self?.runProcessingPipeline(
                for: job,
                runID: runID
            )
        }
    }

    func retryCurrentJob() {
        guard let activeJob else {
            return
        }

        handleIncomingScreenshot(activeJob)
    }

    var latestInputSummary: String? {
        guard let activeJob else {
            return nil
        }

        let width = Int(activeJob.input.size.width)
        let height = Int(activeJob.input.size.height)
        let sourceName = activeJob.input.sourceMetadata.sourceName
        let filename = activeJob.input.sourceMetadata.automationName ?? "unnamed image"

        return "\(sourceName) • \(filename) • \(width)x\(height)"
    }

    private func runProcessingPipeline(
        for job: ProcessingJob,
        runID: UUID
    ) async {
        defer {
            finishRunIfNeeded(runID)
        }

        do {
            let result = try await orchestrator.process(job) { [weak self] progress in
                await self?.apply(
                    progress,
                    for: runID,
                    jobID: job.id
                )
            }

            guard shouldAcceptUpdates(
                for: runID,
                jobID: job.id
            ), Task.isCancelled == false else {
                return
            }

            latestResult = result
            activeError = nil
            state = .completed
            statusMessage = "Processing complete."
            detailMessage = "The screenshot passed normalization, OCR, grouping, translation, and placeholder result packaging."
            onCompleted?(result)
        } catch let error as AppError {
            guard shouldAcceptUpdates(
                for: runID,
                jobID: job.id
            ), Task.isCancelled == false else {
                return
            }

            latestResult = nil
            activeError = error
            state = .failed
            statusMessage = "Processing failed."
            detailMessage = error.errorDescription ?? "The processing pipeline failed."
            onFailed?(error)
        } catch {
            guard shouldAcceptUpdates(
                for: runID,
                jobID: job.id
            ), Task.isCancelled == false else {
                return
            }

            let appError = AppError.featureNotReady(
                "An unexpected processing error occurred."
            )
            latestResult = nil
            activeError = appError
            state = .failed
            statusMessage = "Processing failed."
            detailMessage = appError.errorDescription ?? "The processing pipeline failed."
            onFailed?(appError)
        }
    }

    private func apply(
        _ progress: ProcessingOrchestrator.ProgressUpdate,
        for runID: UUID,
        jobID: UUID
    ) {
        guard shouldAcceptUpdates(for: runID, jobID: jobID) else {
            return
        }

        switch progress {
        case .preparingImage(let imageSize):
            state = .preparingImage
            statusMessage = "Normalizing screenshot input."
            detailMessage = "Preparing \(Int(imageSize.width))x\(Int(imageSize.height)) image data for OCR."
        case .performingOCR:
            state = .performingOCR
            statusMessage = "Recognizing Chinese text."
            detailMessage = "Running Vision OCR on the normalized screenshot."
        case .groupingText(let observationCount):
            state = .groupingText
            statusMessage = "Grouping OCR observations."
            detailMessage = "Combining \(observationCount) OCR observations into logical text blocks."
        case .translatingBlocks(let blockCount):
            state = .translatingBlocks
            statusMessage = "Translating grouped blocks."
            detailMessage = "Translating \(blockCount) grouped text blocks from Chinese to Russian on-device."
        case .renderingOverlay(let translationCount):
            state = .renderingOverlay
            statusMessage = "Packaging placeholder result."
            detailMessage = "Preparing a result object for \(translationCount) translated blocks while overlay rendering is still placeholder."
        }
    }

    private func shouldAcceptUpdates(
        for runID: UUID,
        jobID: UUID
    ) -> Bool {
        activeRunID == runID && activeJob?.id == jobID
    }

    private func finishRunIfNeeded(_ runID: UUID) {
        guard activeRunID == runID else {
            return
        }

        processingTask = nil
        activeRunID = nil
    }
}
