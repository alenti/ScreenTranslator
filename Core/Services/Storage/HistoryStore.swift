import Foundation

final class HistoryStore: HistoryStoreProtocol {
    private var history: [OverlayRenderResult] = []

    func loadHistory() -> [OverlayRenderResult] {
        history
    }

    func save(_ result: OverlayRenderResult) {
        history.insert(result, at: 0)
    }

    func clear() {
        history.removeAll()
    }
}
