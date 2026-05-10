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
    ) throws -> Data {
        guard let sourceImage = UIImage(data: input.imageData) else {
            throw AppError.unsupportedImage
        }

        let canvasSize = input.size
        let blocks = blockMapper.makeBlocks(
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
            compactMixedValueLabels=\(renderPlan.compactMixedValueLabelCount)
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
            offset: CGSize(width: 0, height: 3),
            blur: 8,
            color: UIColor.black.withAlphaComponent(0.18).cgColor
        )
        UIColor.white.withAlphaComponent(0.92).setFill()
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

        for block in blocks {
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
                priority: priority
            )

            if displayText.isShortened {
                shortenedLabelCount += 1
            }

            if displayText.isCompactMixedValue {
                compactMixedValueLabelCount += 1
            }

            let layout = translationOverlayLayout(
                for: block,
                displayText: displayText.text,
                priority: priority,
                canvasRect: canvasRect
            )

            if layout.isEllipsized {
                ellipsizedLabelCount += 1
            }

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
            compactMixedValueLabelCount: compactMixedValueLabelCount
        )
    }

    private func drawOverlayBody(layout: TranslationOverlayLayout) {
        let path = UIBezierPath(
            roundedRect: layout.outerFrame,
            cornerRadius: layout.cornerRadius
        )

        UIColor.white.withAlphaComponent(0.92).setFill()
        path.fill()

        UIColor.systemIndigo.withAlphaComponent(0.34).setStroke()
        path.lineWidth = max(1.5, layout.fontSize * 0.08)
        path.stroke()

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = layout.lineBreakMode
        paragraphStyle.lineSpacing = max(1, layout.fontSize * 0.12)

        NSString(string: layout.text).draw(
            with: layout.textFrame,
            options: [
                .usesLineFragmentOrigin,
                .usesFontLeading
            ],
            attributes: [
                .font: UIFont.systemFont(
                    ofSize: layout.fontSize,
                    weight: .semibold
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
        priority: QuickLookOverlayPriority,
        canvasRect: CGRect
    ) -> TranslationOverlayLayout {
        let sourceFrame = block.sourceFrame.standardized
        let padding = overlayPadding(
            for: sourceFrame,
            priority: priority
        )
        let maximumWidth = maximumOverlayWidth(
            sourceFrame: sourceFrame,
            priority: priority,
            canvasRect: canvasRect
        )
        let minimumWidth = min(
            maximumWidth,
            max(
                sourceFrame.width,
                minimumOverlayWidth(
                    sourceFrame: sourceFrame,
                    priority: priority
                )
            )
        )
        let maximumHeight = maximumOverlayHeight(
            sourceFrame: sourceFrame,
            priority: priority,
            canvasRect: canvasRect
        )
        let textMaximumWidth = max(maximumWidth - (padding * 2), 32)
        let textMaximumHeight = max(maximumHeight - (padding * 2), 18)
        let fit = fittedText(
            text: displayText,
            initialFontSize: initialFontSize(
                sourceFrame: sourceFrame,
                priority: priority
            ),
            minimumFontSize: minimumFontSize(for: priority),
            maximumWidth: textMaximumWidth,
            maximumHeight: textMaximumHeight
        )
        let measuredTextSize = measuredSize(
            text: fit.text,
            fontSize: fit.fontSize,
            maximumWidth: textMaximumWidth
        )
        let overlaySize = CGSize(
            width: min(
                maximumWidth,
                max(minimumWidth, measuredTextSize.width + (padding * 2))
            ),
            height: min(
                maximumHeight,
                max(
                    sourceFrame.height,
                    measuredTextSize.height + (padding * 2)
                )
            )
        )
        let origin = clampedOrigin(
            preferred: sourceFrame.origin,
            size: overlaySize,
            canvasRect: canvasRect
        )
        let outerFrame = CGRect(origin: origin, size: overlaySize)

        return TranslationOverlayLayout(
            text: fit.text,
            outerFrame: outerFrame,
            textFrame: outerFrame.insetBy(dx: padding, dy: padding),
            fontSize: fit.fontSize,
            cornerRadius: min(10, max(5, overlaySize.height * 0.18)),
            lineBreakMode: fit.isEllipsized ? .byTruncatingTail : .byWordWrapping,
            isEllipsized: fit.isEllipsized
        )
    }

    private func fittedText(
        text: String,
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
                maximumWidth: maximumWidth
            )

            if size.height <= maximumHeight {
                return QuickLookTextFit(
                    text: text,
                    fontSize: fontSize,
                    isEllipsized: false
                )
            }

            fontSize -= 1
        }

        let ellipsizedText = ellipsized(
            text,
            fontSize: minimumFontSize,
            maximumWidth: maximumWidth,
            maximumHeight: maximumHeight
        )

        return QuickLookTextFit(
            text: ellipsizedText,
            fontSize: minimumFontSize,
            isEllipsized: ellipsizedText != text
        )
    }

    private func measuredSize(
        text: String,
        fontSize: CGFloat,
        maximumWidth: CGFloat
    ) -> CGSize {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

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
                    weight: .semibold
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
        priority: QuickLookOverlayPriority
    ) -> QuickLookOverlayDisplayText {
        let sourceFrame = block.sourceFrame.standardized
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

        let originalText = normalizedDisplayText(block.displayText)
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

    private func overlayPadding(
        for sourceFrame: CGRect,
        priority: QuickLookOverlayPriority
    ) -> CGFloat {
        let scale: CGFloat = priority == .high ? 0.24 : 0.20
        return max(5, min(priority == .high ? 11 : 9, sourceFrame.height * scale))
    }

    private func minimumOverlayWidth(
        sourceFrame: CGRect,
        priority: QuickLookOverlayPriority
    ) -> CGFloat {
        switch priority {
        case .high:
            return sourceFrame.height < 30 ? 68 : 82
        case .medium:
            return sourceFrame.height < 30 ? 62 : 76
        case .low:
            return 56
        }
    }

    private func maximumOverlayWidth(
        sourceFrame: CGRect,
        priority: QuickLookOverlayPriority,
        canvasRect: CGRect
    ) -> CGFloat {
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
            minimumOverlayWidth(sourceFrame: sourceFrame, priority: priority),
            min(
                canvasRect.width * canvasMultiplier,
                sourceFrame.width * sourceMultiplier + 20
            )
        )
    }

    private func maximumOverlayHeight(
        sourceFrame: CGRect,
        priority: QuickLookOverlayPriority,
        canvasRect: CGRect
    ) -> CGFloat {
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

    private func initialFontSize(
        sourceFrame: CGRect,
        priority: QuickLookOverlayPriority
    ) -> CGFloat {
        let scale: CGFloat = priority == .high ? 0.60 : 0.54
        let maximum: CGFloat = priority == .high ? 28 : 24
        return max(12, min(maximum, sourceFrame.height * scale))
    }

    private func minimumFontSize(
        for priority: QuickLookOverlayPriority
    ) -> CGFloat {
        priority == .low ? 10 : 11
    }

    private func ellipsized(
        _ text: String,
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
                maximumWidth: maximumWidth
            )

            if size.height <= maximumHeight {
                return ellipsizedCandidate
            }

            candidate = String(candidate.dropLast())
        }

        return "..."
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
}

private struct QuickLookOverlayRenderPlan {
    let candidateCount: Int
    let items: [QuickLookOverlayRenderItem]
    let skippedLowPriorityClutter: Int
    let shortenedLabelCount: Int
    let ellipsizedLabelCount: Int
    let compactMixedValueLabelCount: Int
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
