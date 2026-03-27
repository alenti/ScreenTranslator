import Foundation

struct DebugPipelineInspector {
    let screenshotNormalizer: ScreenshotNormalizer
    let ocrService: any OCRServiceProtocol
    let textGroupingService: any TextGroupingServiceProtocol
    let translationService: any TranslationServiceProtocol

    func inspect(_ job: ProcessingJob) async throws -> DebugPipelineSnapshot {
        let normalizedInput = screenshotNormalizer.normalize(job.input)
        let observations = try await ocrService.recognizeText(in: normalizedInput)
        let groupedBlocks = textGroupingService.makeBlocks(from: observations)

        return DebugPipelineSnapshot(
            normalizedInput: normalizedInput,
            ocrObservations: observations,
            groupedBlocks: groupedBlocks
        )
    }

    func translate(_ blocks: [TextBlock]) async throws -> [TranslationBlock] {
        try await translationService.translate(blocks: blocks)
    }
}
