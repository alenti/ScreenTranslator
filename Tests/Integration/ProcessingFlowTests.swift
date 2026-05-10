import CoreGraphics
import XCTest
@testable import ScreenTranslator

@MainActor
final class ProcessingFlowTests: XCTestCase {
    func testHandleIncomingScreenshotCompletesAndPublishesResult() async throws {
        let result = OverlayRenderResult(
            sourceInput: screenshotInput(),
            translatedBlocks: [
                translationBlock(
                    sourceText: "你好",
                    translatedText: "Привет",
                    sourceBoundingBox: CGRect(x: 12, y: 20, width: 60, height: 22)
                )
            ],
            renderStyle: .defaultValue,
            renderMetadata: .init(
                generatedAt: Date(timeIntervalSince1970: 1_700_000_100),
                note: "Flow success"
            ),
            precomposedImageData: Data([0x01])
        )
        let orchestrator = makeOrchestrator(
            translationResult: .success(result.translatedBlocks),
            overlayOutcome: .success(result)
        )
        let viewModel = ProcessingViewModel(orchestrator: orchestrator)
        let job = ProcessingJob(input: screenshotInput())

        var completedResult: OverlayRenderResult?
        var failedError: AppError?

        viewModel.configure(
            onCompleted: { completedResult = $0 },
            onFailed: { failedError = $0 }
        )

        viewModel.handleIncomingScreenshot(job)

        XCTAssertEqual(viewModel.state, .receivedInput)
        XCTAssertEqual(viewModel.activeJob?.id, job.id)
        XCTAssertEqual(
            viewModel.latestInputSummary,
            "Shortcuts / App Intent • processing-flow.png • 180x320"
        )

        await waitUntil(timeout: 1.0) {
            viewModel.state == .completed
        }

        XCTAssertEqual(viewModel.state, .completed)
        XCTAssertEqual(viewModel.latestResult, result)
        XCTAssertNil(viewModel.activeError)
        XCTAssertEqual(completedResult, result)
        XCTAssertNil(failedError)
    }

    func testHandleIncomingScreenshotPublishesTypedFailureAndInvokesFailureCallback() async {
        let orchestrator = makeOrchestrator(
            translationResult: .failure(AppError.missingLanguagePack),
            overlayOutcome: .failure(AppError.renderingFailure)
        )
        let viewModel = ProcessingViewModel(orchestrator: orchestrator)
        let job = ProcessingJob(input: screenshotInput())

        var completedResult: OverlayRenderResult?
        var failedError: AppError?

        viewModel.configure(
            onCompleted: { completedResult = $0 },
            onFailed: { failedError = $0 }
        )

        viewModel.handleIncomingScreenshot(job)

        await waitUntil(timeout: 1.0) {
            viewModel.state == .failed
        }

        XCTAssertEqual(viewModel.state, .failed)
        XCTAssertEqual(viewModel.activeError, .missingLanguagePack)
        XCTAssertNil(viewModel.latestResult)
        XCTAssertNil(completedResult)
        XCTAssertEqual(failedError, .missingLanguagePack)
    }

    func testResetToPlaceholderStateClearsTerminalProcessingState() async throws {
        let result = OverlayRenderResult(
            sourceInput: screenshotInput(),
            translatedBlocks: [
                translationBlock(
                    sourceText: "商品",
                    translatedText: "Товар",
                    sourceBoundingBox: CGRect(x: 12, y: 20, width: 60, height: 22)
                )
            ],
            renderStyle: .defaultValue,
            renderMetadata: .init(
                generatedAt: Date(timeIntervalSince1970: 1_700_000_200),
                note: "Flow reset"
            ),
            precomposedImageData: Data([0x02])
        )
        let viewModel = ProcessingViewModel(
            orchestrator: makeOrchestrator(
                translationResult: .success(result.translatedBlocks),
                overlayOutcome: .success(result)
            )
        )

        viewModel.handleIncomingScreenshot(ProcessingJob(input: screenshotInput()))
        await waitUntil(timeout: 1.0) {
            viewModel.state == .completed
        }

        viewModel.resetToPlaceholderState()

        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertNil(viewModel.activeJob)
        XCTAssertNil(viewModel.latestResult)
        XCTAssertNil(viewModel.activeError)
        XCTAssertEqual(viewModel.statusMessage, "Waiting for screenshot input.")
    }

