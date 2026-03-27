import CoreGraphics
import XCTest
@testable import ScreenTranslator

final class TranslationBatchBuilderTests: XCTestCase {
    func testBuildBatchNormalizesWhitespaceAndSkipsEmptyBlocks() {
        let builder = TranslationBatchBuilder()
        let keptBlock = textBlock(
            sourceText: "  你好   世界  \n  第二   行  ",
            boundingBox: CGRect(x: 10, y: 20, width: 120, height: 48)
        )
        let skippedBlock = textBlock(
            sourceText: " \n   ",
            boundingBox: CGRect(x: 40, y: 80, width: 20, height: 20)
        )

        let batch = builder.buildBatch(from: [keptBlock, skippedBlock])

        XCTAssertEqual(batch.count, 1)
        XCTAssertEqual(batch[0].id, keptBlock.id)
        XCTAssertEqual(batch[0].blockIndex, 0)
        XCTAssertEqual(batch[0].clientIdentifier, keptBlock.id.uuidString)
        XCTAssertEqual(batch[0].sourceText, "你好 世界\n第二 行")
        XCTAssertEqual(batch[0].sourceBoundingBox, keptBlock.combinedBoundingBox)
    }

    func testMakeTranslationBlocksPrefersMatchingClientIdentifiers() {
        let builder = TranslationBatchBuilder()
        let batch = [
            batchItem(
                sourceText: "第一",
                boundingBox: CGRect(x: 10, y: 20, width: 60, height: 24)
            ),
            batchItem(
                sourceText: "第二",
                boundingBox: CGRect(x: 20, y: 60, width: 60, height: 24)
            )
        ]

        let results = [
            TranslationSessionBroker.ResultItem(
                clientIdentifier: batch[1].clientIdentifier,
                sourceText: batch[1].sourceText,
                translatedText: " второе "
            ),
            TranslationSessionBroker.ResultItem(
                clientIdentifier: batch[0].clientIdentifier,
                sourceText: batch[0].sourceText,
                translatedText: " первое "
            )
        ]

        let translationBlocks = builder.makeTranslationBlocks(
            from: batch,
            results: results
        )

        XCTAssertEqual(translationBlocks.map(\.translatedText), ["первое", "второе"])
        XCTAssertEqual(translationBlocks[0].targetFrame, batch[0].sourceBoundingBox)
        XCTAssertEqual(translationBlocks[1].targetFrame, batch[1].sourceBoundingBox)
    }

    func testMakeTranslationBlocksFallsBackToOrderedResultsAndThenSourceText() {
        let builder = TranslationBatchBuilder()
        let batch = [
            batchItem(
                sourceText: "原文一",
                boundingBox: CGRect(x: 12, y: 24, width: 80, height: 28)
            ),
            batchItem(
                sourceText: "原文二",
                boundingBox: CGRect(x: 12, y: 64, width: 80, height: 28)
            )
        ]

        let results = [
            TranslationSessionBroker.ResultItem(
                clientIdentifier: nil,
                sourceText: batch[0].sourceText,
                translatedText: " резерв "
            )
        ]

        let translationBlocks = builder.makeTranslationBlocks(
            from: batch,
            results: results
        )

        XCTAssertEqual(translationBlocks[0].translatedText, "резерв")
        XCTAssertEqual(translationBlocks[1].translatedText, "原文二")
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

    private func batchItem(
        sourceText: String,
        boundingBox: CGRect,
        renderingStyle: OverlayRenderStyle = .defaultValue
    ) -> TranslationBatchBuilder.BatchItem {
        TranslationBatchBuilder.BatchItem(
            id: UUID(),
            blockIndex: 0,
            clientIdentifier: UUID().uuidString,
            sourceText: sourceText,
            sourceBoundingBox: boundingBox,
            renderingStyle: renderingStyle
        )
    }
}
