import CoreGraphics
import Foundation

struct TextBlockComposer: Sendable {
    struct Configuration: Equatable, Sendable {
        let lineToleranceMultiplier: CGFloat
        let minimumLineTolerance: CGFloat
        let latinSpaceGapMultiplier: CGFloat
        let minimumLatinSpaceGap: CGFloat

        static let standard = Configuration(
            lineToleranceMultiplier: 0.45,
            minimumLineTolerance: 8,
            latinSpaceGapMultiplier: 0.30,
            minimumLatinSpaceGap: 6
        )
    }

    private let configuration: Configuration

    init(configuration: Configuration = .standard) {
        self.configuration = configuration
    }

    func compose(groups: [[OCRTextObservation]]) -> [TextBlock] {
        groups.compactMap(composeBlock)
    }

    private func composeBlock(from group: [OCRTextObservation]) -> TextBlock? {
        let orderedObservations = sortByReadingOrder(group)
        guard orderedObservations.isEmpty == false else {
            return nil
        }

        let lineGroups = splitIntoLines(orderedObservations)
        let blockText = lineGroups
            .map(composeLine)
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard blockText.isEmpty == false else {
            return nil
        }

        let combinedBoundingBox = orderedObservations.reduce(CGRect.null) { partialResult, observation in
            partialResult.union(observation.boundingBox)
        }

        return TextBlock(
            sourceText: blockText,
            observations: orderedObservations,
            combinedBoundingBox: combinedBoundingBox
        )
    }

    private func splitIntoLines(
        _ observations: [OCRTextObservation]
    ) -> [[OCRTextObservation]] {
        var lines: [[OCRTextObservation]] = []

        for observation in observations {
            if let lastLine = lines.last, shouldAppend(observation, to: lastLine) {
                lines[lines.count - 1].append(observation)
            } else {
                lines.append([observation])
            }
        }

        return lines.map { line in
            line.sorted { lhs, rhs in
                lhs.boundingBox.minX < rhs.boundingBox.minX
            }
        }
    }

    private func shouldAppend(
        _ observation: OCRTextObservation,
        to line: [OCRTextObservation]
    ) -> Bool {
        guard let firstObservation = line.first else {
            return false
        }

        let lineBoundingBox = line.reduce(CGRect.null) { partialResult, candidate in
            partialResult.union(candidate.boundingBox)
        }
        let lineHeight = max(lineBoundingBox.height, firstObservation.boundingBox.height)
        let lineTolerance = max(
            lineHeight * configuration.lineToleranceMultiplier,
            configuration.minimumLineTolerance
        )

        return abs(observation.boundingBox.midY - lineBoundingBox.midY) <= lineTolerance
    }

    private func composeLine(_ line: [OCRTextObservation]) -> String {
        guard let firstObservation = line.first else {
            return ""
        }

        var composedText = cleaned(firstObservation.originalText)
        var previousObservation = firstObservation

        for observation in line.dropFirst() {
            let nextText = cleaned(observation.originalText)
            guard nextText.isEmpty == false else {
                continue
            }

            let separator = separator(
                after: composedText,
                previousObservation: previousObservation,
                nextText: nextText,
                nextObservation: observation
            )

            composedText += separator + nextText
            previousObservation = observation
        }

        return composedText
    }

    private func separator(
        after currentText: String,
        previousObservation: OCRTextObservation,
        nextText: String,
        nextObservation: OCRTextObservation
    ) -> String {
        guard
            currentText.isEmpty == false,
            nextText.isEmpty == false
        else {
            return ""
        }

        let previousTail = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let gap = max(nextObservation.boundingBox.minX - previousObservation.boundingBox.maxX, 0)
        let minimumHeight = max(
            min(previousObservation.boundingBox.height, nextObservation.boundingBox.height),
            1
        )
        let latinSpaceThreshold = max(
            minimumHeight * configuration.latinSpaceGapMultiplier,
            configuration.minimumLatinSpaceGap
        )

        if shouldJoinWithoutSpace(lhs: previousTail, rhs: nextText, gap: gap, threshold: latinSpaceThreshold) {
            return ""
        }

        return gap >= latinSpaceThreshold ? " " : ""
    }

    private func shouldJoinWithoutSpace(
        lhs: String,
        rhs: String,
        gap: CGFloat,
        threshold: CGFloat
    ) -> Bool {
        if lhs.isEmpty || rhs.isEmpty {
            return true
        }

        if lhs.hasSuffix("-") {
            return true
        }

        if isPunctuation(lhs.last) || isPunctuation(rhs.first) {
            return true
        }

        if isCJKDominant(lhs) && isCJKDominant(rhs) {
            return true
        }

        return gap < threshold * 0.5
    }

    private func cleaned(_ text: String) -> String {
        text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    private func sortByReadingOrder(
        _ observations: [OCRTextObservation]
    ) -> [OCRTextObservation] {
        let medianHeight = observations
            .map { $0.boundingBox.height }
            .sorted()[safe: observations.count / 2] ?? 20
        let lineTolerance = max(medianHeight * 0.30, 8)

        return observations.sorted { lhs, rhs in
            if abs(lhs.boundingBox.minY - rhs.boundingBox.minY) > lineTolerance {
                return lhs.boundingBox.minY < rhs.boundingBox.minY
            }

            return lhs.boundingBox.minX < rhs.boundingBox.minX
        }
    }

    private func isCJKDominant(_ text: String) -> Bool {
        let scalars = text.unicodeScalars.filter { $0.properties.isAlphabetic || $0.properties.generalCategory == .otherLetter }
        guard scalars.isEmpty == false else {
            return false
        }

        let cjkCount = scalars.filter { scalar in
            switch scalar.value {
            case 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xF900...0xFAFF, 0x20000...0x2CEAF:
                return true
            default:
                return false
            }
        }.count

        return CGFloat(cjkCount) / CGFloat(scalars.count) >= 0.5
    }

    private func isPunctuation(_ character: Character?) -> Bool {
        guard let character else {
            return false
        }

        return character.unicodeScalars.allSatisfy {
            CharacterSet.punctuationCharacters.contains($0)
        }
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
