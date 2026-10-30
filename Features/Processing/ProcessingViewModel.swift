import Foundation
import UIKit

@MainActor
final class ProcessingViewModel: ObservableObject {
    @Published private(set) var state: ProcessingState = .idle
    /// True only while the local model is being loaded (first use or after the OS reclaimed memory).
    @Published private(set) var isPreparingModel = false
    @Published private(set) var translatedCount = 0
    @Published private(set) var totalCount = 0
    @Published private(set) var activeJob: ProcessingJob?
    @Published private(set) var activeError: AppError?

    private let engine: HyMTTranslator
    private var localTarget: TargetLanguage = .russian
    var isAppActive = true
    var onLocalCompleted: ((ProcessedScreenshot) -> Void)?
    var onFailed: ((AppError) -> Void)?
    private(set) var memoryWarningCount = 0
    private var processingTask: Task<Void, Never>?
    private var activeRunID: UUID?

    var diagnosticRoute = "unknown"
    #if DEBUG
    private func diagnosticEvent(_ name: String, extra: [String:Any] = [:]) {
        let folder = documents.appendingPathComponent("Acceptance")
        try? FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        var event: [String:Any] = ["event":name,"timestamp":Date().timeIntervalSince1970,"route":diagnosticRoute,
            "requestID":activeJob?.id.uuidString ?? "","runID":activeRunID?.uuidString ?? "","target":localTarget.rawValue]
        event.merge(extra) { _,new in new }
        guard var data = try? JSONSerialization.data(withJSONObject:event,options:.sortedKeys) else { return }
        print("ACCEPTANCE \(String(decoding:data,as:UTF8.self))")
        data.append(10)
        let url = folder.appendingPathComponent("events.jsonl")
        if !FileManager.default.fileExists(atPath:url.path) { FileManager.default.createFile(atPath:url.path,contents:nil) }
        if let file = try? FileHandle(forWritingTo:url) { defer { try? file.close() }; _ = try? file.seekToEnd(); try? file.write(contentsOf:data) }
    }
    // Presentation/DTO regression only: an exported real result, never a translator or processing fallback.
    func presentRegressionResult(_ result: ProcessedScreenshot, job: ProcessingJob) {
        resetToPlaceholderState()
        activeJob = job; localTarget = result.targetLanguage; state = .completed
        onLocalCompleted?(result)
    }
    #endif

    init(engine: HyMTTranslator) {
        self.engine = engine
    }

    func memoryWarningReceived() async {
        memoryWarningCount += 1
        #if DEBUG
        diagnosticEvent("memory-warning",extra:["count":memoryWarningCount])
        #endif
        await suspendLocalProcessing()
    }

    func resetToPlaceholderState() {
        processingTask?.cancel()
        activeRunID = nil
        activeJob = nil
        activeError = nil
        isPreparingModel = false
        state = .idle
    }

    func handleIncomingScreenshot(_ job: ProcessingJob, localTarget: TargetLanguage) {
        #if DEBUG
        if processingTask != nil { diagnosticEvent("replacement",extra:["newRequestID":job.id.uuidString]) }
        #endif
        let previous = processingTask
        processingTask?.cancel()
        self.localTarget = localTarget
        let runID = UUID(), receivedAt = ProcessInfo.processInfo.systemUptime
        activeRunID = runID
        activeJob = job
        #if DEBUG
        diagnosticEvent("received")
        #endif
        activeError = nil
        isPreparingModel = false
        translatedCount = 0
        totalCount = 0
        state = .readingScreenshot

        processingTask = Task { [self] in
            await previous?.value
            guard !Task.isCancelled else { return }
            await runLocalPipeline(job, target: localTarget, runID: runID, receivedAt: receivedAt)
        }
    }

    func retryCurrentJob() {
        guard let activeJob else { return }
        #if DEBUG
        diagnosticEvent("retry")
        #endif
        handleIncomingScreenshot(activeJob, localTarget: localTarget)
    }

    func cancelCurrentJob() {
        #if DEBUG
        diagnosticEvent("cancel")
        #endif
        processingTask?.cancel()
        activeRunID = nil
        isPreparingModel = false
        state = .cancelled
    }

    func suspendLocalProcessing() async {
        if let previous = processingTask {
            cancelCurrentJob()
            await previous.value
        }
        // Scene backgrounding must not evict a model owned by a headless Quick Look job.
    }