    func testNewerIncomingScreenshotWinsOverCancelledOlderRun() async {
        let firstInput = screenshotInput(filename: "slow-processing.png")
        let secondInput = screenshotInput(filename: "fast-processing.png")
        let firstJob = ProcessingJob(input: firstInput)
        let secondJob = ProcessingJob(input: secondInput)
        let orchestrator = ProcessingOrchestrator(
            screenshotNormalizer: ScreenshotNormalizer(
                orientationResolver: ImageOrientationResolver()
            ),
            ocrService: DelayedOCRServiceStub(
                delaysByInputID: [
                    firstInput.id: 250_000_000,
                    secondInput.id: 10_000_000
                ]
            ),
            textGroupingService: EchoGroupingService(),
            translationService: EchoTranslationService(),
            overlayRenderer: EchoOverlayRenderer(),
            settingsStore: SettingsStoreStub(settings: .defaultValue)
        )
        let viewModel = ProcessingViewModel(orchestrator: orchestrator)

        var completedResults: [OverlayRenderResult] = []

        viewModel.configure(
            onCompleted: { completedResults.append($0) },
            onFailed: { error in
                XCTFail("Expected success for newer job, got \(error)")
            }
        )

        viewModel.handleIncomingScreenshot(firstJob)
        try? await Task.sleep(nanoseconds: 30_000_000)
        viewModel.handleIncomingScreenshot(secondJob)

        await waitUntil(timeout: 1.0) {
            viewModel.state == .completed
                && viewModel.latestResult?.sourceInput.id == secondInput.id
        }

        XCTAssertEqual(viewModel.activeJob?.id, secondJob.id)
        XCTAssertEqual(viewModel.latestResult?.sourceInput.id, secondInput.id)
        XCTAssertEqual(completedResults.map(\.sourceInput.id), [secondInput.id])
    }

    func testHandleIncomingScreenshotContinuesAfterEphemeralOwnerReleasesViewModel() async throws {
        let result = OverlayRenderResult(
            sourceInput: screenshotInput(filename: "ephemeral-owner.png"),
            translatedBlocks: [
                translationBlock(
                    sourceText: "你好",
                    translatedText: "Привет",
                    sourceBoundingBox: CGRect(x: 12, y: 20, width: 60, height: 22)
                )
            ],
            renderStyle: .defaultValue,
            renderMetadata: .init(
                generatedAt: Date(timeIntervalSince1970: 1_700_000_300),
                note: "Ephemeral owner success"
            ),
            precomposedImageData: Data([0x03])
        )
        let job = ProcessingJob(input: result.sourceInput)
        var completedResult: OverlayRenderResult?
        var failedError: AppError?

        do {
            let viewModel = ProcessingViewModel(
                orchestrator: makeOrchestrator(
                    translationResult: .success(result.translatedBlocks),
                    overlayOutcome: .success(result)
                )
            )

            viewModel.configure(
                onCompleted: { completedResult = $0 },
                onFailed: { failedError = $0 }
            )
            viewModel.handleIncomingScreenshot(job)
        }

        await waitUntil(timeout: 1.0) {
            completedResult == result || failedError != nil
        }

        XCTAssertEqual(completedResult, result)
        XCTAssertNil(failedError)
    }

    func testTranslationSessionBrokerTimesOutWhenSessionLoopIsNotRunning() async {
        let broker = TranslationSessionBroker(
            translationTimeout: 0.05,
            preparationTimeout: 0.05
        )
        let batch = [
            TranslationBatchBuilder.BatchItem(
                id: UUID(),
                blockIndex: 0,
                clientIdentifier: UUID().uuidString,
                sourceText: "你好",
                sourceBoundingBox: CGRect(x: 10, y: 20, width: 60, height: 24),
                renderingStyle: .defaultValue
            )
        ]

        do {
            _ = try await broker.translate(batch: batch)
            XCTFail("Expected translate to time out without a running session loop")
        } catch {
            XCTAssertEqual(
                error as? TranslationSessionBroker.BrokerError,
                .operationTimedOut
            )
        }
    }

    private func makeOrchestrator(
        translationResult: Result<[TranslationBlock], Error>,
        overlayOutcome: OverlayRendererSpy.Outcome
    ) -> ProcessingOrchestrator {
        let observations = [
            OCRTextObservation(
                originalText: "你好",
                boundingBox: CGRect(x: 12, y: 20, width: 60, height: 22),
                confidence: 0.95,
                lineIndex: 0
            )
        ]
        let groupedBlocks = [
            TextBlock(
                sourceText: "你好",
                observations: observations,
                combinedBoundingBox: CGRect(x: 12, y: 20, width: 60, height: 22)
            )
        ]

        return ProcessingOrchestrator(
            screenshotNormalizer: ScreenshotNormalizer(
                orientationResolver: ImageOrientationResolver()
            ),
            ocrService: OCRServiceStub(result: .success(observations)),
            textGroupingService: GroupingServiceStub(blocks: groupedBlocks),
            translationService: TranslationServiceStub(result: translationResult),
            overlayRenderer: OverlayRendererSpy(outcome: overlayOutcome),
            settingsStore: SettingsStoreStub(settings: .defaultValue)
        )
    }

    private func screenshotInput(
        filename: String = "processing-flow.png"
    ) -> ScreenshotInput {
        ScreenshotInput(
            imageData: Data([0x01, 0x02]),
            size: CGSize(width: 180, height: 320),
            orientation: .up,
            sourceMetadata: .shortcuts(filename: filename)
        )
    }

