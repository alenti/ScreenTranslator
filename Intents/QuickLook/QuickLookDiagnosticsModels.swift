import CoreGraphics
import Foundation

struct QuickLookDiagnosticsSnapshot: Equatable {
    let summary: QuickLookDiagnosticsSummary
    let blocks: [QuickLookDiagnosticsBlock]
}

struct QuickLookDiagnosticsSummary: Equatable {
    let totalOCRBlocks: Int
    let cjkBlocks: Int
    let matchedBlocks: Int
    let missedBlocks: Int
    let skippedBlocks: Int
    let skippedUnknownCJK: Int
    let phraseOverrideHits: Int
    let exactHits: Int
    let segmentHits: Int
    let singleAllowlistHits: Int
    let summaryHits: Int
    let longUntranslated: Int
    let renderedBlocks: Int
}

struct QuickLookDiagnosticsBlock: Equatable {
    let originalText: String
    let normalizedText: String
    let sourceFrame: CGRect
    let confidence: Double
    let dictionaryDiagnostics: QuickLookDictionaryDiagnostics
    let status: QuickLookDiagnosticsBlockStatus
    let skipReason: QuickLookDiagnosticsSkipReason?
    let rendersInNormalOutput: Bool
}

enum QuickLookDiagnosticsBlockStatus: Equatable {
    case matched
    case missed
    case skipped
    case longUntranslated
}

enum QuickLookDiagnosticsSkipReason: String, Equatable {
    case emptyText = "empty"
    case nonSubstantive = "punctuation"
    case lowConfidence = "low confidence"
    case invalidFrame = "invalid frame"
    case normalRenderFilter = "size/noise filter"
}

struct QuickLookDiagnosticsAnalyzer {
    private let cjkDetector: QuickLookCJKTextDetector
    private let translationProvider: QuickLookEnglishTranslationProvider
    private let minimumConfidence: Double

    init(
        cjkDetector: QuickLookCJKTextDetector = QuickLookCJKTextDetector(),
        translationProvider: QuickLookEnglishTranslationProvider = QuickLookEnglishTranslationProvider(),
        minimumConfidence: Double = 0.20
    ) {
        self.cjkDetector = cjkDetector
        self.translationProvider = translationProvider
        self.minimumConfidence = minimumConfidence
    }

    func analyze(
        observations: [OCRTextObservation],
        canvasSize: CGSize
    ) -> QuickLookDiagnosticsSnapshot {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        var cjkBlockCount = 0
        var blocks: [QuickLookDiagnosticsBlock] = []

        for observation in observations {
            let dictionaryDiagnostics = translationProvider.diagnostics(
                for: observation.originalText
            )
            let normalizedText = dictionaryDiagnostics.normalizedText

            guard cjkDetector.containsCJK(in: normalizedText) else {
                continue
            }

            cjkBlockCount += 1

            let clippedFrame = observation.boundingBox
                .standardized
                .intersection(canvasRect)
            let classification = classify(
                normalizedText: normalizedText,
                frame: clippedFrame,
                confidence: observation.confidence,
                dictionaryDiagnostics: dictionaryDiagnostics,
                canvasSize: canvasSize
            )

            blocks.append(
                QuickLookDiagnosticsBlock(
                    originalText: observation.originalText,
                    normalizedText: normalizedText,
                    sourceFrame: clippedFrame,
                    confidence: observation.confidence,
                    dictionaryDiagnostics: dictionaryDiagnostics,
                    status: classification.status,
                    skipReason: classification.skipReason,
                    rendersInNormalOutput: classification.rendersInNormalOutput
                )
            )
        }

        let matchedBlocks = blocks.filter { $0.status == .matched }.count
        let missedBlocks = blocks.filter { $0.status == .missed }.count
        let skippedBlocks = blocks.filter { $0.status == .skipped }.count
        let longUntranslated = blocks.filter {
            $0.status == .longUntranslated
        }.count
        let phraseOverrideHits = blocks.filter {
            $0.dictionaryDiagnostics.translation?.matchKind == .phraseOverride
        }.count
        let exactHits = blocks.filter {
            $0.dictionaryDiagnostics.translation?.matchKind == .exact
        }.count
        let segmentHits = blocks.filter {
            $0.dictionaryDiagnostics.translation?.matchKind == .segment
        }.count
        let singleAllowlistHits = blocks.filter {
            $0.dictionaryDiagnostics.translation?.matchKind == .singleAllowlist
        }.count
        let summaryHits = blocks.filter {
            $0.dictionaryDiagnostics.translation?.matchKind == .summary
        }.count
        let renderedBlocks = blocks.filter(\.rendersInNormalOutput).count

        return QuickLookDiagnosticsSnapshot(
            summary: QuickLookDiagnosticsSummary(
                totalOCRBlocks: observations.count,
                cjkBlocks: cjkBlockCount,
                matchedBlocks: matchedBlocks,
                missedBlocks: missedBlocks,
                skippedBlocks: skippedBlocks,
                skippedUnknownCJK: missedBlocks,
                phraseOverrideHits: phraseOverrideHits,
                exactHits: exactHits,
                segmentHits: segmentHits,
                singleAllowlistHits: singleAllowlistHits,
                summaryHits: summaryHits,
                longUntranslated: longUntranslated,
                renderedBlocks: renderedBlocks
            ),
            blocks: blocks
        )
    }

