import CoreGraphics
import Foundation

struct BoundingBoxGrouper: Sendable {
    struct Configuration: Equatable, Sendable {
        let sameLineMinimumVerticalOverlap: CGFloat
        let sameLineCenterToleranceMultiplier: CGFloat
        let sameLineMinimumCompatibilityScore: CGFloat
        let sameLineCJKHorizontalGapMultiplier: CGFloat
        let sameLineMixedHorizontalGapMultiplier: CGFloat
        let sameLineLatinHorizontalGapMultiplier: CGFloat
        let sameLineMinimumStrictHorizontalGap: CGFloat
        let sameLineShortFragmentMaximumCharacterCount: Int
        let sameLineShortFragmentMinimumGap: CGFloat
        let sameLineShortFragmentCJKGapToCharacterWidthMultiplier: CGFloat
        let sameLineShortFragmentMixedGapToCharacterWidthMultiplier: CGFloat
        let sameLineShortFragmentLatinGapToCharacterWidthMultiplier: CGFloat
        let compactBlockMaximumCharacterCount: Int
        let compactBlockMaximumWidthToHeightRatio: CGFloat
        let compactBlockVerticalGapMultiplier: CGFloat
        let compactBlockMinimumVerticalGap: CGFloat
        let compactBlockMinimumAlignmentScore: CGFloat
        let compactBlockMinimumWidthSimilarity: CGFloat
        let compactBlockMaximumCenterDeltaMultiplier: CGFloat
        let compactBlockProfileMismatchVerticalGapMultiplier: CGFloat
        let blockVerticalGapMultiplier: CGFloat
        let blockMinimumVerticalGap: CGFloat
        let blockMinimumHorizontalOverlap: CGFloat
        let blockAlignmentToleranceMultiplier: CGFloat
        let blockMinimumAlignmentScore: CGFloat
        let blockColumnSeparationMultiplier: CGFloat
        let blockSameRowVerticalOverlapThreshold: CGFloat

        static let standard = Configuration(
            sameLineMinimumVerticalOverlap: 0.52,
            sameLineCenterToleranceMultiplier: 0.55,
            sameLineMinimumCompatibilityScore: 0.42,
            sameLineCJKHorizontalGapMultiplier: 0.92,
            sameLineMixedHorizontalGapMultiplier: 0.58,
            sameLineLatinHorizontalGapMultiplier: 0.42,
            sameLineMinimumStrictHorizontalGap: 6,
            sameLineShortFragmentMaximumCharacterCount: 4,
            sameLineShortFragmentMinimumGap: 4,
            sameLineShortFragmentCJKGapToCharacterWidthMultiplier: 0.72,
            sameLineShortFragmentMixedGapToCharacterWidthMultiplier: 0.68,
            sameLineShortFragmentLatinGapToCharacterWidthMultiplier: 0.96,
            compactBlockMaximumCharacterCount: 12,
            compactBlockMaximumWidthToHeightRatio: 5.8,
            compactBlockVerticalGapMultiplier: 0.55,
            compactBlockMinimumVerticalGap: 8,
            compactBlockMinimumAlignmentScore: 0.68,
            compactBlockMinimumWidthSimilarity: 0.52,
            compactBlockMaximumCenterDeltaMultiplier: 1.1,
            compactBlockProfileMismatchVerticalGapMultiplier: 0.30,
            blockVerticalGapMultiplier: 1.35,
            blockMinimumVerticalGap: 18,
            blockMinimumHorizontalOverlap: 0.14,
            blockAlignmentToleranceMultiplier: 1.7,
            blockMinimumAlignmentScore: 0.44,
            blockColumnSeparationMultiplier: 3.0,
            blockSameRowVerticalOverlapThreshold: 0.28
        )
    }

    private let configuration: Configuration

    init(configuration: Configuration = .standard) {
        self.configuration = configuration
    }

    func group(_ observations: [OCRTextObservation]) -> [[OCRTextObservation]] {
        guard observations.isEmpty == false else {
            return []
        }

        let orderedObservations = sortByReadingOrder(observations)
        let lines = buildLines(from: orderedObservations)
        let blocks = buildBlocks(from: lines)

        return blocks
            .sorted(by: { lhs, rhs in
                if abs(lhs.boundingBox.minY - rhs.boundingBox.minY) > 8 {
                    return lhs.boundingBox.minY < rhs.boundingBox.minY
                }

                return lhs.boundingBox.minX < rhs.boundingBox.minX
            })
            .map(\.observations)
    }

