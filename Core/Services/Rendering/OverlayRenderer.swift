import Foundation

struct OverlayRenderer: OverlayRendererProtocol {
    let layoutEngine: OverlayLayoutEngine
    let textFitter: OverlayTextFitter
    let imageComposer: OverlayImageComposer

    func renderOverlay(
        for input: ScreenshotInput,
        translatedBlocks: [TranslationBlock],
        style: OverlayRenderStyle
    ) async throws -> OverlayRenderResult {
        guard translatedBlocks.isEmpty == false else {
            throw AppError.renderingFailure
        }

        let renderedBlocks: [RenderedBlock] = translatedBlocks.map { block in
            let proposal = layoutEngine.proposal(
                for: block,
                in: input.size,
                style: style
            )
            let fittedText = textFitter.fit(
                text: block.translatedText,
                within: proposal.textFrame.size,
                style: style
            )
            let resolvedLayout = layoutEngine.resolvedLayout(
                for: block,
                fittedText: fittedText,
                in: input.size,
                style: style
            )

            return RenderedBlock(
                sourceBlock: block,
                outerFrame: resolvedLayout.outerFrame,
                textFrame: resolvedLayout.textFrame,
                fittedText: fittedText
            )
        }

        let collisionResolution = layoutEngine.resolveCollisions(
            for: renderedBlocks.map { renderedBlock in
                collisionCandidate(
                    for: renderedBlock,
                    in: input.size,
                    style: style
                )
            },
            in: input.size,
            style: style
        )
        let collisionAdjustedBlocks = zip(
            renderedBlocks,
            collisionResolution.layouts
        ).map { renderedBlock, adjustedLayout in
            RenderedBlock(
                sourceBlock: renderedBlock.sourceBlock,
                outerFrame: adjustedLayout.outerFrame,
                textFrame: adjustedLayout.textFrame,
                fittedText: renderedBlock.fittedText
            )
        }

        let instructions = collisionAdjustedBlocks.map { renderedBlock in
            OverlayImageComposer.RenderInstruction(
                blockID: renderedBlock.sourceBlock.id,
                outerFrame: renderedBlock.outerFrame,
                textFrame: renderedBlock.textFrame,
                text: renderedBlock.fittedText.text,
                fontSize: renderedBlock.fittedText.fontSize,
                style: style
            )
        }
        let composedImageData = try imageComposer.composeImageData(
            for: input,
            instructions: instructions
        )

        let resolvedBlocks = collisionAdjustedBlocks.map { renderedBlock in
            TranslationBlock(
                id: renderedBlock.sourceBlock.id,
                sourceText: renderedBlock.sourceBlock.sourceText,
                translatedText: renderedBlock.fittedText.text,
                sourceBoundingBox: renderedBlock.sourceBlock.sourceBoundingBox,
                targetFrame: renderedBlock.outerFrame,
                renderingStyle: style
            )
        }

        return OverlayRenderResult(
            sourceInput: input,
            translatedBlocks: resolvedBlocks,
            renderStyle: style,
            renderMetadata: .init(
                generatedAt: .now,
                note: renderNote(
                    blockCount: resolvedBlocks.count,
                    adjustmentCount: collisionResolution.adjustmentCount
                )
            ),
            precomposedImageData: composedImageData
        )
    }

    private func renderNote(
        blockCount: Int,
        adjustmentCount: Int
    ) -> String {
        if adjustmentCount == 0 {
            return "Rendered \(blockCount) translated blocks over the original screenshot."
        }

        return "Rendered \(blockCount) translated blocks over the original screenshot with \(adjustmentCount) collision adjustments."
    }

    private func collisionCandidate(
        for renderedBlock: RenderedBlock,
        in canvasSize: CGSize,
        style: OverlayRenderStyle
    ) -> OverlayLayoutEngine.CollisionCandidate {
        let preferredLayout = OverlayLayoutEngine.LayoutPlan(
            outerFrame: renderedBlock.outerFrame,
            textFrame: renderedBlock.textFrame
        )

        return OverlayLayoutEngine.CollisionCandidate(
            preferredLayout: preferredLayout,
            alternativeLayouts: tightenedLayouts(
                for: renderedBlock,
                in: canvasSize,
                style: style
            )
        )
    }

    private func tightenedLayouts(
        for renderedBlock: RenderedBlock,
        in canvasSize: CGSize,
        style: OverlayRenderStyle
    ) -> [OverlayLayoutEngine.LayoutPlan] {
        guard shouldGenerateTighterLayouts(for: renderedBlock, style: style) else {
            return []
        }

        let sourceFrame = renderedBlock.sourceBlock.sourceBoundingBox.standardized
        let currentWidth = renderedBlock.outerFrame.width
        let minimumUsefulWidth = max(
            sourceFrame.width,
            (style.paddingValue * 2) + 36
        )
        let shrinkRatios: [CGFloat] = [0.88, 0.78]

        return shrinkRatios.compactMap { ratio in
            let widthCap = max(
                minimumUsefulWidth,
                currentWidth * ratio
            )

            guard widthCap < currentWidth - 6 else {
                return nil
            }

            let fittedText = textFitter.fit(
                text: renderedBlock.sourceBlock.translatedText,
                within: CGSize(
                    width: max(widthCap - (style.paddingValue * 2), 1),
                    height: canvasSize.height
                ),
                style: style
            )
            let tightenedLayout = layoutEngine.resolvedLayout(
                for: renderedBlock.sourceBlock,
                fittedText: fittedText,
                in: canvasSize,
                style: style,
                maximumOuterWidth: widthCap
            )

            guard tightenedLayout.outerFrame.width < renderedBlock.outerFrame.width - 4 else {
                return nil
            }

            guard tightenedLayout.outerFrame.height <= renderedBlock.outerFrame.height * 1.45 else {
                return nil
            }

            return tightenedLayout
        }
    }

    private func shouldGenerateTighterLayouts(
        for renderedBlock: RenderedBlock,
        style: OverlayRenderStyle
    ) -> Bool {
        let sourceFrame = renderedBlock.sourceBlock.sourceBoundingBox.standardized
        let widthExpansionRatio = renderedBlock.outerFrame.width / max(sourceFrame.width, 1)
        let extraWidth = renderedBlock.outerFrame.width
            - (renderedBlock.fittedText.measuredSize.width + (style.paddingValue * 2))

        return sourceFrame.height <= 96
            && sourceFrame.width <= 260
            && (
                widthExpansionRatio > 1.18
                    || extraWidth > 10
            )
    }
}

private struct RenderedBlock {
    let sourceBlock: TranslationBlock
    let outerFrame: CGRect
    let textFrame: CGRect
    let fittedText: OverlayTextFitter.FittedText
}
