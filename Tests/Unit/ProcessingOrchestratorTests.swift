import CoreGraphics
import XCTest
@testable import ScreenTranslator

final class ProcessingOrchestratorTests: XCTestCase {
    func testProcessRunsPipelineInOrderAndPassesConfiguredStyleToRenderer() async throws {
        let input = screenshotInput(
            size: CGSize(width: 100, height: 200),
            orientation: .right
        )
        let job = ProcessingJob(input: input)
        let normalizer = ScreenshotNormalizer(
            orientationResolver: ImageOrientationResolver()
        )
        let normalizedInput = normalizer.normalize(input)
        let observations = [
            observation("你好", x: 12, y: 18, width: 40, height: 20, lineIndex: 0),
            observation("世界", x: 54, y: 18, width: 40, height: 20, lineIndex: 0)
        ]
        let groupedBlocks = [
            textBlock(
                sourceText: "你好世界",
                boundingBox: CGRect(x: 12, y: 18, width: 82, height: 20)
            )
        ]
        let translationBlocks = [
            translationBlock(
                sourceText: "你好世界",
                translatedText: "Привет мир",
                sourceBoundingBox: groupedBlocks[0].combinedBoundingBox
            )
        ]
        let overlayStyle = OverlayRenderStyle(
            minimumFontSize: 13,
            maximumFontSize: 24,
            padding: 10,
            backgroundOpacity: 0.9,
            cornerRadius: 14,
            textColorStyle: .automatic
        )
        let expectedResult = OverlayRenderResult(
            sourceInput: normalizedInput,
            translatedBlocks: translationBlocks,
            renderStyle: overlayStyle,
            renderMetadata: .init(
                generatedAt: Date(timeIntervalSince1970: 1_700_000_000),
                note: "Rendered in test"
            ),
            precomposedImageData: Data([0x01, 0x02, 0x03])
        )

        let ocrService = OCRServiceStub(result: .success(observations))
        let textGroupingService = GroupingServiceStub(blocks: groupedBlocks)
        let translationService = TranslationServiceStub(
            result: .success(translationBlocks)
        )
        let overlayRenderer = OverlayRendererSpy(
            outcome: .success(expectedResult)
        )
        let settingsStore = SettingsStoreStub(
            settings: AppSettings(
                overlayStyle: overlayStyle,
                preferredDisplayModeRawValue: "overlay",
                historyEnabled: true,
                debugOptionsEnabled: true
            )
        )
        let progressRecorder = ProgressRecorder()
        let orchestrator = ProcessingOrchestrator(
            screenshotNormalizer: normalizer,
            ocrService: ocrService,
            textGroupingService: textGroupingService,
            translationService: translationService,
            overlayRenderer: overlayRenderer,
            settingsStore: settingsStore
        )

        let result = try await orchestrator.process(job) { progress in
            await progressRecorder.record(progress)
        }
        let recordedProgress = await progressRecorder.values()
        let recordedOCRInput = await ocrService.lastInput()
        let recordedGroupedBlocks = await translationService.lastBlocks()
        let recordedRendererInput = await overlayRenderer.lastInput()
        let recordedRendererBlocks = await overlayRenderer.lastBlocks()
        let recordedRendererStyle = await overlayRenderer.lastStyle()

        XCTAssertEqual(result, expectedResult)
        XCTAssertEqual(
            recordedProgress,
            [
                "preparingImage:100x200",
                "performingOCR",
                "groupingText:2",
                "translatingBlocks:1",
                "renderingOverlay:1"
            ]
        )
        XCTAssertEqual(recordedOCRInput, normalizedInput)
        XCTAssertEqual(recordedGroupedBlocks, groupedBlocks)
        XCTAssertEqual(recordedRendererInput, normalizedInput)
        XCTAssertEqual(recordedRendererBlocks, translationBlocks)
        XCTAssertEqual(recordedRendererStyle, overlayStyle)
    }