    private func buildLines(from observations: [OCRTextObservation]) -> [TextLine] {
        var lines: [TextLine] = []

        for observation in observations {
            if let index = bestLineIndex(for: observation, in: lines) {
                lines[index].append(observation)
            } else {
                lines.append(TextLine(observations: [observation]))
            }
        }

        return lines
            .map { line in
                var normalizedLine = line
                normalizedLine.normalizeReadingOrder()
                return normalizedLine
            }
            .sorted(by: { lhs, rhs in
                if abs(lhs.boundingBox.minY - rhs.boundingBox.minY) > 8 {
                    return lhs.boundingBox.minY < rhs.boundingBox.minY
                }

                return lhs.boundingBox.minX < rhs.boundingBox.minX
            })
    }

    private func buildBlocks(from lines: [TextLine]) -> [TextBlockSeed] {
        var blocks: [TextBlockSeed] = []

        for line in lines {
            if let index = bestBlockIndex(for: line, in: blocks) {
                blocks[index].append(line)
            } else {
                blocks.append(TextBlockSeed(lines: [line]))
            }
        }

        return blocks
    }

    private func bestLineIndex(
        for observation: OCRTextObservation,
        in lines: [TextLine]
    ) -> Int? {
        var bestIndex: Int?
        var bestScore: CGFloat = 0

        for (index, line) in lines.enumerated() {
            let score = lineCompatibilityScore(
                observation: observation,
                line: line
            )

            guard score > bestScore else {
                continue
            }

            bestScore = score
            bestIndex = index
        }

        guard bestScore >= configuration.sameLineMinimumCompatibilityScore else {
            return nil
        }

        return bestIndex
    }

    private func bestBlockIndex(
        for line: TextLine,
        in blocks: [TextBlockSeed]
    ) -> Int? {
        var bestIndex: Int?
        var bestScore: CGFloat = 0

        for (index, block) in blocks.enumerated() {
            let score = blockCompatibilityScore(
                line: line,
                block: block
            )

            guard score > bestScore else {
                continue
            }

            bestScore = score
            bestIndex = index
        }

        return bestIndex
    }

    private func lineCompatibilityScore(
        observation: OCRTextObservation,
        line: TextLine
    ) -> CGFloat {
        let verticalOverlap = verticalOverlapRatio(
            observation.boundingBox,
            line.boundingBox
        )
        let averageHeight = max(
            (observation.boundingBox.height + line.averageHeight) / 2,
            1
        )
        let centerTolerance = max(
            averageHeight * configuration.sameLineCenterToleranceMultiplier,
            8
        )
        let centerDelta = abs(
            observation.boundingBox.midY - line.boundingBox.midY
        )
        let horizontalGap = horizontalGap(
            between: observation.boundingBox,
            and: line.boundingBox
        )
        let combinedProfile = combinedTextProfile(
            textProfile(for: observation.originalText),
            line.textProfile
        )
        let maximumHorizontalGap = maximumSameLineGap(
            for: combinedProfile,
            averageHeight: averageHeight
        )

        guard shouldKeepObservationSeparated(
            observation,
            from: line,
            baseMaximumHorizontalGap: maximumHorizontalGap
        ) == false else {
            return 0
        }

        guard
            verticalOverlap >= configuration.sameLineMinimumVerticalOverlap
                || centerDelta <= centerTolerance
        else {
            return 0
        }

        guard horizontalGap <= maximumHorizontalGap else {
            return 0
        }

        let overlapScore = clamped(verticalOverlap)
        let centerScore = inverseNormalized(
            value: centerDelta,
            maximum: centerTolerance
        )
        let gapScore = inverseNormalized(
            value: max(horizontalGap, 0),
            maximum: maximumHorizontalGap
        )
        let lineHintScore: CGFloat = observation.lineIndex == line.primaryLineIndex
            ? 0.12
            : 0

        return overlapScore * 0.42
            + centerScore * 0.28
            + gapScore * 0.18
            + lineHintScore
    }

