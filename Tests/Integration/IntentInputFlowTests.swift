import Foundation
import XCTest
@testable import ScreenTranslator

final class IntentInputFlowTests: XCTestCase {
    func testBuiltScreenshotRoundTripsThroughTemporaryStoreAndRoutesToProcessing() async throws {
        let baseDirectoryURL = try TestFixtures.makeTemporaryDirectory(
            prefix: "IntentInputFlow"
        )
        defer { try? FileManager.default.removeItem(at: baseDirectoryURL) }
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

        let imageData = try TestFixtures.makePNGData(
            width: 64,
            height: 32,
            orientation: 6
        )
        let builder = ScreenshotInputBuilder()
        let store = TemporaryImageStore(baseDirectoryURL: baseDirectoryURL)
        let router = IntentResultRouter()

        let input = try builder.build(
            imageData: imageData,
            sourceMetadata: .shortcuts(filename: "capture.png"),
            scale: 3.0,
            timestamp: timestamp
        )
        let request = IntentHandoffRequest(
            screenshot: input,
            launchBehavior: .openInApp
        )

        try await store.store(request)

        let peekedRequest = try await store.peekLatestRequest()
        let consumedRequest = try await store.consumeLatestRequest()
        let afterConsume = try await store.peekLatestRequest()

        XCTAssertEqual(peekedRequest, request)
        XCTAssertEqual(consumedRequest, request)
        XCTAssertNil(afterConsume)
        XCTAssertEqual(
            router.routeForIncomingRequest(request),
            .processing
        )
    }

    func testConsumeLatestInputThrowsIntentInputFailureForCorruptedPayload() async throws {
        let baseDirectoryURL = try TestFixtures.makeTemporaryDirectory(
            prefix: "IntentInputCorruption"
        )
        defer { try? FileManager.default.removeItem(at: baseDirectoryURL) }

        let storeURL = baseDirectoryURL
            .appendingPathComponent("ScreenTranslator", isDirectory: true)
            .appendingPathComponent("IntentHandoff", isDirectory: true)
            .appendingPathComponent("pending-screenshot.json")

        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not-json".utf8).write(to: storeURL)

        let store = TemporaryImageStore(baseDirectoryURL: baseDirectoryURL)

        do {
            _ = try await store.consumeLatestInput()
            XCTFail("Expected corrupted intent payload to throw")
        } catch {
            XCTAssertEqual(error as? AppError, .intentInputFailure)
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: storeURL.path))
    }

    func testStalePendingScreenshotIsDiscardedInsteadOfBeingReplayed() async throws {
        let baseDirectoryURL = try TestFixtures.makeTemporaryDirectory(
            prefix: "IntentInputStale"
        )
        defer { try? FileManager.default.removeItem(at: baseDirectoryURL) }

        let staleTimestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let now = Date(timeIntervalSince1970: 1_700_000_000 + 3_600)
        let imageData = try TestFixtures.makePNGData(
            width: 64,
            height: 32,
            orientation: 1
        )
        let builder = ScreenshotInputBuilder()
        let store = TemporaryImageStore(
            baseDirectoryURL: baseDirectoryURL,
            maxPendingAge: 60,
            now: { now }
        )

        let input = try builder.build(
            imageData: imageData,
            sourceMetadata: .shortcuts(filename: "stale-capture.png"),
            scale: 3.0,
            timestamp: staleTimestamp
        )

        try await store.store(input)

        let peekedInput = try await store.peekLatestInput()
        let consumedInput = try await store.consumeLatestInput()

        XCTAssertNil(peekedInput)
        XCTAssertNil(consumedInput)
    }

    func testLegacyScreenshotPayloadStillDecodesAsOpenInAppRequest() async throws {
        let baseDirectoryURL = try TestFixtures.makeTemporaryDirectory(
            prefix: "IntentLegacyInput"
        )
        defer { try? FileManager.default.removeItem(at: baseDirectoryURL) }

        let imageData = try TestFixtures.makePNGData(
            width: 64,
            height: 32,
            orientation: 1
        )
        let builder = ScreenshotInputBuilder()
        let store = TemporaryImageStore(baseDirectoryURL: baseDirectoryURL)
        let input = try builder.build(
            imageData: imageData,
            sourceMetadata: .shortcuts(filename: "legacy.png"),
            scale: 3.0,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )

        try await store.store(input)

        let request = try await store.consumeLatestRequest()

        XCTAssertEqual(
            request,
            IntentHandoffRequest(
                screenshot: input,
                launchBehavior: .openInApp
            )
        )
    }

    func testFloatingPreviewRequestsRoundTripThroughTemporaryStore() async throws {
        let baseDirectoryURL = try TestFixtures.makeTemporaryDirectory(
            prefix: "IntentFloatingRoundTrip"
        )
        defer { try? FileManager.default.removeItem(at: baseDirectoryURL) }

        let imageData = try TestFixtures.makePNGData(
            width: 64,
            height: 32,
            orientation: 1
        )
        let builder = ScreenshotInputBuilder()
        let store = TemporaryImageStore(baseDirectoryURL: baseDirectoryURL)
        let input = try builder.build(
            imageData: imageData,
            sourceMetadata: .shortcuts(filename: "floating.png"),
            scale: 3.0,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let request = IntentHandoffRequest(
            screenshot: input,
            launchBehavior: .floatingPreview
        )

        try await store.store(request)

        let peekedRequest = try await store.peekLatestRequest()
        let consumedRequest = try await store.consumeLatestRequest()
        let pendingRequest = try await store.peekLatestRequest()

        XCTAssertEqual(peekedRequest, request)
        XCTAssertEqual(consumedRequest, request)
        XCTAssertNil(pendingRequest)
    }
}