    private func runLocalPipeline(_ job: ProcessingJob, target: TargetLanguage, runID: UUID, receivedAt: TimeInterval) async {
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = false; finishRunIfNeeded(runID) }
        do {
            guard isAppActive else { throw CancellationError() }
            guard let image = UIImage(data: job.input.imageData) else { throw AppError.unsupportedImage }
            #if DEBUG
            let folder = documents.appendingPathComponent("Phase1Reports/\(job.id.uuidString)/\(runID.uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try job.input.imageData.write(to: folder.appendingPathComponent("input.png"), options: .atomic)
            let cancellationFile = folder.appendingPathComponent("cancellation-\(runID.uuidString).json")
            defer {
                if let data = try? Data(contentsOf: cancellationFile),
                   var timing = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
                   let requested = timing["requestedAt"] as? Double {
                    let exited = Date().timeIntervalSince1970
                    timing["processingExitedAt"] = exited
                    timing["nativeReturnedBy"] = exited
                    timing["exitLatencyMs"] = (exited - requested) * 1000
                    try? writeJSON(timing, to: cancellationFile)
                }
            }
            #endif
            let result = try await withTaskCancellationHandler {
                try await ScreenshotProcessor.process(image, to: target, engine: engine, requestID: job.id, receivedAt: receivedAt) { [weak self] progress in
                    await self?.applyLocal(progress, runID: runID, jobID: job.id)
                    #if DEBUG
                    // UI-only cancellation test: hold the real preparation boundary without a simulator model.
                    if ProcessInfo.processInfo.environment["PHASE2_MODE"] == "ui", case .preparingModel = progress {
                        try? await Task.sleep(for: .seconds(60))
                    }
                    #endif
                }
            } onCancel: {
                #if DEBUG
                try? writeJSON(["runID":runID.uuidString, "requestID":job.id.uuidString,
                               "requestedAt":Date().timeIntervalSince1970], to: cancellationFile)
                #endif
            }
            guard shouldAcceptUpdates(for: runID, jobID: job.id), !Task.isCancelled, isAppActive else { return }
            state = .completed
            isPreparingModel = false
            #if DEBUG
            var report = result.report
            report["load"] = try await engine.prepare()
            report["iOS"] = UIDevice.current.systemVersion
            report["batteryState"] = UIDevice.current.batteryState.rawValue
            report["hardwareMemoryBytes"] = ProcessInfo.processInfo.physicalMemory
            report["memoryWarnings"] = memoryWarningCount
            report["runID"] = runID.uuidString
            report["route"] = diagnosticRoute
            report["engineCounters"] = await engine.diagnosticCounters
            try writeJSON(report, to: folder.appendingPathComponent("report.json"))
            try savePNG(result.renderedImage, to: folder.appendingPathComponent("result.png"))
            let raw = (report["ocr"] as? [[String:Any]] ?? []).map(Phase2Checks.diagnosticBlock)
            let groups = (report["groups"] as? [[String:Any]] ?? []).map(Phase2Checks.diagnosticBlock)
            try? savePNG(Phase2Checks.annotated(result.originalImage,observations:raw,groups:[]),to:folder.appendingPathComponent("vision-observations.png"))
            try? savePNG(Phase2Checks.annotated(result.originalImage,observations:raw,groups:groups),to:folder.appendingPathComponent("grouping-debug.png"))
            diagnosticEvent("completed",extra:["counters":await engine.diagnosticCounters,"totalMs":report["totalMs"] ?? NSNull()])
            #endif
            guard shouldAcceptUpdates(for: runID, jobID: job.id), !Task.isCancelled, isAppActive else { return }
            writeProcessingMetrics(result, extra: ["route": diagnosticRoute, "runID": runID.uuidString,
                                                   "counters": result.report["engineCounters"] ?? [:]])
            onLocalCompleted?(result)
        } catch {
            #if DEBUG
            diagnosticEvent(Task.isCancelled ? "processing-exited-cancelled" : "processing-error",extra:["runID":runID.uuidString,"requestID":job.id.uuidString,"error":error.localizedDescription])
            #endif
            guard shouldAcceptUpdates(for: runID, jobID: job.id), !Task.isCancelled else { return }
            let appError = AppError(error)
            activeError = appError
            isPreparingModel = false
            state = .failed
            onFailed?(appError)
        }
    }

    private func applyLocal(_ progress: ScreenshotProgress, runID: UUID, jobID: UUID) {
        guard shouldAcceptUpdates(for: runID, jobID: jobID), isAppActive else { return }
        #if DEBUG
        diagnosticEvent("progress",extra:["stage":String(describing:progress)])
        #endif
        switch progress {
        case .readingText, .grouping:
            state = .readingScreenshot
        case .preparingModel:
            state = .translating
            isPreparingModel = true
        case .translating(let completed, let total):
            state = .translating
            isPreparingModel = false
            translatedCount = min(completed, total)
            totalCount = total
        case .rendering:
            state = .preparingPreview
            isPreparingModel = false
        }
    }

    private func shouldAcceptUpdates(for runID: UUID, jobID: UUID) -> Bool {
        activeRunID == runID && activeJob?.id == jobID
    }

    private func finishRunIfNeeded(_ runID: UUID) {
        guard activeRunID == runID else { return }
        processingTask = nil
        activeRunID = nil
    }
}
