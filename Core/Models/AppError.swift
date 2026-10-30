import Foundation

/// User-facing failures. Raw engine/native messages never reach the UI; they stay in `detail` for diagnostics.
enum AppError: Error, LocalizedError, Equatable, Sendable {
    case unsupportedImage
    case intentInputFailure
    case noTextFound
    case modelNotInstalled
    case modelDamaged
    case modelLoadFailed
    case insufficientStorage
    case translationFailed(detail: String)

    /// Maps processor/native errors (plain NSError messages) to a readable case.
    init(_ error: Error) {
        if let error = error as? AppError { self = error; return }
        let nsError = error as NSError
        if (nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteOutOfSpaceError)
            || (nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(ENOSPC)) {
            self = .insufficientStorage; return
        }
        let message = nsError.localizedDescription
        func has(_ text: String) -> Bool { message.localizedCaseInsensitiveContains(text) }
        if has("Model missing") { self = .modelNotInstalled }
        else if has("incorrect model") || has("SHA256") { self = .modelDamaged }
        else if has("GGUF load") || has("Context creation") || has("Metal offload") || has("model manifest") || has("model path") { self = .modelLoadFailed }
        else if has("No Chinese text") { self = .noTextFound }
        else if has("Image dimensions") || has("cannot be decoded") || has("Invalid Quick Look screenshot") { self = .unsupportedImage }
        else { self = .translationFailed(detail: message) }
    }

    var title: String {
        switch self {
        case .unsupportedImage: String(localized: "Can’t Read This Image")
        case .intentInputFailure: String(localized: "Screenshot Not Received")
        case .noTextFound: String(localized: "No Chinese Text Found")
        case .modelNotInstalled: String(localized: "AI Model Not Installed")
        case .modelDamaged: String(localized: "AI Model Needs Reinstalling")
        case .modelLoadFailed: String(localized: "AI Model Couldn’t Start")
        case .insufficientStorage: String(localized: "Not Enough Storage")
        case .translationFailed: String(localized: "Translation Failed")
        }
    }

    var symbolName: String {
        switch self {
        case .unsupportedImage, .intentInputFailure: "photo.badge.exclamationmark"
        case .noTextFound: "text.magnifyingglass"
        case .modelNotInstalled, .modelDamaged, .modelLoadFailed: "cpu"
        case .insufficientStorage: "externaldrive.badge.exclamationmark"
        case .translationFailed: "exclamationmark.triangle"
        }
    }

    var errorDescription: String? {
        switch self {
        case .unsupportedImage: String(localized: "The image is empty, damaged or in an unsupported format.")
        case .intentInputFailure: String(localized: "The screenshot from Shortcuts couldn’t be opened.")
        case .noTextFound: String(localized: "Make sure the screenshot contains Chinese text and try again.")
        case .modelNotInstalled: String(localized: "Install the AI model in Settings to translate on this iPhone.")
        case .modelDamaged: String(localized: "The installed AI model file is incomplete or damaged. Import it again in Settings.")
        case .modelLoadFailed: String(localized: "Close other apps and try again. If this keeps happening, restart your iPhone.")
        case .insufficientStorage: String(localized: "Free up some space on your iPhone and try again.")
        case .translationFailed: String(localized: "Something went wrong while translating. Please try again.")
        }
    }

    var needsModelSetup: Bool {
        switch self {
        case .modelNotInstalled, .modelDamaged: true
        default: false
        }
    }

    var canRetry: Bool {
        switch self {
        case .unsupportedImage, .intentInputFailure, .modelNotInstalled, .modelDamaged: false
        default: true
        }
    }

    /// Internal cause for DEBUG diagnostics only.
    var detail: String {
        if case .translationFailed(let detail) = self { return detail }
        return String(describing: self)
    }
}
