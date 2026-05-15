import CoreGraphics
import Foundation
import OSLog

struct QuickLookMTPreparedBlock: Equatable {
    let id: String
    let observationIndex: Int
    let observationIndices: [Int]
    let text: String
    let kind: String
    let sourceFrame: CGRect
    let childFrames: [CGRect]
    let childTexts: [String]
    let blockType: QuickLookTextGroupBlockType
    let confidence: Double
    let lineCount: Int
    let route: QuickLookTranslationRoute
    let routeReason: String

    var requestBlock: QuickLookMTBlock {
        QuickLookMTBlock(id: id, text: text, kind: kind)
    }
}

enum QuickLookTranslationRoute: String, Equatable {
    case localMT = "ROUTE_MT"
    case domainDictionary = "ROUTE_DOMAIN"
    case cedict = "ROUTE_CEDICT"
    case skip = "ROUTE_SKIP"
}

struct QuickLookTranslationRouteDecision: Equatable {
    let id: String
    let observationIndex: Int
    let observationIndices: [Int]
    let text: String
    let sourceFrame: CGRect
    let childFrames: [CGRect]
    let childTexts: [String]
    let blockType: QuickLookTextGroupBlockType
    let confidence: Double
    let lineCount: Int
    let route: QuickLookTranslationRoute
    let reason: String
}

struct QuickLookMTBlockPreparation: Equatable {
    let blocks: [QuickLookMTPreparedBlock]
    let routeDecisions: [QuickLookTranslationRouteDecision]
    let cjkBlockCount: Int
    let rejectedEmptyText: Int
    let rejectedNonCJK: Int
    let rejectedNonSubstantive: Int
    let rejectedLowConfidence: Int
    let rejectedInvalidFrame: Int
    let cappedAtMaximum: Bool
    let rawLineCount: Int
    let groupedBlockCount: Int
}

struct QuickLookMTBlockPreparer {
    private let cjkDetector: QuickLookCJKTextDetector
    private let normalizer: QuickLookEnglishTextNormalizer
    private let textBlockGrouper: QuickLookTextBlockGrouper
    private let maximumBlocks: Int
    private let maximumCharactersPerBlock: Int
    private let minimumConfidence: Double
    private let logger = Logger(
        subsystem: "AlenShamatov.ScreenTranslator",
        category: "QuickLookLocalMT"
    )

    init(
        cjkDetector: QuickLookCJKTextDetector = QuickLookCJKTextDetector(),
        normalizer: QuickLookEnglishTextNormalizer = QuickLookEnglishTextNormalizer(),
        textBlockGrouper: QuickLookTextBlockGrouper = QuickLookTextBlockGrouper(),
        maximumBlocks: Int = QuickLookLocalMTConfig.maximumBlocks,
        maximumCharactersPerBlock: Int = QuickLookLocalMTConfig.maximumCharactersPerBlock,
        minimumConfidence: Double = 0.20
    ) {
        self.cjkDetector = cjkDetector
        self.normalizer = normalizer
        self.textBlockGrouper = textBlockGrouper
        self.maximumBlocks = maximumBlocks
        self.maximumCharactersPerBlock = maximumCharactersPerBlock
        self.minimumConfidence = minimumConfidence
    }

