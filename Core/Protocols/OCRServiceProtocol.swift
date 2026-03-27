import Foundation

protocol OCRServiceProtocol: Sendable {
    func recognizeText(in input: ScreenshotInput) async throws -> [OCRTextObservation]
}
