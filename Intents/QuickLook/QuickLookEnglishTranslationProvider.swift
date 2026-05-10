import Foundation

struct QuickLookEnglishTranslationProvider {
    private let store: QuickLookCEDICTStore
    private let normalizer: QuickLookEnglishTextNormalizer

    init(
        store: QuickLookCEDICTStore = .shared,
        normalizer: QuickLookEnglishTextNormalizer = QuickLookEnglishTextNormalizer()
    ) {
        self.store = store
        self.normalizer = normalizer
    }

    func normalizedSource(_ text: String) -> String {
        normalizer.normalize(text)
    }

    func diagnostics(for rawText: String) -> QuickLookDictionaryDiagnostics {
        let normalizedText = normalizedSource(rawText)
        let resolution = resolve(normalizedText: normalizedText)

        return QuickLookDictionaryDiagnostics(
            originalText: rawText,
            normalizedText: normalizedText,
            translation: resolution.translation,
            matchType: diagnosticsMatchType(for: resolution.translation),
            unresolvedReason: resolution.unresolvedReason
        )
    }

    func translation(for rawText: String) -> QuickLookDictionaryTranslation? {
        resolve(normalizedText: normalizedSource(rawText)).translation
    }

    private func resolve(
        normalizedText: String
    ) -> QuickLookEnglishTranslationResolution {
        let compactText = normalizer.compact(normalizedText)

        guard compactText.isEmpty == false else {
            return QuickLookEnglishTranslationResolution()
        }

        if let valueTranslation = mixedValueTranslation(
            normalizedText: normalizedText,
            compactText: compactText
        ) {
            return QuickLookEnglishTranslationResolution(
                translation: valueTranslation
            )
        }

        if let override = Self.phraseOverrideLookup[compactText] {
            return QuickLookEnglishTranslationResolution(
                translation: translation(
                    from: override,
                    matchedSource: compactText,
                    matchKind: .phraseOverride
                )
            )
        }

        if let singleTranslation = singleCharacterTranslation(
            for: compactText
        ) {
            return QuickLookEnglishTranslationResolution(
                translation: singleTranslation
            )
        }

        if store.isAvailable,
           let exactHit = store.lookupExact(compactText),
           let translation = translation(from: exactHit) {
            return QuickLookEnglishTranslationResolution(
                translation: translation
            )
        }

        if let overrideTranslation = containedOverrideTranslation(
            in: compactText
        ) {
            return QuickLookEnglishTranslationResolution(
                translation: overrideTranslation
            )
        }

        let isLongText = isLongChineseSentence(compactText)
        let segmentHits = store.isAvailable
            ? store.lookupSegments(
                in: compactText,
                maxSegments: isLongText ? 4 : 3
            )
            : []

        guard segmentHits.isEmpty == false else {
            return QuickLookEnglishTranslationResolution(
                unresolvedReason: isLongText ? .longUntranslated : nil
            )
        }

        if let segmentTranslation = translation(
            fromSegments: segmentHits,
            sourceCompact: compactText,
            forceSummary: isLongText
        ) {
            return QuickLookEnglishTranslationResolution(
                translation: segmentTranslation
            )
        }

        return QuickLookEnglishTranslationResolution(
            unresolvedReason: isLongText ? .longUntranslated : nil
        )
    }

    private func singleCharacterTranslation(
        for compactText: String
    ) -> QuickLookDictionaryTranslation? {
        guard compactText.count == 1,
              let displayText = Self.singleCharacterAllowlist[compactText] else {
            return nil
        }

        return QuickLookDictionaryTranslation(
            displayText: displayText,
            matchedSource: compactText,
            matchKind: .singleAllowlist,
            isImportant: true,
            hasPreservedValue: false,
            sourceKind: "single_allowlist",
            selectionReason: "runtimeSingleAllowlist",
            englishRaw: displayText,
            pinyin: nil
        )
    }

