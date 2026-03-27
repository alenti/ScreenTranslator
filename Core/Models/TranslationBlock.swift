import CoreGraphics
import Foundation

struct TranslationBlock: Identifiable, Equatable, Sendable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let sourceBoundingBox: CGRect
    let targetFrame: CGRect
    let renderingStyle: OverlayRenderStyle

    init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String,
        sourceBoundingBox: CGRect,
        targetFrame: CGRect,
        renderingStyle: OverlayRenderStyle
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceBoundingBox = sourceBoundingBox
        self.targetFrame = targetFrame
        self.renderingStyle = renderingStyle
    }

    static let placeholder = TranslationBlock(
        sourceText: "示例文本",
        translatedText: "Пример перевода",
        sourceBoundingBox: CGRect(x: 24, y: 40, width: 240, height: 56),
        targetFrame: CGRect(x: 24, y: 40, width: 240, height: 72),
        renderingStyle: .defaultValue
    )
}
