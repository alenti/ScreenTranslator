import Foundation

struct QuickLookDictionaryTranslation: Equatable {
    let displayText: String
    let matchedSource: String
    let matchKind: QuickLookDictionaryMatchKind
    let isImportant: Bool
    let hasPreservedValue: Bool
    let sourceKind: String?
    let selectionReason: String?
    let englishRaw: String?
    let pinyin: String?

    init(
        displayText: String,
        matchedSource: String,
        matchKind: QuickLookDictionaryMatchKind,
        isImportant: Bool,
        hasPreservedValue: Bool,
        sourceKind: String? = nil,
        selectionReason: String? = nil,
        englishRaw: String? = nil,
        pinyin: String? = nil
    ) {
        self.displayText = displayText
        self.matchedSource = matchedSource
        self.matchKind = matchKind
        self.isImportant = isImportant
        self.hasPreservedValue = hasPreservedValue
        self.sourceKind = sourceKind
        self.selectionReason = selectionReason
        self.englishRaw = englishRaw
        self.pinyin = pinyin
    }
}

enum QuickLookDictionaryMatchKind: Equatable {
    case localMT
    case phraseOverride
    case exact
    case segment
    case singleAllowlist
    case summary
    case contained
    case mixedPhrase
    case amountUnit
}

struct QuickLookDictionaryDiagnostics: Equatable {
    let originalText: String
    let normalizedText: String
    let translation: QuickLookDictionaryTranslation?
    let matchType: QuickLookDictionaryDiagnosticsMatchType
    let unresolvedReason: QuickLookDictionaryUnresolvedReason?
}

enum QuickLookDictionaryDiagnosticsMatchType: String, Equatable {
    case localMT = "LOCAL_MT"
    case phraseOverride = "PHRASE"
    case exact = "EXACT"
    case segment = "SEG"
    case singleAllowlist = "SINGLE"
    case summary = "SUMMARY"
    case contained = "CONTAINED"
    case multiPhrase = "MULTI"
    case mixedValue = "VALUE"
    case none = "MISS"
}

enum QuickLookDictionaryUnresolvedReason: String, Equatable {
    case longUntranslated = "LONG_UNTRANSLATED"
}

struct QuickLookLocalDictionaryTranslationProvider {
    static var starterDictionaryEntryCount: Int {
        defaultEntries.count
    }

    private let normalizer: QuickLookDictionaryTextNormalizer
    private let exactLookup: [String: QuickLookDictionaryEntry]
    private let containedEntries: [QuickLookDictionaryEntry]
    private let amountUnitEntries: [QuickLookDictionaryEntry]

    init(entries: [QuickLookDictionaryEntry] = Self.defaultEntries) {
        let normalizer = QuickLookDictionaryTextNormalizer()
        var exactLookup: [String: QuickLookDictionaryEntry] = [:]

        for entry in entries {
            exactLookup[normalizer.compact(entry.source)] = entry
        }

        self.normalizer = normalizer
        self.exactLookup = exactLookup
        self.containedEntries = entries
            .filter(\.allowsContainedMatch)
            .sorted { lhs, rhs in
                let lhsLength = normalizer.compact(lhs.source).count
                let rhsLength = normalizer.compact(rhs.source).count

                if lhsLength != rhsLength {
                    return lhsLength > rhsLength
                }

                if lhs.isImportant != rhs.isImportant {
                    return lhs.isImportant
                }

                return lhs.source < rhs.source
            }
        self.amountUnitEntries = entries.filter(\.allowsAmountUnitMatch)
    }

    func normalizedSource(_ text: String) -> String {
        normalizer.normalize(text)
    }

    func diagnostics(for rawText: String) -> QuickLookDictionaryDiagnostics {
        let normalizedText = normalizedSource(rawText)
        let translation = translation(for: rawText)

        return QuickLookDictionaryDiagnostics(
            originalText: rawText,
            normalizedText: normalizedText,
            translation: translation,
            matchType: diagnosticsMatchType(for: translation),
            unresolvedReason: nil
        )
    }

