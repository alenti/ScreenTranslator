import Foundation
import Vision

struct OCRRequestFactory {
    struct Configuration: Equatable, Sendable {
        let recognitionLevelDescription: String
        let languageHints: [String]
        let usesLanguageCorrection: Bool
        let minimumTextHeight: Float
    }

    func makeConfiguration() -> Configuration {
        Configuration(
            recognitionLevelDescription: "accurate",
            languageHints: ["zh-Hans", "zh-Hant"],
            usesLanguageCorrection: false,
            minimumTextHeight: 0.0
        )
    }

    func makeRecognizeTextRequest() -> VNRecognizeTextRequest {
        let configuration = makeConfiguration()
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = configuration.languageHints
        request.usesLanguageCorrection = configuration.usesLanguageCorrection
        request.minimumTextHeight = configuration.minimumTextHeight
        return request
    }
}
