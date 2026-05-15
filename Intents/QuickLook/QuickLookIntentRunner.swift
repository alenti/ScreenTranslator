import AppIntents
import Foundation
import OSLog
import UIKit
import UniformTypeIdentifiers

enum QuickLookIntentMode: Sendable {
    case translated
    case debug
    case echo

    var filename: String {
        switch self {
        case .translated:
            return "screen-translator-result.png"
        case .debug:
            return "screen-translator-debug.png"
        case .echo:
            return "screen-translator-echo.png"
        }
    }

    var logName: String {
        switch self {
        case .translated:
            return "normal"
        case .debug:
            return "debug"
        case .echo:
            return "echo"
        }
    }

    var returnMarker: QuickLookIntentReturnMarker {
        switch self {
        case .translated:
            return .normal
        case .debug:
            return .debug
        case .echo:
            return .echo
        }
    }
}

struct QuickLookIntentRunner {
    private let timeoutNanoseconds: UInt64
    private let logger = Logger(
        subsystem: "AlenShamatov.ScreenTranslator",
        category: "QuickLookIntent"
    )

    init(timeoutNanoseconds: UInt64 = 15_000_000_000) {
        self.timeoutNanoseconds = timeoutNanoseconds
    }

    func run(
        screenshot: IntentFile,
        mode: QuickLookIntentMode
    ) async -> QuickLookIntentFileResult {
        let fallbackRenderer = QuickLookFallbackRenderer()
        let decoder = IntentInputDecoder()
        let fileFactory = QuickLookIntentFileFactory()
        var fallbackImageData: Data?

        do {
            let snapshot = try decoder.snapshot(screenshot)
            fallbackImageData = snapshot.imageData

            logger.info(
                """
                Quick Look \(mode.logName, privacy: .public) input bytes=\
                \(snapshot.imageData.count, privacy: .public), source=\
                \(snapshot.sourceDescription, privacy: .public)
                """
            )

            let decodedScreenshot = try decoder.decode(snapshot)

            logger.info(
                """
                Quick Look \(mode.logName, privacy: .public) image decode \
                success size=\(Int(decodedScreenshot.size.width), privacy: .public)x\
                \(Int(decodedScreenshot.size.height), privacy: .public)
                """
            )

            let pngData = try await Self.withTimeout(
                nanoseconds: timeoutNanoseconds
            ) {
                let observations = try await VisionOCRService(
                    requestFactory: OCRRequestFactory()
                ).recognizeText(
                    in: decodedScreenshot
                )
                let cjkCount = Self.cjkCount(in: observations)

                logger.info(
                    """
                    Quick Look \(mode.logName, privacy: .public) OCR blocks=\
                    \(observations.count, privacy: .public), cjk=\
                    \(cjkCount, privacy: .public)
                    """
                )

                let outputData: Data

                switch mode {
                case .translated:
                    logger.info(
                        """
                        Quick Look Local MT startup enabled=\
                        \(QuickLookLocalMTConfig.isEnabled, privacy: .public), \
                        baseURL=\(QuickLookLocalMTConfig.baseURLString, privacy: .public), \
                        cjkOCRBlocks=\(cjkCount, privacy: .public)
                        """
                    )

                    if cjkCount == 0 {
                        logger.info(
                            """
                            Quick Look Local MT preparedMTBlocks=0 reason=\
                            noCJKFastPath
                            """
                        )

                        outputData = fallbackRenderer.renderPNGData(
                            backgroundImageData: decodedScreenshot.imageData,
                            message: "No Chinese text detected"
                        )
                    } else {
                        outputData = try await QuickLookOverlayRenderer().renderPNGData(
                            for: decodedScreenshot,
                            observations: observations
                        )
                    }
                case .debug:
                    outputData = try await QuickLookDiagnosticsRenderer().renderPNGData(
                        for: decodedScreenshot,
                        observations: observations
                    )
                case .echo:
                    outputData = decodedScreenshot.imageData
                }

                logger.info(
                    """
                    Quick Look \(mode.logName, privacy: .public) output PNG \
                    bytes=\(outputData.count, privacy: .public)
                    """
                )

                return outputData
            }

            return fileFactory.makePNGFile(
                data: pngData,
                filename: mode.filename,
                marker: mode.returnMarker
            )
        } catch is QuickLookIntentTimeoutError {
            logger.error(
                "Quick Look \(mode.logName, privacy: .public) timed out"
            )

            let pngData = fallbackRenderer.renderPNGData(
                backgroundImageData: fallbackImageData,
                message: "ScreenTranslator timed out"
            )

            logger.info(
                """
                Quick Look \(mode.logName, privacy: .public) fallback PNG \
                bytes=\(pngData.count, privacy: .public)
                """
            )

            return fileFactory.makePNGFile(
                data: pngData,
                filename: mode.filename,
                marker: .error
            )
        } catch {
            logger.error(
                """
                Quick Look \(mode.logName, privacy: .public) caught error: \
                \(String(describing: error), privacy: .public)
                """
            )

            let pngData = fallbackRenderer.renderPNGData(
                backgroundImageData: fallbackImageData,
                message: "ScreenTranslator error"
            )

            logger.info(
                """
                Quick Look \(mode.logName, privacy: .public) fallback PNG \
                bytes=\(pngData.count, privacy: .public)
                """
            )

            return fileFactory.makePNGFile(
                data: pngData,
                filename: mode.filename,
                marker: .error
            )
        }
    }

