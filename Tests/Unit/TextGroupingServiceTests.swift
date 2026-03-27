import CoreGraphics
import XCTest
@testable import ScreenTranslator

final class TextGroupingServiceTests: XCTestCase {
    func testMakeBlocksProducesLogicalBlocksFromMixedLayout() {
        let service = TextGroupingService(
            grouper: BoundingBoxGrouper(),
            composer: TextBlockComposer()
        )
        let observations = [
            observation("设置", x: 24, y: 20, width: 52, height: 22, lineIndex: 0),
            observation("菜单", x: 24, y: 52, width: 52, height: 22, lineIndex: 1),
            observation("SHOP", x: 214, y: 20, width: 52, height: 22, lineIndex: 0),
            observation("NOW", x: 214, y: 52, width: 46, height: 22, lineIndex: 1),
            observation("继续", x: 24, y: 132, width: 52, height: 22, lineIndex: 2)
        ]

        let blocks = service.makeBlocks(from: observations)

        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].sourceText, "设置\n菜单")
        XCTAssertEqual(blocks[1].sourceText, "SHOP\nNOW")
        XCTAssertEqual(blocks[2].sourceText, "继续")
    }

    func testMakeBlocksSeparatesLatinCTAsWithClearGapOnSameRow() {
        let service = TextGroupingService(
            grouper: BoundingBoxGrouper(),
            composer: TextBlockComposer()
        )
        let observations = [
            observation("FREE", x: 24, y: 24, width: 46, height: 20, lineIndex: 0),
            observation("RETURNS", x: 104, y: 24, width: 70, height: 20, lineIndex: 0),
            observation("继续", x: 24, y: 78, width: 40, height: 22, lineIndex: 1)
        ]

        let blocks = service.makeBlocks(from: observations)

        XCTAssertEqual(blocks.count, 3)
        XCTAssertEqual(blocks[0].sourceText, "FREE")
        XCTAssertEqual(blocks[1].sourceText, "RETURNS")
        XCTAssertEqual(blocks[2].sourceText, "继续")
    }

    func testMakeBlocksKeepsDenseCommerceMetadataFragmentedAcrossRows() {
        let service = TextGroupingService(
            grouper: BoundingBoxGrouper(),
            composer: TextBlockComposer()
        )
        let observations = [
            observation("券后", x: 24, y: 28, width: 34, height: 20, lineIndex: 0),
            observation("¥129", x: 24, y: 56, width: 44, height: 22, lineIndex: 1),
            observation("包邮", x: 24, y: 84, width: 34, height: 20, lineIndex: 2),
            observation("月销1k+", x: 24, y: 112, width: 52, height: 20, lineIndex: 3)
        ]

        let blocks = service.makeBlocks(from: observations)

        XCTAssertEqual(blocks.count, 4)
        XCTAssertEqual(blocks[0].sourceText, "券后")
        XCTAssertEqual(blocks[1].sourceText, "¥129")
        XCTAssertEqual(blocks[2].sourceText, "包邮")
        XCTAssertEqual(blocks[3].sourceText, "月销1k+")
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
            confidence: 0.9,
            lineIndex: lineIndex
        )
    }
}
