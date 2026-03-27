import Foundation

enum ErrorRecoveryAction: String, Identifiable, Equatable, Sendable {
    case retryCurrentJob
    case backToProcessing
    case openSettings
    case openDebug
    case prepareOfflineLanguageData

    var id: String { rawValue }
}

struct ErrorRecoveryOption: Identifiable, Equatable, Sendable {
    enum Emphasis: Equatable, Sendable {
        case primary
        case secondary
    }

    let action: ErrorRecoveryAction
    let title: String
    let emphasis: Emphasis

    var id: ErrorRecoveryAction { action }
}

@MainActor
final class ErrorViewModel: ObservableObject {
    let error: AppError
    let title: String
    let message: String
    let failureReason: String?
    let recoverySuggestion: String?
    let symbolName: String
    let recoveryOptions: [ErrorRecoveryOption]

    init(error: AppError) {
        self.error = error
        self.title = error.title
        self.message = error.errorDescription ?? "An unknown error occurred."
        self.failureReason = error.failureReason
        self.recoverySuggestion = error.recoverySuggestion
        self.symbolName = error.symbolName
        self.recoveryOptions = Self.recoveryOptions(for: error)
    }

    var primaryRecoveryOption: ErrorRecoveryOption? {
        recoveryOptions.first { $0.emphasis == .primary }
    }

    var secondaryRecoveryOptions: [ErrorRecoveryOption] {
        recoveryOptions.filter { $0.emphasis == .secondary }
    }

    private static func recoveryOptions(
        for error: AppError
    ) -> [ErrorRecoveryOption] {
        switch error {
        case .ocrFailure:
            return [
                ErrorRecoveryOption(
                    action: .retryCurrentJob,
                    title: "Retry OCR",
                    emphasis: .primary
                ),
                ErrorRecoveryOption(
                    action: .openDebug,
                    title: "Open Debug",
                    emphasis: .secondary
                )
            ]
        case .translationUnavailable:
            return [
                ErrorRecoveryOption(
                    action: .openSettings,
                    title: "Open Settings",
                    emphasis: .primary
                ),
                ErrorRecoveryOption(
                    action: .backToProcessing,
                    title: "Back",
                    emphasis: .secondary
                )
            ]
        case .unsupportedImage, .intentInputFailure:
            return [
                ErrorRecoveryOption(
                    action: .backToProcessing,
                    title: "Try Again",
                    emphasis: .primary
                )
            ]
        case .renderingFailure:
            return [
                ErrorRecoveryOption(
                    action: .retryCurrentJob,
                    title: "Retry Render",
                    emphasis: .primary
                ),
                ErrorRecoveryOption(
                    action: .openDebug,
                    title: "Open Debug",
                    emphasis: .secondary
                )
            ]
        case .missingLanguagePack:
            return [
                ErrorRecoveryOption(
                    action: .prepareOfflineLanguageData,
                    title: "Prepare Offline Data",
                    emphasis: .primary
                ),
                ErrorRecoveryOption(
                    action: .openSettings,
                    title: "Open Settings",
                    emphasis: .secondary
                )
            ]
        case .noTextDetected:
            return [
                ErrorRecoveryOption(
                    action: .openDebug,
                    title: "Inspect OCR",
                    emphasis: .primary
                ),
                ErrorRecoveryOption(
                    action: .backToProcessing,
                    title: "Try Another Screenshot",
                    emphasis: .secondary
                )
            ]
        case .featureNotReady:
            return [
                ErrorRecoveryOption(
                    action: .backToProcessing,
                    title: "Back to Processing",
                    emphasis: .primary
                )
            ]
        }
    }
}