    private func mixedValueTranslation(
        normalizedText: String,
        compactText: String
    ) -> QuickLookDictionaryTranslation? {
        if let flashHour = capturedGroups(
            in: normalizedText,
            pattern: #"([0-9]{1,2})\s*点\s*抢"#
        )?.first, let hour = Int(flashHour), (0...24).contains(hour) {
            return runtimeTranslation(
                displayText: "grab at \(hour):00",
                matchedSource: "\(flashHour)点抢",
                matchKind: .phraseOverride,
                isImportant: true,
                hasPreservedValue: true,
                selectionReason: "runtimePattern:hourFlashSale"
            )
        }

        if compactText.contains("网络错误"), compactText.contains("重试") {
            return runtimeTranslation(
                displayText: "network error · retry",
                matchedSource: "网络错误 + 重试",
                matchKind: .phraseOverride,
                isImportant: true,
                hasPreservedValue: false,
                selectionReason: "runtimePattern:networkRetry"
            )
        }

        if let priceTranslation = pricePhraseTranslation(
            normalizedText: normalizedText,
            compactText: compactText
        ) {
            return priceTranslation
        }

        if let couponTranslation = couponTimeTranslation(
            normalizedText: normalizedText,
            compactText: compactText
        ) {
            return couponTranslation
        }

        return nil
    }

    private func pricePhraseTranslation(
        normalizedText: String,
        compactText: String
    ) -> QuickLookDictionaryTranslation? {
        let phraseLabels: [(source: String, label: String)] = [
            ("直播价", "live price"),
            ("补贴价", "subsidized price"),
            ("券后价", "after-coupon price"),
            ("到手价", "final price")
        ]

        guard let phrase = phraseLabels.first(where: { compactText.contains($0.source) }) else {
            return nil
        }

        let amount = capturedGroups(
            in: normalizedText,
            pattern: "\(phrase.source)\\s*[¥￥]?\\s*([0-9]+(?:[.,][0-9]+)?)"
        )?.first

        let displayText = amount.map { "\(phrase.label) ¥\($0)" } ?? phrase.label

        return runtimeTranslation(
            displayText: displayText,
            matchedSource: phrase.source,
            matchKind: .phraseOverride,
            isImportant: true,
            hasPreservedValue: amount != nil,
            selectionReason: "runtimePattern:pricePhrase"
        )
    }

    private func couponTimeTranslation(
        normalizedText: String,
        compactText: String
    ) -> QuickLookDictionaryTranslation? {
        guard compactText.contains("消费券")
            || compactText.contains("优惠券")
            || compactText.contains("待使用")
            || compactText.contains("剩") else {
            return nil
        }

        var segments: [String] = []

        if let amount = capturedGroups(
            in: normalizedText,
            pattern: #"([0-9]+(?:[.,][0-9]+)?)\s*元"#
        )?.first {
            if compactText.contains("消费券") || compactText.contains("优惠券") {
                segments.append("\(amount) yuan coupon")
            } else {
                segments.append("\(amount) yuan")
            }
        } else if compactText.contains("消费券") || compactText.contains("优惠券") {
            segments.append("coupon")
        }

        if let timeText = compactTimeText(from: normalizedText) {
            segments.append(timeText)
        }

        guard segments.isEmpty == false else {
            return nil
        }

        return runtimeTranslation(
            displayText: segments.prefix(2).joined(separator: " · "),
            matchedSource: "消费券 + 待使用",
            matchKind: .summary,
            isImportant: true,
            hasPreservedValue: true,
            selectionReason: "runtimePattern:couponTime"
        )
    }

