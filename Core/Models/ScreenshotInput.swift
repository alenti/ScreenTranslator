import CoreGraphics
import Foundation

struct ScreenshotInput: Identifiable, Equatable, Sendable, Codable {
    enum Orientation: String, CaseIterable, Sendable, Codable {
        case up
        case down
        case left
        case right
    }

    struct SourceMetadata: Equatable, Sendable, Codable {
        let sourceName: String
        let automationName: String?

        static let scaffold = SourceMetadata(
            sourceName: "Scaffold",
            automationName: "Prompt 1 Placeholder"
        )

        static func shortcuts(filename: String?) -> SourceMetadata {
            SourceMetadata(
                sourceName: "Shortcuts / App Intent",
                automationName: filename
            )
        }
    }

    let id: UUID
    let imageData: Data
    let size: CGSize
    let orientation: Orientation
    let scale: CGFloat
    let timestamp: Date
    let sourceMetadata: SourceMetadata

    init(
        id: UUID = UUID(),
        imageData: Data,
        size: CGSize,
        orientation: Orientation,
        scale: CGFloat = 1.0,
        timestamp: Date = .now,
        sourceMetadata: SourceMetadata
    ) {
        self.id = id
        self.imageData = imageData
        self.size = size
        self.orientation = orientation
        self.scale = scale
        self.timestamp = timestamp
        self.sourceMetadata = sourceMetadata
    }

    static let placeholder = ScreenshotInput(
        imageData: Data(),
        size: CGSize(width: 1179, height: 2556),
        orientation: .up,
        scale: 3.0,
        sourceMetadata: .scaffold
    )
}