    func translation(for rawText: String) -> QuickLookDictionaryTranslation? {
        let normalizedText = normalizedSource(rawText)
        let compactText = normalizer.compact(normalizedText)

        guard compactText.isEmpty == false else {
            return nil
        }

        if let exactEntry = exactLookup[compactText] {
            return QuickLookDictionaryTranslation(
                displayText: exactEntry.russian,
                matchedSource: exactEntry.source,
                matchKind: .exact,
                isImportant: exactEntry.isImportant,
                hasPreservedValue: false
            )
        }

        let phraseMatches = selectedPhraseMatches(in: compactText)

        if phraseMatches.isEmpty == false,
           let displayText = displayText(
               for: phraseMatches,
               compactText: compactText
           ) {
            let hasPreservedValue = preservedValueText(
                from: compactText
            ).isEmpty == false
            let matchKind: QuickLookDictionaryMatchKind =
                phraseMatches.count > 1 || hasPreservedValue
                    ? .mixedPhrase
                    : .contained

            return QuickLookDictionaryTranslation(
                displayText: displayText,
                matchedSource: phraseMatches
                    .map(\.entry.source)
                    .joined(separator: " + "),
                matchKind: matchKind,
                isImportant: phraseMatches.contains { $0.entry.isImportant },
                hasPreservedValue: hasPreservedValue
            )
        }

        for entry in amountUnitEntries {
            let compactSource = normalizer.compact(entry.source)

            guard compactText.contains(compactSource),
                  compactText.contains(where: \.isNumber) else {
                continue
            }

            let valueText = preservedValueText(from: compactText)

            guard valueText.isEmpty == false else {
                continue
            }

            return QuickLookDictionaryTranslation(
                displayText: valueText,
                matchedSource: entry.source,
                matchKind: .amountUnit,
                isImportant: entry.isImportant,
                hasPreservedValue: true
            )
        }

        return nil
    }

