import SwiftUI

struct DebugOCRInspectorView: View {
    @Environment(\.colorScheme) private var colorScheme

    let inputSummary: String?
    let comparisonSummary: String?
    let observations: [OCRTextObservation]
    let groupedBlocks: [TextBlock]
    let translationBlocks: [TranslationBlock]
    let isLoading: Bool
    let statusMessage: String
    let groupingStatusMessage: String
    let translationStatusMessage: String
    let overlayBlocks: [TranslationBlock]
    let overlayStatusMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Structured Output")
                .font(.title3.weight(.semibold))
                .foregroundStyle(primaryTextColor)

            if let inputSummary {
                Text(inputSummary)
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
                    .padding(.top, 2)
            }

            if let comparisonSummary {
                Text(comparisonSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(primaryTextColor.opacity(0.88))
                    .padding(.vertical, 2)
            }

            if isLoading {
                ProgressView()
                    .padding(.top, 8)
                    .tint(progressTintColor)
            } else {
                rawObservationSection
                groupedBlockSection
                translatedBlockSection
                overlayFrameSection
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(cardStroke)
        )
    }

    private var rawObservationSection: some View {
        sectionCard(
            title: "Raw OCR Observations",
            status: statusMessage,
            accentColor: .orange
        ) {
            if observations.isEmpty {
                emptyState("No OCR observations to display yet.")
            } else {
                ForEach(Array(observations.enumerated()), id: \.element.id) { entry in
                    let index = entry.offset
                    let observation = entry.element

                    rowCard(accentColor: .orange) {
                        Text("Observation \(index)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(primaryTextColor)

                        Text(observation.originalText)
                            .font(.body)
                            .foregroundStyle(primaryTextColor.opacity(0.92))

                        Text("Confidence: \(confidenceDescription(for: observation.confidence))")
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)

                        Text("Line: \(observation.lineIndex)")
                            .font(.caption2)
                            .foregroundStyle(secondaryTextColor)

                        monoText("Box: \(frameDescription(for: observation.boundingBox))")
                    }
                }
            }
        }
    }

    private var groupedBlockSection: some View {
        sectionCard(
            title: "Grouped Text Blocks",
            status: groupingStatusMessage,
            accentColor: .blue
        ) {
            if groupedBlocks.isEmpty {
                emptyState("No grouped blocks to display yet.")
            } else {
                ForEach(Array(groupedBlocks.enumerated()), id: \.element.id) { entry in
                    let blockIndex = entry.offset
                    let block = entry.element

                    rowCard(accentColor: .blue) {
                        Text("Block \(blockIndex)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(primaryTextColor)

                        Text(block.sourceText)
                            .font(.body)
                            .foregroundStyle(primaryTextColor.opacity(0.92))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Observations: \(block.observations.count)")
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)

                        monoText("Box: \(frameDescription(for: block.combinedBoundingBox))")
                    }
                }
            }
        }
    }

