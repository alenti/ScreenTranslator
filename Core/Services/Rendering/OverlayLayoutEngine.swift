import CoreGraphics
import Foundation

struct OverlayLayoutEngine {
    private struct CanvasInsets: Equatable, Sendable {
        let top: CGFloat
        let left: CGFloat
        let bottom: CGFloat
        let right: CGFloat
    }

    private enum LayoutCategory: Sendable {
        case compact
        case medium
        case expansive
    }

    private struct WidthStrategy: Equatable, Sendable {
        let minimumWidth: CGFloat
        let desiredWidth: CGFloat
        let maximumWidth: CGFloat
    }

    struct CollisionCandidate: Equatable, Sendable {
        let preferredLayout: LayoutPlan
        let alternativeLayouts: [LayoutPlan]
    }

    struct CollisionResolution: Equatable, Sendable {
        let layouts: [LayoutPlan]
        let adjustmentCount: Int
    }

    struct LayoutPlan: Equatable, Sendable {
        let outerFrame: CGRect
        let textFrame: CGRect
    }

    func proposal(
        for block: TranslationBlock,
        in canvasSize: CGSize,
        style: OverlayRenderStyle
    ) -> LayoutPlan {
        guard canvasSize != .zero else {
            let fallbackTextFrame = block.targetFrame.insetBy(
                dx: style.paddingValue,
                dy: style.paddingValue
            )
            return LayoutPlan(
                outerFrame: block.targetFrame,
                textFrame: fallbackTextFrame
            )
        }

        let sourceFrame = standardizedFrame(block.sourceBoundingBox)
        let layoutCategory = layoutCategory(
            block,
            sourceFrame: sourceFrame
        )
        let canvasInsets = edgeInsets(
            for: canvasSize,
            style: style
        )
        let widthStrategy = widthStrategy(
            sourceFrame: sourceFrame,
            layoutCategory: layoutCategory,
            canvasSize: canvasSize,
            canvasInsets: canvasInsets,
            style: style
        )
        let outerWidth = min(
            max(widthStrategy.desiredWidth, widthStrategy.minimumWidth),
            widthStrategy.maximumWidth
        )
        let minimumHeight = max(
            sourceFrame.height,
            style.minimumFontSizeValue + (style.paddingValue * 2)
        )

        let originX = clampedX(
            sourceMinX: sourceFrame.minX,
            width: outerWidth,
            canvasSize: canvasSize,
            insets: canvasInsets
        )
        let originY = clampedY(
            sourceMinY: sourceFrame.minY,
            height: minimumHeight,
            canvasSize: canvasSize,
            insets: canvasInsets
        )

        let outerFrame = CGRect(
            x: originX,
            y: originY,
            width: outerWidth,
            height: minimumHeight
        )

        return LayoutPlan(
            outerFrame: outerFrame,
            textFrame: insetFrame(outerFrame, style: style)
        )
    }

    func resolvedLayout(
        for block: TranslationBlock,
        fittedText: OverlayTextFitter.FittedText,
        in canvasSize: CGSize,
        style: OverlayRenderStyle,
        maximumOuterWidth: CGFloat? = nil
    ) -> LayoutPlan {
        let sourceFrame = standardizedFrame(block.sourceBoundingBox)
        let layoutCategory = layoutCategory(
            block,
            sourceFrame: sourceFrame
        )
        let canvasInsets = edgeInsets(
            for: canvasSize,
            style: style
        )
        let widthStrategy = widthStrategy(
            sourceFrame: sourceFrame,
            layoutCategory: layoutCategory,
            canvasSize: canvasSize,
            canvasInsets: canvasInsets,
            style: style
        )
        let resolvedMaximumWidth = min(
            widthStrategy.maximumWidth,
            maximumOuterWidth ?? widthStrategy.maximumWidth
        )
        let resolvedMinimumWidth = min(
            widthStrategy.minimumWidth,
            resolvedMaximumWidth
        )
        let outerWidth = min(
            max(
                sourceFrame.width,
                resolvedMinimumWidth,
                fittedText.measuredSize.width + (style.paddingValue * 2)
            ),
            resolvedMaximumWidth
        )
        let maximumHeight = max(
            canvasSize.height - canvasInsets.top - canvasInsets.bottom,
            sourceFrame.height
        )
        let outerHeight = min(
            max(
                sourceFrame.height,
                fittedText.measuredSize.height + (style.paddingValue * 2)
            ),
            maximumHeight
        )

        let originX = clampedX(
            sourceMinX: sourceFrame.minX,
            width: outerWidth,
            canvasSize: canvasSize,
            insets: canvasInsets
        )
        let originY = clampedY(
            sourceMinY: sourceFrame.minY,
            height: outerHeight,
            canvasSize: canvasSize,
            insets: canvasInsets
        )

        let outerFrame = CGRect(
            x: originX,
            y: originY,
            width: outerWidth,
            height: outerHeight
        )

        return LayoutPlan(
            outerFrame: outerFrame,
            textFrame: insetFrame(outerFrame, style: style)
        )
    }

