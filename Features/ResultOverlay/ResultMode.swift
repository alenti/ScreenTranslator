import Foundation

enum ResultMode: String, CaseIterable, Identifiable, Sendable {
    case overlay
    case original
    case text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overlay:
            return "Translation"
        case .original:
            return "Original"
        case .text:
            return "Text"
        }
    }

    var systemImageName: String {
        switch self {
        case .overlay:
            return "text.bubble"
        case .original:
            return "photo"
        case .text:
            return "doc.text"
        }
    }
}