    private func blockCompatibilityScore(
        line: TextLine,
        block: TextBlockSeed
    ) -> CGFloat {
        let lastLine = block.lastLine
        let verticalGap = line.boundingBox.minY - lastLine.boundingBox.maxY
        let averageHeight = max(line.averageHeight, block.averageLineHeight)
        let baseAllowedVerticalGap = max(
            averageHeight * configuration.blockVerticalGapMultiplier,
            configuration.blockMinimumVerticalGap
        )
        let compactPair = line.isCompactUILabel(
            maximumCharacterCount: configuration.compactBlockMaximumCharacterCount,
            maximumWidthToHeightRatio: configuration.compactBlockMaximumWidthToHeightRatio
        ) || lastLine.isCompactUILabel(
            maximumCharacterCount: configuration.compactBlockMaximumCharacterCount,
            maximumWidthToHeightRatio: configuration.compactBlockMaximumWidthToHeightRatio
        )
        let compactAllowedVerticalGap = max(
            averageHeight * configuration.compactBlockVerticalGapMultiplier,
            configuration.compactBlockMinimumVerticalGap
        )
        let allowedVerticalGap = compactPair
            ? min(baseAllowedVerticalGap, compactAllowedVerticalGap)
            : baseAllowedVerticalGap
        let sameRowVerticalOverlap = verticalOverlapRatio(
            line.boundingBox,
            lastLine.boundingBox
        )

        guard sameRowVerticalOverlap <= configuration.blockSameRowVerticalOverlapThreshold else {
            return 0
        }

        guard verticalGap <= allowedVerticalGap else {
            return 0
        }

        let horizontalOverlap = horizontalOverlapRatio(
            line.boundingBox,
            block.boundingBox
        )
        let widthSimilarity = line.widthSimilarity(to: lastLine)
        let centerDelta = abs(line.boundingBox.midX - lastLine.boundingBox.midX)
        let alignmentTolerance = max(
            averageHeight * configuration.blockAlignmentToleranceMultiplier,
            18
        )
        let leftAlignmentScore = inverseNormalized(
            value: abs(line.boundingBox.minX - block.leftAnchor),
            maximum: alignmentTolerance
        )
        let rightAlignmentScore = inverseNormalized(
            value: abs(line.boundingBox.maxX - block.rightAnchor),
            maximum: alignmentTolerance * 1.2
        )
        let centerAlignmentScore = inverseNormalized(
            value: abs(line.boundingBox.midX - block.centerAnchor),
            maximum: alignmentTolerance * 1.25
        )
        let alignmentScore = max(
            leftAlignmentScore,
            rightAlignmentScore,
            centerAlignmentScore
        )
        let columnSeparation = horizontalGap(
            between: line.boundingBox,
            and: block.boundingBox
        )
        let maximumColumnSeparation = max(
            averageHeight * configuration.blockColumnSeparationMultiplier,
            36
        )

        if compactPair {
            guard widthSimilarity >= configuration.compactBlockMinimumWidthSimilarity else {
                return 0
            }

            guard alignmentScore >= configuration.compactBlockMinimumAlignmentScore else {
                return 0
            }

            let maximumCenterDelta = averageHeight * configuration.compactBlockMaximumCenterDeltaMultiplier
            if centerDelta > maximumCenterDelta, horizontalOverlap < configuration.blockMinimumHorizontalOverlap {
                return 0
            }

            if line.textProfile != lastLine.textProfile {
                let mismatchGapLimit = averageHeight * configuration.compactBlockProfileMismatchVerticalGapMultiplier
                if verticalGap > mismatchGapLimit {
                    return 0
                }
            }
        }

        if
            horizontalOverlap < configuration.blockMinimumHorizontalOverlap
                && alignmentScore < configuration.blockMinimumAlignmentScore
                && columnSeparation > maximumColumnSeparation
        {
            return 0
        }

        let verticalScore = inverseNormalized(
            value: max(verticalGap, 0),
            maximum: allowedVerticalGap
        )
        let overlapScore = max(
            clamped(horizontalOverlap),
            inverseNormalized(
                value: columnSeparation,
                maximum: maximumColumnSeparation
            ) * 0.35
        )

        return verticalScore * 0.40
            + alignmentScore * 0.40
            + overlapScore * 0.20
    }

