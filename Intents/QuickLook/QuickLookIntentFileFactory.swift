import AppIntents
import Foundation
import OSLog
import UniformTypeIdentifiers

enum QuickLookIntentReturnMarker: String, Sendable {
    case normal = "QL_NORMAL_RETURN_START"
    case debug = "QL_DEBUG_RETURN_START"
    case echo = "QL_ECHO_RETURN_START"
    case error = "QL_ERROR_RETURN_START"
}

enum QuickLookIntentOutputBacking: String, Sendable {
    case dataBacked = "data"
    case fileBacked = "file"
}

struct QuickLookIntentFileResult: Sendable {
    let file: IntentFile
    let byteCount: Int
    let backing: QuickLookIntentOutputBacking
    let marker: QuickLookIntentReturnMarker
    let filePath: String?
    let fileSize: Int?
}

struct QuickLookIntentFileFactory {
    private enum OutputMode {
        case dataBacked
        case fileBacked
    }

    private static let outputMode: OutputMode = .dataBacked

    private let logger = Logger(
        subsystem: "AlenShamatov.ScreenTranslator",
        category: "QuickLookIntent"
    )

    func makePNGFile(
        data pngData: Data,
        filename: String,
        marker: QuickLookIntentReturnMarker
    ) -> QuickLookIntentFileResult {
        switch Self.outputMode {
        case .dataBacked:
            return makeDataBackedPNGFile(
                data: pngData,
                filename: filename,
                marker: marker
            )
        case .fileBacked:
            return makeFileBackedPNGFile(
                data: pngData,
                filename: filename,
                marker: marker
            )
        }
    }

    private func makeDataBackedPNGFile(
        data pngData: Data,
        filename: String,
        marker: QuickLookIntentReturnMarker
    ) -> QuickLookIntentFileResult {
        QuickLookIntentFileResult(
            file: IntentFile(
                data: pngData,
                filename: filename,
                type: .png
            ),
            byteCount: pngData.count,
            backing: .dataBacked,
            marker: marker,
            filePath: nil,
            fileSize: nil
        )
    }

    private func makeFileBackedPNGFile(
        data pngData: Data,
        filename: String,
        marker: QuickLookIntentReturnMarker
    ) -> QuickLookIntentFileResult {
        do {
            let directoryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "ScreenTranslatorQuickLookIntent",
                    isDirectory: true
                )
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )

            let outputURL = directoryURL.appendingPathComponent(
                "\(UUID().uuidString)-\(filename)",
                isDirectory: false
            )
            try pngData.write(to: outputURL, options: .atomic)

            let fileSize = Self.fileSize(at: outputURL) ?? pngData.count
            var outputFile = IntentFile(
                fileURL: outputURL,
                filename: filename,
                type: .png
            )
            outputFile.removedOnCompletion = true

            return QuickLookIntentFileResult(
                file: outputFile,
                byteCount: pngData.count,
                backing: .fileBacked,
                marker: marker,
                filePath: outputURL.path,
                fileSize: fileSize
            )
        } catch {
            logger.error(
                """
                Quick Look file-backed output failed; falling back to data: \
                \(String(describing: error), privacy: .public)
                """
            )

            return makeDataBackedPNGFile(
                data: pngData,
                filename: filename,
                marker: marker
            )
        }
    }

    private static func fileSize(at url: URL) -> Int? {
        guard let number = try? FileManager.default
            .attributesOfItem(atPath: url.path)[.size] as? NSNumber else {
            return nil
        }

        return number.intValue
    }
}

struct QuickLookIntentReturnLogger {
    private let logger = Logger(
        subsystem: "AlenShamatov.ScreenTranslator",
        category: "QuickLookIntent"
    )

    func logReturnStart(_ result: QuickLookIntentFileResult) {
        switch result.backing {
        case .dataBacked:
            logger.info(
                """
                \(result.marker.rawValue, privacy: .public) bytes=\
                \(result.byteCount, privacy: .public) mode=data
                """
            )
        case .fileBacked:
            logger.info(
                """
                \(result.marker.rawValue, privacy: .public) bytes=\
                \(result.byteCount, privacy: .public) mode=file path=\
                \(result.filePath ?? "nil", privacy: .public) fileSize=\
                \(result.fileSize ?? -1, privacy: .public)
                """
            )
        }
    }
}