    func prepare(
        observations: [OCRTextObservation],
        canvasSize: CGSize
    ) -> QuickLookMTBlockPreparation {
        let canvasRect = CGRect(origin: .zero, size: canvasSize)
        var blocks: [QuickLookMTPreparedBlock] = []
        var cjkBlockCount = 0
        var rejectedEmptyText = 0
        var rejectedNonCJK = 0
        var rejectedNonSubstantive = 0
        var rejectedLowConfidence = 0
        var rejectedInvalidFrame = 0
        var cappedAtMaximum = false
        var candidateLines: [QuickLookTextLine] = []
        var routeDecisions: [QuickLookTranslationRouteDecision] = []

        for (index, observation) in observations.enumerated() {
            let normalizedText = normalizer.normalize(observation.originalText)
            let clippedFrame = observation.boundingBox
                .standardized
                .intersection(canvasRect)

            if normalizedText.isEmpty {
                rejectedEmptyText += 1
                continue
            }

            guard cjkDetector.containsCJK(in: normalizedText) else {
                rejectedNonCJK += 1
                continue
            }

            cjkBlockCount += 1

            guard containsSubstantiveText(normalizedText) else {
                rejectedNonSubstantive += 1
                continue
            }

            guard observation.confidence >= minimumConfidence else {
                rejectedLowConfidence += 1
                continue
            }

            guard clippedFrame.isNull == false,
                  clippedFrame.isEmpty == false else {
                rejectedInvalidFrame += 1
                continue
            }

            candidateLines.append(
                QuickLookTextLine(
                    observationIndex: index,
                    text: normalizedText,
                    frame: clippedFrame,
                    confidence: observation.confidence
                )
            )
        }

        let groups = textBlockGrouper.group(
            lines: candidateLines,
            canvasSize: canvasSize
        )

        logger.info(
            """
            Quick Look grouping inputBlocks=\
            \(candidateLines.count, privacy: .public), outputGroups=\
            \(groups.count, privacy: .public)
            """
        )

        for group in groups {
            let routeDecision = routeDecision(for: group, canvasSize: canvasSize)
            routeDecisions.append(routeDecision)
            logger.debug(
                """
                Quick Look group id=\(group.id, privacy: .public), \
                type=\(group.blockType.rawValue, privacy: .public), \
                lineCount=\(group.lineCount, privacy: .public), \
                charCount=\(group.sourceText.count, privacy: .public), \
                route=\(routeDecision.route.rawValue, privacy: .public), \
                reason=\(routeDecision.reason, privacy: .public), \
                frame=\(frameSummary(group.frame), privacy: .public), \
                preview=\(preview(group.sourceText), privacy: .public)
                """
            )

            guard routeDecision.route == .localMT else {
                continue
            }

            guard blocks.count < maximumBlocks else {
                cappedAtMaximum = true
                continue
            }

            blocks.append(
                QuickLookMTPreparedBlock(
                    id: group.id,
                    observationIndex: group.childObservationIndices.first ?? 0,
                    observationIndices: group.childObservationIndices,
                    text: limitedText(group.sourceText),
                    kind: group.blockType.rawValue,
                    sourceFrame: group.frame,
                    childFrames: group.childFrames,
                    childTexts: group.childTexts,
                    blockType: group.blockType,
                    confidence: group.confidence,
                    lineCount: group.lineCount,
                    route: routeDecision.route,
                    routeReason: routeDecision.reason
                )
            )
        }

        return QuickLookMTBlockPreparation(
            blocks: blocks,
            routeDecisions: routeDecisions,
            cjkBlockCount: cjkBlockCount,
            rejectedEmptyText: rejectedEmptyText,
            rejectedNonCJK: rejectedNonCJK,
            rejectedNonSubstantive: rejectedNonSubstantive,
            rejectedLowConfidence: rejectedLowConfidence,
            rejectedInvalidFrame: rejectedInvalidFrame,
            cappedAtMaximum: cappedAtMaximum,
            rawLineCount: candidateLines.count,
            groupedBlockCount: groups.count
        )
    }

    private func routeDecision(
        for group: QuickLookTextGroup,
        canvasSize: CGSize
    ) -> QuickLookTranslationRouteDecision {
        let compactText = normalizer.compact(group.sourceText)
        let routeAndReason: (QuickLookTranslationRoute, String)

        if shouldSkipGroup(compactText: compactText, group: group) {
            routeAndReason = (.skip, "valueOrNoiseOnly")
        } else if let localMTReason = localMTRouteReason(
            compactText: compactText,
            group: group,
            canvasSize: canvasSize
        ) {
            routeAndReason = (.localMT, localMTReason)
        } else if shouldRouteToDomainDictionary(
            compactText: compactText,
            group: group,
            canvasSize: canvasSize
        ) {
            routeAndReason = (.domainDictionary, "shortDomainOrUI")
        } else {
            routeAndReason = (.cedict, "termFallback")
        }

        return QuickLookTranslationRouteDecision(
            id: group.id,
            observationIndex: group.childObservationIndices.first ?? 0,
            observationIndices: group.childObservationIndices,
            text: limitedText(group.sourceText),
            sourceFrame: group.frame,
            childFrames: group.childFrames,
            childTexts: group.childTexts,
            blockType: group.blockType,
            confidence: group.confidence,
            lineCount: group.lineCount,
            route: routeAndReason.0,
            reason: routeAndReason.1
        )
    }