    private func containedOverrideTranslation(
        in compactText: String
    ) -> QuickLookDictionaryTranslation? {
        let candidates = selectedOverrideCandidates(in: compactText)

        guard candidates.isEmpty == false else {
            return nil
        }

        var labels: [String] = []

        for candidate in candidates {
            let displayText = compactDisplayText(candidate.override.displayText)

            guard displayText.isEmpty == false,
                  labels.contains(displayText) == false else {
                continue
            }

            labels.append(displayText)

            if labels.count >= (isLongChineseSentence(compactText) ? 4 : 3) {
                break
            }
        }

        guard labels.isEmpty == false else {
            return nil
        }

        let displayText = labels.joined(separator: " · ")
        let matchKind: QuickLookDictionaryMatchKind =
            isLongChineseSentence(compactText) || labels.count > 1
                ? .summary
                : .phraseOverride

        return QuickLookDictionaryTranslation(
            displayText: displayText,
            matchedSource: candidates.map(\.key).joined(separator: " + "),
            matchKind: matchKind,
            isImportant: candidates.contains { $0.override.isImportant },
            hasPreservedValue: compactText.contains(where: \.isNumber),
            sourceKind: "runtime_override",
            selectionReason: candidates
                .map { "runtimeOverride:\($0.key)" }
                .joined(separator: " | "),
            englishRaw: displayText,
            pinyin: nil
        )
    }

    private func selectedOverrideCandidates(
        in compactText: String
    ) -> [QuickLookEnglishOverrideCandidate] {
        var candidates: [QuickLookEnglishOverrideCandidate] = []

        for override in Self.phraseOverrides where override.source.count >= 2 {
            var searchRange = compactText.startIndex..<compactText.endIndex

            while let range = compactText.range(
                of: override.source,
                options: [],
                range: searchRange
            ) {
                candidates.append(
                    QuickLookEnglishOverrideCandidate(
                        key: override.source,
                        override: override,
                        start: compactText.distance(
                            from: compactText.startIndex,
                            to: range.lowerBound
                        ),
                        length: override.source.count
                    )
                )

                searchRange = range.upperBound..<compactText.endIndex

                if searchRange.isEmpty {
                    break
                }
            }
        }

        let sortedCandidates = candidates.sorted { lhs, rhs in
            if lhs.length != rhs.length {
                return lhs.length > rhs.length
            }

            if lhs.override.isImportant != rhs.override.isImportant {
                return lhs.override.isImportant
            }

            return lhs.start < rhs.start
        }
        var occupied = IndexSet()
        var selected: [QuickLookEnglishOverrideCandidate] = []

        for candidate in sortedCandidates {
            let range = candidate.start..<candidate.start + candidate.length

            guard occupied.intersection(IndexSet(integersIn: range)).isEmpty else {
                continue
            }

            occupied.insert(integersIn: range)
            selected.append(candidate)
        }

        return selected.sorted { $0.start < $1.start }
    }

    private func translation(
        from override: QuickLookEnglishPhraseOverride,
        matchedSource: String,
        matchKind: QuickLookDictionaryMatchKind
    ) -> QuickLookDictionaryTranslation {
        QuickLookDictionaryTranslation(
            displayText: compactDisplayText(override.displayText),
            matchedSource: matchedSource,
            matchKind: matchKind,
            isImportant: override.isImportant,
            hasPreservedValue: false,
            sourceKind: "runtime_override",
            selectionReason: "runtimeOverride:\(matchedSource)",
            englishRaw: override.displayText,
            pinyin: nil
        )
    }

    private func runtimeTranslation(
        displayText: String,
        matchedSource: String,
        matchKind: QuickLookDictionaryMatchKind,
        isImportant: Bool,
        hasPreservedValue: Bool,
        selectionReason: String
    ) -> QuickLookDictionaryTranslation {
        QuickLookDictionaryTranslation(
            displayText: compactDisplayText(displayText),
            matchedSource: matchedSource,
            matchKind: matchKind,
            isImportant: isImportant,
            hasPreservedValue: hasPreservedValue,
            sourceKind: "runtime_override",
            selectionReason: selectionReason,
            englishRaw: displayText,
            pinyin: nil
        )
    }

    private func translation(
        from hit: QuickLookEnglishDictionaryHit
    ) -> QuickLookDictionaryTranslation? {
        let displayText = compactDisplayText(hit.englishDisplay)

        guard displayText.isEmpty == false else {
            return nil
        }

        return QuickLookDictionaryTranslation(
            displayText: displayText,
            matchedSource: hit.source,
            matchKind: hit.matchKind,
            isImportant: isImportant(hit),
            hasPreservedValue: false,
            sourceKind: hit.sourceKind,
            selectionReason: hit.selectionReason,
            englishRaw: hit.englishRaw,
            pinyin: hit.pinyin
        )
    }

