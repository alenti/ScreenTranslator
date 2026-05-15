import CoreGraphics
import Foundation
import OSLog

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
    let mtAccepted: Int
    let suspiciousRejected: Int
    let localMTHits: Int
    let cedictHits: Int
    let fallbackHits: Int
    let mtFailures: Int
    let phraseOverrideHits: Int
    let exactHits: Int
    let segmentHits: Int
    let singleAllowlistHits: Int
    let summaryHits: Int
    let longUntranslated: Int
    let renderedBlocks: Int
    let groupedBlocks: Int
    let localMTTranslatedGroups: Int
    let fallbackGroups: Int
    let renderedGroups: Int
    let routeMT: Int
    let routeDomain: Int
    let routeCEDICT: Int
    let routeSkip: Int
    let lowQualityFallbackRejected: Int
    let renderedReplacementCards: Int
    let renderedPills: Int
}

struct QuickLookDiagnosticsBlock: Equatable {
    let groupID: String?
    let originalText: String
    let normalizedText: String
    let sourceFrame: CGRect
    let childFrames: [CGRect]
    let confidence: Double
    let dictionaryDiagnostics: QuickLookDictionaryDiagnostics
    let status: QuickLookDiagnosticsBlockStatus
    let skipReason: QuickLookDiagnosticsSkipReason?
    let rendersInNormalOutput: Bool
    let blockType: QuickLookTextGroupBlockType
    let lineCount: Int
    let route: QuickLookTranslationRoute
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
    case lowQualityFallbackRejected = "LOW_QUALITY_FALLBACK_REJECTED"
    case suspiciousMTRejected = "SUSPICIOUS_REJECTED"
}

struct QuickLookDiagnosticsAnalyzer {
    private let cjkDetector: QuickLookCJKTextDetector
    private let translationProvider: QuickLookEnglishTranslationProvider
    private let mtBlockPreparer: QuickLookMTBlockPreparer
    private let mtProvider: QuickLookLocalMTTranslationProvider
    private let minimumConfidence: Double
    private let logger = Logger(
        subsystem: "AlenShamatov.ScreenTranslator",
        category: "QuickLookLocalMT"
    )

    init(
        cjkDetector: QuickLookCJKTextDetector = QuickLookCJKTextDetector(),
        translationProvider: QuickLookEnglishTranslationProvider = QuickLookEnglishTranslationProvider(),
        mtBlockPreparer: QuickLookMTBlockPreparer = QuickLookMTBlockPreparer(),
        mtProvider: QuickLookLocalMTTranslationProvider = QuickLookLocalMTTranslationProvider(),
        minimumConfidence: Double = 0.20
    ) {
        self.cjkDetector = cjkDetector
        self.translationProvider = translationProvider
        self.mtBlockPreparer = mtBlockPreparer
        self.mtProvider = mtProvider
        self.minimumConfidence = minimumConfidence
    }