    func testProcessReturnsPlaceholderResultWhenRendererFailsGracefully() async throws {
        let input = screenshotInput()
        let job = ProcessingJob(input: input)
        let normalizer = ScreenshotNormalizer(
            orientationResolver: ImageOrientationResolver()
        )
        let normalizedInput = normalizer.normalize(input)
        let observations = [
            observation("立即", x: 14, y: 20, width: 36, height: 18, lineIndex: 0)
        ]
        let groupedBlocks = [
            textBlock(
                sourceText: "立即",
                boundingBox: CGRect(x: 14, y: 20, width: 36, height: 18)
            )
        ]
        let translationBlocks = [
            translationBlock(
                sourceText: "立即",
                translatedText: "Сейчас",
                sourceBoundingBox: groupedBlocks[0].combinedBoundingBox
            )
        ]
        let overlayStyle = OverlayRenderStyle(
            minimumFontSize: 12,
            maximumFontSize: 20,
            padding: 8,
            backgroundOpacity: 0.85,
            cornerRadius: 12,
            textColorStyle: .automatic
        )

        let orchestrator = ProcessingOrchestrator(
            screenshotNormalizer: normalizer,
            ocrService: OCRServiceStub(result: .success(observations)),
            textGroupingService: GroupingServiceStub(blocks: groupedBlocks),
            translationService: TranslationServiceStub(result: .success(translationBlocks)),
            overlayRenderer: OverlayRendererSpy(outcome: .failure(AppError.renderingFailure)),
            settingsStore: SettingsStoreStub(
                settings: AppSettings(
                    overlayStyle: overlayStyle,
                    preferredDisplayModeRawValue: "overlay",
                    historyEnabled: true,
                    debugOptionsEnabled: true
                )
            )
        )

        let result = try await orchestrator.process(job)

        XCTAssertEqual(result.sourceInput, normalizedInput)
        XCTAssertEqual(result.renderStyle, overlayStyle)
        XCTAssertEqual(
            result.translatedBlocks.map(\.sourceText),
            translationBlocks.map(\.sourceText)
        )
        XCTAssertEqual(
            result.translatedBlocks.map(\.translatedText),
            translationBlocks.map(\.translatedText)
        )
        XCTAssertTrue(
            result.translatedBlocks.allSatisfy { $0.renderingStyle == overlayStyle }
        )
        XCTAssertNil(result.precomposedImageData)
        XCTAssertEqual(
            result.renderMetadata.note,
            "Placeholder render result produced by ProcessingOrchestrator while overlay rendering is still pending."
        )
    }

    func testProcessWithRealRendererUsesConfiguredOverlayStyleForRenderedOutput() async throws {
        let input = ScreenshotInput(
            imageData: try TestFixtures.makePNGData(
                width: 220,
                height: 360
            ),
            size: CGSize(width: 220, height: 360),
            orientation: .up,
            sourceMetadata: .shortcuts(filename: "styled-render.png")
        )
        let job = ProcessingJob(input: input)
        let observations = [
            observation("折扣", x: 24, y: 40, width: 60, height: 22, lineIndex: 0)
        ]
        let groupedBlocks = [
            textBlock(
                sourceText: "折扣",
                boundingBox: CGRect(x: 24, y: 40, width: 60, height: 22)
            )
        ]
        let translationBlocks = [
            translationBlock(
                sourceText: "折扣",
                translatedText: "Очень большая скидка",
                sourceBoundingBox: groupedBlocks[0].combinedBoundingBox
            )
        ]
        let compactStyle = OverlayRenderStyle(
            minimumFontSize: 12,
            maximumFontSize: 16,
            padding: 6,
            backgroundOpacity: 0.55,
            cornerRadius: 8,
            textColorStyle: .automatic
        )
        let roomyStyle = OverlayRenderStyle(
            minimumFontSize: 12,
            maximumFontSize: 28,
            padding: 20,
            backgroundOpacity: 0.95,
            cornerRadius: 22,
            textColorStyle: .automatic
        )

        let compactResult = try await realRenderedResult(
            for: job,
            observations: observations,
            groupedBlocks: groupedBlocks,
            translationBlocks: translationBlocks,
            overlayStyle: compactStyle
        )
        let roomyResult = try await realRenderedResult(
            for: job,
            observations: observations,
            groupedBlocks: groupedBlocks,
            translationBlocks: translationBlocks,
            overlayStyle: roomyStyle
        )

        XCTAssertEqual(compactResult.translatedBlocks.first?.renderingStyle, compactStyle)
        XCTAssertEqual(roomyResult.translatedBlocks.first?.renderingStyle, roomyStyle)
        XCTAssertNotEqual(
            compactResult.precomposedImageData,
            roomyResult.precomposedImageData
        )
        XCTAssertLessThan(
            compactResult.translatedBlocks[0].targetFrame.height,
            roomyResult.translatedBlocks[0].targetFrame.height
        )
    }

