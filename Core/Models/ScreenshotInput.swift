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

        static let photoLibrary = SourceMetadata(sourceName: "Photos", automationName: nil)

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
}

struct IntentHandoffRequest: Equatable, Sendable, Codable {
    enum LaunchBehavior: String, CaseIterable, Sendable, Codable {
        case floatingPreview
        case openInApp
    }

    let screenshot: ScreenshotInput
    let launchBehavior: LaunchBehavior
}
