import Foundation
import OSLog
import UIKit

struct QuickLookOverlayRenderer {
    private let blockMapper: QuickLookOCRBlockMapper
    private let cjkDetector: QuickLookCJKTextDetector
    private let logger = Logger(
        subsystem: "AlenShamatov.ScreenTranslator",
        category: "QuickLookMode"
    )

    init(
        blockMapper: QuickLookOCRBlockMapper = QuickLookOCRBlockMapper(),
        cjkDetector: QuickLookCJKTextDetector = QuickLookCJKTextDetector()
    ) {
        self.blockMapper = blockMapper
        self.cjkDetector = cjkDetector
    }

    func renderPNGData(
        for input: ScreenshotInput,
        observations: [OCRTextObservation]
    ) async throws -> Data {
        guard let sourceImage = UIImage(data: input.imageData) else {
            throw AppError.unsupportedImage
        }

        let canvasSize = input.size
        let blocks = await blockMapper.makeBlocks(
            from: observations,
            canvasSize: canvasSize
        )
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let renderPlan = makeRenderPlan(
            from: blocks,
            canvasRect: canvasRect
        )

        logger.debug(
            """
            Quick Look overlay visual candidates=\(renderPlan.candidateCount), \
            rendered=\(renderPlan.items.count), \
            skippedLowPriorityClutter=\(renderPlan.skippedLowPriorityClutter), \
            shortenedLabels=\(renderPlan.shortenedLabelCount), \
            ellipsizedLabels=\(renderPlan.ellipsizedLabelCount), \
            compactMixedValueLabels=\(renderPlan.compactMixedValueLabelCount), \
            localMTTextReplacement=\
            \(renderPlan.localMTTextReplacementCount), \
            localMTParagraphCards=\
            \(renderPlan.localMTParagraphCardCount), \
            localMTShortBubbles=\(renderPlan.localMTShortBubbleCount), \
            avgLocalMTCardHeight=\
            \(renderPlan.averageLocalMTCardHeight, format: .fixed(precision: 1)), \
            maxLocalMTCardHeight=\
            \(renderPlan.maximumLocalMTCardHeight, format: .fixed(precision: 1)), \
            truncatedLocalMT=\
            \(renderPlan.truncatedLocalMTCount), \
            dictionaryPills=\(renderPlan.dictionaryPillCount)
            """
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(
            size: canvasSize,
            format: format
        )
        let pngData = renderer.pngData { _ in
            sourceImage.draw(in: canvasRect)

            for item in renderPlan.items {
                drawTranslationOverlay(layout: item.layout)
            }

            if containsCJK(in: observations) == false {
                drawStatusBadge(
                    text: "No Chinese text detected",
                    canvasSize: canvasSize,
                    alpha: 0.62
                )
            }
        }

        guard pngData.isEmpty == false else {
            throw AppError.unsupportedImage
        }

        return pngData
    }

    private func containsCJK(in observations: [OCRTextObservation]) -> Bool {
        observations.contains { observation in
            cjkDetector.containsCJK(in: observation.originalText)
        }
    }

    private func drawTranslationOverlay(
        layout: TranslationOverlayLayout
    ) {
        let shadowPath = UIBezierPath(
            roundedRect: layout.outerFrame,
            cornerRadius: layout.cornerRadius
        )

        guard let context = UIGraphicsGetCurrentContext() else {
            drawOverlayBody(layout: layout)
            return
        }

        context.saveGState()
        context.setShadow(
            offset: CGSize(
                width: 0,
                height: shadowOffsetY(for: layout.renderMode)
            ),
            blur: shadowBlur(for: layout.renderMode),
            color: UIColor.black
                .withAlphaComponent(
                    shadowAlpha(for: layout.renderMode)
                )
                .cgColor
        )
        UIColor.white
            .withAlphaComponent(backgroundAlpha(for: layout.renderMode))
            .setFill()
        shadowPath.fill()
        context.restoreGState()

        drawOverlayBody(layout: layout)
    }

    private func makeRenderPlan(
        from blocks: [QuickLookOCRBlock],
        canvasRect: CGRect
    ) -> QuickLookOverlayRenderPlan {
        var items: [QuickLookOverlayRenderItem] = []
        var skippedLowPriorityClutter = 0
        var shortenedLabelCount = 0
        var ellipsizedLabelCount = 0
        var compactMixedValueLabelCount = 0
        var localMTTextReplacementCount = 0
        var localMTParagraphCardCount = 0
        var localMTShortBubbleCount = 0
        var localMTCardHeightTotal: CGFloat = 0
        var maximumLocalMTCardHeight: CGFloat = 0
        var truncatedLocalMTCount = 0
        var dictionaryPillCount = 0
        var placedLocalMTFrames: [CGRect] = []

        for block in blocks {
            let renderMode = overlayRenderMode(for: block)
            let priority = overlayPriority(for: block)

            if shouldSkipForClutter(
                block: block,
                priority: priority,
                canvasRect: canvasRect
            ) {
                skippedLowPriorityClutter += 1
                continue
            }

            let displayText = overlayDisplayText(
                for: block,
                priority: priority,
                renderMode: renderMode
            )

            if displayText.isShortened {
                shortenedLabelCount += 1
            }

            if displayText.isCompactMixedValue {
                compactMixedValueLabelCount += 1
            }

            var layout = translationOverlayLayout(
                for: block,
                displayText: displayText.text,
                renderMode: renderMode,
                priority: priority,
                canvasRect: canvasRect
            )
            layout = adjustedForLocalMTOverlap(
                layout,
                placedFrames: placedLocalMTFrames,
                canvasRect: canvasRect
            )

            if layout.isEllipsized {
                ellipsizedLabelCount += 1
            }

            switch renderMode {
            case .localMTTextReplacement:
                localMTTextReplacementCount += 1
                localMTCardHeightTotal += layout.outerFrame.height
                maximumLocalMTCardHeight = max(
                    maximumLocalMTCardHeight,
                    layout.outerFrame.height
                )
                placedLocalMTFrames.append(layout.outerFrame)
                if displayText.isShortened || layout.isEllipsized {
                    truncatedLocalMTCount += 1
                }
            case .localMTParagraphCard:
                localMTParagraphCardCount += 1
                localMTCardHeightTotal += layout.outerFrame.height
                maximumLocalMTCardHeight = max(
                    maximumLocalMTCardHeight,
                    layout.outerFrame.height
                )
                placedLocalMTFrames.append(layout.outerFrame)
                if displayText.isShortened || layout.isEllipsized {
                    truncatedLocalMTCount += 1
                }
            case .localMTShortBubble:
                localMTShortBubbleCount += 1
                localMTCardHeightTotal += layout.outerFrame.height
                maximumLocalMTCardHeight = max(
                    maximumLocalMTCardHeight,
                    layout.outerFrame.height
                )
                placedLocalMTFrames.append(layout.outerFrame)
                if displayText.isShortened || layout.isEllipsized {
                    truncatedLocalMTCount += 1
                }
            case .dictionaryPill:
                dictionaryPillCount += 1
            }

            logger.debug(
                """
                Quick Look overlay item groupID=\
                \(block.groupID ?? "none", privacy: .public), sourceKind=\
                \(sourceKindName(block.overlaySourceKind), privacy: .public), \
                mode=\(renderMode.rawValue, privacy: .public), \
                sourcePreview=\(preview(block.sourceText), privacy: .public), \
                rawDisplayPreview=\
                \(preview(block.displayText), privacy: .public), \
                normalDisplayPreview=\
                \(preview(displayText.text), privacy: .public), \
                sourceFrame=\
                \(frameSummary(block.sourceFrame), privacy: .public), \
                translatedTextLength=\
                \(block.displayText.count, privacy: .public), \
                displayTextLength=\
                \(displayText.text.count, privacy: .public), \
                measuredSize=\
                \(sizeSummary(layout.measuredTextSize), privacy: .public), \
                finalFrame=\
                \(frameSummary(layout.outerFrame), privacy: .public), \
                chosenFontSize=\
                \(layout.fontSize, format: .fixed(precision: 1)), \
                lineCountEstimate=\
                \(layout.lineCountEstimate, privacy: .public), \
                fitsWithoutTruncation=\
                \(layout.fitsWithoutTruncation, privacy: .public), \
                didGrowFrame=\(layout.didGrowFrame, privacy: .public), \
                shortened=\(displayText.isShortened, privacy: .public), \
                ellipsized=\(layout.isEllipsized, privacy: .public)
                """
            )

            items.append(
                QuickLookOverlayRenderItem(
                    layout: layout,
                    priority: priority
                )
            )
        }

        return QuickLookOverlayRenderPlan(
            candidateCount: blocks.count,
            items: items,
            skippedLowPriorityClutter: skippedLowPriorityClutter,
            shortenedLabelCount: shortenedLabelCount,
            ellipsizedLabelCount: ellipsizedLabelCount,
            compactMixedValueLabelCount: compactMixedValueLabelCount,
            localMTTextReplacementCount: localMTTextReplacementCount,
            localMTParagraphCardCount: localMTParagraphCardCount,
            localMTShortBubbleCount: localMTShortBubbleCount,
            averageLocalMTCardHeight: localMTCardCount(
                replacementCount: localMTTextReplacementCount,
                paragraphCount: localMTParagraphCardCount,
                shortCount: localMTShortBubbleCount
            ) > 0
                ? localMTCardHeightTotal / CGFloat(
                    localMTCardCount(
                        replacementCount: localMTTextReplacementCount,
                        paragraphCount: localMTParagraphCardCount,
                        shortCount: localMTShortBubbleCount
                    )
                )
                : 0,
            maximumLocalMTCardHeight: maximumLocalMTCardHeight,
            truncatedLocalMTCount: truncatedLocalMTCount,
            dictionaryPillCount: dictionaryPillCount
        )
    }

    private func drawOverlayBody(layout: TranslationOverlayLayout) {
        let path = UIBezierPath(
            roundedRect: layout.outerFrame,
            cornerRadius: layout.cornerRadius
        )

        UIColor.white
            .withAlphaComponent(backgroundAlpha(for: layout.renderMode))
            .setFill()
        path.fill()

        let strokeColor: UIColor = {
            switch layout.renderMode {
            case .dictionaryPill:
                return UIColor.systemIndigo.withAlphaComponent(0.34)
            case .localMTTextReplacement:
                return UIColor.black.withAlphaComponent(0.12)
            case .localMTParagraphCard, .localMTShortBubble:
                return UIColor.systemTeal.withAlphaComponent(0.28)
            }
        }()
        strokeColor.setStroke()
        path.lineWidth = max(
            layout.renderMode == .dictionaryPill ? 1.5 : 1.2,
            layout.fontSize * 0.07
        )
        path.stroke()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = layout.lineBreakMode
        paragraphStyle.lineSpacing = lineSpacing(
            for: layout.renderMode,
            fontSize: layout.fontSize
        )

        NSString(string: layout.text).draw(
            with: layout.textFrame,
            options: [
                .usesLineFragmentOrigin,
                .usesFontLeading
            ],
            attributes: [
                .font: UIFont.systemFont(
                    ofSize: layout.fontSize,
                    weight: fontWeight(for: layout.renderMode)
                ),
                .foregroundColor: UIColor(
                    red: 0.10,
                    green: 0.10,
                    blue: 0.14,
                    alpha: 1
                ),
                .paragraphStyle: paragraphStyle
            ],
            context: nil
        )
    }

    private func translationOverlayLayout(
        for block: QuickLookOCRBlock,
        displayText: String,
        renderMode: QuickLookOverlayRenderMode,
        priority: QuickLookOverlayPriority,
        canvasRect: CGRect
    ) -> TranslationOverlayLayout {
        let sourceFrame = block.sourceFrame.standardized

        if renderMode == .localMTTextReplacement {
            return textReplacementOverlayLayout(
                sourceFrame: sourceFrame,
                displayText: displayText,
                renderMode: renderMode,
                priority: priority,
                canvasRect: canvasRect
            )
        }

        let padding = overlayPadding(
            for: sourceFrame,
            priority: priority,
            renderMode: renderMode,
            canvasRect: canvasRect
        )
        let maximumWidth = maximumOverlayWidth(
            sourceFrame: sourceFrame,
            priority: priority,
            canvasRect: canvasRect,
            renderMode: renderMode
        )
        let baseMinimumWidth = minimumOverlayWidth(
            sourceFrame: sourceFrame,
            priority: priority,
            canvasRect: canvasRect,
            renderMode: renderMode
        )
        let minimumWidth = min(
            maximumWidth,
            renderMode == .dictionaryPill
                ? max(sourceFrame.width, baseMinimumWidth)
                : baseMinimumWidth
        )
        let maximumHeight = maximumOverlayHeight(
            sourceFrame: sourceFrame,
            priority: priority,
            canvasRect: canvasRect,
            renderMode: renderMode
        )
        let textMaximumWidth = max(maximumWidth - (padding * 2), 32)
        let textMaximumHeight = max(maximumHeight - (padding * 2), 18)
        let fit = fittedText(
            text: displayText,
            renderMode: renderMode,
            initialFontSize: initialFontSize(
                sourceFrame: sourceFrame,
                priority: priority,
                canvasRect: canvasRect,
                renderMode: renderMode
            ),
            minimumFontSize: minimumFontSize(
                for: priority,
                renderMode: renderMode
            ),
            maximumWidth: textMaximumWidth,
            maximumHeight: textMaximumHeight
        )
        let measuredTextSize = measuredSize(
            text: fit.text,
            fontSize: fit.fontSize,
            maximumWidth: textMaximumWidth,
            renderMode: renderMode
        )
        let measuredOverlayWidth = measuredTextSize.width + (padding * 2)
        let measuredOverlayHeight = measuredTextSize.height + (padding * 2)
        let minimumHeight = minimumOverlayHeight(
            sourceFrame: sourceFrame,
            maximumHeight: maximumHeight,
            renderMode: renderMode
        )
        let overlaySize = CGSize(
            width: min(
                maximumWidth,
                max(minimumWidth, measuredOverlayWidth)
            ),
            height: min(
                maximumHeight,
                max(
                    minimumHeight,
                    measuredOverlayHeight
                )
            )
        )
        let preferredOrigin = preferredOverlayOrigin(
            sourceFrame: sourceFrame,
            renderMode: renderMode
        )
        let origin = clampedOrigin(
            preferred: preferredOrigin,
            size: overlaySize,
            canvasRect: canvasRect
        )
        let outerFrame = CGRect(origin: origin, size: overlaySize)

        return TranslationOverlayLayout(
            text: fit.text,
            outerFrame: outerFrame,
            textFrame: outerFrame.insetBy(dx: padding, dy: padding),
            fontSize: fit.fontSize,
            cornerRadius: cornerRadius(
                for: renderMode,
                overlaySize: overlaySize
            ),
            lineBreakMode: renderMode == .dictionaryPill && fit.isEllipsized
                ? .byTruncatingTail
                : .byWordWrapping,
            isEllipsized: fit.isEllipsized,
            fitsWithoutTruncation: fit.isEllipsized == false,
            didGrowFrame: false,
            renderMode: renderMode,
            measuredTextSize: measuredTextSize,
            lineCountEstimate: fit.lineCountEstimate
        )
    }

    private func textReplacementOverlayLayout(
        sourceFrame: CGRect,
        displayText: String,
        renderMode: QuickLookOverlayRenderMode,
        priority: QuickLookOverlayPriority,
        canvasRect: CGRect
    ) -> TranslationOverlayLayout {
        let margin = max(3, min(8, canvasRect.width * 0.004))
        let padding = overlayPadding(
            for: sourceFrame,
            priority: priority,
            renderMode: renderMode,
            canvasRect: canvasRect
        )
        let preferredWidth = min(
            canvasRect.width - 8,
            max(sourceFrame.width + margin * 2, min(canvasRect.width * 0.72, 230))
        )
        let preferredBaseHeight = max(sourceFrame.height + margin * 2, 58)
        let maximumHeight = min(
            canvasRect.height * 0.48,
            max(preferredBaseHeight * 1.28, preferredBaseHeight + 70)
        )
        let baseHeight = min(preferredBaseHeight, maximumHeight)
        let preferredOrigin = CGPoint(
            x: sourceFrame.minX - margin,
            y: sourceFrame.minY - margin
        )
        let baseOrigin = clampedOrigin(
            preferred: preferredOrigin,
            size: CGSize(width: preferredWidth, height: baseHeight),
            canvasRect: canvasRect
        )
        let textWidth = max(preferredWidth - padding * 2, 48)
        let initialFont = replacementInitialFontSize(
            sourceFrame: sourceFrame,
            canvasRect: canvasRect
        )
        let minimumFont = minimumFontSize(
            for: priority,
            renderMode: renderMode
        )
        let baseFit = fittedText(
            text: displayText,
            renderMode: renderMode,
            initialFontSize: initialFont,
            minimumFontSize: minimumFont,
            maximumWidth: textWidth,
            maximumHeight: max(baseHeight - padding * 2, 24)
        )
        let grewFrame = baseFit.isEllipsized
        let finalHeight: CGFloat
        let fit: QuickLookTextFit

        if grewFrame {
            let grownFit = fittedText(
                text: displayText,
                renderMode: renderMode,
                initialFontSize: initialFont,
                minimumFontSize: minimumFont,
                maximumWidth: textWidth,
                maximumHeight: max(maximumHeight - padding * 2, 24)
            )
            fit = grownFit
            let measuredHeight = measuredSize(
                text: grownFit.text,
                fontSize: grownFit.fontSize,
                maximumWidth: textWidth,
                renderMode: renderMode
            ).height + padding * 2
            finalHeight = min(maximumHeight, max(baseHeight, measuredHeight))
        } else {
            fit = baseFit
            finalHeight = baseHeight
        }

        let finalSize = CGSize(width: preferredWidth, height: finalHeight)
        let finalOrigin = clampedOrigin(
            preferred: baseOrigin,
            size: finalSize,
            canvasRect: canvasRect
        )
        let outerFrame = CGRect(origin: finalOrigin, size: finalSize)
        let measuredTextSize = measuredSize(
            text: fit.text,
            fontSize: fit.fontSize,
            maximumWidth: textWidth,
            renderMode: renderMode
        )

        return TranslationOverlayLayout(
            text: fit.text,
            outerFrame: outerFrame,
            textFrame: outerFrame.insetBy(dx: padding, dy: padding),
            fontSize: fit.fontSize,
            cornerRadius: cornerRadius(
                for: renderMode,
                overlaySize: finalSize
            ),
            lineBreakMode: .byWordWrapping,
            isEllipsized: fit.isEllipsized,
            fitsWithoutTruncation: fit.isEllipsized == false,
            didGrowFrame: grewFrame && finalHeight > baseHeight + 1,
            renderMode: renderMode,
            measuredTextSize: measuredTextSize,
            lineCountEstimate: fit.lineCountEstimate
        )
    }

    private func fittedText(
        text: String,
        renderMode: QuickLookOverlayRenderMode,
        initialFontSize: CGFloat,
        minimumFontSize: CGFloat,
        maximumWidth: CGFloat,
        maximumHeight: CGFloat
    ) -> QuickLookTextFit {
        var fontSize = initialFontSize

        while fontSize >= minimumFontSize {
            let size = measuredSize(
                text: text,
                fontSize: fontSize,
                maximumWidth: maximumWidth,
                renderMode: renderMode
            )

            if size.height <= maximumHeight {
                return QuickLookTextFit(
                    text: text,
                    fontSize: fontSize,
                    isEllipsized: false,
                    lineCountEstimate: estimatedLineCount(
                        textHeight: size.height,
                        fontSize: fontSize,
                        renderMode: renderMode
                    )
                )
            }

            fontSize -= 1
        }

        let ellipsizedText = ellipsized(
            text,
            renderMode: renderMode,
            fontSize: minimumFontSize,
            maximumWidth: maximumWidth,
            maximumHeight: maximumHeight
        )
        let ellipsizedSize = measuredSize(
            text: ellipsizedText,
            fontSize: minimumFontSize,
            maximumWidth: maximumWidth,
            renderMode: renderMode
        )

        return QuickLookTextFit(
            text: ellipsizedText,
            fontSize: minimumFontSize,
            isEllipsized: ellipsizedText != text,
            lineCountEstimate: estimatedLineCount(
                textHeight: ellipsizedSize.height,
                fontSize: minimumFontSize,
                renderMode: renderMode
            )
        )
    }

    private func measuredSize(
        text: String,
        fontSize: CGFloat,
        maximumWidth: CGFloat,
        renderMode: QuickLookOverlayRenderMode = .dictionaryPill
    ) -> CGSize {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = lineSpacing(
            for: renderMode,
            fontSize: fontSize
        )

        let boundingRect = NSString(string: text).boundingRect(
            with: CGSize(
                width: maximumWidth,
                height: .greatestFiniteMagnitude
            ),
            options: [
                .usesLineFragmentOrigin,
                .usesFontLeading
            ],
            attributes: [
                .font: UIFont.systemFont(
                    ofSize: fontSize,
                    weight: fontWeight(for: renderMode)
                ),
                .paragraphStyle: paragraphStyle
            ],
            context: nil
        )

        return CGSize(
            width: ceil(boundingRect.width),
            height: ceil(boundingRect.height)
        )
    }

    private func overlayPriority(
        for block: QuickLookOCRBlock
    ) -> QuickLookOverlayPriority {
        let combinedSource = "\(block.sourceText) \(block.matchedSource)"
        let displayText = block.displayText.lowercased()

        if block.hasPreservedValue,
           containsAny(combinedSource, priceAndValueTokens)
                || displayText.contains("¥")
                || displayText.contains("yuan") {
            return .high
        }

        if block.matchKind == .singleAllowlist {
            return .medium
        }

        if block.matchKind == .localMT {
            if block.lineCount > 1 {
                return .high
            }

            return block.sourceText.count >= 14 ? .high : .medium
        }

        if block.matchKind == .summary, block.isImportant {
            return .high
        }

        if containsAny(combinedSource, highPrioritySourceTokens)
            || containsAny(displayText, highPriorityDisplayTokens) {
            return .high
        }

        if containsAny(combinedSource, mediumPrioritySourceTokens) {
            return .medium
        }

        if block.isImportant && isLikelyProductText(block) == false {
            return .medium
        }

        return .low
    }

    private func shouldSkipForClutter(
        block: QuickLookOCRBlock,
        priority: QuickLookOverlayPriority,
        canvasRect: CGRect
    ) -> Bool {
        guard priority == .low else {
            return false
        }

        guard block.matchKind != .localMT else {
            return false
        }

        guard block.hasPreservedValue == false else {
            return false
        }

        let frame = block.sourceFrame.standardized
        let canvasArea = max(canvasRect.width * canvasRect.height, 1)
        let areaRatio = (frame.width * frame.height) / canvasArea
        let widthRatio = frame.width / max(canvasRect.width, 1)
        let midYRatio = frame.midY / max(canvasRect.height, 1)

        if midYRatio < 0.13 || midYRatio > 0.90 {
            return false
        }

        if isLikelyProductText(block),
           widthRatio > 0.16 || areaRatio > 0.0018 {
            return true
        }

        if block.sourceText.count >= 12 && widthRatio > 0.20 {
            return true
        }

        return areaRatio > 0.004 && widthRatio > 0.15
    }

    private func overlayDisplayText(
        for block: QuickLookOCRBlock,
        priority: QuickLookOverlayPriority,
        renderMode: QuickLookOverlayRenderMode
    ) -> QuickLookOverlayDisplayText {
        let sourceFrame = block.sourceFrame.standardized
        let originalText = normalizedDisplayText(block.displayText)

        if renderMode == .localMTTextReplacement
            || renderMode == .localMTParagraphCard {
            let maxCharacters = 1000
            let text = originalText.count > maxCharacters
                ? trimmedPrefix(originalText, maxCharacters: maxCharacters)
                : originalText

            return QuickLookOverlayDisplayText(
                text: text,
                isShortened: text != originalText,
                isCompactMixedValue: false
            )
        }

        if renderMode == .localMTShortBubble {
            let maxCharacters = 240
            let text = originalText.count > maxCharacters
                ? trimmedPrefix(originalText, maxCharacters: maxCharacters)
                : originalText

            return QuickLookOverlayDisplayText(
                text: text,
                isShortened: text != originalText,
                isCompactMixedValue: false
            )
        }

        let isSmallChip = sourceFrame.height < 42 || sourceFrame.width < 120
        let maxCharacters: Int

        switch priority {
        case .high:
            maxCharacters = isSmallChip ? 22 : 32
        case .medium:
            maxCharacters = isSmallChip ? 18 : 26
        case .low:
            maxCharacters = isSmallChip ? 14 : 20
        }

        if let compactMixedValueText = compactMixedValueDisplayText(for: block) {
            return QuickLookOverlayDisplayText(
                text: compactMixedValueText,
                isShortened: compactMixedValueText != originalText,
                isCompactMixedValue: true
            )
        }

        var text = compactDisplayText(originalText)

        guard text.count > maxCharacters else {
            return QuickLookOverlayDisplayText(
                text: text,
                isShortened: text != originalText,
                isCompactMixedValue: false
            )
        }

        let segments = displaySegments(from: text)
        if segments.count > 1 {
            switch priority {
            case .high:
                text = joinedHighPrioritySegments(
                    segments,
                    sourceText: block.sourceText,
                    maxCharacters: maxCharacters
                )
            case .medium, .low:
                text = segments[0]
            }
        }

        guard text.count > maxCharacters else {
            return QuickLookOverlayDisplayText(
                text: text,
                isShortened: text != originalText,
                isCompactMixedValue: false
            )
        }

        let trimmedText = trimmedPrefix(text, maxCharacters: maxCharacters)

        return QuickLookOverlayDisplayText(
            text: trimmedText,
            isShortened: trimmedText != originalText,
            isCompactMixedValue: false
        )
    }

    private func compactDisplayText(_ text: String) -> String {
        var compactText = normalizedDisplayText(text)
        let replacements: [(String, String)] = [
            ("shopping cart", "cart"),
            ("verification code", "verify code"),
            ("customer service", "support"),
            ("national subsidy", "natl subsidy"),
            ("government subsidy", "gov subsidy"),
            ("subsidized price", "subsidy price"),
            ("after-coupon price", "coupon price"),
            ("high-heeled shoes", "heels"),
            ("in stock · fast shipping", "stock · fast ship"),
            ("Taobao Coins", "coins"),
            ("collect coins", "coins"),
            ("Taobao Factory", "factory"),
            ("red packet", "red packet"),
            ("network error · retry", "network · retry")
        ]

        for replacement in replacements {
            compactText = compactText.replacingOccurrences(
                of: replacement.0,
                with: replacement.1
            )
        }

        return normalizedDisplayText(compactText)
    }

    private func compactMixedValueDisplayText(
        for block: QuickLookOCRBlock
    ) -> String? {
        guard block.hasPreservedValue else {
            return nil
        }

        let sourceText = block.sourceText

        guard sourceText.contains("消费券")
            || sourceText.contains("购物金")
            || sourceText.contains("待使用")
            || sourceText.contains("剩") else {
            return nil
        }

        var segments: [String] = []

        if let yuanAmountText = compactYuanAmountText(from: sourceText) {
            segments.append(yuanAmountText)
        } else if let quantityText = compactQuantityText(from: sourceText) {
            segments.append(quantityText)
        }

        if let timeText = compactTimeText(from: sourceText) {
            segments.append(timeText)
        }

        guard segments.isEmpty == false else {
            return nil
        }

        return segments.prefix(2).joined(separator: " · ")
    }

    private func compactYuanAmountText(from sourceText: String) -> String? {
        guard let captures = capturedGroups(
            in: sourceText,
            pattern: #"([0-9]+(?:[.,][0-9]+)?)元"#
        ), let amount = captures.first else {
            return nil
        }

        if sourceText.contains("消费券") || sourceText.contains("优惠券") {
            return "\(amount) yuan coupon"
        }

        return "\(amount) yuan"
    }

    private func compactQuantityText(from sourceText: String) -> String? {
        guard let captures = capturedGroups(
            in: sourceText,
            pattern: #"([0-9]+)(?:张|件)"#
        ), let quantity = captures.first else {
            return nil
        }

        return "\(quantity) pcs"
    }

    private func compactTimeText(from sourceText: String) -> String? {
        if let captures = capturedGroups(
            in: sourceText,
            pattern: #"剩?([0-9]+)天([0-9]+)小时"#
        ), captures.count == 2 {
            return "\(captures[0])d \(captures[1])h left"
        }

        if let captures = capturedGroups(
            in: sourceText,
            pattern: #"剩?([0-9]+)天"#
        ), let days = captures.first {
            return "\(days)d left"
        }

        if let captures = capturedGroups(
            in: sourceText,
            pattern: #"剩?([0-9]+)小时"#
        ), let hours = captures.first {
            return "\(hours)h left"
        }

        return nil
    }

    private func capturedGroups(
        in text: String,
        pattern: String
    ) -> [String]? {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)

        guard let match = expression.firstMatch(
            in: text,
            range: nsRange
        ) else {
            return nil
        }

        var captures: [String] = []

        for index in 1..<match.numberOfRanges {
            let range = match.range(at: index)

            guard let stringRange = Range(range, in: text) else {
                continue
            }

            captures.append(String(text[stringRange]))
        }

        return captures
    }