    func testProcessWithRealRendererKeepsCompactShoppingLabelCloseToSourceZone() async throws {
        let input = ScreenshotInput(
            imageData: try TestFixtures.makePNGData(
                width: 240,
                height: 360
            ),
            size: CGSize(width: 240, height: 360),
            orientation: .up,
            sourceMetadata: .shortcuts(filename: "compact-label.png")
        )
        let job = ProcessingJob(input: input)
        let sourceBoundingBox = CGRect(x: 24, y: 40, width: 56, height: 22)
        let observations = [
            observation("折扣", x: 24, y: 40, width: 56, height: 22, lineIndex: 0)
        ]
        let groupedBlocks = [
            textBlock(
                sourceText: "折扣",
                boundingBox: sourceBoundingBox
            )
        ]
        let translationBlocks = [
            translationBlock(
                sourceText: "折扣",
                translatedText: "Скидка",
                sourceBoundingBox: sourceBoundingBox
            )
        ]

        let result = try await realRenderedResult(
            for: job,
            observations: observations,
            groupedBlocks: groupedBlocks,
            translationBlocks: translationBlocks,
            overlayStyle: .defaultValue
        )

        let targetFrame = result.translatedBlocks[0].targetFrame

        XCTAssertLessThan(targetFrame.width, 104)
        XCTAssertLessThan(targetFrame.height, 64)
        XCTAssertEqual(targetFrame.minX, sourceBoundingBox.minX, accuracy: 0.5)
        XCTAssertEqual(targetFrame.minY, sourceBoundingBox.minY, accuracy: 0.5)
    }

    func testProcessWithRealRendererKeepsMediumCommerceBlockTighterToMeasuredText() async throws {
        let input = ScreenshotInput(
            imageData: try TestFixtures.makePNGData(
                width: 320,
                height: 420
            ),
            size: CGSize(width: 320, height: 420),
            orientation: .up,
            sourceMetadata: .shortcuts(filename: "medium-commerce-block.png")
        )
        let job = ProcessingJob(input: input)
        let sourceBoundingBox = CGRect(x: 24, y: 52, width: 96, height: 28)
        let observations = [
            observation("满减优惠", x: 24, y: 52, width: 96, height: 28, lineIndex: 0)
        ]
        let groupedBlocks = [
            textBlock(
                sourceText: "满减优惠",
                boundingBox: sourceBoundingBox
            )
        ]
        let translationBlocks = [
            translationBlock(
                sourceText: "满减优惠",
                translatedText: "Скидка по акции",
                sourceBoundingBox: sourceBoundingBox
            )
        ]

        let result = try await realRenderedResult(
            for: job,
            observations: observations,
            groupedBlocks: groupedBlocks,
            translationBlocks: translationBlocks,
            overlayStyle: .defaultValue
        )

        let targetFrame = result.translatedBlocks[0].targetFrame

        XCTAssertLessThan(targetFrame.width, 150)
        XCTAssertLessThan(targetFrame.height, 74)
        XCTAssertEqual(targetFrame.minX, sourceBoundingBox.minX, accuracy: 0.5)
        XCTAssertEqual(targetFrame.minY, sourceBoundingBox.minY, accuracy: 0.5)
    }

