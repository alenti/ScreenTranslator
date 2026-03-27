import CoreGraphics
import Foundation

enum DebugInspectionStage: String, CaseIterable, Identifiable, Sendable {
    case ocrObservations
    case groupedBlocks
    case translatedBlocks
    case overlayFrames

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ocrObservations:
            return "OCR Boxes"
        case .groupedBlocks:
            return "Grouped Blocks"
        case .translatedBlocks:
            return "Translated Blocks"
        case .overlayFrames:
            return "Final Overlay Frames"
        }
    }

    var subtitle: String {
        switch self {
        case .ocrObservations:
            return "Inspect raw Vision OCR observations before grouping."
        case .groupedBlocks:
            return "Inspect merged text blocks after grouping heuristics run."
        case .translatedBlocks:
            return "Inspect translated content against each source text box."
        case .overlayFrames:
            return "Inspect the final rendered frame positions used by the overlay subsystem."
        }
    }

    var badgePrefix: String {
        switch self {
        case .ocrObservations:
            return "O"
        case .groupedBlocks:
            return "G"
        case .translatedBlocks:
            return "T"
        case .overlayFrames:
            return "R"
        }
    }
}

struct DebugInspectionBox: Identifiable, Equatable, Sendable {
    let id: UUID
    let badgeText: String
    let title: String
    let subtitle: String
    let detail: String
    let frame: CGRect
}

struct DebugPipelineSnapshot: Sendable {
    let normalizedInput: ScreenshotInput
    let ocrObservations: [OCRTextObservation]
    let groupedBlocks: [TextBlock]
}
