import CoreGraphics
import Foundation

struct QuickLookTextLine: Equatable {
    let observationIndex: Int
    let text: String
    let frame: CGRect
    let confidence: Double
}

struct QuickLookTextGroup: Equatable {
    let id: String
    let sourceText: String
    let frame: CGRect
    let childFrames: [CGRect]
    let childTexts: [String]
    let childObservationIndices: [Int]
    let blockType: QuickLookTextGroupBlockType
    let confidence: Double
    let lineCount: Int
}

enum QuickLookTextGroupBlockType: String, Equatable {
    case chatBubble
    case paragraph
    case uiLabel
    case button
    case productCard
    case addressBlock
    case unknown
}

struct QuickLookTextBlockGrouper {
    func group(
        lines: [QuickLookTextLine],
        canvasSize: CGSize
    ) -> [QuickLookTextGroup] {
        guard lines.isEmpty == false else {
            return []
        }

        let sortedLines = lines.sorted { lhs, rhs in
            let rowTolerance = max(lhs.frame.height, rhs.frame.height) * 0.45

            if abs(lhs.frame.minY - rhs.frame.minY) > rowTolerance {
                return lhs.frame.minY < rhs.frame.minY
            }

            return lhs.frame.minX < rhs.frame.minX
        }

        var rawGroups: [[QuickLookTextLine]] = []
        var currentGroup: [QuickLookTextLine] = []

        for line in sortedLines {
            guard currentGroup.isEmpty == false else {
                currentGroup = [line]
                continue
            }

            if shouldMerge(
                currentGroup: currentGroup,
                nextLine: line,
                canvasSize: canvasSize
            ) {
                currentGroup.append(line)
            } else {
                rawGroups.append(currentGroup)
                currentGroup = [line]
            }
        }

        if currentGroup.isEmpty == false {
            rawGroups.append(currentGroup)
        }

        return rawGroups.enumerated().map { index, groupLines in
            makeTextGroup(
                id: "group_\(index)",
                lines: groupLines,
                canvasSize: canvasSize
            )
        }
    }

    private func shouldMerge(
        currentGroup: [QuickLookTextLine],
        nextLine: QuickLookTextLine,
        canvasSize: CGSize
    ) -> Bool {
        guard let previousLine = currentGroup.last else {
            return false
        }

        let nextFrame = nextLine.frame.standardized
        let previousFrame = previousLine.frame.standardized
        let groupFrame = unionFrame(for: currentGroup.map(\.frame))
        let verticalGap = nextFrame.minY - previousFrame.maxY
        let averageLineHeight = max(
            1,
            (previousFrame.height + nextFrame.height) / 2
        )

        if verticalGap < -(averageLineHeight * 0.55) {
            return false
        }

        if verticalGap > max(averageLineHeight * 0.95, canvasSize.height * 0.018) {
            return false
        }

        if shouldSplitParagraph(
            currentGroup: currentGroup,
            nextLine: nextLine,
            groupFrame: groupFrame,
            verticalGap: verticalGap,
            averageLineHeight: averageLineHeight,
            canvasSize: canvasSize
        ) {
            return false
        }

        if isBottomNavigation(line: previousLine, canvasSize: canvasSize)
            || isBottomNavigation(line: nextLine, canvasSize: canvasSize) {
            return false
        }

        if isStandaloneIdentifier(previousLine.text)
            || isStandaloneIdentifier(nextLine.text) {
            return false
        }

        let horizontalOverlap = overlapRatio(
            lhs: groupFrame,
            rhs: nextFrame
        )
        let xAligned = abs(groupFrame.minX - nextFrame.minX)
            <= max(averageLineHeight * 2.2, canvasSize.width * 0.08)
        let centerAligned = abs(groupFrame.midX - nextFrame.midX)
            <= max(groupFrame.width, nextFrame.width) * 0.34
        let similarWidth = widthSimilarity(
            lhs: groupFrame.width,
            rhs: nextFrame.width
        ) >= 0.48

        guard horizontalOverlap >= 0.30 || xAligned || centerAligned else {
            return false
        }

        let currentText = joinedText(for: currentGroup.map(\.text))
        let currentLooksParagraphLike = currentGroup.count >= 2
            || currentText.count >= 14
            || looksSentenceLike(currentText)
        let nextLooksParagraphLike = nextLine.text.count >= 9
            || looksSentenceLike(nextLine.text)

        if isButtonLike(text: previousLine.text)
            || isButtonLike(text: nextLine.text) {
            return currentLooksParagraphLike
                && nextLooksParagraphLike
                && horizontalOverlap >= 0.45
        }

        if isShortIsolatedUILabel(line: previousLine, canvasSize: canvasSize)
            && isShortIsolatedUILabel(line: nextLine, canvasSize: canvasSize)
            && currentLooksParagraphLike == false {
            return false
        }

        if currentLooksParagraphLike || nextLooksParagraphLike {
            return horizontalOverlap >= 0.20 || xAligned || similarWidth
        }

        return horizontalOverlap >= 0.55 && similarWidth
    }

