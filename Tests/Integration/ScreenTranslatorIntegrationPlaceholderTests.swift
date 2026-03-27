import CoreGraphics
import XCTest
@testable import ScreenTranslator

final class ScreenTranslatorIntegrationSmokeTests: XCTestCase {
    func testTemporaryImageStoreStartsEmpty() async throws {
        let baseDirectoryURL = try TestFixtures.makeTemporaryDirectory(
            prefix: "TemporaryImageStoreSmoke"
        )
        defer { try? FileManager.default.removeItem(at: baseDirectoryURL) }

        let store = TemporaryImageStore(baseDirectoryURL: baseDirectoryURL)

        let peekedInput = try await store.peekLatestInput()
        let consumedInput = try await store.consumeLatestInput()

        XCTAssertNil(peekedInput)
        XCTAssertNil(consumedInput)
    }

    func testIntentResultRouterReturnsProcessingForIncomingScreenshot() {
        let router = IntentResultRouter()
        let input = ScreenshotInput(
            imageData: Data([0x01]),
            size: CGSize(width: 320, height: 640),
            orientation: .up,
            sourceMetadata: .shortcuts(filename: "sample.png")
        )

        XCTAssertEqual(router.routeForIncomingScreenshot(input), .processing)
    }
}
