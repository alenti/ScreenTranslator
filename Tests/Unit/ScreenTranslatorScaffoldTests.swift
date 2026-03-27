import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import ScreenTranslator

final class ScreenTranslatorScaffoldTests: XCTestCase {
    func testPlaceholderOverlayResultIncludesTranslatedBlocksAndDefaultStyle() {
        let result = OverlayRenderResult.placeholder()

        XCTAssertEqual(result.translatedBlocks.count, 2)
        XCTAssertEqual(result.renderStyle, .defaultValue)
        XCTAssertNil(result.precomposedImageData)
        XCTAssertFalse(result.renderMetadata.note.isEmpty)
    }

    func testMissingLanguagePackErrorExposesUserFacingRecoveryCopy() {
        let error = AppError.missingLanguagePack

        XCTAssertEqual(error.title, "Offline Data Needed")
        XCTAssertNotNil(error.errorDescription)
        XCTAssertEqual(
            error.recoverySuggestion,
            "Prepare the offline Chinese to Russian language data, then retry the job."
        )
    }
}

enum TestFixtures {
    static func makePNGData(
        width: Int,
        height: Int,
        orientation: UInt32 = 1
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
            throw TestFixtureError.failedToCreateImage
        }

        context.setFillColor(CGColor(red: 0.15, green: 0.18, blue: 0.22, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let image = context.makeImage() else {
            throw TestFixtureError.failedToCreateImage
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            throw TestFixtureError.failedToCreateImage
        }

        let properties: CFDictionary = [
            kCGImagePropertyOrientation: orientation
        ] as CFDictionary

        CGImageDestinationAddImage(destination, image, properties)

        guard CGImageDestinationFinalize(destination) else {
            throw TestFixtureError.failedToCreateImage
        }

        return data as Data
    }

    static func makeTemporaryDirectory(
        prefix: String = "ScreenTranslatorTests"
    ) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(prefix)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )

        return directoryURL
    }
}

enum TestFixtureError: Error {
    case failedToCreateImage
}
