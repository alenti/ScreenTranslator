import Foundation

/// How the Action Button shortcut shows a translation. iOS runs the Shortcut the user built, so each
/// choice maps to its own Shortcut configuration; the app guides the user instead of rewriting it.
enum ResultPresentation: String, CaseIterable, Identifiable, Sendable {
    case quickPreview
    case openInApp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quickPreview: String(localized: "Quick Preview")
        case .openInApp: String(localized: "Open in App")
        }
    }

    var summary: String {
        switch self {
        case .quickPreview: String(localized: "Stay in the current app. The translation opens in a system preview; close it to go right back.")
        case .openInApp: String(localized: "Open ScreenTranslator with the full viewer: compare, zoom, copy text, share and save.")
        }
    }

    var symbolName: String {
        switch self {
        case .quickPreview: "eye"
        case .openInApp: "arrow.up.forward.app"
        }
    }
}

/// Only states the app can actually reach today. A future download flow adds its own cases here.
enum ModelState: Equatable, Sendable {
    case checking
    case notInstalled
    case damaged
    case installing
    case insufficientStorage
    case ready
    case failed(AppError)

    /// Users only need to know whether translation works; the reason goes in the footer.
    var title: String {
        switch self {
        case .checking: String(localized: "Checking…")
        case .installing: String(localized: "Installing…")
        case .ready: String(localized: "Working")
        case .notInstalled, .damaged, .insufficientStorage, .failed: String(localized: "Not Working")
        }
    }

    var isReady: Bool { self == .ready }
    var isBusy: Bool { self == .checking || self == .installing }
}

@MainActor
final class SettingsViewModel: ObservableObject {
    private let defaults: UserDefaults

    @Published var localTarget: TargetLanguage {
        didSet { defaults.set(localTarget.rawValue, forKey: "localTarget") }
    }
    @Published var resultPresentation: ResultPresentation {
        didSet { defaults.set(resultPresentation.rawValue, forKey: "resultPresentation") }
    }
    @Published var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: "onboardingCompleted") }
    }
    /// Persisted so an interrupted onboarding resumes where it stopped.
    @Published var onboardingStep: Int {
        didSet { defaults.set(onboardingStep, forKey: "onboardingStep") }
    }
    @Published private(set) var modelState: ModelState = .checking

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // The Quick Look intent reads the same "localTarget" key; keep its default in sync.
        localTarget = TargetLanguage(rawValue: defaults.string(forKey: "localTarget") ?? "") ?? .russian
        resultPresentation = ResultPresentation(rawValue: defaults.string(forKey: "resultPresentation") ?? "") ?? .quickPreview
        onboardingCompleted = defaults.bool(forKey: "onboardingCompleted")
        onboardingStep = defaults.integer(forKey: "onboardingStep")
    }

    var modelBytes: Int64 { ((try? modelManifest())?["bytes"] as? NSNumber)?.int64Value ?? 0 }

    var modelSizeText: String { ByteCountFormatter.string(fromByteCount: modelBytes, countStyle: .file) }

    var availableStorage: Int64? {
        try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            .volumeAvailableCapacityForImportantUsage
    }

    /// Cheap presence/size check; the full SHA-256 verification still runs before every model load.
    func refreshModelState() {
        guard modelState != .installing else { return }
        do {
            let manifest = try modelManifest()
            let size = try? modelFileURL(manifest).resourceValues(forKeys: [.fileSizeKey]).fileSize
            switch size {
            case nil: modelState = .notInstalled
            case (manifest["bytes"] as? NSNumber)?.intValue: modelState = .ready
            default: modelState = .damaged
            }
        } catch {
            modelState = .failed(AppError(error))
        }
    }

    func importModel(from result: Result<URL, Error>, engine: HyMTTranslator, beforeImport: () async -> Void) async {
        guard case .success(let url) = result else { return } // User cancelled the picker.
        if let available = availableStorage, available < modelBytes, modelState != .ready {
            modelState = .insufficientStorage
            return
        }
        modelState = .installing
        await beforeImport()
        do {
            try await engine.importModel(url)
            modelState = .checking
            refreshModelState()
        } catch {
            #if DEBUG
            print("Model import failed: \(error)")
            #endif
            modelState = .failed(AppError(error))
        }
    }
}
