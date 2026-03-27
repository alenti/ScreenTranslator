import CoreGraphics
import Foundation

struct TextBlock: Identifiable, Equatable, Sendable {
    let id: UUID
    let sourceText: String
    let observations: [OCRTextObservation]
    let combinedBoundingBox: CGRect

    init(
        id: UUID = UUID(),
        sourceText: String,
        observations: [OCRTextObservation],
        combinedBoundingBox: CGRect
    ) {
        self.id = id
        self.sourceText = sourceText
        self.observations = observations
        self.combinedBoundingBox = combinedBoundingBox
    }

    static let placeholder = TextBlock(
        sourceText: "示例文本",
        observations: [.placeholder],
        combinedBoundingBox: OCRTextObservation.placeholder.boundingBox
    )
}