    func analyze(
        observations: [OCRTextObservation],
        canvasSize: CGSize
    ) async -> QuickLookDiagnosticsSnapshot {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let mtPreparation = mtBlockPreparer.prepare(
            observations: observations,
            canvasSize: canvasSize
        )

        logger.info(
            """
            Quick Look Local MT diagnostics config enabled=\
            \(QuickLookLocalMTConfig.isEnabled, privacy: .public), baseURL=\
            \(QuickLookLocalMTConfig.baseURLString, privacy: .public), \
            cjkOCRBlocks=\(mtPreparation.cjkBlockCount, privacy: .public), \
            preparedMTBlocks=\(mtPreparation.blocks.count, privacy: .public), \
            routeMT=\(routeCount(.localMT, in: mtPreparation), privacy: .public), \
            routeDomain=\
            \(routeCount(.domainDictionary, in: mtPreparation), privacy: .public), \
            routeCEDICT=\(routeCount(.cedict, in: mtPreparation), privacy: .public), \
            routeSkip=\(routeCount(.skip, in: mtPreparation), privacy: .public)
            """
        )

        if mtPreparation.cjkBlockCount > 0,
           mtPreparation.blocks.isEmpty,
           routeCount(.localMT, in: mtPreparation) > 0 {
            logger.warning(
                """
                Quick Look Local MT diagnostics prepared zero request blocks \
                despite CJK OCR blocks. rejectedEmpty=\
                \(mtPreparation.rejectedEmptyText, privacy: .public), \
                rejectedNonCJK=\(mtPreparation.rejectedNonCJK, privacy: .public), \
                rejectedPunctuation=\
                \(mtPreparation.rejectedNonSubstantive, privacy: .public), \
                rejectedLowConfidence=\
                \(mtPreparation.rejectedLowConfidence, privacy: .public), \
                rejectedInvalidFrame=\
                \(mtPreparation.rejectedInvalidFrame, privacy: .public), \
                capped=\(mtPreparation.cappedAtMaximum, privacy: .public)
                """
            )
        }

        let mtOutcome = mtPreparation.blocks.isEmpty
            ? QuickLookLocalMTTranslationOutcome.disabled
            : await mtProvider.translate(preparedBlocks: mtPreparation.blocks)
        let cjkBlockCount = mtPreparation.cjkBlockCount
        var blocks: [QuickLookDiagnosticsBlock] = []
        var coveredObservationIndices = Set<Int>()

        for preparedBlock in mtPreparation.blocks {
            guard let localMTTranslation = mtOutcome.translationsByID[preparedBlock.id] else {
                let normalizedText = translationProvider.normalizedSource(
                    preparedBlock.text
                )
                let dictionaryDiagnostics = translationProvider.diagnostics(
                    for: preparedBlock.text
                )
                let classification: QuickLookDiagnosticsClassification

                if let fallbackTranslation = dictionaryDiagnostics.translation,
                   shouldRejectLowQualityFallback(
                    sourceText: preparedBlock.text,
                    lineCount: preparedBlock.lineCount,
                    blockType: preparedBlock.blockType,
                    translation: fallbackTranslation
                   ) {
                    classification = .skipped(.lowQualityFallbackRejected)
                } else {
                    classification = classify(
                        normalizedText: normalizedText,
                        frame: preparedBlock.sourceFrame,
                        confidence: preparedBlock.confidence,
                        dictionaryDiagnostics: dictionaryDiagnostics,
                        canvasSize: canvasSize
                    )
                }

                blocks.append(
                    QuickLookDiagnosticsBlock(
                        groupID: preparedBlock.id,
                        originalText: preparedBlock.text,
                        normalizedText: normalizedText,
                        sourceFrame: preparedBlock.sourceFrame,
                        childFrames: preparedBlock.childFrames,
                        confidence: preparedBlock.confidence,
                        dictionaryDiagnostics: dictionaryDiagnostics,
                        status: classification.status,
                        skipReason: classification.skipReason,
                        rendersInNormalOutput: classification.rendersInNormalOutput,
                        blockType: preparedBlock.blockType,
                        lineCount: preparedBlock.lineCount,
                        route: .localMT
                    )
                )
                coveredObservationIndices.formUnion(preparedBlock.observationIndices)
                continue
            }

            let normalizedText = translationProvider.normalizedSource(
                preparedBlock.text
            )
            let dictionaryDiagnostics = QuickLookDictionaryDiagnostics(
                originalText: preparedBlock.text,
                normalizedText: normalizedText,
                translation: localMTTranslation,
                matchType: .localMT,
                unresolvedReason: nil
            )
            let classification = classify(
                normalizedText: normalizedText,
                frame: preparedBlock.sourceFrame,
                confidence: preparedBlock.confidence,
                dictionaryDiagnostics: dictionaryDiagnostics,
                canvasSize: canvasSize
            )
            let finalClassification = suspiciousLocalMTRejectionReason(
                preparedBlock: preparedBlock,
                translation: localMTTranslation
            ) == nil
                ? classification
                : .skipped(.suspiciousMTRejected)

            blocks.append(
                QuickLookDiagnosticsBlock(
                    groupID: preparedBlock.id,
                    originalText: preparedBlock.text,
                    normalizedText: normalizedText,
                    sourceFrame: preparedBlock.sourceFrame,
                    childFrames: preparedBlock.childFrames,
                    confidence: preparedBlock.confidence,
                    dictionaryDiagnostics: dictionaryDiagnostics,
                    status: finalClassification.status,
                    skipReason: finalClassification.skipReason,
                    rendersInNormalOutput: finalClassification.rendersInNormalOutput,
                    blockType: preparedBlock.blockType,
                    lineCount: preparedBlock.lineCount,
                    route: .localMT
                )
            )
            coveredObservationIndices.formUnion(preparedBlock.observationIndices)
        }

        for routeDecision in mtPreparation.routeDecisions {
            guard routeDecision.route != .localMT else {
                continue
            }

            guard coveredObservationIndices
                .isDisjoint(with: routeDecision.observationIndices) else {
                continue
            }

            coveredObservationIndices.formUnion(routeDecision.observationIndices)

            let normalizedText = translationProvider.normalizedSource(
                routeDecision.text
            )
            let dictionaryDiagnostics = routeDecision.route == .skip
                ? QuickLookDictionaryDiagnostics(
                    originalText: routeDecision.text,
                    normalizedText: normalizedText,
                    translation: nil,
                    matchType: .none,
                    unresolvedReason: nil
                )
                : translationProvider.diagnostics(for: routeDecision.text)
            let classification = routeDecision.route == .skip
                ? QuickLookDiagnosticsClassification.skipped(.normalRenderFilter)
                : classificationForFallback(
                    sourceText: routeDecision.text,
                    lineCount: routeDecision.lineCount,
                    blockType: routeDecision.blockType,
                    normalizedText: normalizedText,
                    frame: routeDecision.sourceFrame,
                    confidence: routeDecision.confidence,
                    dictionaryDiagnostics: dictionaryDiagnostics,
                    canvasSize: canvasSize
                )

            blocks.append(
                QuickLookDiagnosticsBlock(
                    groupID: routeDecision.id,
                    originalText: routeDecision.text,
                    normalizedText: normalizedText,
                    sourceFrame: routeDecision.sourceFrame,
                    childFrames: routeDecision.childFrames,
                    confidence: routeDecision.confidence,
                    dictionaryDiagnostics: dictionaryDiagnostics,
                    status: classification.status,
                    skipReason: classification.skipReason,
                    rendersInNormalOutput: classification.rendersInNormalOutput,
                    blockType: routeDecision.blockType,
                    lineCount: routeDecision.lineCount,
                    route: routeDecision.route
                )
            )
        }

        for (index, observation) in observations.enumerated() {
            guard coveredObservationIndices.contains(index) == false else {
                continue
            }

            let normalizedText = translationProvider.normalizedSource(
                observation.originalText
            )

            guard cjkDetector.containsCJK(in: normalizedText) else {
                continue
            }

            let dictionaryDiagnostics: QuickLookDictionaryDiagnostics
            dictionaryDiagnostics = translationProvider.diagnostics(
                for: observation.originalText
            )

            let clippedFrame = observation.boundingBox
                .standardized
                .intersection(canvasRect)
            let classification = classificationForFallback(
                sourceText: normalizedText,
                lineCount: 1,
                blockType: .uiLabel,
                normalizedText: normalizedText,
                frame: clippedFrame,
                confidence: observation.confidence,
                dictionaryDiagnostics: dictionaryDiagnostics,
                canvasSize: canvasSize
            )

            blocks.append(
                QuickLookDiagnosticsBlock(
                    groupID: nil,
                    originalText: observation.originalText,
                    normalizedText: normalizedText,
                    sourceFrame: clippedFrame,
                    childFrames: [],
                    confidence: observation.confidence,
                    dictionaryDiagnostics: dictionaryDiagnostics,
                    status: classification.status,
                    skipReason: classification.skipReason,
                    rendersInNormalOutput: classification.rendersInNormalOutput,
                    blockType: .uiLabel,
                    lineCount: 1,
                    route: routeForDictionaryDiagnostics(dictionaryDiagnostics)
                )
            )
        }

        return QuickLookDiagnosticsSnapshot(
            summary: summary(
                observations: observations,
                cjkBlockCount: cjkBlockCount,
                blocks: blocks,
                mtOutcome: mtOutcome,
                mtPreparation: mtPreparation
            ),
            blocks: blocks
        )
    }

