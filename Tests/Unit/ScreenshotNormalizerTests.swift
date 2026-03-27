import CoreGraphics
import XCTest
@testable import ScreenTranslator

final class ScreenshotNormalizerTests: XCTestCase {
    func testNormalizeSwapsDimensionsAndResetsRightOrientation() {
        let input = ScreenshotInput(
            imageData: Data([0x01]),
            size: CGSize(width: 1179, height: 2556),
            orientation: .right,
            scale: 3.0,
            sourceMetadata: .scaffold
        )
        let normalizer = ScreenshotNormalizer(
            orientationResolver: ImageOrientationResolver()
        )

        let normalized = normalizer.normalize(input)

        XCTAssertEqual(normalized.id, input.id)
        XCTAssertEqual(normalized.size, CGSize(width: 2556, height: 1179))
        XCTAssertEqual(normalized.orientation, .up)
        XCTAssertEqual(normalized.scale, 3.0)
        XCTAssertEqual(normalized.timestamp, input.timestamp)
        XCTAssertEqual(normalized.sourceMetadata, input.sourceMetadata)
    }

    func testNormalizeKeepsSizeForDownOrientation() {
        let input = ScreenshotInput(
            imageData: Data([0x01]),
            size: CGSize(width: 1290, height: 2796),
            orientation: .down,
            scale: 3.0,
            sourceMetadata: .scaffold
        )
        let normalizer = ScreenshotNormalizer(
            orientationResolver: ImageOrientationResolver()
        )

        let normalized = normalizer.normalize(input)

        XCTAssertEqual(normalized.size, CGSize(width: 1290, height: 2796))
        XCTAssertEqual(normalized.orientation, .up)
        XCTAssertEqual(normalized.scale, 3.0)
    }

    func testNormalizeRepairsInvalidSizeAndScaleValues() {
        let input = ScreenshotInput(
            imageData: Data([0x01]),
            size: CGSize(width: -400, height: CGFloat.nan),
            orientation: .left,
            scale: -CGFloat.infinity,
            sourceMetadata: .scaffold
        )
        let normalizer = ScreenshotNormalizer(
            orientationResolver: ImageOrientationResolver()
        )

        let normalized = normalizer.normalize(input)

        XCTAssertEqual(normalized.size, CGSize(width: 1, height: 400))
        XCTAssertEqual(normalized.orientation, ScreenshotInput.Orientation.up)
        XCTAssertEqual(normalized.scale, 1.0)
    }
}
