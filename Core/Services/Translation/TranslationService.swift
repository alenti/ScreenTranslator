import Foundation
import Translation

enum TranslationFailureMapper {
    static func mapRuntimeError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        if let brokerError = error as? TranslationSessionBroker.BrokerError,
           brokerError == .operationTimedOut {
            return .featureNotReady(
                "The on-device translation session timed out before returning results."
            )
        }

        if TranslationError.unsupportedSourceLanguage ~= error
            || TranslationError.unsupportedTargetLanguage ~= error
            || TranslationError.unsupportedLanguagePairing ~= error
            || TranslationError.unableToIdentifyLanguage ~= error
        {
            return .translationUnavailable
        }

        if TranslationError.nothingToTranslate ~= error {
            return .noTextDetected
        }

        return .translationUnavailable
    }

    static func mapPreparationError(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        if let brokerError = error as? TranslationSessionBroker.BrokerError,
           brokerError == .operationTimedOut {
            return .featureNotReady(
                "The offline translation session did not become ready in time."
            )
        }

        if TranslationError.unsupportedSourceLanguage ~= error
            || TranslationError.unsupportedTargetLanguage ~= error
            || TranslationError.unsupportedLanguagePairing ~= error
        {
            return .translationUnavailable
        }

        return .missingLanguagePack
    }
}