    private func summary(
        observations: [OCRTextObservation],
        cjkBlockCount: Int,
        blocks: [QuickLookDiagnosticsBlock],
        mtOutcome: QuickLookLocalMTTranslationOutcome,
        mtPreparation: QuickLookMTBlockPreparation
    ) -> QuickLookDiagnosticsSummary {
        let matchedBlocks = blocks.filter { $0.status == .matched }.count
        let missedBlocks = blocks.filter { $0.status == .missed }.count
        let skippedBlocks = blocks.filter { $0.status == .skipped }.count
        let longUntranslated = blocks.filter {
            $0.status == .longUntranslated
        }.count
        let localMTHits = blocks.filter {
            $0.dictionaryDiagnostics.translation?.matchKind == .localMT
                && $0.skipReason != .suspiciousMTRejected
        }.count
        let suspiciousRejected = blocks.filter {
            $0.skipReason == .suspiciousMTRejected
        }.count
        let mtAccepted = localMTHits
        let cedictHits = blocks.filter {
            guard let matchKind = $0.dictionaryDiagnostics.translation?.matchKind else {
                return false
            }

            return matchKind != .localMT
        }.count
        let fallbackHits = mtOutcome.attempted ? cedictHits : 0
        let phraseOverrideHits = blocks.filter {
            $0.dictionaryDiagnostics.translation?.matchKind == .phraseOverride
        }.count
        let exactHits = blocks.filter {
            $0.dictionaryDiagnostics.translation?.matchKind == .exact
        }.count
        let segmentHits = blocks.filter {
            switch $0.dictionaryDiagnostics.translation?.matchKind {
            case .segment, .contained, .mixedPhrase, .amountUnit:
                return true
            default:
                return false
            }
        }.count
        let singleAllowlistHits = blocks.filter {
            $0.dictionaryDiagnostics.translation?.matchKind == .singleAllowlist
        }.count
        let summaryHits = blocks.filter {
            $0.dictionaryDiagnostics.translation?.matchKind == .summary
        }.count
        let renderedBlocks = blocks.filter(\.rendersInNormalOutput).count
        let groupedBlocks = mtPreparation.groupedBlockCount
        let localMTTranslatedGroups = blocks.filter {
            $0.groupID != nil
                && $0.dictionaryDiagnostics.translation?.matchKind == .localMT
        }.count
        let fallbackGroups = mtOutcome.attempted ? cedictHits : 0
        let renderedGroups = blocks.filter {
            $0.rendersInNormalOutput && $0.lineCount > 1
        }.count
        let mtFailureCount = mtOutcome.failed ? 1 : 0
        let routeMT = routeCount(.localMT, in: mtPreparation)
        let routeDomain = routeCount(.domainDictionary, in: mtPreparation)
        let routeCEDICT = routeCount(.cedict, in: mtPreparation)
        let routeSkip = routeCount(.skip, in: mtPreparation)
        let lowQualityFallbackRejected = blocks.filter {
            $0.skipReason == .lowQualityFallbackRejected
        }.count
        let renderedReplacementCards = blocks.filter {
            $0.rendersInNormalOutput
                && $0.dictionaryDiagnostics.translation?.matchKind == .localMT
                && ($0.lineCount >= 2
                    || $0.normalizedText.count >= 20
                    || $0.blockType == .chatBubble
                    || $0.blockType == .paragraph
                    || $0.blockType == .addressBlock)
        }.count
        let renderedPills = blocks.filter {
            $0.rendersInNormalOutput
                && $0.dictionaryDiagnostics.translation?.matchKind != .localMT
        }.count

        return QuickLookDiagnosticsSummary(
            totalOCRBlocks: observations.count,
            cjkBlocks: cjkBlockCount,
            matchedBlocks: matchedBlocks,
            missedBlocks: missedBlocks,
            skippedBlocks: skippedBlocks,
            skippedUnknownCJK: missedBlocks,
            mtAccepted: mtAccepted,
            suspiciousRejected: suspiciousRejected,
            localMTHits: localMTHits,
            cedictHits: cedictHits,
            fallbackHits: fallbackHits,
            mtFailures: mtFailureCount,
            phraseOverrideHits: phraseOverrideHits,
            exactHits: exactHits,
            segmentHits: segmentHits,
            singleAllowlistHits: singleAllowlistHits,
            summaryHits: summaryHits,
            longUntranslated: longUntranslated,
            renderedBlocks: renderedBlocks,
            groupedBlocks: groupedBlocks,
            localMTTranslatedGroups: localMTTranslatedGroups,
            fallbackGroups: fallbackGroups,
            renderedGroups: renderedGroups,
            routeMT: routeMT,
            routeDomain: routeDomain,
            routeCEDICT: routeCEDICT,
            routeSkip: routeSkip,
            lowQualityFallbackRejected: lowQualityFallbackRejected,
            renderedReplacementCards: renderedReplacementCards,
            renderedPills: renderedPills
        )
    }

