import Foundation

struct ProcessingJob: Identifiable, Equatable, Sendable {
    let id: UUID
    let input: ScreenshotInput
    let createdAt: Date

    init(
        id: UUID = UUID(),
        input: ScreenshotInput,
        createdAt: Date = .now
    ) {
        self.id = id
        self.input = input
        self.createdAt = createdAt
    }

    static let placeholder = ProcessingJob(input: .placeholder)
}