    private func localMTRouteReason(
        compactText: String,
        group: QuickLookTextGroup,
        canvasSize: CGSize
    ) -> String? {
        guard compactText.count >= 8 else {
            return nil
        }

        if isBottomNavigation(group: group, canvasSize: canvasSize)
            || isMostlyPriceOrNumber(compactText) {
            return nil
        }

        let triggerTerms = triggeredSellerSentenceTerms(in: compactText)
        let hasSentencePunctuation = containsSentencePunctuation(group.sourceText)
        let isShortKnownUI = compactText.count <= 8
            && (isKnownCommerceLabel(compactText)
                || isShortUILabel(compactText: compactText, group: group)
                || group.blockType == .button)

        guard isShortKnownUI == false else {
            return nil
        }

        if group.lineCount >= 2 && compactText.count >= 12 {
            return "multiLineSentence"
        }

        if compactText.count >= 18 && hasSentencePunctuation {
            return "sentencePunctuation"
        }

        if compactText.count >= 12 && triggerTerms.isEmpty == false {
            return "logisticsTrigger:\(triggerTerms.prefix(4).joined(separator: "+"))"
        }

        if group.blockType == .chatBubble || group.blockType == .paragraph {
            return compactText.count >= 12 ? "textBlockType:\(group.blockType.rawValue)" : nil
        }

        if group.blockType == .addressBlock {
            return compactText.count >= 12 ? "addressBlock" : nil
        }

        if group.blockType == .unknown,
           compactText.count >= 18,
           hasSentencePunctuation {
            return "unknownSentence"
        }

        if group.blockType == .productCard,
           compactText.count >= 24,
           hasSentencePunctuation {
            return "productSentence"
        }

        return nil
    }

    private func shouldRouteToDomainDictionary(
        compactText: String,
        group: QuickLookTextGroup,
        canvasSize: CGSize
    ) -> Bool {
        if isBottomNavigation(group: group, canvasSize: canvasSize) {
            return true
        }

        if isKnownCommerceLabel(compactText) {
            return true
        }

        if group.blockType == .button && compactText.count <= 10 {
            return true
        }

        if group.blockType == .uiLabel && compactText.count <= 10 {
            return true
        }

        if group.blockType == .productCard,
           compactText.count <= 14,
           containsSentencePunctuation(group.sourceText) == false {
            return true
        }

        return false
    }

    private func shouldSkipGroup(
        compactText: String,
        group: QuickLookTextGroup
    ) -> Bool {
        compactText.isEmpty
            || isMostlyPriceOrNumber(compactText)
                && containsAny(compactText, pricePhraseTokens) == false
                && group.blockType != .productCard
    }

    private func isShortUILabel(
        compactText: String,
        group: QuickLookTextGroup
    ) -> Bool {
        (group.blockType == .uiLabel || group.blockType == .button)
            && compactText.count <= 8
    }

    private func isBottomNavigation(
        group: QuickLookTextGroup,
        canvasSize: CGSize
    ) -> Bool {
        let frame = group.frame.standardized

        return frame.midY / max(canvasSize.height, 1) > 0.88
            && group.lineCount == 1
            && normalizer.compact(group.sourceText).count <= 8
    }

    private func isKnownCommerceLabel(_ compactText: String) -> Bool {
        containsAny(compactText, domainDictionaryTokens)
    }