    private func translationBlock(
        sourceText: String,
        translatedText: String,
        sourceBoundingBox: CGRect
    ) -> TranslationBlock {
        TranslationBlock(
            sourceText: sourceText,
            translatedText: translatedText,
            sourceBoundingBox: sourceBoundingBox,
            targetFrame: sourceBoundingBox,
            renderingStyle: .defaultValue
        )
    }

    private func waitUntil(
        timeout: TimeInterval,
        condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return
            }

            try? await Task.sleep(nanoseconds: 10_000_000)
        }

        XCTFail("Timed out waiting for condition")
    }
}

private actor OCRServiceStub: OCRServiceProtocol {
    private let result: Result<[OCRTextObservation], Error>

    init(result: Result<[OCRTextObservation], Error>) {
        self.result = result
    }

    func recognizeText(in input: ScreenshotInput) async throws -> [OCRTextObservation] {
        _ = input
        return try result.get()
    }
}

private struct GroupingServiceStub: TextGroupingServiceProtocol {
    let blocks: [TextBlock]

    func makeBlocks(from observations: [OCRTextObservation]) -> [TextBlock] {
        _ = observations
        return blocks
    }
}

private actor TranslationServiceStub: TranslationServiceProtocol {
    private let result: Result<[TranslationBlock], Error>

    init(result: Result<[TranslationBlock], Error>) {
        self.result = result
    }

    func translate(blocks: [TextBlock]) async throws -> [TranslationBlock] {
        _ = blocks
        return try result.get()
    }
}

private actor DelayedOCRServiceStub: OCRServiceProtocol {
    private let delaysByInputID: [UUID: UInt64]

    init(delaysByInputID: [UUID: UInt64]) {
        self.delaysByInputID = delaysByInputID
    }

    func recognizeText(in input: ScreenshotInput) async throws -> [OCRTextObservation] {
        if let delay = delaysByInputID[input.id] {
            try? await Task.sleep(nanoseconds: delay)
        }

        return [
            OCRTextObservation(
                originalText: input.sourceMetadata.automationName ?? "image",
                boundingBox: CGRect(x: 12, y: 20, width: 120, height: 22),
                confidence: 0.95,
                lineIndex: 0
            )
        ]
    }
}

private struct EchoGroupingService: TextGroupingServiceProtocol {
    func makeBlocks(from observations: [OCRTextObservation]) -> [TextBlock] {
        guard let firstObservation = observations.first else {
            return []
        }

        let combinedBoundingBox = observations
            .dropFirst()
            .reduce(firstObservation.boundingBox) { partialResult, observation in
                partialResult.union(observation.boundingBox)
            }

        return [
            TextBlock(
                sourceText: observations.map(\.originalText).joined(separator: " "),
                observations: observations,
                combinedBoundingBox: combinedBoundingBox
            )
        ]
    }
}

private actor EchoTranslationService: TranslationServiceProtocol {
    func translate(blocks: [TextBlock]) async throws -> [TranslationBlock] {
        blocks.map { block in
            TranslationBlock(
                sourceText: block.sourceText,
                translatedText: "RU: \(block.sourceText)",
                sourceBoundingBox: block.combinedBoundingBox,
                targetFrame: block.combinedBoundingBox,
                renderingStyle: .defaultValue
            )
        }
    }
}

private actor EchoOverlayRenderer: OverlayRendererProtocol {
    func renderOverlay(
        for input: ScreenshotInput,
        translatedBlocks: [TranslationBlock],
        style: OverlayRenderStyle
    ) async throws -> OverlayRenderResult {
        OverlayRenderResult(
            sourceInput: input,
            translatedBlocks: translatedBlocks.map { block in
                TranslationBlock(
                    id: block.id,
                    sourceText: block.sourceText,
                    translatedText: block.translatedText,
                    sourceBoundingBox: block.sourceBoundingBox,
                    targetFrame: block.targetFrame,
                    renderingStyle: style
                )
            },
            renderStyle: style,
            renderMetadata: .init(
                generatedAt: Date(timeIntervalSince1970: 1_700_000_300),
                note: "Echo overlay render"
            ),
            precomposedImageData: nil
        )
    }
}

private actor OverlayRendererSpy: OverlayRendererProtocol {
    enum Outcome {
        case success(OverlayRenderResult)
        case failure(Error)
    }

    private let outcome: Outcome

    init(outcome: Outcome) {
        self.outcome = outcome
    }

    func renderOverlay(
        for input: ScreenshotInput,
        translatedBlocks: [TranslationBlock],
        style: OverlayRenderStyle
    ) async throws -> OverlayRenderResult {
        _ = input
        _ = translatedBlocks
        _ = style

        switch outcome {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        }
    }
}

private final class SettingsStoreStub: SettingsStoreProtocol {
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func loadSettings() -> AppSettings {
        settings
    }

    func saveSettings(_ settings: AppSettings) {
        _ = settings
    }
}
