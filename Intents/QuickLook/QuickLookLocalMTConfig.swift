import Foundation

enum QuickLookLocalMTConfig {
    // DEVELOPMENT ONLY. Set back to false before App Store work.
    static let isEnabled = true

    // DEVELOPMENT ONLY: Mac LAN server used for real-device OPUS-MT testing.
    static let baseURL = URL(string: "http://192.168.1.54:8766")!

    static let requestTimeout: TimeInterval = 8
    static let maximumBlocks = 20
    static let maximumCharactersPerBlock = 1000

    static var baseURLString: String {
        baseURL.absoluteString
    }
}
