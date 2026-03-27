import CoreGraphics
import Foundation

struct OCRTextObservation: Identifiable, Equatable, Sendable {
    let id: UUID
    let originalText: String
    let boundingBox: CGRect
    let confidence: Double
    let lineIndex: Int
    let blockIndex: Int?

    init(
        id: UUID = UUID(),
        originalText: String,
        boundingBox: CGRect,
        confidence: Double,
        lineIndex: Int,
        blockIndex: Int? = nil
    ) {
        self.id = id
        self.originalText = originalText
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.lineIndex = lineIndex
        self.blockIndex = blockIndex
    }

    static let placeholder = OCRTextObservation(
        originalText: "示例文本",
        boundingBox: CGRect(x: 24, y: 40, width: 240, height: 56),
        confidence: 0.95,
        lineIndex: 0
    )
}