    private func makeTextGroup(
        id: String,
        lines: [QuickLookTextLine],
        canvasSize: CGSize
    ) -> QuickLookTextGroup {
        let childFrames = lines.map(\.frame)
        let childTexts = lines.map(\.text)
        let frame = unionFrame(for: childFrames)
        let sourceText = joinedText(for: childTexts)
        let confidence = lines.map(\.confidence).reduce(0, +)
            / Double(max(lines.count, 1))
        let blockType = classify(
            sourceText: sourceText,
            frame: frame,
            lineCount: lines.count,
            canvasSize: canvasSize
        )

        return QuickLookTextGroup(
            id: id,
            sourceText: sourceText,
            frame: frame,
            childFrames: childFrames,
            childTexts: childTexts,
            childObservationIndices: lines.map(\.observationIndex),
            blockType: blockType,
            confidence: confidence,
            lineCount: lines.count
        )
    }

    private func joinedText(for texts: [String]) -> String {
        var output = ""

        for text in texts.map(normalizedText).filter({ $0.isEmpty == false }) {
            guard output.isEmpty == false else {
                output = text
                continue
            }

            if shouldInsertSeparator(previous: output, next: text) {
                output += " \(text)"
            } else {
                output += text
            }
        }

        return output
    }

    private func shouldInsertSeparator(
        previous: String,
        next: String
    ) -> Bool {
        guard let lastCharacter = previous.last,
              let firstCharacter = next.first else {
            return false
        }

        if "。！？!?；;，,、：:".contains(lastCharacter) {
            return true
        }

        if isASCIIOrDigit(lastCharacter) || isASCIIOrDigit(firstCharacter) {
            return true
        }

        return false
    }

    private func classify(
        sourceText: String,
        frame: CGRect,
        lineCount: Int,
        canvasSize: CGSize
    ) -> QuickLookTextGroupBlockType {
        if containsAny(sourceText, [
            "地址",
            "仓库",
            "运输",
            "物流",
            "快递",
            "货物",
            "包装",
            "标签",
            "外箱"
        ]) {
            return .addressBlock
        }

        if containsAny(sourceText, [
            "购物车",
            "付款",
            "支付",
            "订单",
            "确认",
            "取消",
            "领取",
            "去使用",
            "购买",
            "抢购",
            "搜索",
            "登录"
        ]) && lineCount == 1 {
            return .button
        }

        if containsAny(sourceText, [
            "¥",
            "￥",
            "元",
            "优惠",
            "券",
            "价",
            "商品",
            "详情",
            "评价",
            "高跟鞋",
            "洗面奶",
            "化妆水"
        ]) {
            return .productCard
        }

        let widthRatio = frame.width / max(canvasSize.width, 1)
        if lineCount >= 2 && widthRatio >= 0.34 {
            return .chatBubble
        }

        if lineCount >= 2 {
            return .paragraph
        }

        if sourceText.count <= 8 {
            return .uiLabel
        }

        return .unknown
    }

    private func unionFrame(for frames: [CGRect]) -> CGRect {
        frames.map(\.standardized)
            .filter { $0.isNull == false && $0.isEmpty == false }
            .reduce(CGRect.null) { partialResult, frame in
                partialResult.isNull ? frame : partialResult.union(frame)
            }
    }

    private func overlapRatio(lhs: CGRect, rhs: CGRect) -> CGFloat {
        let lhsFrame = lhs.standardized
        let rhsFrame = rhs.standardized
        let overlap = max(
            0,
            min(lhsFrame.maxX, rhsFrame.maxX)
                - max(lhsFrame.minX, rhsFrame.minX)
        )
        let smallerWidth = max(1, min(lhsFrame.width, rhsFrame.width))

        return overlap / smallerWidth
    }

