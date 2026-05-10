import Foundation

enum AppRoute: String, CaseIterable, Sendable {
    case idle
    case processing
    case floatingPreview
    case result
    case error
    case settings
    case debug
}