    func resolveCollisions(
        for candidates: [CollisionCandidate],
        in canvasSize: CGSize,
        style: OverlayRenderStyle
    ) -> CollisionResolution {
        guard candidates.isEmpty == false else {
            return CollisionResolution(
                layouts: [],
                adjustmentCount: 0
            )
        }

        let canvasInsets = edgeInsets(
            for: canvasSize,
            style: style
        )
        let availableCanvasRect = CGRect(
            x: canvasInsets.left,
            y: canvasInsets.top,
            width: max(canvasSize.width - canvasInsets.left - canvasInsets.right, 1),
            height: max(canvasSize.height - canvasInsets.top - canvasInsets.bottom, 1)
        )
        let minimumSpacing = max(
            style.paddingValue * 0.75,
            4
        )
        let orderedIndices = candidates.indices.sorted { lhs, rhs in
            let lhsFrame = candidates[lhs].preferredLayout.outerFrame
            let rhsFrame = candidates[rhs].preferredLayout.outerFrame

            if abs(lhsFrame.minY - rhsFrame.minY) > 8 {
                return lhsFrame.minY < rhsFrame.minY
            }

            return lhsFrame.minX < rhsFrame.minX
        }

        var resolvedLayouts = Array(
            repeating: LayoutPlan(
                outerFrame: .zero,
                textFrame: .zero
            ),
            count: candidates.count
        )
        var placedFrames: [CGRect] = []
        var adjustmentCount = 0

        for index in orderedIndices {
            let candidate = candidates[index]
            let preferredFrame = clampedFrame(
                candidate.preferredLayout.outerFrame,
                inside: availableCanvasRect
            )
            let layoutOptions = deduplicatedLayouts(
                [candidate.preferredLayout] + candidate.alternativeLayouts
            )
            let resolvedOption = layoutOptions
                .map { option in
                    let clampedOptionFrame = clampedFrame(
                        option.outerFrame,
                        inside: availableCanvasRect
                    )
                    let resolvedFrame = resolvedCollisionFreeFrame(
                        startingFrom: clampedOptionFrame,
                        placedFrames: placedFrames,
                        canvasRect: availableCanvasRect,
                        minimumSpacing: minimumSpacing
                    )

                    return LayoutPlan(
                        outerFrame: resolvedFrame,
                        textFrame: insetFrame(resolvedFrame, style: style)
                    )
                }
                .min { lhs, rhs in
                    candidateScore(
                        lhs.outerFrame,
                        preferredFrame: preferredFrame,
                        placedFrames: placedFrames,
                        minimumSpacing: minimumSpacing
                    ) < candidateScore(
                        rhs.outerFrame,
                        preferredFrame: preferredFrame,
                        placedFrames: placedFrames,
                        minimumSpacing: minimumSpacing
                    )
                }
                ?? LayoutPlan(
                    outerFrame: preferredFrame,
                    textFrame: insetFrame(preferredFrame, style: style)
                )

            if framesDiffer(candidate.preferredLayout.outerFrame, resolvedOption.outerFrame) {
                adjustmentCount += 1
            }

            resolvedLayouts[index] = resolvedOption
            placedFrames.append(resolvedOption.outerFrame)
        }

        return CollisionResolution(
            layouts: resolvedLayouts,
            adjustmentCount: adjustmentCount
        )
    }