    private var translatedBlockSection: some View {
        sectionCard(
            title: "Translated Blocks",
            status: translationStatusMessage,
            accentColor: .green
        ) {
            if translationBlocks.isEmpty {
                emptyState("No translated blocks to display yet.")
            } else {
                ForEach(Array(translationBlocks.enumerated()), id: \.element.id) { entry in
                    let blockIndex = entry.offset
                    let block = entry.element

                    rowCard(accentColor: .green) {
                        Text("Block \(blockIndex)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(primaryTextColor)

                        Text("Source")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(secondaryTextColor)
                        Text(block.sourceText)
                            .font(.body)
                            .foregroundStyle(primaryTextColor.opacity(0.92))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Translated")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(secondaryTextColor)
                        Text(block.translatedText)
                            .font(.body)
                            .foregroundStyle(primaryTextColor.opacity(0.92))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("Status: \(translationStatusDescription(for: block))")
                            .font(.caption)
                            .foregroundStyle(secondaryTextColor)

                        monoText("Source Box: \(frameDescription(for: block.sourceBoundingBox))")
                    }
                }
            }
        }
    }

    private var overlayFrameSection: some View {
        sectionCard(
            title: "Final Overlay Frames",
            status: overlayStatusMessage,
            accentColor: .pink
        ) {
            if overlayBlocks.isEmpty {
                emptyState("No final overlay frames to display yet.")
            } else {
                Text(overlayOverlapSummary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        overlayOverlapPairCount == 0
                            ? secondaryTextColor
                            : Color.orange.opacity(0.92)
                    )

                ForEach(Array(overlayBlocks.enumerated()), id: \.element.id) { entry in
                    let blockIndex = entry.offset
                    let block = entry.element
                    let overlapsNeighbor = overlayBlockOverlapsAnotherBlock(block)

                    rowCard(accentColor: overlapsNeighbor ? .orange : .pink) {
                        Text("Block \(blockIndex)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(primaryTextColor)

                        Text(block.translatedText)
                            .font(.body)
                            .foregroundStyle(primaryTextColor.opacity(0.92))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        monoText("Source Box: \(frameDescription(for: block.sourceBoundingBox))")
                        monoText("Target Frame: \(frameDescription(for: block.targetFrame))")
                        monoText("Delta: \(deltaDescription(for: block))")
                        monoText(
                            overlapsNeighbor
                                ? "Collision: overlaps another final overlay frame"
                                : "Collision: clear"
                        )
                    }
                }
            }
        }
    }

    private func confidenceDescription(for confidence: Double) -> String {
        String(format: "%.2f", confidence)
    }

    private func translationStatusDescription(for block: TranslationBlock) -> String {
        let translatedText = block.translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return translatedText.isEmpty ? "empty response" : "translated"
    }

    private func frameDescription(for rect: CGRect) -> String {
        let x = Int(rect.origin.x.rounded())
        let y = Int(rect.origin.y.rounded())
        let width = Int(rect.size.width.rounded())
        let height = Int(rect.size.height.rounded())
        return "x:\(x) y:\(y) w:\(width) h:\(height)"
    }

    private func deltaDescription(for block: TranslationBlock) -> String {
        let widthDelta = Int((block.targetFrame.width - block.sourceBoundingBox.width).rounded())
        let heightDelta = Int((block.targetFrame.height - block.sourceBoundingBox.height).rounded())
        return "dw \(signedValue(widthDelta)) • dh \(signedValue(heightDelta))"
    }

    private var overlayOverlapPairCount: Int {
        var count = 0

        for (index, block) in overlayBlocks.enumerated() {
            let remainingBlocks = overlayBlocks.dropFirst(index + 1)

            count += remainingBlocks.filter { candidate in
                block.targetFrame.intersects(candidate.targetFrame)
            }.count
        }

        return count
    }

    private var overlayOverlapSummary: String {
        if overlayOverlapPairCount == 0 {
            return "No overlapping target frames detected."
        }

        return "\(overlayOverlapPairCount) overlapping target frame pair(s) detected."
    }

    private func overlayBlockOverlapsAnotherBlock(_ block: TranslationBlock) -> Bool {
        overlayBlocks.contains { candidate in
            candidate.id != block.id
                && candidate.targetFrame.intersects(block.targetFrame)
        }
    }

    private func signedValue(_ value: Int) -> String {
        value > 0 ? "+\(value)" : "\(value)"
    }

    private func sectionCard<Content: View>(
        title: String,
        status: String,
        accentColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(primaryTextColor)

                Text(status)
                    .font(.caption)
                    .foregroundStyle(secondaryTextColor)
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .strokeBorder(accentColor.opacity(0.26))
        )
    }

    private func rowCard<Content: View>(
        accentColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(rowFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(accentColor.opacity(0.32))
        )
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(secondaryTextColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 2)
    }

    private func monoText(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(secondaryTextColor)
    }

    private var primaryTextColor: Color {
        colorScheme == .dark
            ? .white
            : Color.primary
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark
            ? .white.opacity(0.66)
            : Color.secondary
    }

    private var progressTintColor: Color {
        colorScheme == .dark
            ? .white
            : Color.accentColor
    }

    private var cardFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.white.opacity(0.76)
    }

    private var cardStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.08)
    }

    private var rowFill: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.16)
            : Color.black.opacity(0.04)
    }
}