    private func routeCount(
        _ route: QuickLookTranslationRoute,
        in preparation: QuickLookMTBlockPreparation
    ) -> Int {
        preparation.routeDecisions.filter { $0.route == route }.count
    }

    private func routeForDictionaryDiagnostics(
        _ diagnostics: QuickLookDictionaryDiagnostics
    ) -> QuickLookTranslationRoute {
        guard let translation = diagnostics.translation else {
            return .skip
        }

        if translation.sourceKind == "runtime_override"
            || translation.sourceKind == "app_phrase_override"
            || translation.matchKind == .phraseOverride {
            return .domainDictionary
        }

        return .cedict
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

    private func classificationForFallback(
        sourceText: String,
        lineCount: Int,
        blockType: QuickLookTextGroupBlockType,
        normalizedText: String,
        frame: CGRect,
        confidence: Double,
        dictionaryDiagnostics: QuickLookDictionaryDiagnostics,
        canvasSize: CGSize
    ) -> QuickLookDiagnosticsClassification {
        if let translation = dictionaryDiagnostics.translation,
           shouldRejectLowQualityFallback(
            sourceText: sourceText,
            lineCount: lineCount,
            blockType: blockType,
            translation: translation
           ) {
            return .skipped(.lowQualityFallbackRejected)
        }

        return classify(
            normalizedText: normalizedText,
            frame: frame,
            confidence: confidence,
            dictionaryDiagnostics: dictionaryDiagnostics,
            canvasSize: canvasSize
        )
    }

    private func shouldRejectLowQualityFallback(
        sourceText: String,
        lineCount: Int,
        blockType: QuickLookTextGroupBlockType,
        translation: QuickLookDictionaryTranslation
    ) -> Bool {
        guard translation.matchKind != .localMT else {
            return false
        }

        let compactSource = sourceText
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        let isSentenceLike = compactSource.count >= 12
            && (lineCount >= 2
                || containsSentencePunctuation(sourceText)
                || blockType == .chatBubble
                || blockType == .paragraph
                || blockType == .addressBlock
                || containsAny(compactSource, sentenceFallbackTriggerTokens))

        guard isSentenceLike else {
            return false
        }

        let displayText = translation.displayText
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let words = displayText
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }

        return displayText.count < 12 && words.count < 3
    }

