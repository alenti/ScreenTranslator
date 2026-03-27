import Foundation

protocol HistoryStoreProtocol {
    func loadHistory() -> [OverlayRenderResult]
    func save(_ result: OverlayRenderResult)
    func clear()
}