    private func diagnosticsMatchType(
        for translation: QuickLookDictionaryTranslation?
    ) -> QuickLookDictionaryDiagnosticsMatchType {
        guard let translation else {
            return .none
        }

        switch translation.matchKind {
        case .localMT:
            return .localMT
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

    private func selectedPhraseMatches(
        in compactText: String
    ) -> [QuickLookDictionaryPhraseMatch] {
        var candidates: [QuickLookDictionaryPhraseMatch] = []

        for entry in containedEntries {
            let compactSource = normalizer.compact(entry.source)

            guard compactSource.isEmpty == false else {
                continue
            }

            var searchRange = compactText.startIndex..<compactText.endIndex

            while let range = compactText.range(
                of: compactSource,
                options: [],
                range: searchRange
            ) {
                candidates.append(
                    QuickLookDictionaryPhraseMatch(
                        entry: entry,
                        compactSource: compactSource,
                        range: range
                    )
                )

                searchRange = range.upperBound..<compactText.endIndex

                if searchRange.isEmpty {
                    break
                }
            }
        }

        let sortedCandidates = candidates.sorted { lhs, rhs in
            if lhs.compactSource.count != rhs.compactSource.count {
                return lhs.compactSource.count > rhs.compactSource.count
            }

            if lhs.entry.isImportant != rhs.entry.isImportant {
                return lhs.entry.isImportant
            }

            return compactText.distance(
                from: compactText.startIndex,
                to: lhs.range.lowerBound
            ) < compactText.distance(
                from: compactText.startIndex,
                to: rhs.range.lowerBound
            )
        }

        var selected: [QuickLookDictionaryPhraseMatch] = []

        for candidate in sortedCandidates {
            guard selected.contains(where: { $0.range.overlaps(candidate.range) }) == false else {
                continue
            }

            selected.append(candidate)

            if selected.count == 3 {
                break
            }
        }

        return selected.sorted { lhs, rhs in
            compactText.distance(
                from: compactText.startIndex,
                to: lhs.range.lowerBound
            ) < compactText.distance(
                from: compactText.startIndex,
                to: rhs.range.lowerBound
            )
        }
    }

    private func displayText(
        for matches: [QuickLookDictionaryPhraseMatch],
        compactText: String
    ) -> String? {
        var segments: [QuickLookDictionaryDisplaySegment] = []
        var currentIndex = compactText.startIndex

        for match in matches {
            let leadingValueText = preservedValueText(
                from: String(compactText[currentIndex..<match.range.lowerBound])
            )

            if leadingValueText.isEmpty == false {
                if match.entry.source == "周年庆" {
                    segments.append(.phrase(match.entry.russian))
                    segments.append(.value(leadingValueText))
                    currentIndex = match.range.upperBound
                    continue
                } else if match.entry.source == "点抢" {
                    segments.append(
                        .phrase("\(match.entry.russian) \(leadingValueText):00")
                    )
                    currentIndex = match.range.upperBound
                    continue
                } else {
                    segments.append(.value(leadingValueText))
                }
            }

            segments.append(.phrase(match.entry.russian))
            currentIndex = match.range.upperBound
        }

        let trailingValueText = preservedValueText(
            from: String(compactText[currentIndex..<compactText.endIndex])
        )

        if trailingValueText.isEmpty == false {
            segments.append(.value(trailingValueText))
        }

        let formatted = formattedDisplayText(from: segments)
        return formatted.isEmpty ? nil : formatted
    }

    private func formattedDisplayText(
        from segments: [QuickLookDictionaryDisplaySegment]
    ) -> String {
        var output = ""
        var previousSegment: QuickLookDictionaryDisplaySegment?
        var phraseCount = 0

        for segment in segments {
            let text = segment.text

            guard text.isEmpty == false else {
                continue
            }

            switch segment {
            case .phrase:
                let separator: String

                if output.isEmpty {
                    separator = ""
                } else if previousSegment?.isPhrase == true {
                    separator = ", "
                } else if previousSegment?.isValue == true && phraseCount > 0 {
                    separator = ", "
                } else {
                    separator = " "
                }

                output += separator + text
                phraseCount += 1
            case .value:
                output += (output.isEmpty ? "" : " ") + text
            }

            previousSegment = segment
        }

        return normalizer.collapseWhitespace(output)
    }

    private func preservedValueText(from normalizedText: String) -> String {
        let compactText = normalizer.compact(normalizedText)

        if let timeValueText = timeValueText(from: compactText) {
            return timeValueText
        }

        if let discountValueText = discountValueText(from: compactText) {
            return discountValueText
        }

        return genericValueText(from: normalizedText)
    }

    private func timeValueText(from compactText: String) -> String? {
        if let captures = capturedGroups(
            in: compactText,
            pattern: #"剩?([0-9]+)天([0-9]+)小时"#
        ), captures.count == 2 {
            let days = captures[0]
            let hours = captures[1]
            let prefix = compactText.contains("剩") ? "осталось " : ""

            return "\(prefix)\(days) \(dayWord(for: days)) \(hours) \(hourWord(for: hours))"
        }

        if let captures = capturedGroups(
            in: compactText,
            pattern: #"剩?([0-9]+)天"#
        ), captures.count == 1 {
            let days = captures[0]
            let prefix = compactText.contains("剩") ? "осталось " : ""

            return "\(prefix)\(days) \(dayWord(for: days))"
        }

        if let captures = capturedGroups(
            in: compactText,
            pattern: #"剩?([0-9]+)小时"#
        ), captures.count == 1 {
            let hours = captures[0]
            let prefix = compactText.contains("剩") ? "осталось " : ""

            return "\(prefix)\(hours) \(hourWord(for: hours))"
        }

        return nil
    }

    private func discountValueText(from compactText: String) -> String? {
        guard compactText.contains("折"),
              compactText.contains(where: \.isNumber),
              let captures = capturedGroups(
                  in: compactText,
                  pattern: #"([0-9]+(?:[.,][0-9]+)?)折"#
              ),
              captures.isEmpty == false else {
            return nil
        }

        let discount = captures[0]

        if compactText.contains("起") {
            return "скидка от \(discount)折"
        }

        return "скидка \(discount)折"
    }

    private func genericValueText(from normalizedText: String) -> String {
        let hasFromMarker = normalizedText.contains("起")
            && normalizedText.contains(where: \.isNumber)
        let localizedUnits = normalizedText
            .replacingOccurrences(of: "元", with: " юаней ")
            .replacingOccurrences(of: "件", with: " шт. ")
            .replacingOccurrences(of: "张", with: " шт. ")
            .replacingOccurrences(of: "￥", with: "¥")
        let valueScalars = localizedUnits.unicodeScalars.filter { scalar in
            isCJKUnifiedIdeograph(scalar) == false
        }
        let trimmed = valueTokens(
            from: String(String.UnicodeScalarView(valueScalars))
        ).joined(separator: " ")

        guard trimmed.isEmpty == false else {
            return ""
        }

        if hasFromMarker {
            return "от \(trimmed)"
        }

        return trimmed
    }

    private func valueTokens(from text: String) -> [String] {
        let localizedUnitWords: Set<String> = [
            "юаней",
            "шт",
            "шт.",
            "день",
            "дня",
            "дней",
            "час",
            "часа",
            "часов"
        ]
        let rawTokens = normalizer
            .collapseWhitespace(text)
            .components(separatedBy: .whitespacesAndNewlines)
        var tokens: [String] = []

        for rawToken in rawTokens {
            let trimmedToken = rawToken.trimmingCharacters(
                in: CharacterSet.whitespacesAndNewlines
                    .union(CharacterSet(charactersIn: ":;|/\\-_"))
            )

            if localizedUnitWords.contains(trimmedToken) {
                tokens.append(trimmedToken == "шт" ? "шт." : trimmedToken)
                continue
            }

            let filteredScalars = trimmedToken.unicodeScalars.filter { scalar in
                CharacterSet.decimalDigits.contains(scalar)
                    || CharacterSet(charactersIn: "¥$€₽%.,+").contains(scalar)
            }
            let filteredToken = String(
                String.UnicodeScalarView(filteredScalars)
            ).trimmingCharacters(in: CharacterSet(charactersIn: ",."))

            guard filteredToken.isEmpty == false else {
                continue
            }

            tokens.append(filteredToken)
        }

        return tokens
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

    private func dayWord(for value: String) -> String {
        russianCountWord(
            for: value,
            one: "день",
            few: "дня",
            many: "дней"
        )
    }

    private func hourWord(for value: String) -> String {
        russianCountWord(
            for: value,
            one: "час",
            few: "часа",
            many: "часов"
        )
    }

    private func russianCountWord(
        for value: String,
        one: String,
        few: String,
        many: String
    ) -> String {
        guard let number = Int(value) else {
            return many
        }

        let lastTwoDigits = number % 100
        let lastDigit = number % 10

        if lastTwoDigits >= 11 && lastTwoDigits <= 14 {
            return many
        }

        if lastDigit == 1 {
            return one
        }

        if (2...4).contains(lastDigit) {
            return few
        }

        return many
    }

    private func isCJKUnifiedIdeograph(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF,
             0x4E00...0x9FFF,
             0xF900...0xFAFF,
             0x20000...0x2A6DF,
             0x2A700...0x2B73F,
             0x2B740...0x2B81F,
             0x2B820...0x2CEAF,
             0x2F800...0x2FA1F:
            return true
        default:
            return false
        }
    }
}

struct QuickLookDictionaryEntry: Equatable {
    let source: String
    let russian: String
    let isImportant: Bool
    let allowsContainedMatch: Bool
    let allowsAmountUnitMatch: Bool
}

private struct QuickLookDictionaryPhraseMatch: Equatable {
    let entry: QuickLookDictionaryEntry
    let compactSource: String
    let range: Range<String.Index>
}

private enum QuickLookDictionaryDisplaySegment: Equatable {
    case phrase(String)
    case value(String)

    var text: String {
        switch self {
        case let .phrase(text), let .value(text):
            text
        }
    }

    var isPhrase: Bool {
        if case .phrase = self {
            return true
        }

        return false
    }

    var isValue: Bool {
        if case .value = self {
            return true
        }

        return false
    }
}

private struct QuickLookDictionaryTextNormalizer {
    func normalize(_ text: String) -> String {
        var normalized = text.applyingTransform(
            .fullwidthToHalfwidth,
            reverse: false
        ) ?? text

        normalized = normalized
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "￥", with: "¥")
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "。", with: ".")
            .replacingOccurrences(of: "、", with: " ")

        let invisibleCharacters = CharacterSet(
            charactersIn: "\u{200B}\u{200C}\u{200D}\u{2060}\u{FEFF}"
        )
        let filteredScalars = normalized.unicodeScalars.filter { scalar in
            invisibleCharacters.contains(scalar) == false
                && CharacterSet.controlCharacters.contains(scalar) == false
        }

        return collapseWhitespace(String(String.UnicodeScalarView(filteredScalars)))
    }