    private func suspiciousLocalMTRejectionReason(
        preparedBlock: QuickLookMTPreparedBlock,
        translation: QuickLookDictionaryTranslation
    ) -> String? {
        let source = preparedBlock.text
            .components(separatedBy: .whitespacesAndNewlines)
            .joined()
        let displayText = translation.displayText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if shouldTrustLocalMTSentence(
            source: source,
            preparedBlock: preparedBlock,
            displayText: displayText
        ) {
            return nil
        }

        if source.count <= 8,
           suspiciousShortLabelSources.contains(where: { source.contains($0) }) {
            return "shortDomainSource"
        }

        let matchedSuspiciousLabel = suspiciousLocalMTLabels.first { suspiciousLabel in
            displayText == suspiciousLabel
                || displayText.contains(suspiciousLabel)
        }

        return matchedSuspiciousLabel.map { "badShortLabelOutput:\($0)" }
    }

    private func shouldTrustLocalMTSentence(
        source: String,
        preparedBlock: QuickLookMTPreparedBlock,
        displayText: String
    ) -> Bool {
        guard preparedBlock.route == .localMT else {
            return false
        }

        let hasSentenceSource = containsSentencePunctuation(preparedBlock.text)
            || preparedBlock.blockType == .chatBubble
            || preparedBlock.blockType == .paragraph
            || preparedBlock.blockType == .addressBlock
            || preparedBlock.blockType == .unknown
            || containsAny(source, sentenceFallbackTriggerTokens)
        let words = displayText
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
        let looksLikeSentence = displayText.count > 8
            && (displayText.contains(".")
                || displayText.contains(",")
                || displayText.contains(" ")
                || words.count >= 3)

        return hasSentenceSource && looksLikeSentence
    }

    private func containsSentencePunctuation(_ text: String) -> Bool {
        text.contains { character in
            "。！？；，,!?;.".contains(character)
        }
    }

    private func containsAny(
        _ text: String,
        _ tokens: [String]
    ) -> Bool {
        tokens.contains { text.contains($0) }
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
           translation.matchKind != .localMT,
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

private let sentenceFallbackTriggerTokens = [
    "发货",
    "货物",
    "包装",
    "国际运输",
    "运输",
    "木架",
    "加固",
    "破损",
    "玻璃",
    "灯具",
    "确认",
    "补发",
    "退",
    "重新发",
    "外包装",
    "标注",
    "麻烦",
    "请您",
    "但是",
    "因为",
    "所以",
    "结果",
    "如果",
    "我现在",
    "我会",
    "之前"
]

private let suspiciousShortLabelSources = [
    "红包",
    "抢",
    "淘宝秒杀",
    "试用领取",
    "淘工厂",
    "优惠",
    "直播有好价"
]

private let suspiciousLocalMTLabels = [
    "red bag",
    "rob",
    "we're going to kill",
    "we are going to kill",
    "adjudication",
    "paddy factory",
    "preferences",
    "good price on the live air"
]
