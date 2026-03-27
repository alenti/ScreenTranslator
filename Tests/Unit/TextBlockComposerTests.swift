import CoreGraphics
import XCTest
@testable import ScreenTranslator

final class TextBlockComposerTests: XCTestCase {
    func testComposeBuildsCleanMultilineChineseTextAndBoundingBoxUnion() {
        let composer = TextBlockComposer()
        let groups = [[
            observation("你好", x: 20, y: 24, width: 46, height: 22, lineIndex: 0),
            observation("世界", x: 68, y: 24, width: 48, height: 22, lineIndex: 0),
            observation("第二", x: 22, y: 54, width: 44, height: 22, lineIndex: 1),
            observation("行", x: 68, y: 54, width: 24, height: 22, lineIndex: 1)
        ]]

        let blocks = composer.compose(groups: groups)

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].sourceText, "你好世界\n第二行")
        XCTAssertEqual(
            blocks[0].combinedBoundingBox,
            CGRect(x: 20, y: 24, width: 96, height: 52)
        )
    }

    func testComposeAddsSpaceBetweenSeparatedLatinFragments() {
        let composer = TextBlockComposer()
        let groups = [[
            observation("Tap", x: 20, y: 24, width: 28, height: 20, lineIndex: 0),
            observation("Continue", x: 62, y: 24, width: 72, height: 20, lineIndex: 0)
        ]]

        let blocks = composer.compose(groups: groups)

        XCTAssertEqual(blocks.first?.sourceText, "Tap Continue")
    }

    func testComposeKeepsHyphenatedLatinFragmentsWithoutInsertingExtraSpace() {
        let composer = TextBlockComposer()
        let groups = [[
            observation("Sign-", x: 20, y: 24, width: 42, height: 20, lineIndex: 0),
            observation("in", x: 63, y: 24, width: 18, height: 20, lineIndex: 0)
        ]]

        let blocks = composer.compose(groups: groups)

        XCTAssertEqual(blocks.first?.sourceText, "Sign-in")
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
            confidence: 0.96,
            lineIndex: lineIndex
        )
    }
}