    private func joinedHighPrioritySegments(
        _ segments: [String],
        sourceText: String,
        maxCharacters: Int
    ) -> String {
        let firstSegment = segments[0]
        let secondarySegment: String? = {
            if sourceText.contains("周年庆"),
               let anniversarySegment = segments.first(where: { $0.contains("год") }) {
                return anniversarySegment
            }

            return segments.dropFirst().first
        }()

        guard let secondarySegment else {
            return firstSegment
        }

        let joined = "\(firstSegment) · \(secondarySegment)"
        if joined.count <= maxCharacters + 4 {
            return joined
        }

        return firstSegment
    }

    private func displaySegments(from text: String) -> [String] {
        text.replacingOccurrences(of: " · ", with: ",")
            .components(separatedBy: ",")
            .map(normalizedDisplayText)
            .filter { $0.isEmpty == false }
    }

    private func normalizedDisplayText(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func trimmedPrefix(
        _ text: String,
        maxCharacters: Int
    ) -> String {
        let prefixText = String(text.prefix(max(1, maxCharacters - 3)))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ",. "))

        return "\(prefixText)..."
    }

    private func overlayRenderMode(
        for block: QuickLookOCRBlock
    ) -> QuickLookOverlayRenderMode {
        let displayText = normalizedDisplayText(block.displayText)

        switch block.overlaySourceKind {
        case .localMTGroup:
            if shouldUseReplacementCard(for: block, displayText: displayText) {
                return .localMTTextReplacement
            }

            if block.lineCount >= 2
                || displayText.count > 90
                || block.sourceFrame.height > 54 {
                return .localMTParagraphCard
            }

            return .localMTShortBubble
        case .localMTLine:
            return displayText.count > 110
                ? .localMTParagraphCard
                : .localMTShortBubble
        case .cedict, .single, .debug:
            return .dictionaryPill
        }
    }

    private func shouldUseReplacementCard(
        for block: QuickLookOCRBlock,
        displayText: String
    ) -> Bool {
        guard block.sourceText.count >= 20 else {
            return false
        }

        switch block.blockType {
        case .chatBubble, .addressBlock, .paragraph:
            return true
        case .unknown:
            return block.lineCount >= 2 || displayText.count >= 90
        case .uiLabel, .button, .productCard:
            return block.lineCount >= 2 && displayText.count >= 70
        }
    }

    private func overlayPadding(
        for sourceFrame: CGRect,
        priority: QuickLookOverlayPriority,
        renderMode: QuickLookOverlayRenderMode,
        canvasRect: CGRect
    ) -> CGFloat {
        switch renderMode {
        case .localMTTextReplacement:
            return max(10, min(16, canvasRect.width * 0.011))
        case .localMTParagraphCard:
            return max(10, min(15, canvasRect.width * 0.010))
        case .localMTShortBubble:
            return max(8, min(12, canvasRect.width * 0.008))
        case .dictionaryPill:
            let scale: CGFloat = priority == .high ? 0.24 : 0.20
            return max(
                5,
                min(priority == .high ? 11 : 9, sourceFrame.height * scale)
            )
        }
    }

    private func minimumOverlayWidth(
        sourceFrame: CGRect,
        priority: QuickLookOverlayPriority,
        canvasRect: CGRect,
        renderMode: QuickLookOverlayRenderMode
    ) -> CGFloat {
        switch renderMode {
        case .localMTTextReplacement:
            return min(
                canvasRect.width * 0.78,
                max(250, sourceFrame.width * 0.94)
            )
        case .localMTParagraphCard:
            return min(
                canvasRect.width * 0.62,
                max(230, sourceFrame.width * 0.74)
            )
        case .localMTShortBubble:
            return min(
                canvasRect.width * 0.54,
                max(150, sourceFrame.width * 0.72)
            )
        case .dictionaryPill:
            switch priority {
            case .high:
                return sourceFrame.height < 30 ? 68 : 82
            case .medium:
                return sourceFrame.height < 30 ? 62 : 76
            case .low:
                return 56
            }
        }
    }

    private func maximumOverlayWidth(
        sourceFrame: CGRect,
        priority: QuickLookOverlayPriority,
        canvasRect: CGRect,
        renderMode: QuickLookOverlayRenderMode
    ) -> CGFloat {
        switch renderMode {
        case .localMTTextReplacement:
            let targetWidth = max(
                sourceFrame.width * 1.06 + 18,
                canvasRect.width * 0.48
            )
            return max(
                minimumOverlayWidth(
                    sourceFrame: sourceFrame,
                    priority: priority,
                    canvasRect: canvasRect,
                    renderMode: renderMode
                ),
                min(canvasRect.width * 0.86, targetWidth)
            )
        case .localMTParagraphCard:
            let targetWidth = max(
                sourceFrame.width * 1.32 + 64,
                canvasRect.width * 0.52
            )
            return max(
                minimumOverlayWidth(
                    sourceFrame: sourceFrame,
                    priority: priority,
                    canvasRect: canvasRect,
                    renderMode: renderMode
                ),
                min(canvasRect.width * 0.82, targetWidth)
            )
        case .localMTShortBubble:
            let targetWidth = max(sourceFrame.width * 1.18 + 44, 220)
            return max(
                minimumOverlayWidth(
                    sourceFrame: sourceFrame,
                    priority: priority,
                    canvasRect: canvasRect,
                    renderMode: renderMode
                ),
                min(canvasRect.width * 0.70, targetWidth)
            )
        case .dictionaryPill:
            let sourceMultiplier: CGFloat
            let canvasMultiplier: CGFloat

            switch priority {
            case .high:
                sourceMultiplier = 1.30
                canvasMultiplier = 0.48
            case .medium:
                sourceMultiplier = 1.18
                canvasMultiplier = 0.38
            case .low:
                sourceMultiplier = 1.05
                canvasMultiplier = 0.30
            }

            return max(
                minimumOverlayWidth(
                    sourceFrame: sourceFrame,
                    priority: priority,
                    canvasRect: canvasRect,
                    renderMode: renderMode
                ),
                min(
                    canvasRect.width * canvasMultiplier,
                    sourceFrame.width * sourceMultiplier + 20
                )
            )
        }
    }

    private func maximumOverlayHeight(
        sourceFrame: CGRect,
        priority: QuickLookOverlayPriority,
        canvasRect: CGRect,
        renderMode: QuickLookOverlayRenderMode
    ) -> CGFloat {
        switch renderMode {
        case .localMTTextReplacement:
            return min(
                canvasRect.height * 0.42,
                max(sourceFrame.height * 1.12 + 24, 180)
            )
        case .localMTParagraphCard:
            return min(canvasRect.height * 0.30, max(168, sourceFrame.height + 92))
        case .localMTShortBubble:
            return min(canvasRect.height * 0.14, max(72, sourceFrame.height + 44))
        case .dictionaryPill:
            let sourceMultiplier: CGFloat

            switch priority {
            case .high:
                sourceMultiplier = 2.15
            case .medium:
                sourceMultiplier = 1.85
            case .low:
                sourceMultiplier = 1.45
            }

            return min(
                canvasRect.height - 8,
                max(sourceFrame.height * sourceMultiplier, priority == .high ? 42 : 36)
            )
        }
    }

    private func initialFontSize(
        sourceFrame: CGRect,
        priority: QuickLookOverlayPriority,
        canvasRect: CGRect,
        renderMode: QuickLookOverlayRenderMode
    ) -> CGFloat {
        switch renderMode {
        case .localMTTextReplacement:
            return max(17, min(23, canvasRect.width * 0.016))
        case .localMTParagraphCard:
            return max(18, min(24, canvasRect.width * 0.017))
        case .localMTShortBubble:
            return max(17, min(24, canvasRect.width * 0.018))
        case .dictionaryPill:
            let scale: CGFloat = priority == .high ? 0.60 : 0.54
            let maximum: CGFloat = priority == .high ? 28 : 24
            return max(12, min(maximum, sourceFrame.height * scale))
        }
    }

    private func replacementInitialFontSize(
        sourceFrame: CGRect,
        canvasRect: CGRect
    ) -> CGFloat {
        let heightBasedSize = sourceFrame.height * 0.22
        let widthBasedSize = sourceFrame.width * 0.038
        let canvasBasedSize = canvasRect.width * 0.022

        return max(
            18,
            min(
                36,
                max(heightBasedSize, widthBasedSize, canvasBasedSize)
            )
        )
    }

    private func minimumFontSize(
        for priority: QuickLookOverlayPriority,
        renderMode: QuickLookOverlayRenderMode
    ) -> CGFloat {
        switch renderMode {
        case .localMTTextReplacement:
            return 14
        case .localMTParagraphCard:
            return 15
        case .localMTShortBubble:
            return 14
        case .dictionaryPill:
            return priority == .low ? 10 : 11
        }
    }

    private func cornerRadius(
        for renderMode: QuickLookOverlayRenderMode,
        overlaySize: CGSize
    ) -> CGFloat {
        switch renderMode {
        case .localMTTextReplacement:
            return min(16, max(10, overlaySize.height * 0.10))
        case .localMTParagraphCard:
            return min(16, max(10, overlaySize.height * 0.11))
        case .localMTShortBubble:
            return min(13, max(8, overlaySize.height * 0.16))
        case .dictionaryPill:
            return min(10, max(5, overlaySize.height * 0.18))
        }
    }

    private func minimumOverlayHeight(
        sourceFrame: CGRect,
        maximumHeight: CGFloat,
        renderMode: QuickLookOverlayRenderMode
    ) -> CGFloat {
        switch renderMode {
        case .localMTTextReplacement:
            return min(
                maximumHeight,
                max(92, sourceFrame.height * 0.68)
            )
        case .localMTParagraphCard, .localMTShortBubble:
            return 0
        case .dictionaryPill:
            return sourceFrame.height
        }
    }

    private func preferredOverlayOrigin(
        sourceFrame: CGRect,
        renderMode: QuickLookOverlayRenderMode
    ) -> CGPoint {
        switch renderMode {
        case .localMTTextReplacement:
            return CGPoint(x: sourceFrame.minX - 4, y: sourceFrame.minY - 4)
        case .localMTParagraphCard, .localMTShortBubble:
            return CGPoint(x: sourceFrame.minX, y: sourceFrame.minY)
        case .dictionaryPill:
            return sourceFrame.origin
        }
    }

    private func backgroundAlpha(
        for renderMode: QuickLookOverlayRenderMode
    ) -> CGFloat {
        switch renderMode {
        case .localMTTextReplacement:
            return 0.92
        case .localMTParagraphCard:
            return 0.90
        case .localMTShortBubble:
            return 0.88
        case .dictionaryPill:
            return 0.92
        }
    }

    private func shadowOffsetY(
        for renderMode: QuickLookOverlayRenderMode
    ) -> CGFloat {
        switch renderMode {
        case .localMTTextReplacement:
            return 1
        case .dictionaryPill:
            return 3
        case .localMTParagraphCard, .localMTShortBubble:
            return 2
        }
    }

    private func shadowBlur(
        for renderMode: QuickLookOverlayRenderMode
    ) -> CGFloat {
        switch renderMode {
        case .localMTTextReplacement:
            return 3
        case .dictionaryPill:
            return 8
        case .localMTParagraphCard, .localMTShortBubble:
            return 7
        }
    }

    private func shadowAlpha(
        for renderMode: QuickLookOverlayRenderMode
    ) -> CGFloat {
        switch renderMode {
        case .localMTTextReplacement:
            return 0.08
        case .dictionaryPill:
            return 0.18
        case .localMTParagraphCard, .localMTShortBubble:
            return 0.15
        }
    }

    private func ellipsized(
        _ text: String,
        renderMode: QuickLookOverlayRenderMode,
        fontSize: CGFloat,
        maximumWidth: CGFloat,
        maximumHeight: CGFloat
    ) -> String {
        var candidate = text

        while candidate.count > 4 {
            let ellipsizedCandidate = trimmedPrefix(
                candidate,
                maxCharacters: candidate.count
            )
            let size = measuredSize(
                text: ellipsizedCandidate,
                fontSize: fontSize,
                maximumWidth: maximumWidth,
                renderMode: renderMode
            )

            if size.height <= maximumHeight {
                return ellipsizedCandidate
            }

            candidate = String(candidate.dropLast())
        }

        return "..."
    }

    private func adjustedForLocalMTOverlap(
        _ layout: TranslationOverlayLayout,
        placedFrames: [CGRect],
        canvasRect: CGRect
    ) -> TranslationOverlayLayout {
        guard layout.renderMode != .dictionaryPill,
              layout.renderMode != .localMTTextReplacement,
              placedFrames.isEmpty == false else {
            return layout
        }

        let overlappingFrame = placedFrames.first { placedFrame in
            let intersection = layout.outerFrame.intersection(placedFrame)

            guard intersection.isNull == false,
                  intersection.isEmpty == false else {
                return false
            }

            let smallerArea = max(
                1,
                min(
                    layout.outerFrame.width * layout.outerFrame.height,
                    placedFrame.width * placedFrame.height
                )
            )

            return (intersection.width * intersection.height) / smallerArea > 0.34
        }

        guard let overlappingFrame else {
            return layout
        }

        let spacing: CGFloat = 6
        let downwardOrigin = CGPoint(
            x: layout.outerFrame.minX,
            y: overlappingFrame.maxY + spacing
        )
        let upwardOrigin = CGPoint(
            x: layout.outerFrame.minX,
            y: overlappingFrame.minY - layout.outerFrame.height - spacing
        )
        let proposedOrigin = downwardOrigin.y + layout.outerFrame.height
            <= canvasRect.maxY - 4
            ? downwardOrigin
            : upwardOrigin
        let origin = clampedOrigin(
            preferred: proposedOrigin,
            size: layout.outerFrame.size,
            canvasRect: canvasRect
        )
        let yDelta = origin.y - layout.outerFrame.minY
        let xDelta = origin.x - layout.outerFrame.minX
        let outerFrame = CGRect(origin: origin, size: layout.outerFrame.size)
        let textFrame = layout.textFrame.offsetBy(dx: xDelta, dy: yDelta)

        return TranslationOverlayLayout(
            text: layout.text,
            outerFrame: outerFrame,
            textFrame: textFrame,
            fontSize: layout.fontSize,
            cornerRadius: layout.cornerRadius,
            lineBreakMode: layout.lineBreakMode,
            isEllipsized: layout.isEllipsized,
            fitsWithoutTruncation: layout.fitsWithoutTruncation,
            didGrowFrame: layout.didGrowFrame,
            renderMode: layout.renderMode,
            measuredTextSize: layout.measuredTextSize,
            lineCountEstimate: layout.lineCountEstimate
        )
    }

    private func fontWeight(
        for renderMode: QuickLookOverlayRenderMode
    ) -> UIFont.Weight {
        switch renderMode {
        case .localMTTextReplacement:
            return .regular
        case .localMTParagraphCard:
            return .regular
        case .localMTShortBubble:
            return .medium
        case .dictionaryPill:
            return .semibold
        }
    }

    private func lineSpacing(
        for renderMode: QuickLookOverlayRenderMode,
        fontSize: CGFloat
    ) -> CGFloat {
        switch renderMode {
        case .localMTTextReplacement:
            return max(2, fontSize * 0.18)
        case .localMTParagraphCard:
            return max(2, fontSize * 0.18)
        case .localMTShortBubble:
            return max(1, fontSize * 0.12)
        case .dictionaryPill:
            return max(1, fontSize * 0.10)
        }
    }

    private func estimatedLineCount(
        textHeight: CGFloat,
        fontSize: CGFloat,
        renderMode: QuickLookOverlayRenderMode
    ) -> Int {
        let approximateLineHeight = max(
            1,
            fontSize + lineSpacing(for: renderMode, fontSize: fontSize)
        )

        return max(1, Int(ceil(textHeight / approximateLineHeight)))
    }

    private func localMTCardCount(
        replacementCount: Int,
        paragraphCount: Int,
        shortCount: Int
    ) -> Int {
        replacementCount + paragraphCount + shortCount
    }

    private func sizeSummary(_ size: CGSize) -> String {
        "\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
    }

    private func frameSummary(_ frame: CGRect) -> String {
        let standardizedFrame = frame.standardized

        return "x=\(Int(standardizedFrame.minX.rounded())),y=\(Int(standardizedFrame.minY.rounded())),w=\(Int(standardizedFrame.width.rounded())),h=\(Int(standardizedFrame.height.rounded()))"
    }

    private func isLikelyProductText(_ block: QuickLookOCRBlock) -> Bool {
        let sourceText = "\(block.sourceText) \(block.matchedSource)"

        if containsAny(sourceText, productSourceTokens) {
            return true
        }

        return block.sourceText.count > 14
            && containsAny(sourceText, highPrioritySourceTokens) == false
            && block.hasPreservedValue == false
    }

    private func containsAny(
        _ text: String,
        _ tokens: [String]
    ) -> Bool {
        tokens.contains { token in
            text.localizedCaseInsensitiveContains(token)
        }
    }

    private func sourceKindName(
        _ sourceKind: QuickLookOverlaySourceKind
    ) -> String {
        switch sourceKind {
        case .localMTGroup:
            return "localMTGroup"
        case .localMTLine:
            return "localMTLine"
        case .cedict:
            return "cedict"
        case .single:
            return "single"
        case .debug:
            return "debug"
        }
    }

    private func preview(_ text: String) -> String {
        let normalizedText = normalizedDisplayText(text)

        guard normalizedText.count > 96 else {
            return normalizedText
        }

        return "\(normalizedText.prefix(96))..."
    }

    private func clampedOrigin(
        preferred: CGPoint,
        size: CGSize,
        canvasRect: CGRect
    ) -> CGPoint {
        CGPoint(
            x: min(
                max(preferred.x, canvasRect.minX + 4),
                max(canvasRect.maxX - size.width - 4, canvasRect.minX + 4)
            ),
            y: min(
                max(preferred.y, canvasRect.minY + 4),
                max(canvasRect.maxY - size.height - 4, canvasRect.minY + 4)
            )
        )
    }

    private func drawPreviewBadge(canvasSize: CGSize) {
        drawStatusBadge(
            text: "ScreenTranslator Preview",
            canvasSize: canvasSize,
            alpha: 0.58
        )
    }

    private func drawStatusBadge(
        text: String,
        canvasSize: CGSize,
        alpha: CGFloat = 0.74
    ) {
        let fontSize = max(15, min(24, canvasSize.width * 0.024))
        let textSize = measuredSize(
            text: text,
            fontSize: fontSize,
            maximumWidth: max(canvasSize.width - 44, 80)
        )
        let badgeRect = CGRect(
            x: 16,
            y: 16,
            width: min(canvasSize.width - 32, textSize.width + 22),
            height: textSize.height + 14
        )
        let badgePath = UIBezierPath(
            roundedRect: badgeRect,
            cornerRadius: min(10, badgeRect.height * 0.28)
        )

        UIColor.black.withAlphaComponent(alpha).setFill()
        badgePath.fill()

        NSString(string: text).draw(
            with: badgeRect.insetBy(dx: 11, dy: 6),
            options: [
                .usesLineFragmentOrigin,
                .truncatesLastVisibleLine
            ],
            attributes: [
                .font: UIFont.systemFont(
                    ofSize: fontSize,
                    weight: .semibold
                ),
                .foregroundColor: UIColor.white
            ],
            context: nil
        )
    }
}

