import Foundation

enum ResultMode: String, CaseIterable, Identifiable, Sendable {
    case overlay
    case original

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overlay: String(localized: "Translated")
        case .original: String(localized: "Original")
        }
    }
}
