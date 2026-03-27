import CoreGraphics
import XCTest
@testable import ScreenTranslator

final class OverlayTextFitterTests: XCTestCase {
    func testFitNormalizesTextAndKeepsMaximumFontSizeWhenSpaceAllows() {
        let fitter = OverlayTextFitter()
        let style = OverlayRenderStyle.defaultValue

        let fitted = fitter.fit(
            text: "  Привет  \n  мир  ",
            within: CGSize(width: 280, height: 200),
            style: style
        )

        XCTAssertEqual(fitted.text, "Привет\nмир")
        XCTAssertEqual(fitted.fontSize, style.maximumFontSize)
        XCTAssertGreaterThanOrEqual(fitted.lineCount, 2)
    }

    func testFitDropsToMinimumFontSizeWhenHeightIsExtremelyTight() {
        let fitter = OverlayTextFitter()
        let style = OverlayRenderStyle.defaultValue

        let fitted = fitter.fit(
            text: "Очень длинный русский перевод для тесного блока",
            within: CGSize(width: 110, height: 12),
            style: style
        )

        XCTAssertEqual(fitted.fontSize, style.minimumFontSize)
        XCTAssertGreaterThan(fitted.lineCount, 1)
    }

    func testFitWrapsIntoMoreLinesForNarrowWidth() {
        let fitter = OverlayTextFitter()
        let style = OverlayRenderStyle.defaultValue
        let text = "Очень длинный русский текст для проверки переноса строк"

        let wide = fitter.fit(
            text: text,
            within: CGSize(width: 320, height: 240),
            style: style
        )
        let narrow = fitter.fit(
            text: text,
            within: CGSize(width: 90, height: 240),
            style: style
        )

        XCTAssertGreaterThan(narrow.lineCount, wide.lineCount)
        XCTAssertLessThanOrEqual(narrow.fontSize, wide.fontSize)
    }
}
