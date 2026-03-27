import Foundation

enum ProcessingState: String, CaseIterable, Sendable {
    case idle
    case receivedInput
    case preparingImage
    case performingOCR
    case groupingText
    case translatingBlocks
    case renderingOverlay
    case completed
    case failed

    var displayTitle: String {
        switch self {
        case .idle:
            return "Waiting for Screenshot"
        case .receivedInput:
            return "Screenshot Received"
        case .preparingImage:
            return "Preparing Image"
        case .performingOCR:
            return "Recognizing Text"
        case .groupingText:
            return "Grouping Text Blocks"
        case .translatingBlocks:
            return "Translating Blocks"
        case .renderingOverlay:
            return "Rendering Overlay"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        }
    }

    var progressValue: Double? {
        switch self {
        case .idle:
            return 0
        case .receivedInput:
            return 0.10
        case .preparingImage:
            return 0.22
        case .performingOCR:
            return 0.45
        case .groupingText:
            return 0.62
        case .translatingBlocks:
            return 0.80
        case .renderingOverlay:
            return 0.92
        case .completed:
            return 1.0
        case .failed:
            return nil
        }
    }

    var isTerminal: Bool {
        switch self {
        case .completed, .failed:
            return true
        default:
            return false
        }
    }
}