    private func widthSimilarity(lhs: CGFloat, rhs: CGFloat) -> CGFloat {
        let larger = max(lhs, rhs, 1)
        let smaller = max(min(lhs, rhs), 1)

        return smaller / larger
    }

    private func isBottomNavigation(
        line: QuickLookTextLine,
        canvasSize: CGSize
    ) -> Bool {
        let frame = line.frame.standardized

        return frame.midY / max(canvasSize.height, 1) > 0.88
            && line.text.count <= 8
    }

    private func isShortIsolatedUILabel(
        line: QuickLookTextLine,
        canvasSize: CGSize
    ) -> Bool {
        line.text.count <= 6
            && line.frame.width / max(canvasSize.width, 1) < 0.32
            && looksSentenceLike(line.text) == false
    }

    private func isButtonLike(text: String) -> Bool {
        containsAny(text, [
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
            "提交"
        ]) && text.count <= 8
    }

    private func shouldSplitParagraph(
        currentGroup: [QuickLookTextLine],
        nextLine: QuickLookTextLine,
        groupFrame: CGRect,
        verticalGap: CGFloat,
        averageLineHeight: CGFloat,
        canvasSize: CGSize
    ) -> Bool {
        guard let previousLine = currentGroup.last else {
            return false
        }

        let previousText = normalizedText(previousLine.text)
        let nextText = normalizedText(nextLine.text)
        let nextFrame = nextLine.frame.standardized
        let nonTrivialGap = verticalGap > max(2, averageLineHeight * 0.22)
        let meaningfulGap = verticalGap > max(3, averageLineHeight * 0.38)
        let xShift = abs(groupFrame.minX - nextFrame.minX)
        let frameMoved = xShift > max(averageLineHeight * 1.55, canvasSize.width * 0.052)
        let currentText = joinedText(for: currentGroup.map(\.text))

        if nonTrivialGap,
           endsWithStrongPunctuation(previousText),
           startsNewThought(nextText) || meaningfulGap {
            return true
        }

        if nonTrivialGap,
           startsNewThought(nextText),
           currentText.count >= 18 || currentGroup.count >= 2 {
            return true
        }

        if frameMoved,
           nonTrivialGap,
           startsNewThought(nextText) || endsWithStrongPunctuation(previousText) {
            return true
        }

        return false
    }

    private func endsWithStrongPunctuation(_ text: String) -> Bool {
        guard let lastCharacter = text.last else {
            return false
        }

        return "。！？!?；;".contains(lastCharacter)
    }

    private func startsNewThought(_ text: String) -> Bool {
        startsWithAny(text, [
            "但是",
            "我现在",
            "麻烦",
            "请您",
            "我会",
            "另外",
            "如果",
            "所以",
            "因为",
            "因此",
            "然后",
            "之前",
            "抱歉",
            "不好意思",
            "需要",
            "可以"
        ])
    }

    private func looksSentenceLike(_ text: String) -> Bool {
        text.count >= 12 || containsAny(text, [
            "，",
            "。",
            "？",
            "！",
            ",",
            ".",
            "?",
            "!",
            "请",
            "如果",
            "因为",
            "必须",
            "需要",
            "方便",
            "可以",
            "无法"
        ])
    }

    private func isStandaloneIdentifier(_ text: String) -> Bool {
        let compact = normalizedText(text)
        guard compact.count >= 8 else {
            return false
        }

        let scalarCount = max(compact.unicodeScalars.count, 1)
        let digitOrASCII = compact.unicodeScalars.filter { scalar in
            isASCIILetterOrDigit(scalar)
        }.count

        return Double(digitOrASCII) / Double(scalarCount) >= 0.75
    }

    private func normalizedText(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isASCIIOrDigit(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { scalar in
            isASCIILetterOrDigit(scalar)
                || (scalar.value >= 0x20 && scalar.value <= 0x7E)
        }
    }

    private func isASCIILetterOrDigit(_ scalar: UnicodeScalar) -> Bool {
        (scalar.value >= 0x30 && scalar.value <= 0x39)
            || (scalar.value >= 0x41 && scalar.value <= 0x5A)
            || (scalar.value >= 0x61 && scalar.value <= 0x7A)
    }

    private func containsAny(
        _ text: String,
        _ tokens: [String]
    ) -> Bool {
        tokens.contains { text.contains($0) }
    }

    private func startsWithAny(
        _ text: String,
        _ tokens: [String]
    ) -> Bool {
        tokens.contains { text.hasPrefix($0) }
    }
}
