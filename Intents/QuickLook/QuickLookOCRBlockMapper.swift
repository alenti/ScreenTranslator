import CoreGraphics
import Foundation
import OSLog

struct QuickLookOCRBlock: Equatable {
    let sourceText: String
    let sourceFrame: CGRect
    let confidence: Double
    let displayText: String
    let matchedSource: String
    let matchKind: QuickLookDictionaryMatchKind
    let isImportant: Bool
    let hasPreservedValue: Bool
}

struct QuickLookOCRBlockMapper {
    private let cjkDetector: QuickLookCJKTextDetector
    private let translationProvider: QuickLookEnglishTranslationProvider
    private let minimumConfidence: Double
    private let logger = Logger(
        subsystem: "AlenShamatov.ScreenTranslator",
        category: "QuickLookMode"
    )

    init(
        cjkDetector: QuickLookCJKTextDetector = QuickLookCJKTextDetector(),
        translationProvider: QuickLookEnglishTranslationProvider = QuickLookEnglishTranslationProvider(),
        minimumConfidence: Double = 0.20
    ) {
        self.cjkDetector = cjkDetector
        self.translationProvider = translationProvider
        self.minimumConfidence = minimumConfidence
    }

    func makeBlocks(
        from observations: [OCRTextObservation],
        canvasSize: CGSize
    ) -> [QuickLookOCRBlock] {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        var cjkBlockCount = 0
        var dictionaryHitCount = 0
        var phraseOverrideHitCount = 0
        var exactHitCount = 0
        var segmentHitCount = 0
        var singleAllowlistHitCount = 0
        var summaryHitCount = 0
        var skippedUnknownCJKCount = 0
        var longUntranslatedCount = 0
        var renderedBlocks: [QuickLookOCRBlock] = []
        let lookupStart = Date()

        for observation in observations {
            let diagnostics = translationProvider.diagnostics(
                for: observation.originalText
            )
            let normalizedText = diagnostics.normalizedText
            let clippedFrame = observation.boundingBox
                .standardized
                .intersection(canvasRect)

            if cjkDetector.containsCJK(in: normalizedText) {
                cjkBlockCount += 1
            }

            guard shouldKeepCandidate(
                text: normalizedText,
                frame: clippedFrame,
                confidence: observation.confidence
            ) else {
                continue
            }

            guard let translation = diagnostics.translation else {
                if diagnostics.unresolvedReason == .longUntranslated {
                    longUntranslatedCount += 1
                    continue
                }

                skippedUnknownCJKCount += 1
                continue
            }

            dictionaryHitCount += 1
            switch translation.matchKind {
            case .phraseOverride:
                phraseOverrideHitCount += 1
            case .exact:
                exactHitCount += 1
            case .segment:
                segmentHitCount += 1
            case .singleAllowlist:
                singleAllowlistHitCount += 1
            case .summary:
                summaryHitCount += 1
            case .contained:
                segmentHitCount += 1
            case .mixedPhrase:
                segmentHitCount += 1
            case .amountUnit:
                segmentHitCount += 1
            }

            guard shouldRender(
                frame: clippedFrame,
                confidence: observation.confidence,
                translation: translation,
                canvasSize: canvasSize
            ) else {
                continue
            }

            renderedBlocks.append(
                QuickLookOCRBlock(
                    sourceText: normalizedText,
                    sourceFrame: clippedFrame,
                    confidence: observation.confidence,
                    displayText: translation.displayText,
                    matchedSource: translation.matchedSource,
                    matchKind: translation.matchKind,
                    isImportant: translation.isImportant,
                    hasPreservedValue: translation.hasPreservedValue
                )
            )
        }

        logger.debug(
            """
            Quick Look OCR blocks total=\(observations.count), \
            cjk=\(cjkBlockCount), \
            dictionaryHits=\(dictionaryHitCount), \
            phraseOverrideHits=\(phraseOverrideHitCount), \
            exactHits=\(exactHitCount), \
            segmentHits=\(segmentHitCount), \
            singleAllowlistHits=\(singleAllowlistHitCount), \
            summaryHits=\(summaryHitCount), \
            skippedUnknownCJK=\(skippedUnknownCJKCount), \
            longUntranslated=\(longUntranslatedCount), \
            rendered=\(renderedBlocks.count), \
            lookupDuration=\(Date().timeIntervalSince(lookupStart), format: .fixed(precision: 3))s
            """
        )

        return renderedBlocks
    }

    private func shouldKeepCandidate(
        text: String,
        frame: CGRect,
        confidence: Double
    ) -> Bool {
        guard text.isEmpty == false else {
            return false
        }

        guard cjkDetector.containsCJK(in: text) else {
            return false
        }

        guard containsSubstantiveText(text) else {
            return false
        }

        guard confidence >= minimumConfidence else {
            return false
        }

        return frame.isNull == false && frame.isEmpty == false
    }

    private func shouldRender(
        frame: CGRect,
        confidence: Double,
        translation: QuickLookDictionaryTranslation,
        canvasSize: CGSize
    ) -> Bool {
        guard translation.displayText.isEmpty == false else {
            return false
        }

        if translation.matchKind == .singleAllowlist {
            let minimumWidth = max(18, canvasSize.width * 0.012)
            let minimumHeight = max(14, canvasSize.height * 0.006)
            let reasonablyLarge = frame.width >= minimumWidth
                && frame.height >= minimumHeight

            return confidence >= 0.55 || reasonablyLarge
        }

        if translation.matchKind != .exact,
           translation.matchKind != .phraseOverride,
           translation.matchKind != .summary,
           translation.matchedSource.count <= 2,
           translation.isImportant == false,
           confidence < 0.55 {
            return false
        }

        if translation.isImportant {
            let minimumWidth = max(7, canvasSize.width * 0.006)
            let minimumHeight = max(6, canvasSize.height * 0.003)
            let minimumArea = max(
                36,
                canvasSize.width * canvasSize.height * 0.000012
            )

            return frame.width >= minimumWidth
                && frame.height >= minimumHeight
                && (frame.width * frame.height) >= minimumArea
        } else {
            let minimumWidth = max(16, canvasSize.width * 0.016)
            let minimumHeight = max(10, canvasSize.height * 0.006)
            let minimumArea = max(
                120,
                canvasSize.width * canvasSize.height * 0.00004
            )

            return frame.width >= minimumWidth
                && frame.height >= minimumHeight
                && (frame.width * frame.height) >= minimumArea
        }
    }

    private func containsSubstantiveText(_ text: String) -> Bool {
        let ignoredScalars = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(.symbols)

        return text.unicodeScalars.contains { scalar in
            ignoredScalars.contains(scalar) == false
        }
    }
}
