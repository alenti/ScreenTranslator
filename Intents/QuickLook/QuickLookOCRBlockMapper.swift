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
    let lineCount: Int
    let blockType: QuickLookTextGroupBlockType
    let overlaySourceKind: QuickLookOverlaySourceKind
    let groupID: String?
}

enum QuickLookOverlaySourceKind: Equatable {
    case localMTGroup
    case localMTLine
    case cedict
    case single
    case debug
}

struct QuickLookOCRBlockMapper {
    private let cjkDetector: QuickLookCJKTextDetector
    private let translationProvider: QuickLookEnglishTranslationProvider
    private let mtBlockPreparer: QuickLookMTBlockPreparer
    private let mtProvider: QuickLookLocalMTTranslationProvider
    private let minimumConfidence: Double
    private let logger = Logger(
        subsystem: "AlenShamatov.ScreenTranslator",
        category: "QuickLookMode"
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

    func makeBlocks(
        from observations: [OCRTextObservation],
        canvasSize: CGSize
    ) async -> [QuickLookOCRBlock] {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        let lookupStart = Date()
        let mtPreparation = mtBlockPreparer.prepare(
            observations: observations,
            canvasSize: canvasSize
        )

        logger.info(
            """
            Quick Look Local MT config enabled=\
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
                Quick Look Local MT prepared zero request blocks despite CJK \
                OCR blocks. rejectedEmpty=\(mtPreparation.rejectedEmptyText, privacy: .public), \
                rejectedNonCJK=\(mtPreparation.rejectedNonCJK, privacy: .public), \
                rejectedPunctuation=\(mtPreparation.rejectedNonSubstantive, privacy: .public), \
                rejectedLowConfidence=\(mtPreparation.rejectedLowConfidence, privacy: .public), \
                rejectedInvalidFrame=\(mtPreparation.rejectedInvalidFrame, privacy: .public), \
                capped=\(mtPreparation.cappedAtMaximum, privacy: .public)
                """
            )
        }

        let mtOutcome = mtPreparation.blocks.isEmpty
            ? QuickLookLocalMTTranslationOutcome.disabled
            : await mtProvider.translate(preparedBlocks: mtPreparation.blocks)

        let mtFailureCount = mtOutcome.failed ? 1 : 0
        let cjkBlockCount = mtPreparation.cjkBlockCount
        var dictionaryHitCount = 0
        var localMTHitCount = 0
        var mtAcceptedCount = 0
        var fallbackHitCount = 0
        var suspiciousMTFallbackCount = 0
        var lowQualityFallbackRejectedCount = 0
        var phraseOverrideHitCount = 0
        var exactHitCount = 0
        var segmentHitCount = 0
        var singleAllowlistHitCount = 0
        var summaryHitCount = 0
        var skippedUnknownCJKCount = 0
        var longUntranslatedCount = 0
        var renderedBlocks: [QuickLookOCRBlock] = []
        var coveredObservationIndices = Set<Int>()

        for preparedBlock in mtPreparation.blocks {
            guard let localMTTranslation = mtOutcome.translationsByID[preparedBlock.id] else {
                let diagnostics = translationProvider.diagnostics(
                    for: preparedBlock.text
                )

                if let fallbackTranslation = diagnostics.translation,
                   shouldRejectLowQualityFallback(
                    sourceText: preparedBlock.text,
                    lineCount: preparedBlock.lineCount,
                    blockType: preparedBlock.blockType,
                    translation: fallbackTranslation
                   ) == false {
                    dictionaryHitCount += 1

                    if mtOutcome.attempted {
                        fallbackHitCount += 1
                    }

                    addFallbackHitCounts(
                        fallbackTranslation.matchKind,
                        phraseOverrideHitCount: &phraseOverrideHitCount,
                        exactHitCount: &exactHitCount,
                        segmentHitCount: &segmentHitCount,
                        singleAllowlistHitCount: &singleAllowlistHitCount,
                        summaryHitCount: &summaryHitCount
                    )

                    if shouldRender(
                        frame: preparedBlock.sourceFrame,
                        confidence: preparedBlock.confidence,
                        translation: fallbackTranslation,
                        canvasSize: canvasSize
                    ) {
                        renderedBlocks.append(
                            QuickLookOCRBlock(
                                sourceText: diagnostics.normalizedText,
                                sourceFrame: preparedBlock.sourceFrame,
                                confidence: preparedBlock.confidence,
                                displayText: fallbackTranslation.displayText,
                                matchedSource: fallbackTranslation.matchedSource,
                                matchKind: fallbackTranslation.matchKind,
                                isImportant: fallbackTranslation.isImportant,
                                hasPreservedValue: fallbackTranslation.hasPreservedValue,
                                lineCount: preparedBlock.lineCount,
                                blockType: preparedBlock.blockType,
                                overlaySourceKind: fallbackTranslation.matchKind == .singleAllowlist
                                    ? .single
                                    : .cedict,
                                groupID: preparedBlock.id
                            )
                        )
                    }
                } else {
                    lowQualityFallbackRejectedCount += 1
                    logger.warning(
                        """
                        Quick Look fallback rejected id=\
                        \(preparedBlock.id, privacy: .public), sourceLength=\
                        \(preparedBlock.text.count, privacy: .public), \
                        label=\
                        \(preview(diagnostics.translation?.displayText ?? "none"), privacy: .public), \
                        reason=missingLocalMTOrLowQuality
                        """
                    )
                }

                coveredObservationIndices.formUnion(preparedBlock.observationIndices)
                continue
            }

            if let suspiciousRejectedReason = suspiciousLocalMTRejectionReason(
                preparedBlock: preparedBlock,
                translation: localMTTranslation
            ) {
                suspiciousMTFallbackCount += 1
                logger.warning(
                    """
                    Quick Look Local MT suspicious fallback id=\
                    \(preparedBlock.id, privacy: .public), source=\
                    \(preview(preparedBlock.text), privacy: .public), translation=\
                    \(preview(localMTTranslation.displayText), privacy: .public), \
                    acceptedMTAfterSuspiciousCheck=false, \
                    suspiciousRejectedReason=\
                    \(suspiciousRejectedReason, privacy: .public), route=\
                    \(preparedBlock.route.rawValue, privacy: .public), sourceType=\
                    \(preparedBlock.blockType.rawValue, privacy: .public)
                    """
                )
                continue
            }

            dictionaryHitCount += 1
            localMTHitCount += 1
            mtAcceptedCount += 1
            logger.debug(
                """
                Quick Look Local MT suspicious check id=\
                \(preparedBlock.id, privacy: .public), \
                acceptedMTAfterSuspiciousCheck=true, \
                suspiciousRejectedReason=none, route=\
                \(preparedBlock.route.rawValue, privacy: .public), sourceType=\
                \(preparedBlock.blockType.rawValue, privacy: .public), \
                translationPreview=\
                \(preview(localMTTranslation.displayText), privacy: .public)
                """
            )

            guard shouldRender(
                frame: preparedBlock.sourceFrame,
                confidence: preparedBlock.confidence,
                translation: localMTTranslation,
                canvasSize: canvasSize
            ) else {
                continue
            }

            renderedBlocks.append(
                QuickLookOCRBlock(
                    sourceText: preparedBlock.text,
                    sourceFrame: preparedBlock.sourceFrame,
                    confidence: preparedBlock.confidence,
                    displayText: localMTTranslation.displayText,
                    matchedSource: localMTTranslation.matchedSource,
                    matchKind: localMTTranslation.matchKind,
                    isImportant: localMTTranslation.isImportant,
                    hasPreservedValue: localMTTranslation.hasPreservedValue,
                    lineCount: preparedBlock.lineCount,
                    blockType: preparedBlock.blockType,
                    overlaySourceKind: shouldRenderLocalMTAsGroup(preparedBlock)
                        ? .localMTGroup
                        : .localMTLine,
                    groupID: preparedBlock.id
                )
            )
            logger.debug(
                """
                Quick Look Local MT selected group id=\
                \(preparedBlock.id, privacy: .public), type=\
                \(preparedBlock.blockType.rawValue, privacy: .public), \
                lineCount=\(preparedBlock.lineCount, privacy: .public), \
                sourceChars=\(preparedBlock.text.count, privacy: .public), \
                translationChars=\
                \(localMTTranslation.displayText.count, privacy: .public), \
                sourcePreview=\
                \(preview(preparedBlock.text), privacy: .public), \
                translationPreview=\
                \(preview(localMTTranslation.displayText), privacy: .public)
                """
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

            guard routeDecision.route != .skip else {
                continue
            }

            let diagnostics = translationProvider.diagnostics(
                for: routeDecision.text
            )

            guard let routeTranslation = diagnostics.translation else {
                if diagnostics.unresolvedReason == .longUntranslated {
                    longUntranslatedCount += 1
                } else {
                    skippedUnknownCJKCount += 1
                }
                continue
            }

            if shouldRejectLowQualityFallback(
                sourceText: routeDecision.text,
                lineCount: routeDecision.lineCount,
                blockType: routeDecision.blockType,
                translation: routeTranslation
            ) {
                lowQualityFallbackRejectedCount += 1
                logger.warning(
                    """
                    Quick Look fallback rejected id=\
                    \(routeDecision.id, privacy: .public), sourceLength=\
                    \(routeDecision.text.count, privacy: .public), label=\
                    \(preview(routeTranslation.displayText), privacy: .public), \
                    reason=sentenceLikeFallbackTooShort
                    """
                )
                continue
            }

            dictionaryHitCount += 1

            if mtOutcome.attempted {
                fallbackHitCount += 1
            }

            addFallbackHitCounts(
                routeTranslation.matchKind,
                phraseOverrideHitCount: &phraseOverrideHitCount,
                exactHitCount: &exactHitCount,
                segmentHitCount: &segmentHitCount,
                singleAllowlistHitCount: &singleAllowlistHitCount,
                summaryHitCount: &summaryHitCount
            )

            guard shouldRender(
                frame: routeDecision.sourceFrame,
                confidence: routeDecision.confidence,
                translation: routeTranslation,
                canvasSize: canvasSize
            ) else {
                continue
            }

            renderedBlocks.append(
                QuickLookOCRBlock(
                    sourceText: diagnostics.normalizedText,
                    sourceFrame: routeDecision.sourceFrame,
                    confidence: routeDecision.confidence,
                    displayText: routeTranslation.displayText,
                    matchedSource: routeTranslation.matchedSource,
                    matchKind: routeTranslation.matchKind,
                    isImportant: routeTranslation.isImportant,
                    hasPreservedValue: routeTranslation.hasPreservedValue,
                    lineCount: routeDecision.lineCount,
                    blockType: routeDecision.blockType,
                    overlaySourceKind: routeTranslation.matchKind == .singleAllowlist
                        ? .single
                        : .cedict,
                    groupID: routeDecision.id
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
            let clippedFrame = observation.boundingBox
                .standardized
                .intersection(canvasRect)

            guard shouldKeepCandidate(
                text: normalizedText,
                frame: clippedFrame,
                confidence: observation.confidence
            ) else {
                continue
            }

            let translation: QuickLookDictionaryTranslation
            let diagnostics = translationProvider.diagnostics(
                for: observation.originalText
            )

            guard let fallbackTranslation = diagnostics.translation else {
                if diagnostics.unresolvedReason == .longUntranslated {
                    longUntranslatedCount += 1
                    continue
                }

                skippedUnknownCJKCount += 1
                continue
            }

            if shouldRejectLowQualityFallback(
                sourceText: normalizedText,
                lineCount: 1,
                blockType: .uiLabel,
                translation: fallbackTranslation
            ) {
                lowQualityFallbackRejectedCount += 1
                logger.warning(
                    """
                    Quick Look fallback rejected sourceLength=\
                    \(normalizedText.count, privacy: .public), label=\
                    \(preview(fallbackTranslation.displayText), privacy: .public), \
                    reason=rawSentenceFallbackTooShort
                    """
                )
                continue
            }

            translation = fallbackTranslation
            dictionaryHitCount += 1

            if mtOutcome.attempted {
                fallbackHitCount += 1
            }

            addFallbackHitCounts(
                translation.matchKind,
                phraseOverrideHitCount: &phraseOverrideHitCount,
                exactHitCount: &exactHitCount,
                segmentHitCount: &segmentHitCount,
                singleAllowlistHitCount: &singleAllowlistHitCount,
                summaryHitCount: &summaryHitCount
            )

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
                    hasPreservedValue: translation.hasPreservedValue,
                    lineCount: 1,
                    blockType: .uiLabel,
                    overlaySourceKind: translation.matchKind == .singleAllowlist
                        ? .single
                        : .cedict,
                    groupID: nil
                )
            )
        }

        logger.debug(
            """
            Quick Look OCR blocks total=\(observations.count), \
            cjk=\(cjkBlockCount), \
            dictionaryHits=\(dictionaryHitCount), \
            localMTHits=\(localMTHitCount), \
            mtAccepted=\(mtAcceptedCount), \
            fallbackHits=\(fallbackHitCount), \
            mtFailures=\(mtFailureCount), \
            suspiciousMTFallbacks=\(suspiciousMTFallbackCount), \
            lowQualityFallbackRejected=\
            \(lowQualityFallbackRejectedCount), \
            routeMT=\(routeCount(.localMT, in: mtPreparation), privacy: .public), \
            routeDomain=\
            \(routeCount(.domainDictionary, in: mtPreparation), privacy: .public), \
            routeCEDICT=\(routeCount(.cedict, in: mtPreparation), privacy: .public), \
            routeSkip=\(routeCount(.skip, in: mtPreparation), privacy: .public), \
            phraseOverrideHits=\(phraseOverrideHitCount), \
            exactHits=\(exactHitCount), \
            segmentHits=\(segmentHitCount), \
            singleAllowlistHits=\(singleAllowlistHitCount), \
            summaryHits=\(summaryHitCount), \
            skippedUnknownCJK=\(skippedUnknownCJKCount), \
            longUntranslated=\(longUntranslatedCount), \
            groups=\(mtPreparation.groupedBlockCount), \
            renderedGroupedTranslations=\
            \(renderedBlocks.filter { $0.matchKind == .localMT && $0.lineCount > 1 }.count), \
            rendered=\(renderedBlocks.count), \
            lookupDuration=\(Date().timeIntervalSince(lookupStart), format: .fixed(precision: 3))s
            """
        )

        return renderedBlocks
    }

    private func addFallbackHitCounts(
        _ matchKind: QuickLookDictionaryMatchKind,
        phraseOverrideHitCount: inout Int,
        exactHitCount: inout Int,
        segmentHitCount: inout Int,
        singleAllowlistHitCount: inout Int,
        summaryHitCount: inout Int
    ) {
        switch matchKind {
        case .localMT:
            break
        case .phraseOverride:
            phraseOverrideHitCount += 1
        case .exact:
            exactHitCount += 1
        case .segment, .contained, .mixedPhrase, .amountUnit:
            segmentHitCount += 1
        case .singleAllowlist:
            singleAllowlistHitCount += 1
        case .summary:
            summaryHitCount += 1
        }
    }

    private func routeCount(
        _ route: QuickLookTranslationRoute,
        in preparation: QuickLookMTBlockPreparation
    ) -> Int {
        preparation.routeDecisions.filter { $0.route == route }.count
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

    private func shouldRenderLocalMTAsGroup(
        _ preparedBlock: QuickLookMTPreparedBlock
    ) -> Bool {
        preparedBlock.lineCount > 1
            || preparedBlock.text.count >= 20
            || preparedBlock.blockType == .chatBubble
            || preparedBlock.blockType == .paragraph
            || preparedBlock.blockType == .addressBlock
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
        let isMeaningful = displayText.count >= 12 || words.count >= 3

        return isMeaningful == false
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
           translation.matchKind != .localMT,
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

    private func preview(_ text: String) -> String {
        guard text.count > 72 else {
            return text
        }

        return "\(text.prefix(72))..."
    }
}

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