    private func translation(
        fromSegments hits: [QuickLookEnglishDictionaryHit],
        sourceCompact: String,
        forceSummary: Bool
    ) -> QuickLookDictionaryTranslation? {
        let usableHits = hits.filter {
            isUsefulSegmentHit(
                $0,
                sourceCompact: sourceCompact,
                forceSummary: forceSummary
            )
        }
        var labels: [String] = []

        for hit in usableHits {
            let candidate = compactDisplayText(hit.englishDisplay)

            guard candidate.isEmpty == false,
                  labels.contains(candidate) == false else {
                continue
            }

            let proposed = (labels + [candidate]).joined(separator: " · ")

            if proposed.count <= (forceSummary ? 46 : 28) || labels.isEmpty {
                labels.append(candidate)
            }

            if labels.count >= (forceSummary ? 4 : 3) {
                break
            }
        }

        guard labels.isEmpty == false else {
            return nil
        }

        if forceSummary,
           labels.count < 2,
           usableHits.contains(where: isImportant) == false {
            return nil
        }

        let displayText = labels.joined(separator: " · ")
        let topHit = usableHits.first

        return QuickLookDictionaryTranslation(
            displayText: displayText,
            matchedSource: usableHits.map(\.source).joined(separator: " + "),
            matchKind: forceSummary ? .summary : .segment,
            isImportant: usableHits.contains(where: isImportant),
            hasPreservedValue: false,
            sourceKind: topHit?.sourceKind,
            selectionReason: usableHits.map(\.selectionReason).joined(separator: " | "),
            englishRaw: usableHits.map(\.englishRaw).joined(separator: " | "),
            pinyin: usableHits.map(\.pinyin).joined(separator: " | ")
        )
    }

    private func compactDisplayText(_ text: String) -> String {
        var trimmed = text
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("to ") {
            trimmed.removeFirst(3)
        }

        guard trimmed.count > 32 else {
            return trimmed
        }

        return String(trimmed.prefix(29)).trimmingCharacters(in: .whitespaces)
            + "..."
    }

    private func isUsefulSegmentHit(
        _ hit: QuickLookEnglishDictionaryHit,
        sourceCompact: String,
        forceSummary: Bool
    ) -> Bool {
        let display = compactDisplayText(hit.englishDisplay).lowercased()

        guard display.isEmpty == false else {
            return false
        }

        if hit.source.count <= 1 {
            return false
        }

        if Self.blockedSegmentLabels.contains(display) {
            return false
        }

        if forceSummary {
            return isImportant(hit)
                || hit.source.count >= 2 && display.count <= 24
        }

        return true
    }

    private func isImportant(_ hit: QuickLookEnglishDictionaryHit) -> Bool {
        if hit.sourceKind == "app_phrase_override"
            || hit.sourceKind == "runtime_override"
            || hit.sourceKind == "single_allowlist"
            || hit.priority >= 200 {
            return true
        }

        let display = hit.englishDisplay.lowercased()
        let source = hit.source

        return Self.importantEnglishTerms.contains { display.contains($0) }
            || Self.importantChineseTerms.contains { source.contains($0) }
    }

    private func isLongChineseSentence(_ compactText: String) -> Bool {
        compactText.count >= 14
    }

