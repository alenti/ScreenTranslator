import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var languageReadiness: TranslationLanguageManager.ReadinessState
    @Published private(set) var languageSummary: String
    @Published private(set) var isPreparingLanguageData: Bool

    private let settingsStore: any SettingsStoreProtocol
    private let languageManager: TranslationLanguageManager
    private var languagePreparationTask: Task<Void, Never>?

    init(
        settingsStore: any SettingsStoreProtocol,
        languageManager: TranslationLanguageManager
    ) {
        self.settingsStore = settingsStore
        self.languageManager = languageManager
        self.settings = settingsStore.loadSettings()
        self.languageReadiness = languageManager.currentReadiness()
        self.languageSummary = languageManager.preparationSummary()
        self.isPreparingLanguageData = false
    }

    var preferredDisplayMode: ResultMode {
        ResultMode(rawValue: settings.preferredDisplayModeRawValue) ?? .overlay
    }

    var backgroundOpacityLabel: String {
        "\(Int((settings.overlayStyle.backgroundOpacity * 100).rounded()))%"
    }

    var maximumFontSizeLabel: String {
        "\(Int(settings.overlayStyle.maximumFontSize.rounded())) pt"
    }

    var cornerRadiusLabel: String {
        "\(Int(settings.overlayStyle.cornerRadius.rounded())) pt"
    }

    var prepareButtonTitle: String {
        if isPreparingLanguageData {
            return "Preparing Offline Translation..."
        }

        switch languageReadiness {
        case .ready:
            return "Offline Translation Ready"
        case .unsupported:
            return "Language Pair Unavailable"
        case .unknown, .needsPreparation:
            return "Prepare Offline Chinese to Russian"
        }
    }

    var prepareButtonDisabled: Bool {
        isPreparingLanguageData
            || languageReadiness == .ready
            || languageReadiness == .unsupported
    }

    func updatePreferredDisplayMode(_ mode: ResultMode) {
        settings.preferredDisplayModeRawValue = mode.rawValue
        persist()
    }

    func updateBackgroundOpacity(_ value: Double) {
        settings.overlayStyle.backgroundOpacity = value
        persist()
    }

    func updateMaximumFontSize(_ value: Double) {
        settings.overlayStyle.maximumFontSize = value
        persist()
    }

    func updateCornerRadius(_ value: Double) {
        settings.overlayStyle.cornerRadius = value
        persist()
    }

    func resetOverlayStyle() {
        settings.overlayStyle = .defaultValue
        persist()
    }

    func refreshLanguageStatus() async {
        languageReadiness = await languageManager.refreshReadiness()

        if isPreparingLanguageData == false {
            languageSummary = languageManager.preparationSummary()
        }
    }

    func startPreparingOfflineLanguageData() {
        guard languagePreparationTask == nil else {
            return
        }

        guard languageReadiness != .ready, languageReadiness != .unsupported else {
            return
        }

        beginLanguagePreparation()

        let task = Task { [weak self] in
            guard let self else {
                return
            }

            await self.runLanguagePreparationFlow()
        }
        languagePreparationTask = task
    }

    func prepareOfflineLanguageData() async {
        if let languagePreparationTask {
            await languagePreparationTask.value
            return
        }

        guard languageReadiness != .ready, languageReadiness != .unsupported else {
            return
        }

        beginLanguagePreparation()

        let task = Task { [weak self] in
            guard let self else {
                return
            }

            await self.runLanguagePreparationFlow()
        }
        languagePreparationTask = task
        await task.value
    }

    private func beginLanguagePreparation() {
        if languageReadiness != .ready, languageReadiness != .unsupported {
            languageReadiness = .needsPreparation
        }

        languageSummary = languageManager.preparationInProgressSummary()
        isPreparingLanguageData = true
    }

    private func runLanguagePreparationFlow() async {
        defer {
            isPreparingLanguageData = false
            languagePreparationTask = nil
        }

        do {
            try await languageManager.prepareOfflineLanguageData()
            languageReadiness = await languageManager.refreshReadiness()
            languageSummary = languageManager.preparationSummary()
        } catch let error as AppError {
            languageReadiness = await languageManager.refreshReadiness()
            languageSummary = error.errorDescription ?? languageManager.preparationSummary()
        } catch {
            languageReadiness = await languageManager.refreshReadiness()
            let description = (error as NSError).localizedDescription
            languageSummary = description.isEmpty
                ? "Offline language preparation failed."
                : description
        }
    }

    private func persist() {
        settingsStore.saveSettings(settings)
    }
}