    private func sortByReadingOrder(
        _ observations: [OCRTextObservation]
    ) -> [OCRTextObservation] {
        let medianHeight = medianObservationHeight(in: observations)
        let lineTolerance = max(medianHeight * 0.35, 8)

        return observations.sorted { lhs, rhs in
            if abs(lhs.boundingBox.minY - rhs.boundingBox.minY) > lineTolerance {
                return lhs.boundingBox.minY < rhs.boundingBox.minY
            }

            if lhs.lineIndex != rhs.lineIndex {
                return lhs.lineIndex < rhs.lineIndex
            }

            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
    }

    private func medianObservationHeight(
        in observations: [OCRTextObservation]
    ) -> CGFloat {
        let heights = observations
            .map { $0.boundingBox.height }
            .sorted()

        guard let middleHeight = heights[safe: heights.count / 2] else {
            return 20
        }

        return max(middleHeight, 1)
    }

    private func maximumSameLineGap(
        for profile: TextProfile,
        averageHeight: CGFloat
    ) -> CGFloat {
        let multiplier: CGFloat

        switch profile {
        case .cjk:
            multiplier = configuration.sameLineCJKHorizontalGapMultiplier
        case .mixed:
            multiplier = configuration.sameLineMixedHorizontalGapMultiplier
        case .latin:
            multiplier = configuration.sameLineLatinHorizontalGapMultiplier
        case .neutral:
            multiplier = configuration.sameLineMixedHorizontalGapMultiplier
        }

        return max(
            averageHeight * multiplier,
            configuration.sameLineMinimumStrictHorizontalGap
        )
    }

    private func shouldKeepObservationSeparated(
        _ observation: OCRTextObservation,
        from line: TextLine,
        baseMaximumHorizontalGap: CGFloat
    ) -> Bool {
        guard let neighboringObservation = line.closestObservation(to: observation) else {
            return false
        }

        let observationMetrics = textUnitMetrics(for: observation)
        let neighborMetrics = textUnitMetrics(for: neighboringObservation)

        guard
            observationMetrics.isShortFragment(
                maximumCharacterCount: configuration.sameLineShortFragmentMaximumCharacterCount
            ),
            neighborMetrics.isShortFragment(
                maximumCharacterCount: configuration.sameLineShortFragmentMaximumCharacterCount
            )
        else {
            return false
        }

        let pairProfile = combinedTextProfile(
            observationMetrics.profile,
            neighborMetrics.profile
        )
        let pairGap = horizontalGap(
            between: observation.boundingBox,
            and: neighboringObservation.boundingBox
        )
        let averageCharacterWidth = max(
            (observationMetrics.averageCharacterWidth + neighborMetrics.averageCharacterWidth) / 2,
            1
        )
        let strictGapLimit = max(
            averageCharacterWidth * shortFragmentGapMultiplier(for: pairProfile),
            configuration.sameLineShortFragmentMinimumGap
        )

        return pairGap > min(strictGapLimit, baseMaximumHorizontalGap)
    }

    private func textProfile(for text: String) -> TextProfile {
        var cjkCount = 0
        var latinLikeCount = 0

        for scalar in text.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                continue
            }

            if CharacterSet.punctuationCharacters.contains(scalar) {
                continue
            }

            if isCJKScalar(scalar) {
                cjkCount += 1
            } else if CharacterSet.alphanumerics.contains(scalar) {
                latinLikeCount += 1
            }
        }

        if cjkCount > 0 && latinLikeCount > 0 {
            return .mixed
        }

        if cjkCount > 0 {
            return .cjk
        }

        if latinLikeCount > 0 {
            return .latin
        }

