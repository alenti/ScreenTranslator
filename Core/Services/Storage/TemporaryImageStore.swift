import Foundation

actor TemporaryImageStore {
    private static let defaultMaxPendingAge: TimeInterval = 15 * 60

    private let storeURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let maxPendingAge: TimeInterval
    private let now: @Sendable () -> Date

    init(
        baseDirectoryURL: URL? = nil,
        maxPendingAge: TimeInterval = TemporaryImageStore.defaultMaxPendingAge,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.storeURL = Self.makeStoreURL(
            baseDirectoryURL: baseDirectoryURL
        )
        self.maxPendingAge = maxPendingAge
        self.now = now

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func store(_ input: ScreenshotInput) throws {
        try ensureStoreDirectoryExists()
        let encodedInput = try encoder.encode(input)
        try encodedInput.write(to: storeURL, options: .atomic)
    }

    func consumeLatestInput() throws -> ScreenshotInput? {
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            return nil
        }

        guard let input = try loadLatestInput() else {
            return nil
        }

        try? FileManager.default.removeItem(at: storeURL)
        return input
    }

    func peekLatestInput() throws -> ScreenshotInput? {
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            return nil
        }

        return try loadLatestInput()
    }

    func clear() {
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            return
        }

        try? FileManager.default.removeItem(at: storeURL)
    }

    private func ensureStoreDirectoryExists() throws {
        try FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
    }

    private func loadLatestInput() throws -> ScreenshotInput? {
        do {
            let data = try Data(contentsOf: storeURL)
            let input = try decoder.decode(ScreenshotInput.self, from: data)

            guard isFresh(input) else {
                try? FileManager.default.removeItem(at: storeURL)
                return nil
            }

            return input
        } catch {
            try? FileManager.default.removeItem(at: storeURL)
            throw AppError.intentInputFailure
        }
    }

    private func isFresh(_ input: ScreenshotInput) -> Bool {
        now().timeIntervalSince(input.timestamp) <= maxPendingAge
    }

    private static func makeStoreURL(
        baseDirectoryURL: URL?
    ) -> URL {
        let baseURL = baseDirectoryURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        return baseURL
            .appendingPathComponent("ScreenTranslator", isDirectory: true)
            .appendingPathComponent("IntentHandoff", isDirectory: true)
            .appendingPathComponent("pending-screenshot.json")
    }
}