private struct TranslationOverlayLayout {
    let text: String
    let outerFrame: CGRect
    let textFrame: CGRect
    let fontSize: CGFloat
    let cornerRadius: CGFloat
    let lineBreakMode: NSLineBreakMode
    let isEllipsized: Bool
    let fitsWithoutTruncation: Bool
    let didGrowFrame: Bool
    let renderMode: QuickLookOverlayRenderMode
    let measuredTextSize: CGSize
    let lineCountEstimate: Int
}

private struct QuickLookOverlayRenderPlan {
    let candidateCount: Int
    let items: [QuickLookOverlayRenderItem]
    let skippedLowPriorityClutter: Int
    let shortenedLabelCount: Int
    let ellipsizedLabelCount: Int
    let compactMixedValueLabelCount: Int
    let localMTTextReplacementCount: Int
    let localMTParagraphCardCount: Int
    let localMTShortBubbleCount: Int
    let averageLocalMTCardHeight: CGFloat
    let maximumLocalMTCardHeight: CGFloat
    let truncatedLocalMTCount: Int
    let dictionaryPillCount: Int
}

private struct QuickLookOverlayRenderItem {
    let layout: TranslationOverlayLayout
    let priority: QuickLookOverlayPriority
}

private struct QuickLookOverlayDisplayText {
    let text: String
    let isShortened: Bool
    let isCompactMixedValue: Bool
}