    private func compactTimeText(from text: String) -> String? {
        if let captures = capturedGroups(
            in: text,
            pattern: #"剩?([0-9]+)天([0-9]+)小时"#
        ), captures.count == 2 {
            return "\(captures[0])d \(captures[1])h left"
        }

        if let captures = capturedGroups(
            in: text,
            pattern: #"剩?([0-9]+)天"#
        ), let days = captures.first {
            return "\(days)d left"
        }

        if let captures = capturedGroups(
            in: text,
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

    private func diagnosticsMatchType(
        for translation: QuickLookDictionaryTranslation?
    ) -> QuickLookDictionaryDiagnosticsMatchType {
        guard let translation else {
            return .none
        }

        switch translation.matchKind {
        case .phraseOverride:
            return .phraseOverride
        case .exact:
            return .exact
        case .segment:
            return .segment
        case .singleAllowlist:
            return .singleAllowlist
        case .summary:
            return .summary
        case .contained:
            return .contained
        case .mixedPhrase:
            if translation.hasPreservedValue {
                return .mixedValue
            }

            return .multiPhrase
        case .amountUnit:
            return .mixedValue
        }
    }
}

struct QuickLookEnglishTextNormalizer {
    func normalize(_ text: String) -> String {
        var scalars = String.UnicodeScalarView()
        var previousWasWhitespace = false

        for scalar in text.precomposedStringWithCompatibilityMapping.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                if previousWasWhitespace == false {
                    scalars.append(" ")
                    previousWasWhitespace = true
                }

                continue
            }

            guard CharacterSet.controlCharacters.contains(scalar) == false else {
                continue
            }

            scalars.append(normalizedPunctuation(scalar))
            previousWasWhitespace = false
        }

        return String(scalars).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func compact(_ text: String) -> String {
        let normalized = normalize(text)
        var scalars = String.UnicodeScalarView()
        let ignored = CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)
            .union(.symbols)

        for scalar in normalized.unicodeScalars {
            guard ignored.contains(scalar) == false else {
                continue
            }

            scalars.append(scalar)
        }

        return String(scalars)
    }

    private func normalizedPunctuation(
        _ scalar: UnicodeScalar
    ) -> UnicodeScalar {
        switch scalar {
        case "，", "、":
            return ","
        case "。":
            return "."
        case "：":
            return ":"
        case "；":
            return ";"
        case "！":
            return "!"
        case "？":
            return "?"
        default:
            return scalar
        }
    }
}

private struct QuickLookEnglishTranslationResolution: Equatable {
    let translation: QuickLookDictionaryTranslation?
    let unresolvedReason: QuickLookDictionaryUnresolvedReason?

    init(
        translation: QuickLookDictionaryTranslation? = nil,
        unresolvedReason: QuickLookDictionaryUnresolvedReason? = nil
    ) {
        self.translation = translation
        self.unresolvedReason = unresolvedReason
    }
}

private struct QuickLookEnglishPhraseOverride: Equatable {
    let source: String
    let displayText: String
    let isImportant: Bool
}

private struct QuickLookEnglishOverrideCandidate: Equatable {
    let key: String
    let override: QuickLookEnglishPhraseOverride
    let start: Int
    let length: Int
}

private extension QuickLookEnglishTranslationProvider {
    static let singleCharacterAllowlist = [
        "车": "car",
        "船": "boat",
        "狗": "dog",
        "猫": "cat",
        "树": "tree",
        "花": "flower",
        "山": "mountain",
        "水": "water",
        "风": "wind",
        "雨": "rain",
        "手": "hand",
        "脚": "foot",
        "钱": "money",
        "桥": "bridge",
        "灯": "lamp",
        "窗": "window",
        "字": "character"
    ]

