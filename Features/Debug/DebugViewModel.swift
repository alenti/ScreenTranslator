import CoreGraphics
import Foundation

@MainActor
final class DebugViewModel: ObservableObject {
    @Published var selectedStage: DebugInspectionStage
    @Published private(set) var pipelineSnapshot: DebugPipelineSnapshot?
    @Published private(set) var translationBlocks: [TranslationBlock]
    @Published private(set) var isLoadingOCR: Bool
    @Published private(set) var ocrStatusMessage: String
    @Published private(set) var groupingStatusMessage: String
    @Published private(set) var translationStatusMessage: String

    let result: OverlayRenderResult

    private let activeJob: ProcessingJob?
    private let pipelineInspector: DebugPipelineInspector
    private var hasLoadedOCRPreview: Bool

    init(
        result: OverlayRenderResult,
        activeJob: ProcessingJob?,
        pipelineInspector: DebugPipelineInspector
    ) {
        self.result = result
        self.activeJob = activeJob
        self.pipelineInspector = pipelineInspector
        self.selectedStage = .ocrObservations
        self.pipelineSnapshot = nil
        self.translationBlocks = []
        self.isLoadingOCR = false
        self.ocrStatusMessage = activeJob == nil
            ? "No screenshot is loaded yet. Run the shortcut first to inspect OCR output."
            : "Ready to run Vision OCR on the latest normalized screenshot."
        self.groupingStatusMessage = activeJob == nil
            ? "Grouping will become available after OCR has observations to process."
            : "Ready to group OCR observations into logical text blocks."
        self.translationStatusMessage = activeJob == nil
            ? "Translation will become available after OCR and grouping complete."
            : "Ready to translate grouped text blocks from Chinese to Russian on-device."
        self.hasLoadedOCRPreview = false
    }

    var inspectionStages: [DebugInspectionStage] {
        DebugInspectionStage.allCases
    }

    var ocrObservations: [OCRTextObservation] {
        pipelineSnapshot?.ocrObservations ?? []
    }

    var groupedBlocks: [TextBlock] {
        pipelineSnapshot?.groupedBlocks ?? []
    }

    var inputSummary: String? {
        let input = activeJob?.input ?? fallbackPreviewInput
        guard let input else { return nil }

        let width = Int(input.size.width)
        let height = Int(input.size.height)
        let scale = String(format: "%.1fx", input.scale)
        let sourceName = input.sourceMetadata.sourceName
        let filename = input.sourceMetadata.automationName ?? "unnamed image"

        return "\(sourceName) • \(filename) • \(width)x\(height) • \(scale)"
    }

    var comparisonSummary: String? {
        guard activeJob != nil || fallbackPreviewInput != nil else {
            return nil
        }

        if isLoadingOCR {
            return "Running OCR, grouping, and translation preview..."
        }

        let overlaySummary = inspectableOverlayBlocks.isEmpty
            ? "overlay frames pending"
            : "\(inspectableOverlayBlocks.count) final overlay frames"

        return "\(ocrObservations.count) OCR observations • \(groupedBlocks.count) grouped blocks • \(translationBlocks.count) translated blocks • \(overlaySummary)"
    }

    var selectedStageStatusMessage: String {
        switch selectedStage {
        case .ocrObservations:
            return ocrStatusMessage
        case .groupedBlocks:
            return groupingStatusMessage
        case .translatedBlocks:
            return translationStatusMessage
        case .overlayFrames:
            if inspectableOverlayBlocks.isEmpty {
                return "Final overlay frames will appear after the current screenshot finishes rendering."
            }

            if result.precomposedImageData == nil {
                return "\(result.renderMetadata.note) Using the source screenshot as the backdrop because no precomposed overlay image is stored."
            }

            return "\(result.renderMetadata.note) Inspect the rendered overlay result and compare frame placement with the structured rows below."
        }
    }

    var selectedStageBoxes: [DebugInspectionBox] {
        switch selectedStage {
        case .ocrObservations:
            return ocrObservationBoxes
        case .groupedBlocks:
            return groupedBlockBoxes
        case .translatedBlocks:
            return translatedBlockBoxes
        case .overlayFrames:
            return overlayFrameBoxes
        }
    }