    private func classify(
        normalizedText: String,
        frame: CGRect,
        confidence: Double,
        dictionaryDiagnostics: QuickLookDictionaryDiagnostics,
        canvasSize: CGSize
    ) -> QuickLookDiagnosticsClassification {
        guard normalizedText.isEmpty == false else {
            return .skipped(.emptyText)
        }

        guard containsSubstantiveText(normalizedText) else {
            return .skipped(.nonSubstantive)
        }

        guard frame.isNull == false && frame.isEmpty == false else {
            return .skipped(.invalidFrame)
        }

        guard confidence >= minimumConfidence else {
            return .skipped(.lowConfidence)
        }

        guard let translation = dictionaryDiagnostics.translation else {
            if dictionaryDiagnostics.unresolvedReason == .longUntranslated {
                return .longUntranslated
            }

            return .missed
        }

        guard shouldRender(
            frame: frame,
            confidence: confidence,
            translation: translation,
            canvasSize: canvasSize
        ) else {
            return .skipped(.normalRenderFilter)
        }

        return .matched
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

        if translation.matchKind != .exact,
           translation.matchKind != .phraseOverride,
           translation.matchKind != .summary,
           translation.matchedSource.count <= 2,
           translation.isImportant == false,
           confidence < 0.55 {
            return false
        }

        if translation.matchKind == .singleAllowlist {
            let minimumWidth = max(18, canvasSize.width * 0.012)
            let minimumHeight = max(14, canvasSize.height * 0.006)
            let reasonablyLarge = frame.width >= minimumWidth
                && frame.height >= minimumHeight

            return confidence >= 0.55 || reasonablyLarge
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

private struct QuickLookDiagnosticsClassification: Equatable {
    let status: QuickLookDiagnosticsBlockStatus
    let skipReason: QuickLookDiagnosticsSkipReason?
    let rendersInNormalOutput: Bool

    static var matched: QuickLookDiagnosticsClassification {
        QuickLookDiagnosticsClassification(
            status: .matched,
            skipReason: nil,
            rendersInNormalOutput: true
        )
    }

    static var missed: QuickLookDiagnosticsClassification {
        QuickLookDiagnosticsClassification(
            status: .missed,
            skipReason: nil,
            rendersInNormalOutput: false
        )
    }

    static var longUntranslated: QuickLookDiagnosticsClassification {
        QuickLookDiagnosticsClassification(
            status: .longUntranslated,
            skipReason: nil,
            rendersInNormalOutput: false
        )
    }

    static func skipped(
        _ reason: QuickLookDiagnosticsSkipReason
    ) -> QuickLookDiagnosticsClassification {
        QuickLookDiagnosticsClassification(
            status: .skipped,
            skipReason: reason,
            rendersInNormalOutput: false
        )
    }
}
