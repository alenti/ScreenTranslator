import CoreGraphics
import Foundation
import UIKit

@MainActor
final class ResultOverlayViewModel: ObservableObject {
    @Published var displayMode: ResultMode = .overlay
    let result: ProcessedScreenshot

    init(result: ProcessedScreenshot) {
        self.result = result
    }

    var blocks: [ProcessedBlock] { result.blocks }

    var translationFailureCount: Int { result.translationFailureCount }

    var sourceCanvasSize: CGSize {
        CGSize(width: result.originalImage.size.width * result.originalImage.scale, height: result.originalImage.size.height * result.originalImage.scale)
    }

    var shareFilename: String {
        String(localized: "Translation") + "-\(result.targetLanguage.rawValue).png"
    }

    var translationText: String { joined(blocks.compactMap(\.translatedText)) }
    var originalText: String { joined(blocks.map(\.sourceText)) }
    var combinedText: String { joined(blocks.map(combinedText(for:))) }

    func translationText(for block: ProcessedBlock) -> String { trimmed(block.translatedText ?? "") }
    func originalText(for block: ProcessedBlock) -> String { trimmed(block.sourceText) }

    func combinedText(for block: ProcessedBlock) -> String {
        joined([originalText(for: block), translationText(for: block)], separator: "\n")
    }

    /// User-facing note for a block; the raw validation/layout message stays in diagnostics.
    func note(for block: ProcessedBlock) -> String? {
        switch block.failure?.stage {
        case .translation: String(localized: "This text couldn’t be translated reliably, so the original is shown on the image.")
        case .rendering: String(localized: "The translation didn’t fully fit on the image. The complete text is shown here.")
        case nil: nil
        }
    }

    func hotspots(in mode: ResultMode) -> [ZoomablePreviewHotspot] {
        blocks.map { block in
            ZoomablePreviewHotspot(
                id: block.hotspotID,
                frame: mode == .overlay ? (block.renderedRect ?? block.sourceRect) : block.sourceRect,
                accessibilityLabel: translationText(for: block).isEmpty ? originalText(for: block) : translationText(for: block)
            )
        }
    }

    private func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func joined(_ texts: [String], separator: String = "\n\n") -> String {
        texts.map(trimmed).filter { !$0.isEmpty }.joined(separator: separator)
    }
}

extension ProcessedBlock {
    // Existing UIKit zoom viewer uses UUID; project the stable OCR ID deterministically.
    var hotspotID: UUID { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012llx", UInt64(id)))! }
}