    func testProcessWithRealRendererAvoidsCollisionsBetweenNeighboringBlocks() async throws {
        let input = ScreenshotInput(
            imageData: try TestFixtures.makePNGData(
                width: 260,
                height: 360
            ),
            size: CGSize(width: 260, height: 360),
            orientation: .up,
            sourceMetadata: .shortcuts(filename: "collision-render.png")
        )
        let job = ProcessingJob(input: input)
        let observations = [
            observation("优惠一", x: 18, y: 40, width: 74, height: 24, lineIndex: 0),
            observation("优惠二", x: 96, y: 42, width: 74, height: 24, lineIndex: 0)
        ]
        let groupedBlocks = [
            textBlock(
                sourceText: "优惠一",
                boundingBox: CGRect(x: 18, y: 40, width: 74, height: 24)
            ),
            textBlock(
                sourceText: "优惠二",
                boundingBox: CGRect(x: 96, y: 42, width: 74, height: 24)
            )
        ]
        let translationBlocks = [
            translationBlock(
                sourceText: "优惠一",
                translatedText: "Очень длинное описание первой скидки",
                sourceBoundingBox: groupedBlocks[0].combinedBoundingBox
            ),
            translationBlock(
                sourceText: "优惠二",
                translatedText: "Еще одно длинное описание второй скидки",
                sourceBoundingBox: groupedBlocks[1].combinedBoundingBox
            )
        ]
        let overlayStyle = OverlayRenderStyle(
            minimumFontSize: 12,
            maximumFontSize: 22,
            padding: 10,
            backgroundOpacity: 0.88,
            cornerRadius: 12,
            textColorStyle: .automatic
        )
        let layoutEngine = OverlayLayoutEngine()
        let textFitter = OverlayTextFitter()

        let naiveLayouts = translationBlocks.map { block in
            let proposal = layoutEngine.proposal(
                for: block,
                in: input.size,
                style: overlayStyle
            )
            let fittedText = textFitter.fit(
                text: block.translatedText,
                within: proposal.textFrame.size,
                style: overlayStyle
            )
            return layoutEngine.resolvedLayout(
                for: block,
                fittedText: fittedText,
                in: input.size,
                style: overlayStyle
            )
        }

        XCTAssertTrue(
            naiveLayouts[0].outerFrame.intersects(naiveLayouts[1].outerFrame)
        )

        let result = try await realRenderedResult(
            for: job,
            observations: observations,
            groupedBlocks: groupedBlocks,
            translationBlocks: translationBlocks,
            overlayStyle: overlayStyle
        )

        XCTAssertFalse(
            result.translatedBlocks[0].targetFrame.intersects(result.translatedBlocks[1].targetFrame)
        )
        XCTAssertTrue(
            result.translatedBlocks.contains { block in
                abs(block.targetFrame.minX - block.sourceBoundingBox.minX) > 0.5
                    || abs(block.targetFrame.minY - block.sourceBoundingBox.minY) > 0.5
            }
        )
        XCTAssertTrue(
            result.renderMetadata.note.contains("collision adjustments")
        )
    }

    func testProcessWithRealRendererLimitsSameBandExpansionBeforeLargeNeighborJump() async throws {
        let input = ScreenshotInput(
            imageData: try TestFixtures.makePNGData(
                width: 320,
                height: 420
            ),
            size: CGSize(width: 320, height: 420),
            orientation: .up,
            sourceMetadata: .shortcuts(filename: "same-band-render.png")
        )
        let job = ProcessingJob(input: input)
        let observations = [
            observation("今日价", x: 24, y: 60, width: 72, height: 24, lineIndex: 0),
            observation("包邮", x: 126, y: 62, width: 64, height: 24, lineIndex: 0)
        ]
        let groupedBlocks = [
            textBlock(
                sourceText: "今日价",
                boundingBox: CGRect(x: 24, y: 60, width: 72, height: 24)
            ),
            textBlock(
                sourceText: "包邮",
                boundingBox: CGRect(x: 126, y: 62, width: 64, height: 24)
            )
        ]
        let translationBlocks = [
            translationBlock(
                sourceText: "今日价",
                translatedText: "Цена сегодня",
                sourceBoundingBox: groupedBlocks[0].combinedBoundingBox
            ),
            translationBlock(
                sourceText: "包邮",
                translatedText: "Бесплатная доставка",
                sourceBoundingBox: groupedBlocks[1].combinedBoundingBox
            )
        ]

        let result = try await realRenderedResult(
            for: job,
            observations: observations,
            groupedBlocks: groupedBlocks,
            translationBlocks: translationBlocks,
            overlayStyle: .defaultValue
        )

        let firstFrame = result.translatedBlocks[0].targetFrame
        let secondFrame = result.translatedBlocks[1].targetFrame

        XCTAssertFalse(firstFrame.intersects(secondFrame))
        XCTAssertLessThan(firstFrame.width, 150)
        XCTAssertLessThan(secondFrame.width, 178)
        XCTAssertLessThan(abs(firstFrame.minY - groupedBlocks[0].combinedBoundingBox.minY), 28)
        XCTAssertLessThan(abs(secondFrame.minY - groupedBlocks[1].combinedBoundingBox.minY), 48)
    }

