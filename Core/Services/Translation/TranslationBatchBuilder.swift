import Foundation

struct TranslationBatchBuilder {
    struct BatchItem: Identifiable, Equatable, Sendable {
        let id: UUID
        let blockIndex: Int
        let clientIdentifier: String
        let sourceText: String
        let sourceBoundingBox: CGRect
        let renderingStyle: OverlayRenderStyle
    }

    func buildBatch(
        from blocks: [TextBlock],
        renderingStyle: OverlayRenderStyle = .defaultValue
    ) -> [BatchItem] {
        blocks.enumerated().compactMap { index, block in
            let normalizedText = normalizedSourceText(from: block.sourceText)
            guard normalizedText.isEmpty == false else {
                return nil
            }

            return BatchItem(
                id: block.id,
                blockIndex: index,
                clientIdentifier: block.id.uuidString,
                sourceText: normalizedText,
                sourceBoundingBox: block.combinedBoundingBox,
                renderingStyle: renderingStyle
            )
        }
    }

    func makeTranslationBlocks(
        from batch: [BatchItem],
        results: [TranslationSessionBroker.ResultItem]
    ) -> [TranslationBlock] {
        let resultsByIdentifier: [String: String] = Dictionary(
            uniqueKeysWithValues: results.compactMap { result in
                guard let clientIdentifier = result.clientIdentifier else {
                    return nil
                }

                return (clientIdentifier, result.translatedText)
            }
        )
        let orderedFallbackResults = Array(results.prefix(batch.count))

        return batch.enumerated().map { index, item in
            let translatedText = resolvedTranslatedText(
                for: item,
                at: index,
                resultsByIdentifier: resultsByIdentifier,
                fallbackResults: orderedFallbackResults
            )

            return TranslationBlock(
                id: item.id,
                sourceText: item.sourceText,
                translatedText: translatedText,
                sourceBoundingBox: item.sourceBoundingBox,
                targetFrame: item.sourceBoundingBox,
                renderingStyle: item.renderingStyle
            )
        }
    }

    private func normalizedSourceText(from text: String) -> String {
        text
            .components(separatedBy: .newlines)
            .map { line in
                line
                    .components(separatedBy: .whitespaces)
                    .filter { $0.isEmpty == false }
                    .joined(separator: " ")
            }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func resolvedTranslatedText(
        for item: BatchItem,
        at index: Int,
        resultsByIdentifier: [String: String],
        fallbackResults: [TranslationSessionBroker.ResultItem]
    ) -> String {
        if let translatedText = resultsByIdentifier[item.clientIdentifier] {
            return normalizedTranslatedText(translatedText)
        }

        if let fallbackResult = fallbackResults[safe: index] {
            return normalizedTranslatedText(fallbackResult.translatedText)
        }

        return item.sourceText
    }

    private func normalizedTranslatedText(_ text: String) -> String {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? text : normalized
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