    private func triggeredSellerSentenceTerms(in compactText: String) -> [String] {
        sellerSentenceTokens.filter { compactText.contains($0) }
    }

    private func containsSentencePunctuation(_ text: String) -> Bool {
        text.contains { character in
            "。！？；，,!?;".contains(character)
        }
    }

    private func isButtonLike(_ compactText: String) -> Bool {
        containsAny(compactText, buttonTokens) && compactText.count <= 10
    }

    private func isMostlyPriceOrNumber(_ compactText: String) -> Bool {
        guard compactText.isEmpty == false else {
            return true
        }

        let valueScalars = compactText.unicodeScalars.filter { scalar in
            CharacterSet.decimalDigits.contains(scalar)
                || CharacterSet(charactersIn: "¥￥$%.折元件张,./-+").contains(scalar)
        }.count

        return Double(valueScalars)
            / Double(max(compactText.unicodeScalars.count, 1)) >= 0.72
    }

    private func containsAny(
        _ text: String,
        _ tokens: [String]
    ) -> Bool {
        tokens.contains { text.contains($0) }
    }

    private func limitedText(_ text: String) -> String {
        guard text.count > maximumCharactersPerBlock else {
            return text
        }

        return String(text.prefix(maximumCharactersPerBlock))
    }

    private func containsSubstantiveText(_ text: String) -> Bool {
        let ignoredScalars = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(.symbols)

        return text.unicodeScalars.contains { scalar in
            ignoredScalars.contains(scalar) == false
        }
    }

    private func frameSummary(_ frame: CGRect) -> String {
        let standardized = frame.standardized

        return "x=\(Int(standardized.minX)),y=\(Int(standardized.minY)),w=\(Int(standardized.width)),h=\(Int(standardized.height))"
    }

    private func preview(_ text: String) -> String {
        guard text.count > 48 else {
            return text
        }

        return "\(text.prefix(48))..."
    }
}

private let domainDictionaryTokens = [
    "关注",
    "推荐",
    "闪购",
    "外卖",
    "国补",
    "国补飞猪告白季",
    "飞猪",
    "告白季",
    "520告白季",
    "穿搭",
    "清凉",
    "加码",
    "补贴",
    "消费券",
    "搜索",
    "陶瓷花盆",
    "抵钱",
    "优惠",
    "优惠券",
    "领淘金币",
    "淘金币",
    "淘宝秒杀",
    "省钱卡",
    "试用领取",
    "淘工厂",
    "红包",
    "频道专享红包",
    "淘宝直播",
    "直播有好价",
    "直播价",
    "百亿补贴",
    "国家补贴",
    "政府补贴",
    "抢",
    "立即抢",
    "立即抢购",
    "88VIP专享",
    "苹果惊喜直降",
    "优惠超千元",
    "超级单品",
    "闪降更优惠",
    "特惠爆款",
    "风格上新",
    "补贴价",
    "券后价",
    "立即领取",
    "视频",
    "消息",
    "购物车",
    "我的淘宝",
    "自助服务",
    "评价客服",
    "限时买一送一",
    "收藏有礼",
    "支付",
    "付款",
    "订单",
    "退款",
    "发货",
    "收货",
    "地址"
]

private let buttonTokens = [
    "确认",
    "取消",
    "保存",
    "删除",
    "打开",
    "关闭",
    "领取",
    "使用",
    "购买",
    "支付",
    "提交",
    "搜索",
    "登录"
]

private let sellerSentenceTokens = [
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
    "重新发",
    "外包装",
    "标注",
    "麻烦",
    "请",
    "请您",
    "如果",
    "因为",
    "但是",
    "所以",
    "结果",
    "我现在",
    "我会",
    "之前",
    "仓库",
    "物流",
    "快递",
    "发出",
    "收到",
    "检查"
]

private let pricePhraseTokens = [
    "直播价",
    "补贴价",
    "券后价",
    "到手价",
    "优惠",
    "红包",
    "消费券"
]