        return .neutral
    }

    private func combinedTextProfile(
        _ lhs: TextProfile,
        _ rhs: TextProfile
    ) -> TextProfile {
        if lhs == .mixed || rhs == .mixed {
            return .mixed
        }

        if lhs == .neutral {
            return rhs
        }

        if rhs == .neutral {
            return lhs
        }

        if lhs == rhs {
            return lhs
        }

        return .mixed
    }

    private func textUnitMetrics(
        for observation: OCRTextObservation
    ) -> TextUnitMetrics {
        let significantCharacterCount = significantCharacterCount(
            in: observation.originalText
        )
        let averageCharacterWidth = observation.boundingBox.width
            / CGFloat(max(significantCharacterCount, 1))

        return TextUnitMetrics(
            profile: textProfile(for: observation.originalText),
            significantCharacterCount: significantCharacterCount,
            averageCharacterWidth: averageCharacterWidth
        )
    }

    private func significantCharacterCount(in text: String) -> Int {
        text.unicodeScalars.reduce(into: 0) { partialResult, scalar in
            guard CharacterSet.whitespacesAndNewlines.contains(scalar) == false else {
                return
            }

            guard CharacterSet.punctuationCharacters.contains(scalar) == false else {
                return
            }

            partialResult += 1
        }
    }

    private func shortFragmentGapMultiplier(
        for profile: TextProfile
    ) -> CGFloat {
        switch profile {
        case .cjk:
            return configuration.sameLineShortFragmentCJKGapToCharacterWidthMultiplier
        case .mixed, .neutral:
            return configuration.sameLineShortFragmentMixedGapToCharacterWidthMultiplier
        case .latin:
            return configuration.sameLineShortFragmentLatinGapToCharacterWidthMultiplier
        }
    }

    private func isCJKScalar(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2CEAF:
            return true
        default:
            return false
        }
    }

    private func verticalOverlapRatio(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let overlap = max(
            0,
            min(lhs.maxY, rhs.maxY) - max(lhs.minY, rhs.minY)
        )
        let minimumHeight = max(min(lhs.height, rhs.height), 1)
        return overlap / minimumHeight
    }

    private func horizontalOverlapRatio(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
        let overlap = max(
            0,
            min(lhs.maxX, rhs.maxX) - max(lhs.minX, rhs.minX)
        )
        let minimumWidth = max(min(lhs.width, rhs.width), 1)
        return overlap / minimumWidth
    }

    private func horizontalGap(between lhs: CGRect, and rhs: CGRect) -> CGFloat {
        if lhs.maxX < rhs.minX {
            return rhs.minX - lhs.maxX
        }

        if rhs.maxX < lhs.minX {
            return lhs.minX - rhs.maxX
        }

        return 0
    }

    private func inverseNormalized(value: CGFloat, maximum: CGFloat) -> CGFloat {
        guard maximum > 0 else {
            return 1
        }

        return clamped(1 - (value / maximum))
    }

    private func clamped(_ value: CGFloat) -> CGFloat {
        min(max(value, 0), 1)
    }
}

private enum TextProfile: Sendable {
    case cjk
    case latin
    case mixed
    case neutral
}

private struct TextUnitMetrics: Sendable {
    let profile: TextProfile
    let significantCharacterCount: Int
    let averageCharacterWidth: CGFloat

    func isShortFragment(
        maximumCharacterCount: Int
    ) -> Bool {
        significantCharacterCount > 0
            && significantCharacterCount <= maximumCharacterCount
    }
}

private struct TextLine: Sendable {
    private(set) var observations: [OCRTextObservation]
    private(set) var boundingBox: CGRect

    init(observations: [OCRTextObservation]) {
        self.observations = observations
        self.boundingBox = observations.reduce(.null) { partialResult, observation in
            partialResult.union(observation.boundingBox)
        }
    }

    var averageHeight: CGFloat {
        let totalHeight = observations.reduce(CGFloat.zero) { partialResult, observation in
            partialResult + observation.boundingBox.height
        }

        return totalHeight / CGFloat(max(observations.count, 1))
    }

    var primaryLineIndex: Int {
        observations
            .map(\.lineIndex)
            .mostCommonValue
            ?? observations.first?.lineIndex
            ?? 0
    }

    var significantCharacterCount: Int {
        observations.reduce(into: 0) { partialResult, observation in
            partialResult += observation.originalText.unicodeScalars.reduce(into: 0) { subtotal, scalar in
                guard CharacterSet.whitespacesAndNewlines.contains(scalar) == false else {
                    return
                }

                guard CharacterSet.punctuationCharacters.contains(scalar) == false else {
                    return
                }

                subtotal += 1
            }
        }
    }

    var widthToHeightRatio: CGFloat {
        boundingBox.width / max(boundingBox.height, 1)
    }

    var textProfile: TextProfile {
        let hasCJK = observations.contains { observation in
            observation.originalText.unicodeScalars.contains { scalar in
                switch scalar.value {
                case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2CEAF:
                    return true
                default:
                    return false
                }
            }
        }
        let hasLatinLike = observations.contains { observation in
            observation.originalText.unicodeScalars.contains { scalar in
                CharacterSet.alphanumerics.contains(scalar)
                    && {
                        switch scalar.value {
                        case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2CEAF:
                            return false
                        default:
                            return true
                        }
                    }()
            }
        }

        switch (hasCJK, hasLatinLike) {
        case (true, true):
            return .mixed
        case (true, false):
            return .cjk
        case (false, true):
            return .latin
        case (false, false):
            return .neutral
        }
    }