    var previewImageData: Data? {
        switch selectedStage {
        case .overlayFrames:
            return renderedPreviewImageData ?? sourcePreviewImageData
        case .ocrObservations, .groupedBlocks, .translatedBlocks:
            return sourcePreviewImageData
        }
    }

    var previewBackdropDescription: String {
        switch selectedStage {
        case .overlayFrames:
            return renderedPreviewImageData == nil
                ? "Source screenshot with final frame guides"
                : "Rendered overlay preview with final frame guides"
        case .ocrObservations, .groupedBlocks, .translatedBlocks:
            return "Source screenshot with stage guides"
        }
    }

    var previewCanvasSizeForSelectedStage: CGSize {
        if selectedStage == .overlayFrames, inspectableOverlayBlocks.isEmpty == false {
            return normalizedSize(for: result.sourceInput)
        }

        let resolvedSize = normalizedPreviewInputSize
        guard resolvedSize.width > 0, resolvedSize.height > 0 else {
            return CGSize(width: 1, height: 1)
        }

        return resolvedSize
    }

    var overlayBlocksForInspection: [TranslationBlock] {
        inspectableOverlayBlocks
    }

    var overlayInspectionStatusMessage: String {
        if inspectableOverlayBlocks.isEmpty {
            return "Final overlay frames will appear after the current screenshot finishes rendering."
        }

        return "Review source and target frames below to diagnose overlay placement."
    }

    func loadOCRPreviewIfNeeded() async {
        guard hasLoadedOCRPreview == false else {
            return
        }

        hasLoadedOCRPreview = true

        guard let activeJob else {
            return
        }

        isLoadingOCR = true
        ocrStatusMessage = "Running Vision OCR on the normalized screenshot..."

        do {
            let snapshot = try await pipelineInspector.inspect(activeJob)
            pipelineSnapshot = snapshot
            translationBlocks = []
            ocrStatusMessage = snapshot.ocrObservations.isEmpty
                ? "Vision OCR finished, but no text was recognized in this screenshot."
                : "Vision OCR recognized \(snapshot.ocrObservations.count) text observations."
            groupingStatusMessage = snapshot.ocrObservations.isEmpty
                ? "Grouping skipped because there were no OCR observations."
                : "Grouping produced \(snapshot.groupedBlocks.count) text blocks from \(snapshot.ocrObservations.count) OCR observations."

            guard snapshot.groupedBlocks.isEmpty == false else {
                translationStatusMessage = "Translation skipped because grouping did not produce any text blocks."
                isLoadingOCR = false
                return
            }

            do {
                let translatedBlocks = try await pipelineInspector.translate(snapshot.groupedBlocks)
                translationBlocks = translatedBlocks
                translationStatusMessage = translatedBlocks.isEmpty
                    ? "Translation finished, but no TranslationBlocks were produced."
                    : "Translated \(translatedBlocks.count) grouped blocks from Chinese to Russian on-device."
            } catch let error as AppError {
                translationBlocks = []
                translationStatusMessage = error.errorDescription ?? "Translation failed."
            } catch {
                translationBlocks = []
                translationStatusMessage = "Translation failed."
            }
        } catch let error as AppError {
            pipelineSnapshot = nil
            translationBlocks = []
            ocrStatusMessage = error.errorDescription ?? "Vision OCR failed."
            groupingStatusMessage = "Grouping could not run because OCR did not complete successfully."
            translationStatusMessage = "Translation could not run because OCR did not complete successfully."
        } catch {
            pipelineSnapshot = nil
            translationBlocks = []
            ocrStatusMessage = "Vision OCR failed."
            groupingStatusMessage = "Grouping could not run because OCR did not complete successfully."
            translationStatusMessage = "Translation could not run because OCR did not complete successfully."
        }

        isLoadingOCR = false
    }

    private var fallbackPreviewInput: ScreenshotInput? {
        let input = result.sourceInput
        guard input.imageData.isEmpty == false else {
            return nil
        }

        return input
    }

    private var sourcePreviewImageData: Data? {
        if let activeJob, activeJob.input.imageData.isEmpty == false {
            return activeJob.input.imageData
        }

        if result.sourceInput.imageData.isEmpty == false {
            return result.sourceInput.imageData
        }

        return nil
    }

