import AppIntents
import Foundation
import UniformTypeIdentifiers

struct IntentInputSnapshot: Sendable {
    let imageData: Data
    let filename: String?
    let sourceDescription: String
}

struct IntentInputDecoder {
    private let screenshotInputBuilder: ScreenshotInputBuilder

    init(screenshotInputBuilder: ScreenshotInputBuilder = ScreenshotInputBuilder()) {
        self.screenshotInputBuilder = screenshotInputBuilder
    }

    func decode(_ screenshotFile: IntentFile) throws -> ScreenshotInput {
        try decode(snapshot(screenshotFile))
    }

    func snapshot(_ screenshotFile: IntentFile) throws -> IntentInputSnapshot {
        if let fileType = screenshotFile.type, fileType.conforms(to: .image) == false {
            throw AppError.unsupportedImage
        }

        let imageData = materializeOwnedCopy(of: screenshotFile.data)

        guard imageData.isEmpty == false else {
            throw AppError.intentInputFailure
        }

        return IntentInputSnapshot(
            imageData: imageData,
            filename: screenshotFile.filename,
            sourceDescription: "IntentFile.data"
        )
    }

    func decode(_ snapshot: IntentInputSnapshot) throws -> ScreenshotInput {
        return try screenshotInputBuilder.build(
            imageData: snapshot.imageData,
            sourceMetadata: .shortcuts(filename: snapshot.filename)
        )
    }

    private func materializeOwnedCopy(of data: Data) -> Data {
        data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return Data()
            }

            // IntentFile data may be backed by a transient WorkflowKit file URL.
            // Force a deep in-process copy so downstream OCR/rendering never depends
            // on that temporary sandboxed resource remaining readable.
            return Data(bytes: baseAddress, count: buffer.count)
        }
    }
}
