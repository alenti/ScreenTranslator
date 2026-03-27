import CoreGraphics
import Foundation

@MainActor
final class ResultOverlayViewModel: ObservableObject {
    @Published var displayMode: ResultMode
    @Published private(set) var result: OverlayRenderResult

    let availableModes: [ResultMode]

    init(
        result: OverlayRenderResult,
        displayMode: ResultMode = .overlay,
        availableModes: [ResultMode] = [.overlay, .original]
    ) {
        self.result = result
        self.availableModes = availableModes
        self.displayMode = availableModes.contains(displayMode)
            ? displayMode
            : .overlay
    }

    var translatedBlocks: [TranslationBlock] {
        result.translatedBlocks
    }

    var primaryModes: [ResultMode] {
        availableModes
    }

    var title: String {
        "Translation Ready"
    }

    var summaryText: String {
        "\(translatedBlocks.count) block\(translatedBlocks.count == 1 ? "" : "s")"
    }

    var sourceSizeDescription: String {
        let width = Int(result.sourceInput.size.width)
        let height = Int(result.sourceInput.size.height)
        return "\(width)x\(height)"
    }

    var renderNote: String {
        result.renderMetadata.note
    }

    var hasRenderedPreview: Bool {
        result.precomposedImageData != nil
    }

    var hasSourcePreview: Bool {
        result.sourceInput.imageData.isEmpty == false
    }

    var renderedPreviewData: Data? {
        result.precomposedImageData
    }

    var sourcePreviewData: Data? {
        result.sourceInput.imageData.isEmpty ? nil : result.sourceInput.imageData
    }

    var sourceCanvasSize: CGSize {
        result.sourceInput.size
    }

    var sourceFilename: String {
        result.sourceInput.sourceMetadata.automationName ?? "screen-translator-result.png"
    }

    var translationText: String {
        translatedBlocks
            .map(\.translatedText)
            .map(normalizedBlockText(_:))
            .filter { $0.isEmpty == false }
            .joined(separator: "\n\n")
    }

    var originalText: String {
        translatedBlocks
            .map(\.sourceText)
            .map(normalizedBlockText(_:))
            .filter { $0.isEmpty == false }
            .joined(separator: "\n\n")
    }

    var combinedText: String {
        translatedBlocks
            .map { block in
                let original = normalizedBlockText(block.sourceText)
                let translation = normalizedBlockText(block.translatedText)

                if original.isEmpty {
                    return translation
                }

                if translation.isEmpty {
                    return original
                }

                return "\(original)\n\(translation)"
            }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n\n")
    }

    func ensureHeroMode() {
        if displayMode != .overlay {
            displayMode = .overlay
        }
    }

    func interactiveFrame(
        for block: TranslationBlock,
        in mode: ResultMode
    ) -> CGRect {
        switch mode {
        case .overlay:
            return block.targetFrame
        case .original:
            return block.sourceBoundingBox
        case .text:
            return block.targetFrame
        }
    }

    func translationText(
        for block: TranslationBlock
    ) -> String {
        normalizedBlockText(block.translatedText)
    }

    func originalText(
        for block: TranslationBlock
    ) -> String {
        normalizedBlockText(block.sourceText)
    }

    func combinedText(
        for block: TranslationBlock
    ) -> String {
        let original = originalText(for: block)
        let translation = translationText(for: block)

        if original.isEmpty {
            return translation
        }

        if translation.isEmpty {
            return original
        }

        return "\(original)\n\(translation)"
    }

    func blockAccessibilityLabel(
        for block: TranslationBlock
    ) -> String {
        let translation = translationText(for: block)
        if translation.isEmpty == false {
            return translation
        }

        let original = originalText(for: block)
        return original.isEmpty ? "Translation block" : original
    }

    private func normalizedBlockText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