    func compact(_ text: String) -> String {
        normalize(text)
            .unicodeScalars
            .filter { CharacterSet.whitespacesAndNewlines.contains($0) == false }
            .map(String.init)
            .joined()
    }

    func collapseWhitespace(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension QuickLookLocalDictionaryTranslationProvider {
    static let defaultEntries: [QuickLookDictionaryEntry] = [
        entry("付款", "оплата", important: true),
        entry("支付", "оплатить", important: true),
        entry("立即支付", "оплатить сейчас", important: true),
        entry("立即购买", "купить сейчас", important: true),
        entry("购买", "купить"),
        entry("订单", "заказ", important: true),
        entry("我的订单", "мои заказы", important: true),
        entry("提交订单", "оформить заказ", important: true),
        entry("确认订单", "подтвердить заказ", important: true),
        entry("取消订单", "отменить заказ", important: true),
        entry("已付款", "оплачено", important: true),
        entry("待付款", "ожидает оплаты", important: true),
        entry("已完成", "завершено"),
        entry("发货", "отправка", important: true),
        entry("已发货", "отправлено", important: true),
        entry("待发货", "ожидает отправки", important: true),
        entry("收货", "получение", important: true),
        entry("确认收货", "подтвердить получение", important: true),
        entry("物流", "доставка", important: true),
        entry("查看物流", "отследить доставку", important: true),
        entry("快递", "курьер"),
        entry("运费", "доставка"),
        entry("包邮", "бесплатная доставка"),
        entry("地址", "адрес", important: true),
        entry("收货地址", "адрес доставки", important: true),
        entry("退款", "возврат денег", important: true),
        entry("退货", "возврат товара", important: true),
        entry("退货退款", "возврат товара и денег", important: true),
        entry("售后", "поддержка после покупки"),
        entry("客服", "поддержка", important: true),
        entry("联系客服", "связаться с поддержкой", important: true),
        entry("联系卖家", "связаться с продавцом", important: true),
        entry("帮助", "помощь"),
        entry("商品", "товар"),
        entry("店铺", "магазин", important: true),
        entry("卖家", "продавец"),
        entry("买家", "покупатель"),
        entry("价格", "цена"),
        entry("数量", "количество"),
        entry("优惠", "скидка"),
        entry("优惠券", "купон"),
        entry("购物金", "баланс покупок", important: true),
        entry("充值", "пополнить", important: true),
        entry("充值膨胀", "бонус за пополнение", important: true),
        entry("购物金充值", "пополнить баланс", important: true),
        entry("购物金充值膨胀", "бонус за пополнение", important: true),
        entry("加入购物车", "в корзину", important: true),
        entry("购物车", "корзина", important: true),
        entry("规格", "параметры"),
        entry("尺码", "размер"),
        entry("颜色", "цвет"),
        entry("库存", "в наличии"),
        entry("评价", "отзывы"),
        entry("详情", "детали"),
        entry("确认", "подтвердить", important: true),
        entry("取消", "отменить", important: true),
        entry("返回", "назад", important: true),
        entry("保存", "сохранить"),
        entry("删除", "удалить"),
        entry("编辑", "редактировать"),
        entry("复制", "копировать"),
        entry("搜索", "поиск", important: true),
        entry("下一步", "далее", important: true),
        entry("完成", "готово", important: true),
        entry("关闭", "закрыть"),
        entry("打开", "открыть"),
        entry("设置", "настройки"),
        entry("成功", "успешно"),
        entry("失败", "не удалось"),
        entry("错误", "ошибка", important: true),
        entry("加载中", "загрузка"),
        entry("请稍后", "подождите"),
        entry("暂无", "пока нет"),
        entry("更多", "ещё"),
        entry("全部", "все"),
        entry("推荐", "рекомендации", important: true),
        entry("热门", "популярное"),
        entry("元", "юань", important: true, amountUnit: true),
        entry("件", "шт.", important: true, amountUnit: true),
        entry("合计", "итого", important: true),
        entry("总计", "всего", important: true),
        entry("实付款", "оплачено", important: true),
        entry("应付款", "к оплате", important: true),

        entry("关注", "подписки", important: true),
        entry("闪购", "флеш-распродажа", important: true),
        entry("外卖", "доставка еды"),
        entry("山姆外卖", "доставка еды", important: true),
        entry("山外卖", "доставка еды", important: true),
        entry("国补", "гос. субсидия", important: true),
        entry("飞猪", "путешествия"),
        entry("周年庆", "годовщина", important: true),
        entry("穿搭", "образы", important: true),
        entry("红包", "купон", important: true),
        entry("淘票票", "билеты"),
        entry("淘", "Taobao", important: true),
        entry("淘宝秒杀", "распродажа", important: true),
        entry("领淘金币", "получить монеты", important: true),
        entry("淘金币", "монеты"),
        entry("试用领取", "получить пробник", important: true),
        entry("淘工厂", "фабрика Taobao"),
        entry("女款", "женское"),
        entry("男款", "мужское"),
        entry("夏季", "летний"),
        entry("冬季", "зимний"),
        entry("春季", "весенний"),
        entry("秋季", "осенний"),
        entry("直筒", "прямой крой"),
        entry("西装裤", "костюмные брюки"),
        entry("显腿直", "стройнит ноги"),
        entry("高跟鞋", "туфли на каблуке"),
        entry("轻熟", "элегантный стиль"),
        entry("绝美", "очень красивый"),
        entry("轻熟绝美高跟鞋", "туфли на каблуке"),
        entry("爆款", "хит продаж"),
        entry("新款", "новинка"),
        entry("正品", "оригинал"),
        entry("官方", "официальный"),
        entry("自营", "официальный магазин"),
        entry("天猫", "Tmall"),
        entry("淘宝", "Taobao"),
        entry("淘宝直播", "Taobao Live", important: true),
        entry("直播", "прямой эфир"),
        entry("直播价", "цена в эфире", important: true),
        entry("直播有好价", "хорошие цены в эфире", important: true),
        entry("百亿补贴", "большие субсидии", important: true),
        entry("国家补贴", "гос. субсидия", important: true),
        entry("政府补贴", "гос. субсидия", important: true),
        entry("补贴", "субсидия", important: true),
        entry("补贴价", "цена со скидкой", important: true),
        entry("官方立减", "официальная скидка", important: true),
        entry("立减", "скидка", important: true),
        entry("约省", "экономия около", important: true),
        entry("省", "экономия"),
        entry("立即领取", "получить сейчас", important: true),
        entry("领取", "получить", important: true),
        entry("去使用", "использовать", important: true),
        entry("去购买", "купить", important: true),
        entry("去看看", "посмотреть", important: true),
        entry("立即抢购", "купить сейчас", important: true),
        entry("抢购", "купить срочно", important: true),
        entry("20点抢", "успей к 20:00", important: true),
        entry("点抢", "успей к", important: true),
        entry("抢", "успеть", important: true),
        entry("加购", "добавить в корзину", important: true),
        entry("添加购物车", "добавили в корзину", important: true),
        entry("首页", "главная", important: true),
        entry("消息", "сообщения", important: true),
        entry("我的淘宝", "мой Taobao", important: true),
        entry("我的", "мой профиль", important: true),
        entry("AI助手", "AI помощник", important: true),
        entry("到手价", "итоговая цена", important: true),
        entry("券后价", "цена с купоном", important: true),
        entry("原价", "старая цена", important: true),
        entry("现价", "текущая цена", important: true),
        entry("月销", "продаж в месяц", important: true),
        entry("人付款", "оплатили", important: true),
        entry("已售", "продано", important: true),
        entry("多功能蒸煮一体锅", "многофункциональная пароварка", important: true),
        entry("拼团", "групповая покупка", important: true),
        entry("省钱卡", "карта экономии", important: true),
        entry("消费券", "купон на покупки", important: true),
        entry("待使用", "ожидает использования", important: true),
        entry("视频", "видео", important: true),
        entry("图集", "галерея"),
        entry("宝贝讲解", "обзор товара", important: true),
        entry("组合套装", "комплект", important: true),
        entry("送礼", "подарок"),
        entry("店铺评分", "рейтинг магазина", important: true),
        entry("店铺评分超过", "рейтинг магазина выше", important: true),
        entry("现货", "в наличии", important: true),
        entry("现货秒发", "в наличии, быстрая отправка", important: true),
        entry("秒发", "быстрая отправка", important: true),
        entry("专柜", "официальный магазин"),
        entry("新版", "новая версия"),
        entry("洗面奶", "пенка для умывания"),
        entry("化妆水", "тонер"),
        entry("导入液", "сыворотка"),
        entry("基底", "основа"),
        entry("发酵液", "ферментированная эссенция"),
        entry("免运费", "бесплатная доставка", important: true),
        entry("快递免运费", "бесплатная доставка", important: true),
        entry("分享", "поделиться", important: true),
        entry("收藏", "избранное", important: true),
        entry("店铺半牛超", "рейтинг магазина высокий", important: true),
        entry("好评", "хорошие отзывы", important: true),
        entry("超过", "более"),
        entry("起", "от", important: true, amountUnit: true),
        entry("张", "шт.", important: true, amountUnit: true),
        entry("天", "день", important: true, amountUnit: true),
        entry("小时", "час", important: true, amountUnit: true),
        entry("¥", "¥", amountUnit: true)
    ]

    static func entry(
        _ source: String,
        _ russian: String,
        important: Bool = false,
        amountUnit: Bool = false,
        containedMatch: Bool? = nil
    ) -> QuickLookDictionaryEntry {
        QuickLookDictionaryEntry(
            source: source,
            russian: russian,
            isImportant: important || amountUnit,
            allowsContainedMatch: containedMatch ?? (source.count > 1),
            allowsAmountUnitMatch: amountUnit
        )
    }
}
