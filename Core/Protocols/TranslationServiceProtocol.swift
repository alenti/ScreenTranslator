import Foundation

protocol TranslationServiceProtocol {
    func translate(blocks: [TextBlock]) async throws -> [TranslationBlock]
}
