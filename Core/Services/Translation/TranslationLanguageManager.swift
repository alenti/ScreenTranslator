import Foundation
import Translation

@MainActor
final class TranslationLanguageManager {
    enum ReadinessState: String, CaseIterable, Sendable {
        case unknown
        case needsPreparation
        case ready
        case unsupported
    }

    private let availability: LanguageAvailability
    private let sessionBroker: TranslationSessionBroker

    private var cachedReadiness: ReadinessState
    private var cachedSummary: String

    init(
        availability: LanguageAvailability = LanguageAvailability(),
        sessionBroker: TranslationSessionBroker
    ) {
        self.availability = availability
        self.sessionBroker = sessionBroker
        self.cachedReadiness = .unknown
        self.cachedSummary = Self.summary(for: .unknown)
    }

    func currentReadiness() -> ReadinessState {
        cachedReadiness
    }

    func preparationSummary() -> String {
        cachedSummary
    }

    func preparationInProgressSummary() -> String {
        "Preparing Chinese to Russian offline language data on this device. This may take a little while."
    }

    func refreshReadiness() async -> ReadinessState {
        let status = await availability.status(
            from: TranslationSessionBroker.sourceLanguage,
            to: TranslationSessionBroker.targetLanguage
        )
        let readiness = Self.readiness(from: status)

        cachedReadiness = readiness
        cachedSummary = Self.summary(for: readiness)

        return readiness
    }

    func prepareOfflineLanguageData() async throws {
        let readiness = await refreshReadiness()

        switch readiness {
        case .ready:
            return
        case .unsupported:
            throw AppError.translationUnavailable
        case .unknown, .needsPreparation:
            do {
                try await sessionBroker.prepareTranslation()
                let refreshedReadiness = await refreshReadiness()

                guard refreshedReadiness == .ready else {
                    throw AppError.missingLanguagePack
                }
            } catch {
                throw TranslationFailureMapper.mapPreparationError(error)
            }
        }
    }

    private static func readiness(
        from status: LanguageAvailability.Status
    ) -> ReadinessState {
        switch status {
        case .installed:
            return .ready
        case .supported:
            return .needsPreparation
        case .unsupported:
            return .unsupported
        @unknown default:
            return .unknown
        }
    }

    private static func summary(for readiness: ReadinessState) -> String {
        switch readiness {
        case .unknown:
            return "Chinese to Russian translation readiness has not been checked yet."
        case .needsPreparation:
            return "Chinese to Russian translation is supported on this device, but the offline language data still needs to be prepared."
        case .ready:
            return "Chinese to Russian offline language data is installed and ready for on-device translation."
        case .unsupported:
            return "This device does not currently support the Chinese to Russian on-device translation pair."
        }
    }
}