    private func standardizedFrame(_ frame: CGRect) -> CGRect {
        frame.standardized
    }

    private func layoutCategory(
        _ block: TranslationBlock,
        sourceFrame: CGRect
    ) -> LayoutCategory {
        let significantCharacters = significantCharacterCount(in: block.sourceText)
        let lineCount = max(
            block.sourceText.components(separatedBy: "\n").count,
            1
        )
        let widthToHeightRatio = sourceFrame.width / max(sourceFrame.height, 1)

        if significantCharacters > 0
            && significantCharacters <= 18
            && lineCount <= 2
            && sourceFrame.height <= 64
            && sourceFrame.width <= 180
            && widthToHeightRatio <= 6.5
        {
            return .compact
        }

        if significantCharacters > 0
            && significantCharacters <= 40
            && lineCount <= 3
            && sourceFrame.height <= 96
            && sourceFrame.width <= 260
            && widthToHeightRatio <= 8.5
        {
            return .medium
        }

        return .expansive
    }

    private func widthStrategy(
        sourceFrame: CGRect,
        layoutCategory: LayoutCategory,
        canvasSize: CGSize,
        canvasInsets: CanvasInsets,
        style: OverlayRenderStyle
    ) -> WidthStrategy {
        let availableCanvasWidth = max(
            canvasSize.width - canvasInsets.left - canvasInsets.right,
            1
        )

        switch layoutCategory {
        case .compact:
            let minimumWidth = max(
                sourceFrame.width,
                min(sourceFrame.width + (style.paddingValue * 1.5), 92),
                44
            )
            let desiredWidth = max(
                minimumWidth,
                sourceFrame.width * 1.04,
                sourceFrame.width + (style.paddingValue * 1.25)
            )
            let maximumWidth = min(
                max(
                    minimumWidth,
                    sourceFrame.width * 1.35,
                    sourceFrame.width + (style.paddingValue * 3)
                ),
                min(
                    availableCanvasWidth,
                    canvasSize.width * 0.36
                )
            )

            return WidthStrategy(
                minimumWidth: minimumWidth,
                desiredWidth: desiredWidth,
                maximumWidth: max(maximumWidth, minimumWidth)
            )
        case .medium:
            let minimumWidth = max(
                sourceFrame.width,
                min(sourceFrame.width + (style.paddingValue * 2), 116),
                56
            )
            let desiredWidth = max(
                minimumWidth,
                sourceFrame.width * 1.12,
                sourceFrame.width + (style.paddingValue * 2)
            )
            let maximumWidth = min(
                max(
                    minimumWidth,
                    sourceFrame.width * 1.55,
                    sourceFrame.width + (style.paddingValue * 5)
                ),
                min(
                    availableCanvasWidth,
                    canvasSize.width * 0.48
                )
            )

            return WidthStrategy(
                minimumWidth: minimumWidth,
                desiredWidth: desiredWidth,
                maximumWidth: max(maximumWidth, minimumWidth)
            )
        case .expansive:
            let maximumWidth = max(
                min(
                    canvasSize.width * min(style.maximumBlockWidthRatioValue, 0.72),
                    availableCanvasWidth
                ),
                max(
                    sourceFrame.width,
                    72
                )
            )
            let minimumWidth = max(
                sourceFrame.width,
                min(
                    sourceFrame.width + (style.paddingValue * 2),
                    style.minimumBlockWidthValue
                ),
                72
            )
            let desiredWidth = max(
                sourceFrame.width * max(style.blockWidthExpansionMultiplierValue * 0.9, 1.2),
                minimumWidth,
                sourceFrame.width + (style.paddingValue * 2.5)
            )

            return WidthStrategy(
                minimumWidth: minimumWidth,
                desiredWidth: desiredWidth,
                maximumWidth: maximumWidth
            )
        }
    }

    private func insetFrame(
        _ frame: CGRect,
        style: OverlayRenderStyle
    ) -> CGRect {
        frame.insetBy(dx: style.paddingValue, dy: style.paddingValue)
    }

