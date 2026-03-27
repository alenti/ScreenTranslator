import Foundation

struct AppSettings: Equatable, Sendable, Codable {
    var overlayStyle: OverlayRenderStyle
    var preferredDisplayModeRawValue: String
    var historyEnabled: Bool
    var debugOptionsEnabled: Bool

    static let defaultValue = AppSettings(
        overlayStyle: .defaultValue,
        preferredDisplayModeRawValue: "overlay",
        historyEnabled: true,
        debugOptionsEnabled: true
    )
}