    func testProcessThrowsNoTextDetectedWhenOCRReturnsNoObservations() async {
        let orchestrator = ProcessingOrchestrator(
            screenshotNormalizer: ScreenshotNormalizer(
                orientationResolver: ImageOrientationResolver()
            ),
            ocrService: OCRServiceStub(result: .success([])),
            textGroupingService: GroupingServiceStub(blocks: []),
            translationService: TranslationServiceStub(result: .success([])),
            overlayRenderer: OverlayRendererSpy(outcome: .failure(AppError.renderingFailure)),
            settingsStore: SettingsStoreStub(settings: .defaultValue)
        )

        do {
            _ = try await orchestrator.process(ProcessingJob(input: screenshotInput()))
            XCTFail("Expected process to throw noTextDetected")
        } catch {
            XCTAssertEqual(error as? AppError, .noTextDetected)
        }
    }

    func testProcessThrowsTranslationUnavailableWhenTranslationProducesNoBlocks() async {
        let observations = [
            observation("商品", x: 12, y: 18, width: 40, height: 18, lineIndex: 0)
        ]
        let groupedBlocks = [
            textBlock(
                sourceText: "商品",
                boundingBox: CGRect(x: 12, y: 18, width: 40, height: 18)
            )
        ]
        let orchestrator = ProcessingOrchestrator(
            screenshotNormalizer: ScreenshotNormalizer(
                orientationResolver: ImageOrientationResolver()
            ),
            ocrService: OCRServiceStub(result: .success(observations)),
            textGroupingService: GroupingServiceStub(blocks: groupedBlocks),
            translationService: TranslationServiceStub(result: .success([])),
            overlayRenderer: OverlayRendererSpy(outcome: .failure(AppError.renderingFailure)),
            settingsStore: SettingsStoreStub(settings: .defaultValue)
        )

        do {
            _ = try await orchestrator.process(ProcessingJob(input: screenshotInput()))
            XCTFail("Expected process to throw translationUnavailable")
        } catch {
            XCTAssertEqual(error as? AppError, .translationUnavailable)
        }
    }

    private func screenshotInput(
        size: CGSize = CGSize(width: 180, height: 320),
        orientation: ScreenshotInput.Orientation = .up
    ) -> ScreenshotInput {
        ScreenshotInput(
            imageData: Data([0x01, 0x02]),
            size: size,
            orientation: orientation,
            sourceMetadata: .shortcuts(filename: "processing.png")
        )
    }

    private func observation(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        lineIndex: Int
    ) -> OCRTextObservation {
        OCRTextObservation(
            originalText: text,
            boundingBox: CGRect(x: x, y: y, width: width, height: height),
            confidence: 0.95,
            lineIndex: lineIndex
        )
    }

    private func textBlock(
        sourceText: String,
        boundingBox: CGRect
    ) -> TextBlock {
        TextBlock(
            sourceText: sourceText,
            observations: [],
            combinedBoundingBox: boundingBox
        )
    }

    private func translationBlock(
        sourceText: String,
        translatedText: String,
        sourceBoundingBox: CGRect,
        renderingStyle: OverlayRenderStyle = .defaultValue
    ) -> TranslationBlock {
        TranslationBlock(
            sourceText: sourceText,
            translatedText: translatedText,
            sourceBoundingBox: sourceBoundingBox,
            targetFrame: sourceBoundingBox,
            renderingStyle: renderingStyle
        )
    }

