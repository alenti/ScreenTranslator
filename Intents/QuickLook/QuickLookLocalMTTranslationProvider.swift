import Foundation
import OSLog

struct QuickLookLocalMTTranslationOutcome: Equatable {
    let attempted: Bool
    let translationsByID: [String: QuickLookDictionaryTranslation]
    let provider: String?
    let totalLatencyMs: Int?
    let failureDescription: String?

    static var disabled: QuickLookLocalMTTranslationOutcome {
        QuickLookLocalMTTranslationOutcome(
            attempted: false,
            translationsByID: [:],
            provider: nil,
            totalLatencyMs: nil,
            failureDescription: nil
        )
    }

    var hitCount: Int {
        translationsByID.count
    }

    var failed: Bool {
        failureDescription != nil
    }
}

struct QuickLookLocalMTTranslationProvider {
    private let isEnabled: Bool
    private let client: QuickLookLocalMTClient
    private let logger = Logger(
        subsystem: "AlenShamatov.ScreenTranslator",
        category: "QuickLookLocalMT"
    )

    init(
        isEnabled: Bool = QuickLookLocalMTConfig.isEnabled,
        client: QuickLookLocalMTClient = QuickLookLocalMTClient()
    ) {
        self.isEnabled = isEnabled
        self.client = client
    }

    func translate(
        preparedBlocks: [QuickLookMTPreparedBlock]
    ) async -> QuickLookLocalMTTranslationOutcome {
        guard isEnabled else {
            logger.info(
                """
                Quick Look Local MT disabled baseURL=\
                \(client.baseURLString, privacy: .public)
                """
            )

            return .disabled
        }

        guard preparedBlocks.isEmpty == false else {
            logger.warning(
                """
                Quick Look Local MT enabled but no request blocks were \
                prepared baseURL=\(client.baseURLString, privacy: .public)
                """
            )

            return QuickLookLocalMTTranslationOutcome(
                attempted: true,
                translationsByID: [:],
                provider: nil,
                totalLatencyMs: 0,
                failureDescription: "No prepared MT blocks."
            )
        }

        do {
            let start = Date()
            logger.info(
                """
                Quick Look Local MT request started blocks=\
                \(preparedBlocks.count, privacy: .public) endpoint=\
                \(client.endpointURLString, privacy: .public)
                """
            )

            let response = try await client.translateBlocks(
                preparedBlocks.map(\.requestBlock)
            )
            let duration = Date().timeIntervalSince(start)
            var translationsByID: [String: QuickLookDictionaryTranslation] = [:]

            for translation in response.translations {
                let displayText = normalizedDisplayText(
                    translation.translatedText
                )

                guard displayText.isEmpty == false else {
                    continue
                }

                translationsByID[translation.id] = QuickLookDictionaryTranslation(
                    displayText: displayText,
                    matchedSource: translation.sourceText,
                    matchKind: .localMT,
                    isImportant: true,
                    hasPreservedValue: containsValue(in: translation.sourceText),
                    sourceKind: "local_mt",
                    selectionReason: "provider=\(response.provider)",
                    englishRaw: displayText,
                    pinyin: nil
                )
            }

            logger.info(
                """
                Quick Look Local MT response translations=\
                \(response.translations.count, privacy: .public) \
                totalLatencyMs=\(response.totalLatencyMs ?? -1, privacy: .public), \
                usableHits=\(translationsByID.count, privacy: .public), \
                clientDuration=\(duration, format: .fixed(precision: 3))s
                """
            )

            guard translationsByID.isEmpty == false else {
                logger.warning(
                    "Quick Look Local MT returned no usable translations"
                )

                return QuickLookLocalMTTranslationOutcome(
                    attempted: true,
                    translationsByID: [:],
                    provider: response.provider,
                    totalLatencyMs: response.totalLatencyMs,
                    failureDescription: "No usable local MT translations."
                )
            }

            return QuickLookLocalMTTranslationOutcome(
                attempted: true,
                translationsByID: translationsByID,
                provider: response.provider,
                totalLatencyMs: response.totalLatencyMs,
                failureDescription: nil
            )
        } catch {
            logger.error(
                "Quick Look Local MT failed error=\(String(describing: error), privacy: .public)"
            )

            return QuickLookLocalMTTranslationOutcome(
                attempted: true,
                translationsByID: [:],
                provider: nil,
                totalLatencyMs: nil,
                failureDescription: String(describing: error)
            )
        }
    }

    private func normalizedDisplayText(_ text: String) -> String {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func containsValue(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            CharacterSet.decimalDigits.contains(scalar)
                || CharacterSet(charactersIn: "¥￥$%").contains(scalar)
        }
    }
}
