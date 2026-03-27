import Foundation

final class SettingsStore: SettingsStoreProtocol {
    private let storeURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var cachedSettings: AppSettings?

    init(baseDirectoryURL: URL? = nil) {
        self.storeURL = Self.makeStoreURL(baseDirectoryURL: baseDirectoryURL)
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func loadSettings() -> AppSettings {
        if let cachedSettings {
            return cachedSettings
        }

        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            cachedSettings = .defaultValue
            return .defaultValue
        }

        do {
            let data = try Data(contentsOf: storeURL)
            let settings = try decoder.decode(AppSettings.self, from: data)
            cachedSettings = settings
            return settings
        } catch {
            cachedSettings = .defaultValue
            return .defaultValue
        }
    }

    func saveSettings(_ settings: AppSettings) {
        cachedSettings = settings

        do {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(settings)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            return
        }
    }

    private static func makeStoreURL(
        baseDirectoryURL: URL?
    ) -> URL {
        let baseURL = baseDirectoryURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        return baseURL
            .appendingPathComponent("ScreenTranslator", isDirectory: true)
            .appendingPathComponent("Settings", isDirectory: true)
            .appendingPathComponent("app-settings.json")
    }
}