    private var renderedPreviewImageData: Data? {
        guard inspectableOverlayBlocks.isEmpty == false else {
            return nil
        }

        return result.precomposedImageData
    }

    private var normalizedPreviewInputSize: CGSize {
        if let snapshot = pipelineSnapshot {
            return snapshot.normalizedInput.size
        }

        if let activeJob {
            return normalizedSize(for: activeJob.input)
        }

        return normalizedSize(for: result.sourceInput)
    }

    private var inspectableOverlayBlocks: [TranslationBlock] {
        guard result.translatedBlocks.isEmpty == false else {
            return []
        }

        guard let activeJob else {
            return result.sourceInput.imageData.isEmpty == false ? result.translatedBlocks : []
        }

        guard result.sourceInput.id == activeJob.input.id else {
            return []
        }

        return result.translatedBlocks
    }

    private var ocrObservationBoxes: [DebugInspectionBox] {
        ocrObservations.enumerated().map { index, observation in
            DebugInspectionBox(
                id: observation.id,
                badgeText: "\(DebugInspectionStage.ocrObservations.badgePrefix)\(index)",
                title: truncatedText(observation.originalText),
                subtitle: "line \(observation.lineIndex) • conf \(confidenceDescription(observation.confidence))",
                detail: frameDescription(for: observation.boundingBox),
                frame: observation.boundingBox
            )
        }
    }

    private var groupedBlockBoxes: [DebugInspectionBox] {
        groupedBlocks.enumerated().map { index, block in
            DebugInspectionBox(
                id: block.id,
                badgeText: "\(DebugInspectionStage.groupedBlocks.badgePrefix)\(index)",
                title: truncatedText(block.sourceText),
                subtitle: "\(block.observations.count) OCR observations",
                detail: frameDescription(for: block.combinedBoundingBox),
                frame: block.combinedBoundingBox
            )
        }
    }

    private var translatedBlockBoxes: [DebugInspectionBox] {
        translationBlocks.enumerated().map { index, block in
            DebugInspectionBox(
                id: block.id,
                badgeText: "\(DebugInspectionStage.translatedBlocks.badgePrefix)\(index)",
                title: truncatedText(block.translatedText),
                subtitle: translatedBlockStatus(for: block),
                detail: frameDescription(for: block.sourceBoundingBox),
                frame: block.sourceBoundingBox
            )
        }
    }

    private var overlayFrameBoxes: [DebugInspectionBox] {
        inspectableOverlayBlocks.enumerated().map { index, block in
            DebugInspectionBox(
                id: block.id,
                badgeText: "\(DebugInspectionStage.overlayFrames.badgePrefix)\(index)",
                title: truncatedText(block.translatedText),
                subtitle: sizeDeltaDescription(for: block),
                detail: frameDescription(for: block.targetFrame),
                frame: block.targetFrame
            )
        }
    }

    private func normalizedSize(for input: ScreenshotInput) -> CGSize {
        pipelineInspector.screenshotNormalizer.normalize(input).size
    }

    private func truncatedText(_ text: String, limit: Int = 26) -> String {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.count > limit else {
            return normalized.isEmpty ? "Empty" : normalized
        }

        let truncated = normalized.prefix(limit)
        return "\(truncated)…"
    }

    private func confidenceDescription(_ confidence: Double) -> String {
        String(format: "%.2f", confidence)
    }

    private func translatedBlockStatus(for block: TranslationBlock) -> String {
        let translatedText = block.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return translatedText.isEmpty ? "empty translation response" : "translated"
    }

    private func sizeDeltaDescription(for block: TranslationBlock) -> String {
        let widthDelta = Int((block.targetFrame.width - block.sourceBoundingBox.width).rounded())
        let heightDelta = Int((block.targetFrame.height - block.sourceBoundingBox.height).rounded())
        return "dw \(signedValue(widthDelta)) • dh \(signedValue(heightDelta))"
    }

    private func signedValue(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func frameDescription(for rect: CGRect) -> String {
        let x = Int(rect.origin.x.rounded())
        let y = Int(rect.origin.y.rounded())
        let width = Int(rect.size.width.rounded())
        let height = Int(rect.size.height.rounded())
        return "x:\(x) y:\(y) w:\(width) h:\(height)"
    }
}