    private func realRenderedResult(
        for job: ProcessingJob,
        observations: [OCRTextObservation],
        groupedBlocks: [TextBlock],
        translationBlocks: [TranslationBlock],
        overlayStyle: OverlayRenderStyle
    ) async throws -> OverlayRenderResult {
        let orchestrator = ProcessingOrchestrator(
            screenshotNormalizer: ScreenshotNormalizer(
                orientationResolver: ImageOrientationResolver()
            ),
            ocrService: OCRServiceStub(result: .success(observations)),
            textGroupingService: GroupingServiceStub(blocks: groupedBlocks),
            translationService: TranslationServiceStub(result: .success(translationBlocks)),
            overlayRenderer: OverlayRenderer(
                layoutEngine: OverlayLayoutEngine(),
                textFitter: OverlayTextFitter(),
                imageComposer: OverlayImageComposer()
            ),
            settingsStore: SettingsStoreStub(
                settings: AppSettings(
                    overlayStyle: overlayStyle,
                    preferredDisplayModeRawValue: "overlay",
                    historyEnabled: true,
                    debugOptionsEnabled: true
                )
            )
        )

        return try await orchestrator.process(job)
    }
}

private actor OCRServiceStub: OCRServiceProtocol {
    private let result: Result<[OCRTextObservation], Error>
    private var input: ScreenshotInput?

    init(result: Result<[OCRTextObservation], Error>) {
        self.result = result
    }

    func recognizeText(in input: ScreenshotInput) async throws -> [OCRTextObservation] {
        self.input = input
        return try result.get()
    }

    func lastInput() -> ScreenshotInput? {
        input
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
    private var blocks: [TextBlock]?

    init(result: Result<[TranslationBlock], Error>) {
        self.result = result
    }

    func translate(blocks: [TextBlock]) async throws -> [TranslationBlock] {
        self.blocks = blocks
        return try result.get()
    }

    func lastBlocks() -> [TextBlock]? {
        blocks
    }
}

private actor OverlayRendererSpy: OverlayRendererProtocol {
    enum Outcome {
        case success(OverlayRenderResult)
        case failure(Error)
    }

    private let outcome: Outcome
    private var input: ScreenshotInput?
    private var blocks: [TranslationBlock]?
    private var style: OverlayRenderStyle?

    init(outcome: Outcome) {
        self.outcome = outcome
    }

    func renderOverlay(
        for input: ScreenshotInput,
        translatedBlocks: [TranslationBlock],
        style: OverlayRenderStyle
    ) async throws -> OverlayRenderResult {
        self.input = input
        self.blocks = translatedBlocks
        self.style = style

        switch outcome {
        case .success(let result):
            return result
        case .failure(let error):
            throw error
        }
    }

    func lastInput() -> ScreenshotInput? {
        input
    }

    func lastBlocks() -> [TranslationBlock]? {
        blocks
    }

    func lastStyle() -> OverlayRenderStyle? {
        style
    }
}

private final class SettingsStoreStub: SettingsStoreProtocol {
    private(set) var settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func loadSettings() -> AppSettings {
        settings
    }

    func saveSettings(_ settings: AppSettings) {
        self.settings = settings
    }
}

private actor ProgressRecorder {
    private var recordedValues: [String] = []

    func record(_ progress: ProcessingOrchestrator.ProgressUpdate) {
        recordedValues.append(description(for: progress))
    }

    func values() -> [String] {
        recordedValues
    }

    private func description(
        for progress: ProcessingOrchestrator.ProgressUpdate
    ) -> String {
        switch progress {
        case .preparingImage(let imageSize):
            return "preparingImage:\(Int(imageSize.width))x\(Int(imageSize.height))"
        case .performingOCR:
            return "performingOCR"
        case .groupingText(let observationCount):
            return "groupingText:\(observationCount)"
        case .translatingBlocks(let blockCount):
            return "translatingBlocks:\(blockCount)"
        case .renderingOverlay(let translationCount):
            return "renderingOverlay:\(translationCount)"
        }
    }
}
