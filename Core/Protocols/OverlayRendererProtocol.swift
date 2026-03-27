import Foundation

protocol OverlayRendererProtocol {
    func renderOverlay(
        for input: ScreenshotInput,
        translatedBlocks: [TranslationBlock],
        style: OverlayRenderStyle
    ) async throws -> OverlayRenderResult
}
