import AppIntents
import Foundation
import OSLog
import UniformTypeIdentifiers

struct QuickLookDirectEchoScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "Debug Direct Echo Screenshot"
    static var description = IntentDescription(
        "Accepts a screenshot from Shortcuts and directly returns its copied data as a PNG file."
    )
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Screenshot",
        supportedContentTypes: [.image],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<IntentFile> {
        let copiedData = screenshot.data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return Data()
            }

            return Data(bytes: baseAddress, count: buffer.count)
        }
        let logger = Logger(
            subsystem: "AlenShamatov.ScreenTranslator",
            category: "QuickLookIntent"
        )

        logger.info(
            "Quick Look direct echo input bytes=\(copiedData.count, privacy: .public)"
        )

        let outputFile = IntentFile(
            data: copiedData,
            filename: "direct-echo.png",
            type: .png
        )

        logger.info(
            "QL_DIRECT_ECHO_RETURN_START bytes=\(copiedData.count, privacy: .public) mode=data"
        )

        return .result(value: outputFile)
    }
}
