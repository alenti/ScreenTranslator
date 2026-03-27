import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ScreenTranslator

final class ScreenshotInputBuilderTests: XCTestCase {
    func testBuildFromImageDataReadsPixelSizeAndOrientationMetadata() throws {
        let imageData = try makePNGData(width: 48, height: 24, orientation: 6)
        let builder = ScreenshotInputBuilder()

        let input = try builder.build(
            imageData: imageData,
            sourceMetadata: .shortcuts(filename: "capture.png"),
            scale: 3.0
        )

        XCTAssertEqual(input.size, CGSize(width: 48, height: 24))
        XCTAssertEqual(input.orientation, .right)
        XCTAssertEqual(input.scale, 3.0)
        XCTAssertEqual(
            input.sourceMetadata,
            .shortcuts(filename: "capture.png")
        )
    }

    func testBuildWithExplicitValuesSanitizesSizeAndScale() {
        let builder = ScreenshotInputBuilder()

        let input = builder.build(
            imageData: Data([0x01]),
            size: CGSize(width: -120, height: 0),
            orientation: .down,
            scale: 0
        )

        XCTAssertEqual(input.size, CGSize(width: 120, height: 1))
        XCTAssertEqual(input.orientation, .down)
        XCTAssertEqual(input.scale, 1.0)
    }

    func testBuildFromImageDataThrowsForUnreadableImageData() {
        let builder = ScreenshotInputBuilder()

        XCTAssertThrowsError(try builder.build(imageData: Data())) { error in
            XCTAssertEqual(error as? AppError, .unsupportedImage)
        }
    }

    private func makePNGData(
        width: Int,
        height: Int,
        orientation: UInt32
    ) throws -> Data {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("Failed to create bitmap context")
            throw TestError.failedToCreateImage
        }

        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let image = context.makeImage() else {
            XCTFail("Failed to create CGImage")
            throw TestError.failedToCreateImage
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            XCTFail("Failed to create image destination")
            throw TestError.failedToCreateImage
        }

        let properties: CFDictionary = [
            kCGImagePropertyOrientation: orientation
        ] as CFDictionary

        CGImageDestinationAddImage(destination, image, properties)

        guard CGImageDestinationFinalize(destination) else {
            XCTFail("Failed to finalize PNG image data")
            throw TestError.failedToCreateImage
        }

        return data as Data
    }
}

private enum TestError: Error {
    case failedToCreateImage
}
