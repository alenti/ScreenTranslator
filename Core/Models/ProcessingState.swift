import Foundation

/// User-visible stages, each driven by a real `ScreenshotProgress` event.
enum ProcessingState: String, CaseIterable, Sendable {
    case idle
    case readingScreenshot
    case translating
    case preparingPreview
    case completed
    case cancelled
    case failed

    var isTerminal: Bool {
        switch self {
        case .completed, .cancelled, .failed: true
        default: false
        }
    }
}
