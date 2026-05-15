import Foundation
import UIKit

struct QuickLookDiagnosticsRenderer {
    private let analyzer: QuickLookDiagnosticsAnalyzer

    init(
        analyzer: QuickLookDiagnosticsAnalyzer = QuickLookDiagnosticsAnalyzer()
    ) {
        self.analyzer = analyzer
    }

    func renderPNGData(
        for input: ScreenshotInput,
        observations: [OCRTextObservation]
    ) async throws -> Data {
        guard let sourceImage = UIImage(data: input.imageData) else {
            throw AppError.unsupportedImage
        }

        let canvasSize = input.size
        let snapshot = await analyzer.analyze(
            observations: observations,
            canvasSize: canvasSize
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(
            size: canvasSize,
            format: format
        )
        let pngData = renderer.pngData { _ in
            let canvasRect = CGRect(origin: .zero, size: canvasSize)
            sourceImage.draw(in: canvasRect)

            for block in snapshot.blocks {
                drawDiagnosticBlock(block, canvasRect: canvasRect)
            }

            drawSummaryBadge(
                summary: snapshot.summary,
                canvasRect: canvasRect
            )
        }

        guard pngData.isEmpty == false else {
            throw AppError.unsupportedImage
        }

        return pngData
    }

    private func drawDiagnosticBlock(
        _ block: QuickLookDiagnosticsBlock,
        canvasRect: CGRect
    ) {
        let frame = block.sourceFrame.standardized

        guard frame.isNull == false && frame.isEmpty == false else {
            return
        }

        let color = diagnosticColor(for: block.status)
        drawChildFrames(
            block.childFrames,
            canvasRect: canvasRect
        )

        let cornerRadius = min(8, max(3, min(frame.width, frame.height) * 0.08))
        let path = UIBezierPath(
            roundedRect: frame,
            cornerRadius: cornerRadius
        )

        color.withAlphaComponent(0.12).setFill()
        path.fill()
        color.withAlphaComponent(0.95).setStroke()
        path.lineWidth = max(2, canvasRect.width * 0.002)
        path.stroke()

        drawLabel(
            text: labelText(for: block),
            anchorFrame: frame,
            color: color,
            canvasRect: canvasRect
        )
    }

    private func drawSummaryBadge(
        summary: QuickLookDiagnosticsSummary,
        canvasRect: CGRect
    ) {
        let text = """
        OCR \(summary.totalOCRBlocks)  CJK \(summary.cjkBlocks)
        ROUTE_MT \(summary.routeMT)  ROUTE_DOMAIN \(summary.routeDomain)  ROUTE_CEDICT \(summary.routeCEDICT)  ROUTE_SKIP \(summary.routeSkip)
        MT_ACCEPTED \(summary.mtAccepted)  LOCAL_MT \(summary.localMTHits)  SUSPICIOUS_REJECTED \(summary.suspiciousRejected)  CEDICT \(summary.cedictHits)  FALLBACK \(summary.fallbackHits)  MT_FAIL \(summary.mtFailures)
        GROUPS \(summary.groupedBlocks)  LOCAL_MT_GROUP \(summary.localMTTranslatedGroups)  FALLBACK_GROUP \(summary.fallbackGroups)  RENDERED_GROUP \(summary.renderedGroups)
        LOCAL_MT_TEXT_REPLACEMENT \(summary.renderedReplacementCards)  PILL \(summary.renderedPills)  LOW_QUALITY_REJECT \(summary.lowQualityFallbackRejected)
        PHRASE \(summary.phraseOverrideHits)  EXACT \(summary.exactHits)  SEG \(summary.segmentHits)
        SINGLE \(summary.singleAllowlistHits)  SUMMARY \(summary.summaryHits)  LONG \(summary.longUntranslated)
        MATCH \(summary.matchedBlocks)  MISS \(summary.missedBlocks)  UNKNOWN \(summary.skippedUnknownCJK)  SKIP \(summary.skippedBlocks)  RENDER \(summary.renderedBlocks)
        """
        let fontSize = max(18, min(28, canvasRect.width * 0.018))
        let font = UIFont.monospacedSystemFont(
            ofSize: fontSize,
            weight: .semibold
        )
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        let maximumWidth = min(canvasRect.width - 24, canvasRect.width * 0.78)
        let textRect = NSString(string: text).boundingRect(
            with: CGSize(
                width: maximumWidth - 22,
                height: .greatestFiniteMagnitude
            ),
            options: [
                .usesLineFragmentOrigin,
                .usesFontLeading
            ],
            attributes: [
                .font: font,
                .paragraphStyle: paragraphStyle
            ],
            context: nil
        )
        let badgeRect = CGRect(
            x: 12,
            y: 12,
            width: min(maximumWidth, ceil(textRect.width) + 22),
            height: ceil(textRect.height) + 16
        )
        let badgePath = UIBezierPath(
            roundedRect: badgeRect,
            cornerRadius: min(12, badgeRect.height * 0.22)
        )

        UIColor.black.withAlphaComponent(0.72).setFill()
        badgePath.fill()

        NSString(string: text).draw(
            with: badgeRect.insetBy(dx: 11, dy: 8),
            options: [
                .usesLineFragmentOrigin,
                .usesFontLeading
            ],
            attributes: [
                .font: font,
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ],
            context: nil
        )
    }

    private func drawLabel(
        text: String,
        anchorFrame: CGRect,
        color: UIColor,
        canvasRect: CGRect
    ) {
        let fontSize = max(16, min(26, canvasRect.width * 0.016))
        let font = UIFont.monospacedSystemFont(
            ofSize: fontSize,
            weight: .semibold
        )
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byTruncatingTail
        let padding = max(5, fontSize * 0.28)
        let maximumWidth = min(canvasRect.width - 8, max(180, canvasRect.width * 0.66))
        let labelHeight = ceil(font.lineHeight) + (padding * 2)
        let measuredWidth = NSString(string: text).size(
            withAttributes: [
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
        ).width
        let labelWidth = min(maximumWidth, measuredWidth + (padding * 2))
        let preferredY = anchorFrame.minY - labelHeight - 3
        let y = preferredY >= canvasRect.minY + 4
            ? preferredY
            : min(anchorFrame.minY + 3, canvasRect.maxY - labelHeight - 4)
        let x = min(
            max(anchorFrame.minX, canvasRect.minX + 4),
            max(canvasRect.maxX - labelWidth - 4, canvasRect.minX + 4)
        )
        let labelRect = CGRect(
            x: x,
            y: max(y, canvasRect.minY + 4),
            width: labelWidth,
            height: labelHeight
        )
        let path = UIBezierPath(
            roundedRect: labelRect,
            cornerRadius: min(8, labelRect.height * 0.26)
        )

        color.withAlphaComponent(0.88).setFill()
        path.fill()

        NSString(string: text).draw(
            with: labelRect.insetBy(dx: padding, dy: padding),
            options: [
                .usesLineFragmentOrigin,
                .truncatesLastVisibleLine
            ],
            attributes: [
                .font: font,
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ],
            context: nil
        )
    }

    private func drawChildFrames(
        _ childFrames: [CGRect],
        canvasRect: CGRect
    ) {
        guard childFrames.count > 1 else {
            return
        }

        UIColor.systemBlue.withAlphaComponent(0.85).setStroke()

        for childFrame in childFrames {
            let frame = childFrame.standardized

            guard frame.isNull == false && frame.isEmpty == false else {
                continue
            }

            let path = UIBezierPath(
                roundedRect: frame,
                cornerRadius: min(5, max(2, frame.height * 0.08))
            )
            path.lineWidth = max(1, canvasRect.width * 0.0012)
            path.stroke()
        }
    }

    private func labelText(for block: QuickLookDiagnosticsBlock) -> String {
        switch block.status {
        case .matched:
            let translation = block.dictionaryDiagnostics.translation?.displayText ?? ""
            if block.dictionaryDiagnostics.matchType == .localMT,
               shouldLabelAsTextReplacement(block) {
                let groupID = block.groupID ?? "group"
                return clipped(
                    "\(block.route.rawValue) LOCAL_MT_TEXT_REPLACEMENT \(groupID) \(block.blockType.rawValue) L\(block.lineCount): \(translation)",
                    maxLength: 76
                )
            }

            if block.dictionaryDiagnostics.matchType == .localMT {
                return clipped(
                    "\(block.route.rawValue) LOCAL_MT: \(translation)",
                    maxLength: 58
                )
            }

            if block.route == .domainDictionary,
               block.originalText != block.normalizedText {
                return clipped(
                    "\(block.route.rawValue) NORMALIZED_DOMAIN_HIT \(block.dictionaryDiagnostics.matchType.rawValue): \(translation)",
                    maxLength: 70
                )
            }

            if block.blockType == .uiLabel {
                return clipped(
                    "\(block.route.rawValue) UNGROUPED_UI \(block.dictionaryDiagnostics.matchType.rawValue): \(translation)",
                    maxLength: 64
                )
            }

            return clipped(
                "\(block.route.rawValue) \(block.dictionaryDiagnostics.matchType.rawValue): \(translation)",
                maxLength: 58
            )
        case .missed:
            return clipped(
                "\(block.route.rawValue) MISS: \(preferredSourceText(for: block))",
                maxLength: 48
            )
        case .longUntranslated:
            return clipped(
                "\(block.route.rawValue) LONG_UNTRANSLATED: \(preferredSourceText(for: block))",
                maxLength: 58
            )
        case .skipped:
            let reason = block.skipReason?.rawValue ?? "skipped"

            if block.skipReason == .lowQualityFallbackRejected {
                return clipped(
                    "\(block.route.rawValue) LOW_QUALITY_FALLBACK_REJECTED: \(preferredSourceText(for: block))",
                    maxLength: 68
                )
            }

            if block.skipReason == .suspiciousMTRejected {
                return clipped(
                    "\(block.route.rawValue) SUSPICIOUS_REJECTED: \(preferredSourceText(for: block))",
                    maxLength: 68
                )
            }

            if let translation = block.dictionaryDiagnostics.translation {
                return clipped(
                    "\(block.route.rawValue) SKIP \(reason): \(translation.displayText)",
                    maxLength: 58
                )
            }

            return clipped(
                "\(block.route.rawValue) SKIP \(reason): \(preferredSourceText(for: block))",
                maxLength: 48
            )
        }
    }

    private func preferredSourceText(
        for block: QuickLookDiagnosticsBlock
    ) -> String {
        if block.normalizedText.isEmpty == false {
            return block.normalizedText
        }

        return block.originalText
    }

    private func shouldLabelAsTextReplacement(
        _ block: QuickLookDiagnosticsBlock
    ) -> Bool {
        block.lineCount > 1
            || block.normalizedText.count >= 20
            || block.blockType == .chatBubble
            || block.blockType == .paragraph
            || block.blockType == .addressBlock
    }

    private func clipped(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else {
            return text
        }

        return "\(text.prefix(maxLength))..."
    }

    private func diagnosticColor(
        for status: QuickLookDiagnosticsBlockStatus
    ) -> UIColor {
        switch status {
        case .matched:
            return .systemGreen
        case .missed:
            return .systemOrange
        case .skipped:
            return .systemRed
        case .longUntranslated:
            return .systemPurple
        }
    }
}