    private func significantCharacterCount(in text: String) -> Int {
        text.unicodeScalars.reduce(into: 0) { partialResult, scalar in
            guard CharacterSet.whitespacesAndNewlines.contains(scalar) == false else {
                return
            }

            guard CharacterSet.punctuationCharacters.contains(scalar) == false else {
                return
            }

            partialResult += 1
        }
    }

    private func edgeInsets(
        for canvasSize: CGSize,
        style: OverlayRenderStyle
    ) -> CanvasInsets {
        CanvasInsets(
            top: canvasSize.height * style.verticalCanvasInsetRatioValue,
            left: canvasSize.width * style.horizontalCanvasInsetRatioValue,
            bottom: canvasSize.height * style.verticalCanvasInsetRatioValue,
            right: canvasSize.width * style.horizontalCanvasInsetRatioValue
        )
    }

    private func clampedX(
        sourceMinX: CGFloat,
        width: CGFloat,
        canvasSize: CGSize,
        insets: CanvasInsets
    ) -> CGFloat {
        let minimumX = insets.left
        let maximumX = max(
            minimumX,
            canvasSize.width - insets.right - width
        )
        return min(max(sourceMinX, minimumX), maximumX)
    }

    private func clampedY(
        sourceMinY: CGFloat,
        height: CGFloat,
        canvasSize: CGSize,
        insets: CanvasInsets
    ) -> CGFloat {
        let minimumY = insets.top
        let maximumY = max(
            minimumY,
            canvasSize.height - insets.bottom - height
        )
        return min(max(sourceMinY, minimumY), maximumY)
    }

    private func resolvedCollisionFreeFrame(
        startingFrom preferredFrame: CGRect,
        placedFrames: [CGRect],
        canvasRect: CGRect,
        minimumSpacing: CGFloat
    ) -> CGRect {
        guard placedFrames.isEmpty == false else {
            return preferredFrame
        }

        let overlappingFrames = placedFrames.filter {
            paddedIntersectionArea(
                between: preferredFrame,
                and: $0,
                minimumSpacing: minimumSpacing
            ) > 0
        }

        guard overlappingFrames.isEmpty == false else {
            return preferredFrame
        }

        let collisionCluster = overlappingFrames.reduce(CGRect.null) { partialResult, frame in
            partialResult.union(frame)
        }

        var candidateFrames = [preferredFrame]

        for placedFrame in placedFrames {
            candidateFrames.append(
                CGRect(
                    x: preferredFrame.minX,
                    y: placedFrame.maxY + minimumSpacing,
                    width: preferredFrame.width,
                    height: preferredFrame.height
                )
            )
            candidateFrames.append(
                CGRect(
                    x: preferredFrame.minX,
                    y: placedFrame.minY - minimumSpacing - preferredFrame.height,
                    width: preferredFrame.width,
                    height: preferredFrame.height
                )
            )
            candidateFrames.append(
                CGRect(
                    x: placedFrame.maxX + minimumSpacing,
                    y: preferredFrame.minY,
                    width: preferredFrame.width,
                    height: preferredFrame.height
                )
            )
            candidateFrames.append(
                CGRect(
                    x: placedFrame.minX - minimumSpacing - preferredFrame.width,
                    y: preferredFrame.minY,
                    width: preferredFrame.width,
                    height: preferredFrame.height
                )
            )
        }

        if collisionCluster.isNull == false {
            candidateFrames.append(
                CGRect(
                    x: preferredFrame.minX,
                    y: collisionCluster.maxY + minimumSpacing,
                    width: preferredFrame.width,
                    height: preferredFrame.height
                )
            )
            candidateFrames.append(
                CGRect(
                    x: preferredFrame.minX,
                    y: collisionCluster.minY - minimumSpacing - preferredFrame.height,
                    width: preferredFrame.width,
                    height: preferredFrame.height
                )
            )
            candidateFrames.append(
                CGRect(
                    x: collisionCluster.maxX + minimumSpacing,
                    y: preferredFrame.minY,
                    width: preferredFrame.width,
                    height: preferredFrame.height
                )
            )
            candidateFrames.append(
                CGRect(
                    x: collisionCluster.minX - minimumSpacing - preferredFrame.width,
                    y: preferredFrame.minY,
                    width: preferredFrame.width,
                    height: preferredFrame.height
                )
            )
        }

        let clampedCandidates = deduplicatedFrames(
            candidateFrames.map { candidate in
                clampedFrame(candidate, inside: canvasRect)
            }
        )

        return clampedCandidates.min { lhs, rhs in
            candidateScore(
                lhs,
                preferredFrame: preferredFrame,
                placedFrames: placedFrames,
                minimumSpacing: minimumSpacing
            ) < candidateScore(
                rhs,
                preferredFrame: preferredFrame,
                placedFrames: placedFrames,
                minimumSpacing: minimumSpacing
            )
        } ?? preferredFrame
    }

