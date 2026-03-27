import Foundation

struct TextGroupingService: TextGroupingServiceProtocol {
    let grouper: BoundingBoxGrouper
    let composer: TextBlockComposer

    func makeBlocks(from observations: [OCRTextObservation]) -> [TextBlock] {
        let groups = grouper.group(observations)
        return composer.compose(groups: groups)
    }
}