    func runEcho(
        screenshot: IntentFile
    ) async -> QuickLookIntentFileResult {
        let fallbackRenderer = QuickLookFallbackRenderer()
        let decoder = IntentInputDecoder()
        let fileFactory = QuickLookIntentFileFactory()
        var fallbackImageData: Data?

        do {
            let snapshot = try decoder.snapshot(screenshot)
            fallbackImageData = snapshot.imageData

            logger.info(
                """
                Quick Look echo input bytes=\
                \(snapshot.imageData.count, privacy: .public), source=\
                \(snapshot.sourceDescription, privacy: .public)
                """
            )

            guard let image = UIImage(data: snapshot.imageData) else {
                throw AppError.unsupportedImage
            }

            logger.info(
                """
                Quick Look echo image decode success size=\
                \(Self.pixelWidth(for: image), privacy: .public)x\
                \(Self.pixelHeight(for: image), privacy: .public)
                """
            )

            let pngData: Data
            if Self.isPNGData(snapshot.imageData) {
                pngData = snapshot.imageData
            } else if let encodedPNGData = image.pngData(),
                      encodedPNGData.isEmpty == false {
                pngData = encodedPNGData
            } else {
                throw AppError.unsupportedImage
            }

            logger.info(
                "Quick Look echo output PNG bytes=\(pngData.count, privacy: .public)"
            )

            return fileFactory.makePNGFile(
                data: pngData,
                filename: QuickLookIntentMode.echo.filename,
                marker: .echo
            )
        } catch {
            logger.error(
                """
                Quick Look echo caught error: \
                \(String(describing: error), privacy: .public)
                """
            )

            let pngData = fallbackRenderer.renderPNGData(
                backgroundImageData: fallbackImageData,
                message: "ScreenTranslator echo error"
            )

            logger.info(
                "Quick Look echo fallback PNG bytes=\(pngData.count, privacy: .public)"
            )

            return fileFactory.makePNGFile(
                data: pngData,
                filename: QuickLookIntentMode.echo.filename,
                marker: .error
            )
        }
    }

    private static func cjkCount(
        in observations: [OCRTextObservation]
    ) -> Int {
        let detector = QuickLookCJKTextDetector()

        return observations.filter { observation in
            detector.containsCJK(in: observation.originalText)
        }.count
    }