    private func candidateScore(
        _ frame: CGRect,
        preferredFrame: CGRect,
        placedFrames: [CGRect],
        minimumSpacing: CGFloat
    ) -> CGFloat {
        let totalOverlapArea = placedFrames.reduce(CGFloat.zero) { partialResult, placedFrame in
            partialResult + paddedIntersectionArea(
                between: frame,
                and: placedFrame,
                minimumSpacing: minimumSpacing
            )
        }
        let horizontalShift = abs(frame.minX - preferredFrame.minX)
        let verticalShift = abs(frame.minY - preferredFrame.minY)
        let areaPenalty = frame.width * frame.height * 0.004

        return totalOverlapArea * 10_000
            + (horizontalShift * 1.05)
            + (verticalShift * 1.65)
            + areaPenalty
    }

    private func paddedIntersectionArea(
        between lhs: CGRect,
        and rhs: CGRect,
        minimumSpacing: CGFloat
    ) -> CGFloat {
        let paddedLHS = lhs.insetBy(
            dx: -(minimumSpacing / 2),
            dy: -(minimumSpacing / 2)
        )
        let paddedRHS = rhs.insetBy(
            dx: -(minimumSpacing / 2),
            dy: -(minimumSpacing / 2)
        )
        let intersection = paddedLHS.intersection(paddedRHS)

        guard intersection.isNull == false else {
            return 0
        }

        return intersection.width * intersection.height
    }

    private func clampedFrame(
        _ frame: CGRect,
        inside canvasRect: CGRect
    ) -> CGRect {
        let clampedWidth = min(frame.width, canvasRect.width)
        let clampedHeight = min(frame.height, canvasRect.height)
        let minimumX = canvasRect.minX
        let maximumX = max(minimumX, canvasRect.maxX - clampedWidth)
        let minimumY = canvasRect.minY
        let maximumY = max(minimumY, canvasRect.maxY - clampedHeight)

        return CGRect(
            x: min(max(frame.minX, minimumX), maximumX),
            y: min(max(frame.minY, minimumY), maximumY),
            width: clampedWidth,
            height: clampedHeight
        )
    }

    private func deduplicatedFrames(_ frames: [CGRect]) -> [CGRect] {
        var seenKeys = Set<String>()
        var deduplicated: [CGRect] = []

        for frame in frames {
            let key = [
                frame.minX,
                frame.minY,
                frame.width,
                frame.height
            ]
            .map { value in
                String(format: "%.3f", value)
            }
            .joined(separator: "|")

            if seenKeys.insert(key).inserted {
                deduplicated.append(frame)
            }
        }

        return deduplicated
    }

    private func deduplicatedLayouts(
        _ layouts: [LayoutPlan]
    ) -> [LayoutPlan] {
        var seenKeys = Set<String>()
        var deduplicated: [LayoutPlan] = []

        for layout in layouts {
            let frame = layout.outerFrame
            let key = [
                frame.minX,
                frame.minY,
                frame.width,
                frame.height
            ]
            .map { value in
                String(format: "%.3f", value)
            }
            .joined(separator: "|")

            if seenKeys.insert(key).inserted {
                deduplicated.append(layout)
            }
        }

        return deduplicated
    }

    private func framesDiffer(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        abs(lhs.minX - rhs.minX) > 0.5
            || abs(lhs.minY - rhs.minY) > 0.5
            || abs(lhs.width - rhs.width) > 0.5
            || abs(lhs.height - rhs.height) > 0.5
    }
}
