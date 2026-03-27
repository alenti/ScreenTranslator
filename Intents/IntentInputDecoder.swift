import AppIntents
import Foundation
import UniformTypeIdentifiers

struct IntentInputDecoder {
    private let screenshotInputBuilder: ScreenshotInputBuilder

    init(screenshotInputBuilder: ScreenshotInputBuilder = ScreenshotInputBuilder()) {
        self.screenshotInputBuilder = screenshotInputBuilder
    }

    func decode(_ screenshotFile: IntentFile) throws -> ScreenshotInput {
        let imageData = screenshotFile.data

        guard imageData.isEmpty == false else {
            throw AppError.intentInputFailure
        }

        if let fileType = screenshotFile.type, fileType.conforms(to: .image) == false {
            throw AppError.unsupportedImage
        }

        return try screenshotInputBuilder.build(
            imageData: imageData,
            sourceMetadata: .shortcuts(filename: screenshotFile.filename)
        )
    }
}