    static let phraseOverrides: [QuickLookEnglishPhraseOverride] = [
        QuickLookEnglishPhraseOverride(source: "登录", displayText: "log in", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "注册", displayText: "sign up", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "退出登录", displayText: "log out", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "验证码", displayText: "verification code", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "输入验证码", displayText: "verification code", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "网络错误", displayText: "network error", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "网络错误请重试", displayText: "network error · retry", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "请重试", displayText: "retry", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "打开设置", displayText: "open settings", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "暂无数据", displayText: "no data", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "暂无消息", displayText: "no messages", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "暂无内容", displayText: "no content", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "对方正在输入", displayText: "typing...", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "地铁路线", displayText: "metro route", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "支付失败", displayText: "payment failed", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "支付成功", displayText: "payment successful", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "订单已取消", displayText: "order canceled", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "订单已完成", displayText: "order completed", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "退款处理中", displayText: "refund processing", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "退款成功", displayText: "refund successful", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "退款失败", displayText: "refund failed", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "快递已发货", displayText: "shipped", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "物流已发货", displayText: "shipped", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "注册账号", displayText: "sign up", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "绑定手机号", displayText: "bind phone", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "解绑手机号", displayText: "unbind phone", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "修改地址", displayText: "change address", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "上传文件", displayText: "upload file", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "发送消息", displayText: "send message", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "权限不足", displayText: "insufficient permission", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "加载中", displayText: "loading", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "无法连接", displayText: "cannot connect", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "已过期", displayText: "expired", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "不支持", displayText: "not supported", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "购物车", displayText: "cart", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "优惠券", displayText: "coupon", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "红包", displayText: "red packet", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "支付", displayText: "pay", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "付款", displayText: "pay", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "退款", displayText: "refund", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "订单", displayText: "order", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "发货", displayText: "shipped", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "收货", displayText: "receive", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "地址", displayText: "address", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "淘金币", displayText: "Taobao Coins", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "领淘金币", displayText: "collect coins", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "淘宝秒杀", displayText: "flash sale", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "省钱卡", displayText: "savings card", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "试用领取", displayText: "claim trial", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "淘宝直播", displayText: "Taobao Live", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "直播价", displayText: "live price", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "直播有好价", displayText: "live deals", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "百亿补贴", displayText: "big subsidy", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "国家补贴", displayText: "national subsidy", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "政府补贴", displayText: "government subsidy", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "补贴价", displayText: "subsidized price", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "券后价", displayText: "after-coupon price", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "去使用", displayText: "use", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "待使用", displayText: "pending use", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "我的淘宝", displayText: "My Taobao", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "自助服务", displayText: "self service", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "猜你喜欢", displayText: "you may like", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "评价客服", displayText: "reviews / support", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "淘工厂", displayText: "Taobao Factory", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "高跟鞋", displayText: "high-heeled shoes", isImportant: false),
        QuickLookEnglishPhraseOverride(source: "洗面奶", displayText: "cleanser", isImportant: false),
        QuickLookEnglishPhraseOverride(source: "新版洗面奶", displayText: "cleanser", isImportant: false),
        QuickLookEnglishPhraseOverride(source: "化妆水", displayText: "toner", isImportant: false),
        QuickLookEnglishPhraseOverride(source: "免运费", displayText: "free shipping", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "现货", displayText: "in stock", isImportant: true),
        QuickLookEnglishPhraseOverride(source: "现货秒发", displayText: "in stock · fast shipping", isImportant: true)
    ]

    static let phraseOverrideLookup: [String: QuickLookEnglishPhraseOverride] = {
        var lookup: [String: QuickLookEnglishPhraseOverride] = [:]

        for override in phraseOverrides {
            lookup[override.source] = override
        }

        return lookup
    }()

    static let importantChineseTerms = [
        "搜索", "购物车", "付款", "支付", "订单", "发货", "收货", "物流",
        "快递", "退款", "地址", "优惠", "优惠券", "红包", "补贴",
        "券后价", "直播价", "验证码", "网络错误", "设置", "消息",
        "仓库", "包装", "标签", "货物", "运输"
    ]

    static let importantEnglishTerms = [
        "pay", "payment", "order", "refund", "ship", "shipping",
        "address", "search", "settings", "error", "retry", "cart",
        "coupon", "red packet", "subsidy", "login", "log in",
        "log out", "verification", "message", "location", "warehouse",
        "package", "label", "typing", "no data", "free shipping",
        "in stock"
    ]

    static let blockedSegmentLabels = [
        "a", "an", "the", "of", "and", "or", "to", "be", "is", "are",
        "have", "has", "do", "does", "can", "may", "very", "also",
        "again", "country", "province", "hour", "o'clock", "point",
        "dot", "classifier"
    ]
}