    mutating func append(_ observation: OCRTextObservation) {
        observations.append(observation)
        boundingBox = boundingBox.union(observation.boundingBox)
    }

    func isCompactUILabel(
        maximumCharacterCount: Int,
        maximumWidthToHeightRatio: CGFloat
    ) -> Bool {
        significantCharacterCount > 0
            && significantCharacterCount <= maximumCharacterCount
            && widthToHeightRatio <= maximumWidthToHeightRatio
    }

    func widthSimilarity(to other: TextLine) -> CGFloat {
        let maximumWidth = max(max(boundingBox.width, other.boundingBox.width), 1)
        let minimumWidth = min(boundingBox.width, other.boundingBox.width)
        return minimumWidth / maximumWidth
    }

    func closestObservation(
        to observation: OCRTextObservation
    ) -> OCRTextObservation? {
        observations.min { lhs, rhs in
            let lhsGap = horizontalDistance(
                between: lhs.boundingBox,
                and: observation.boundingBox
            )
            let rhsGap = horizontalDistance(
                between: rhs.boundingBox,
                and: observation.boundingBox
            )

            if lhsGap != rhsGap {
                return lhsGap < rhsGap
            }

            let lhsCenterDelta = abs(
                lhs.boundingBox.midX - observation.boundingBox.midX
            )
            let rhsCenterDelta = abs(
                rhs.boundingBox.midX - observation.boundingBox.midX
            )

            return lhsCenterDelta < rhsCenterDelta
        }
    }

    mutating func normalizeReadingOrder() {
        observations.sort { lhs, rhs in
            if abs(lhs.boundingBox.minY - rhs.boundingBox.minY) > 6 {
                return lhs.boundingBox.minY < rhs.boundingBox.minY
            }

            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
        boundingBox = observations.reduce(.null) { partialResult, observation in
            partialResult.union(observation.boundingBox)
        }
    }

    private func horizontalDistance(
        between lhs: CGRect,
        and rhs: CGRect
    ) -> CGFloat {
        if lhs.maxX < rhs.minX {
            return rhs.minX - lhs.maxX
        }

        if rhs.maxX < lhs.minX {
            return lhs.minX - rhs.maxX
        }

        return 0
    }
}

private struct TextBlockSeed: Sendable {
    private(set) var lines: [TextLine]
    private(set) var boundingBox: CGRect

    init(lines: [TextLine]) {
        self.lines = lines
        self.boundingBox = lines.reduce(.null) { partialResult, line in
            partialResult.union(line.boundingBox)
        }
    }

    var observations: [OCRTextObservation] {
        lines
            .sorted(by: { lhs, rhs in
                if abs(lhs.boundingBox.minY - rhs.boundingBox.minY) > 8 {
                    return lhs.boundingBox.minY < rhs.boundingBox.minY
                }

                return lhs.boundingBox.minX < rhs.boundingBox.minX
            })
            .flatMap(\.observations)
    }

    var lastLine: TextLine {
        lines.max(by: { lhs, rhs in
            lhs.boundingBox.maxY < rhs.boundingBox.maxY
        }) ?? lines[0]
    }

    var averageLineHeight: CGFloat {
        let totalHeight = lines.reduce(CGFloat.zero) { partialResult, line in
            partialResult + line.averageHeight
        }

        return totalHeight / CGFloat(max(lines.count, 1))
    }

    var leftAnchor: CGFloat {
        average(of: lines.map { $0.boundingBox.minX })
    }

    var rightAnchor: CGFloat {
        average(of: lines.map { $0.boundingBox.maxX })
    }

    var centerAnchor: CGFloat {
        average(of: lines.map { $0.boundingBox.midX })
    }

    mutating func append(_ line: TextLine) {
        lines.append(line)
        boundingBox = boundingBox.union(line.boundingBox)
    }

    private func average(of values: [CGFloat]) -> CGFloat {
        let total = values.reduce(CGFloat.zero, +)
        return total / CGFloat(max(values.count, 1))
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else {
            return nil
        }

        return self[index]
    }
}

private extension Sequence where Element == Int {
    var mostCommonValue: Int? {
        Dictionary(grouping: self, by: { $0 })
            .max(by: { lhs, rhs in
                lhs.value.count < rhs.value.count
            })?
            .key
    }
}
