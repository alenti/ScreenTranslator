import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import UIKit
import XCTest
@testable import ChinaTap_Screen_Translator

@MainActor
final class SharedCoreContractTests: XCTestCase {
    func testFullViewerKeepsExactProcessedImageAndIdentity() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { _ in }
        let result = ProcessedScreenshot(requestID: UUID(), targetLanguage: .english,
            originalImage: image, renderedImage: image, blocks: [], warnings: [], report: [:])
        let coordinator = AppCoordinator()
        coordinator.showProcessedResult(result, floating: true)
        coordinator.openFullViewer()
        XCTAssertEqual(coordinator.route, .result)
        XCTAssertEqual(coordinator.processedScreenshot?.requestID, result.requestID)
        XCTAssertTrue(coordinator.processedScreenshot?.renderedImage === image)
        // Closing keeps the result so Home can reopen it without another translation.
        coordinator.returnHome()
        XCTAssertEqual(coordinator.route, .idle)
        coordinator.openFullViewer()
        XCTAssertTrue(coordinator.processedScreenshot?.renderedImage === image)
        coordinator.returnHome(); coordinator.releaseLastResult()
        XCTAssertNil(coordinator.processedScreenshot)
    }

    func testErrorsNeverExposeNativeMessages() {
        XCTAssertEqual(AppError(failure("Model missing. Import x in Settings before translating.")), .modelNotInstalled)
        XCTAssertEqual(AppError(failure("Model SHA256 does not match pinned model")), .modelDamaged)
        XCTAssertEqual(AppError(failure("GGUF load failed")), .modelLoadFailed)
        XCTAssertEqual(AppError(failure("No Chinese text was recognized in the supplied screenshot.")), .noTextFound)
        XCTAssertEqual(AppError(NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)), .insufficientStorage)
        let native = AppError(failure("Batched decode failed: llama_decode -3"))
        XCTAssertFalse(native.errorDescription!.contains("llama"))
        XCTAssertTrue(native.detail.contains("llama_decode -3"))
    }

    func testPresentationAndTargetSettingsPersist() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "SettingsTest-\(UUID().uuidString)"))
        let settings = SettingsViewModel(defaults: defaults)
        XCTAssertEqual(settings.resultPresentation, .quickPreview)
        settings.resultPresentation = .openInApp
        settings.localTarget = .english
        settings.onboardingStep = 3
        let reloaded = SettingsViewModel(defaults: defaults)
        XCTAssertEqual(reloaded.resultPresentation, .openInApp)
        XCTAssertEqual(reloaded.localTarget, .english)
        XCTAssertEqual(reloaded.onboardingStep, 3)
        XCTAssertEqual(defaults.string(forKey: "localTarget"), "english") // Read by the Quick Look intent.
    }

    func testProtectedValuesMustSurviveExactly() throws {
        let spans = try ProtectedSpans("测试 USB-C 54W ¥135")
        XCTAssertEqual(try spans.restore(spans.input), "测试 USB-C 54W ¥135")
        XCTAssertThrowsError(try spans.restore("[[P1]]"))
    }

    func testSinglePinnedModelUsesVerifiedSeparatePath() throws {
        let url = try XCTUnwrap(Bundle(for:AppCoordinator.self).url(forResource:"model",withExtension:"json"))
        let manifest = try JSONSerialization.jsonObject(with:Data(contentsOf:url)) as! [String:Any]
        XCTAssertEqual(manifest["sha256"] as? String,"dc5f44fcf1fa496ee7ad725982c0c8c553a4de00259b53af84c4b89fb0c06699")
        XCTAssertEqual(try modelFileURL(manifest).lastPathComponent,"Hy-MT2-1.8B-Q4_K_M.gguf")
        XCTAssertThrowsError(try modelFileURL([:]))
        XCTAssertThrowsError(try modelFileURL(["localPath":"../model.gguf"]))
        XCTAssertThrowsError(try modelFileURL(["localPath":"/model.gguf"]))
    }

    func testExactCacheSeparatesValuesLanguagesModelsTemplatesAndSampling() throws {
        let manifest:[String:Any] = ["sha256":"model-a","runtimeRevision":"runtime-a","sampling":["seed":42]]
        func key(_ source:String = "价格 ¥10",_ language:TargetLanguage = .english,_ config:[String:Any]? = nil,_ template:String = "template-a") throws -> String {
            try ExactTranslationMemory.key(source:source,language:language,manifest:config ?? manifest,template:template)
        }
        let base=try key()
        XCTAssertNotEqual(base,try key("价格 ¥20"))
        XCTAssertNotEqual(base,try key("价格 ¥10",.russian))
        XCTAssertNotEqual(base,try key("价格 ¥10",.english,["sha256":"model-b"]))
        XCTAssertNotEqual(base,try key("价格 ¥10",.english,["sha256":"model-a","runtimeRevision":"runtime-b"]))
        XCTAssertNotEqual(base,try key("价格 ¥10",.english,["sha256":"model-a","sampling":["seed":43]]))
        XCTAssertNotEqual(base,try key("价格 ¥10",.english,nil,"template-b"))
        XCTAssertEqual(try key("é测试"),try key("e\u{301}测试"))
    }

    func testExactCacheRejectsCorruptionAndEvictsWithinBothLimits() throws {
        var cache=ExactTranslationMemory(maximumEntries:2,maximumBytes:64)
        XCTAssertThrowsError(try cache.insert("lost value",source:"价格 ¥10",key:"bad"))
        XCTAssertNil(cache.value(for:"bad"))
        XCTAssertThrowsError(try cache.insert(" ",source:"测试",key:"empty"))
        try cache.insert("Price [[P0]]",source:"价格 ¥10",key:"a")
        XCTAssertEqual(cache.value(for:"a"),"Price [[P0]]")
        try cache.insert("Search",source:"搜索",key:"b")
        try cache.insert("Cart",source:"购物车",key:"c")
        XCTAssertNil(cache.value(for:"a"))
        try cache.insert(String(repeating:"x",count:100),source:"测试",key:"large")
        XCTAssertNil(cache.value(for:"large"))
        cache.clear()
        XCTAssertNil(cache.value(for:"b"));XCTAssertNil(cache.value(for:"c"))
    }

    func testCorruptedSpanRejectsOnlyThatBlockAndQuickLookShowsWarning() throws {
        let spans = try ProtectedSpans("2026新款适用苹果18promax 日默瓦经纬系列\nMagsafe 磁吸铝镁合金手机壳17pro轻奢…")
        let raw = "The new model for 2026 is suitable for the Apple 18; it belongs to the Rimeva Latitude and Longitude series. [[P1]] Magnetic aluminum-magnesium alloy phone case; 17[[P2]] Premium design…"
        var failed = ProcessedBlock(id: 5, sourceText: "source", sourceRect: CGRect(x: 0, y: 0, width: 100, height: 30))
        XCTAssertNil(failed.restoreTranslation(raw, using: spans))
        XCTAssertNil(failed.translatedText)
        XCTAssertNil(failed.renderedRect)
        XCTAssertEqual(failed.failure?.stage, .translation)
        var valid = ProcessedBlock(id: 9, sourceText: "搜索", sourceRect: .zero)
        XCTAssertEqual(valid.restoreTranslation("Search", using: try ProtectedSpans("搜索")), "Search")
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1170, height: 2000), format: format).image { _ in UIColor.white.setFill(); UIRectFill(CGRect(x: 0, y: 0, width: 1170, height: 2000)) }
        let complete = ProcessedScreenshot(requestID: UUID(), targetLanguage: .english, originalImage: image, renderedImage: image, blocks: [valid], warnings: [], report: [:])
        XCTAssertTrue(quickLookPreviewImage(complete) === image)
        let partial = ProcessedScreenshot(requestID: UUID(), targetLanguage: .english, originalImage: image, renderedImage: image, blocks: [failed, valid], warnings: [failed.failure!], report: [:])
        XCTAssertTrue(partial.isPartial)
        XCTAssertEqual(ResultOverlayViewModel(result: partial).translationFailureCount, 1)
        let preview = quickLookPreviewImage(partial)
        XCTAssertEqual(preview.size.width, image.size.width)
        XCTAssertGreaterThan(preview.size.height, image.size.height)
        XCTAssertEqual(preview.cgImage?.cropping(to: CGRect(origin: .zero, size: image.size))?.height, image.cgImage?.height)
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
