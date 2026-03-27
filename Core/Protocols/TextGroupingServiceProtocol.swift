import Foundation

protocol TextGroupingServiceProtocol: Sendable {
    func makeBlocks(from observations: [OCRTextObservation]) -> [TextBlock]
}