private struct QuickLookTextFit {
    let text: String
    let fontSize: CGFloat
    let isEllipsized: Bool
    let lineCountEstimate: Int
}

private enum QuickLookOverlayRenderMode: String, Equatable {
    case dictionaryPill
    case localMTTextReplacement
    case localMTShortBubble
    case localMTParagraphCard
}

private enum QuickLookOverlayPriority: Equatable {
    case high
    case medium
    case low
}

private let highPrioritySourceTokens = [
    "搜索",
    "购物车",
    "付款",
    "支付",
    "订单",
    "发货",
    "收货",
    "物流",
    "快递",
    "退款",
    "退货",
    "售后",
    "客服",
    "地址",
    "优惠",
    "优惠券",
    "购物金",
    "充值",
    "充值膨胀",
    "红包",
    "消费券",
    "补贴",
    "国补",
    "国家补贴",
    "政府补贴",
    "百亿补贴",
    "券后价",
    "到手价",
    "直播价",
    "合计",
    "总计",
    "实付款",
    "应付款",
    "立即",
    "领取",
    "点抢",
    "20点抢",
    "登录",
    "验证码",
    "网络错误",
    "打开设置",
    "暂无数据",
    "对方正在输入",
    "购买",
    "抢购",
    "加购",
    "添加购物车",
    "去使用",
    "去购买",
    "首页",
    "消息",
    "我的淘宝",
    "我的",
    "AI助手",
    "返回",
    "分享",
    "收藏"
]

