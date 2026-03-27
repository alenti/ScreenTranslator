import CoreGraphics
import XCTest
@testable import ScreenTranslator

final class BoundingBoxGrouperTests: XCTestCase {
    func testGroupMergesAlignedNearbyLinesIntoSingleLogicalBlock() {
        let grouper = BoundingBoxGrouper()
        let observations = [
            observation("第一", x: 24, y: 32, width: 72, height: 24, lineIndex: 0),
            observation("行", x: 100, y: 32, width: 28, height: 24, lineIndex: 0),
            observation("第二", x: 26, y: 66, width: 74, height: 24, lineIndex: 1),
            observation("行", x: 104, y: 66, width: 28, height: 24, lineIndex: 1),
            observation("独立标题", x: 24, y: 146, width: 120, height: 26, lineIndex: 2)
        ]

        let groups = grouper.group(observations)

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].map(\.originalText), ["第一", "行", "第二", "行"])
        XCTAssertEqual(groups[1].map(\.originalText), ["独立标题"])
    }

    func testGroupSeparatesColumnsAndMergesEachColumnByReadingOrder() {
        let grouper = BoundingBoxGrouper()
        let observations = [
            observation("左一", x: 24, y: 20, width: 60, height: 22, lineIndex: 0),
            observation("右一", x: 218, y: 20, width: 60, height: 22, lineIndex: 0),
            observation("左二", x: 24, y: 52, width: 60, height: 22, lineIndex: 1),
            observation("右二", x: 218, y: 52, width: 60, height: 22, lineIndex: 1)
        ]

        let groups = grouper.group(observations)

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].map(\.originalText), ["左一", "左二"])
        XCTAssertEqual(groups[1].map(\.originalText), ["右一", "右二"])
    }

    func testGroupDoesNotMergeLatinWordsWithVisibleHorizontalGap() {
        let grouper = BoundingBoxGrouper()
        let observations = [
            observation("Free", x: 24, y: 28, width: 44, height: 20, lineIndex: 0),
            observation("Shipping", x: 98, y: 28, width: 78, height: 20, lineIndex: 0)
        ]

        let groups = grouper.group(observations)

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].map(\.originalText), ["Free"])
        XCTAssertEqual(groups[1].map(\.originalText), ["Shipping"])
    }

    func testGroupKeepsTightlySpacedCJKFragmentsTogether() {
        let grouper = BoundingBoxGrouper()
        let observations = [
            observation("立即", x: 24, y: 32, width: 38, height: 22, lineIndex: 0),
            observation("购买", x: 66, y: 32, width: 38, height: 22, lineIndex: 0)
        ]

        let groups = grouper.group(observations)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].map(\.originalText), ["立即", "购买"])
    }

    func testGroupSeparatesAdjacentShortCJKLabelsOnSameRow() {
        let grouper = BoundingBoxGrouper()
        let observations = [
            observation("登录", x: 24, y: 32, width: 38, height: 22, lineIndex: 0),
            observation("注册", x: 82, y: 32, width: 38, height: 22, lineIndex: 0)
        ]

        let groups = grouper.group(observations)

        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(groups[0].map(\.originalText), ["登录"])
        XCTAssertEqual(groups[1].map(\.originalText), ["注册"])
    }

    func testGroupSeparatesMultipleCompactSameRowLabels() {
        let grouper = BoundingBoxGrouper()
        let observations = [
            observation("推荐", x: 24, y: 32, width: 36, height: 22, lineIndex: 0),
            observation("新品", x: 78, y: 32, width: 36, height: 22, lineIndex: 0),
            observation("折扣", x: 132, y: 32, width: 36, height: 22, lineIndex: 0)
        ]

        let groups = grouper.group(observations)

        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups[0].map(\.originalText), ["推荐"])
        XCTAssertEqual(groups[1].map(\.originalText), ["新品"])
        XCTAssertEqual(groups[2].map(\.originalText), ["折扣"])
    }

    func testGroupKeepsShortLatinPhraseWithNormalWordSpacingTogether() {
        let grouper = BoundingBoxGrouper()
        let observations = [
            observation("Sign", x: 24, y: 28, width: 34, height: 20, lineIndex: 0),
            observation("In", x: 64, y: 28, width: 14, height: 20, lineIndex: 0)
        ]

        let groups = grouper.group(observations)

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].map(\.originalText), ["Sign", "In"])
    }

    func testGroupSeparatesPriceAndPromoChipOnSameRow() {
        let grouper = BoundingBoxGrouper()
        let observations = [
            observation("¥129", x: 24, y: 30, width: 42, height: 20, lineIndex: 0),
            observation("包邮", x: 78, y: 30, width: 34, height: 20, lineIndex: 0),
            observation("月销1k+", x: 126, y: 30, width: 54, height: 20, lineIndex: 0)
        ]

        let groups = grouper.group(observations)

        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups[0].map(\.originalText), ["¥129"])
        XCTAssertEqual(groups[1].map(\.originalText), ["包邮"])
        XCTAssertEqual(groups[2].map(\.originalText), ["月销1k+"])
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
}
