import Foundation

enum AppError: Error, LocalizedError, Equatable, Sendable {
    case ocrFailure
    case translationUnavailable
    case unsupportedImage
    case renderingFailure
    case missingLanguagePack
    case intentInputFailure
    case noTextDetected
    case featureNotReady(String)

    var title: String {
        switch self {
        case .ocrFailure:
            return "Text Recognition Failed"
        case .translationUnavailable:
            return "Translation Unavailable"
        case .unsupportedImage:
            return "Unsupported Input"
        case .renderingFailure:
            return "Overlay Rendering Failed"
        case .missingLanguagePack:
            return "Offline Data Needed"
        case .intentInputFailure:
            return "Screenshot Handoff Failed"
        case .noTextDetected:
            return "No Text Found"
        case .featureNotReady:
            return "Feature Not Ready"
        }
    }

    var symbolName: String {
        switch self {
        case .ocrFailure:
            return "text.viewfinder"
        case .translationUnavailable:
            return "character.book.closed"
        case .unsupportedImage:
            return "doc.badge.xmark"
        case .renderingFailure:
            return "rectangle.3.group.bubble.left"
        case .missingLanguagePack:
            return "arrow.down.circle"
        case .intentInputFailure:
            return "bolt.horizontal.circle"
        case .noTextDetected:
            return "text.magnifyingglass"
        case .featureNotReady:
            return "wrench.and.screwdriver"
        }
    }

    var errorDescription: String? {
        switch self {
        case .ocrFailure:
            return "ScreenTranslator could not extract readable text from this screenshot."
        case .translationUnavailable:
            return "Chinese to Russian on-device translation is not available on this device or for the current language pair."
        case .unsupportedImage:
            return "The incoming file could not be used as a supported screenshot input."
        case .renderingFailure:
            return "The translated blocks were created, but the final overlay image could not be rendered."
        case .missingLanguagePack:
            return "Chinese to Russian offline language data is missing. Prepare it first before running translation."
        case .intentInputFailure:
            return "The screenshot handoff could not be decoded or stored."
        case .noTextDetected:
            return "No readable text was detected in the current screenshot."
        case .featureNotReady(let message):
            return message
        }
    }

    var failureReason: String? {
        switch self {
        case .ocrFailure:
            return "Vision OCR did not complete successfully for this image."
        case .translationUnavailable:
            return "The current device or system configuration does not support the required on-device language pair."
        case .unsupportedImage:
            return "The shortcut handed off input that was empty, damaged, or not a valid screenshot image."
        case .renderingFailure:
            return "The rendering subsystem could not build a final composited preview."
        case .missingLanguagePack:
            return "The device supports the language pair, but the offline translation resources are not prepared yet."
        case .intentInputFailure:
            return "The app could not decode or store the incoming screenshot from Shortcuts."
        case .noTextDetected:
            return "OCR finished, but it did not find enough readable text to continue."
        case .featureNotReady:
            return nil
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .ocrFailure:
            return "Retry the screenshot, or open Debug to inspect what OCR is seeing."
        case .translationUnavailable:
            return "Open Settings to check offline readiness and device support, or continue with another screenshot."
        case .unsupportedImage:
            return "Run the shortcut again with a standard screenshot image."
        case .renderingFailure:
            return "Retry the job or open Debug to inspect the translated blocks without the final overlay."
        case .missingLanguagePack:
            return "Prepare the offline Chinese to Russian language data, then retry the job."
        case .intentInputFailure:
            return "Run the shortcut again and make sure the screenshot is passed directly into the app."
        case .noTextDetected:
            return "Try a clearer screenshot, or inspect the OCR output in Debug."
        case .featureNotReady:
            return "Return to processing and try again."
        }
    }
}
