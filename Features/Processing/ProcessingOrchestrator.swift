import Foundation

final class ProcessingOrchestrator {
    enum ProgressUpdate: Sendable {
        case preparingImage(imageSize: CGSize)
        case performingOCR
        case groupingText(observationCount: Int)
        case translatingBlocks(blockCount: Int)
        case renderingOverlay(translationCount: Int)
    }

    private let screenshotNormalizer: ScreenshotNormalizer
    private let ocrService: any OCRServiceProtocol
    private let textGroupingService: any TextGroupingServiceProtocol
    private let translationService: any TranslationServiceProtocol
    private let overlayRenderer: any OverlayRendererProtocol
    private let settingsStore: any SettingsStoreProtocol

    init(
        screenshotNormalizer: ScreenshotNormalizer,
        ocrService: any OCRServiceProtocol,
        textGroupingService: any TextGroupingServiceProtocol,
        translationService: any TranslationServiceProtocol,
        overlayRenderer: any OverlayRendererProtocol,
        settingsStore: any SettingsStoreProtocol
    ) {
        self.screenshotNormalizer = screenshotNormalizer
        self.ocrService = ocrService
        self.textGroupingService = textGroupingService
        self.translationService = translationService
        self.overlayRenderer = overlayRenderer
        self.settingsStore = settingsStore
    }

    func process(
        _ job: ProcessingJob,
        onProgress: @Sendable (ProgressUpdate) async -> Void = { _ in }
    ) async throws -> OverlayRenderResult {
        await onProgress(
            .preparingImage(imageSize: job.input.size)
        )
        let normalizedInput = screenshotNormalizer.normalize(job.input)

        await onProgress(.performingOCR)
        let observations = try await ocrService.recognizeText(in: normalizedInput)
        guard observations.isEmpty == false else {
            throw AppError.noTextDetected
        }

        await onProgress(
            .groupingText(observationCount: observations.count)
        )
        let textBlocks = textGroupingService.makeBlocks(from: observations)
        guard textBlocks.isEmpty == false else {
            throw AppError.noTextDetected
        }

        await onProgress(
            .translatingBlocks(blockCount: textBlocks.count)
        )
        let translationBlocks = try await translationService.translate(blocks: textBlocks)
        guard translationBlocks.isEmpty == false else {
            throw AppError.translationUnavailable
        }

        await onProgress(
            .renderingOverlay(translationCount: translationBlocks.count)
        )
        let overlayStyle = settingsStore.loadSettings().overlayStyle

        do {
            return try await overlayRenderer.renderOverlay(
                for: normalizedInput,
                translatedBlocks: translationBlocks,
                style: overlayStyle
            )
        } catch let error as AppError {
            switch error {
            case .featureNotReady, .renderingFailure:
                return makePlaceholderResult(
                    input: normalizedInput,
                    translatedBlocks: translationBlocks,
                    style: overlayStyle
                )
            default:
                throw error
            }
        } catch {
            throw AppError.renderingFailure
        }
    }

    private func makePlaceholderResult(
        input: ScreenshotInput,
        translatedBlocks: [TranslationBlock],
        style: OverlayRenderStyle
    ) -> OverlayRenderResult {
        let restyledBlocks = translatedBlocks.map { block in
            TranslationBlock(
                id: block.id,
                sourceText: block.sourceText,
                translatedText: block.translatedText,
                sourceBoundingBox: block.sourceBoundingBox,
                targetFrame: block.targetFrame,
                renderingStyle: style
            )
        }

        return OverlayRenderResult(
            sourceInput: input,
            translatedBlocks: restyledBlocks,
            renderStyle: style,
            renderMetadata: .init(
                generatedAt: .now,
                note: "Placeholder render result produced by ProcessingOrchestrator while overlay rendering is still pending."
            ),
            precomposedImageData: nil
        )
    }
}
