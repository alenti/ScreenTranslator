import Foundation

struct PlaceholderOCRService: OCRServiceProtocol {
    let requestFactory: OCRRequestFactory

    func recognizeText(in input: ScreenshotInput) async throws -> [OCRTextObservation] {
        _ = requestFactory.makeConfiguration()
        _ = input
        return []
    }
}