private let mediumPrioritySourceTokens = [
    "推荐",
    "关注",
    "闪购",
    "外卖",
    "飞猪",
    "周年庆",
    "穿搭",
    "淘票票",
    "淘宝秒杀",
    "淘金币",
    "淘工厂",
    "商品",
    "店铺",
    "详情",
    "评价",
    "规格",
    "尺码",
    "颜色",
    "库存",
    "视频",
    "图集",
    "宝贝讲解",
    "拼团",
    "省钱卡"
]

private let productSourceTokens = [
    "多功能",
    "蒸煮",
    "一体锅",
    "高跟鞋",
    "轻熟",
    "绝美",
    "女款",
    "男款",
    "夏季",
    "冬季",
    "春季",
    "秋季",
    "直筒",
    "西装裤",
    "显腿直",
    "正品",
    "官方",
    "自营",
    "专柜",
    "新版",
    "洗面奶",
    "化妆水",
    "导入液",
    "基底",
    "发酵液",
    "组合套装",
    "送礼"
]

private let priceAndValueTokens = [
    "价",
    "元",
    "¥",
    "合计",
    "总计",
    "实付款",
    "应付款",
    "月销",
    "已售",
    "人付款"
]

private let highPriorityDisplayTokens = [
    "search",
    "cart",
    "pay",
    "order",
    "ship",
    "shipping",
    "support",
    "coupon",
    "refund",
    "subsidy",
    "buy",
    "receive",
    "home",
    "messages",
    "error",
    "retry",
    "log in",
    "log out",
    "verification",
    "typing",
    "no data",
    "red packet"
]
