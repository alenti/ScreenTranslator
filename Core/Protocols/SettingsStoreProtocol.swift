import Foundation

protocol SettingsStoreProtocol {
    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings)
}