    private static func withTimeout<T: Sendable>(
        nanoseconds: UInt64,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        let state = QuickLookTimeoutState<T>()
        var operationTask: Task<Void, Never>?
        var timeoutTask: Task<Void, Never>?

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                operationTask = Task {
                    do {
                        let value = try await operation()
                        timeoutTask?.cancel()
                        state.resume(.success(value), continuation: continuation)
                    } catch {
                        timeoutTask?.cancel()
                        state.resume(.failure(error), continuation: continuation)
                    }
                }

                timeoutTask = Task {
                    do {
                        try await Task.sleep(nanoseconds: nanoseconds)
                    } catch {
                        return
                    }

                    operationTask?.cancel()
                    state.resume(
                        .failure(QuickLookIntentTimeoutError()),
                        continuation: continuation
                    )
                }
            }
        } onCancel: {
            operationTask?.cancel()
            timeoutTask?.cancel()
        }
    }

    private static func isPNGData(_ data: Data) -> Bool {
        let pngSignature: [UInt8] = [
            0x89,
            0x50,
            0x4E,
            0x47,
            0x0D,
            0x0A,
            0x1A,
            0x0A
        ]

        guard data.count >= pngSignature.count else {
            return false
        }

        return zip(data.prefix(pngSignature.count), pngSignature)
            .allSatisfy { pair in
                pair.0 == pair.1
            }
    }

    private static func pixelWidth(for image: UIImage) -> Int {
        image.cgImage?.width ?? Int(image.size.width * image.scale)
    }

    private static func pixelHeight(for image: UIImage) -> Int {
        image.cgImage?.height ?? Int(image.size.height * image.scale)
    }
}

private struct QuickLookIntentTimeoutError: Error {}

private final class QuickLookTimeoutState<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false

    func resume(
        _ result: Result<T, Error>,
        continuation: CheckedContinuation<T, Error>
    ) {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard didResume == false else {
            return
        }

        didResume = true
        continuation.resume(with: result)
    }
}

private struct QuickLookFallbackRenderer {
    func renderPNGData(
        backgroundImageData: Data?,
        message: String
    ) -> Data {
        let sourceImage = backgroundImageData.flatMap(UIImage.init(data:))
        let canvasSize = sourceImage.map(Self.pixelSize) ?? CGSize(
            width: 1179,
            height: 2556
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(
            size: canvasSize,
            format: format
        )

        return renderer.pngData { _ in
            let canvasRect = CGRect(origin: .zero, size: canvasSize)

            if let sourceImage {
                sourceImage.draw(in: canvasRect)
            } else {
                UIColor(
                    red: 0.96,
                    green: 0.96,
                    blue: 0.98,
                    alpha: 1
                ).setFill()
                UIRectFill(canvasRect)
            }

            drawMessage(message, canvasRect: canvasRect)
        }
    }

    private static func pixelSize(for image: UIImage) -> CGSize {
        if let cgImage = image.cgImage {
            return CGSize(
                width: cgImage.width,
                height: cgImage.height
            )
        }

        return image.size
    }

    private func drawMessage(
        _ message: String,
        canvasRect: CGRect
    ) {
        let fontSize = max(18, min(30, canvasRect.width * 0.022))
        let font = UIFont.systemFont(
            ofSize: fontSize,
            weight: .semibold
        )
        let maximumWidth = max(120, canvasRect.width - 48)
        let textSize = NSString(string: message).boundingRect(
            with: CGSize(
                width: maximumWidth,
                height: .greatestFiniteMagnitude
            ),
            options: [
                .usesLineFragmentOrigin,
                .usesFontLeading
            ],
            attributes: [
                .font: font
            ],
            context: nil
        )
        let badgeRect = CGRect(
            x: 16,
            y: 16,
            width: min(canvasRect.width - 32, ceil(textSize.width) + 24),
            height: ceil(textSize.height) + 18
        )
        let path = UIBezierPath(
            roundedRect: badgeRect,
            cornerRadius: min(12, badgeRect.height * 0.26)
        )

        UIColor.black.withAlphaComponent(0.68).setFill()
        path.fill()

        NSString(string: message).draw(
            with: badgeRect.insetBy(dx: 12, dy: 9),
            options: [
                .usesLineFragmentOrigin,
                .usesFontLeading
            ],
            attributes: [
                .font: font,
                .foregroundColor: UIColor.white
            ],
            context: nil
        )
    }
}
