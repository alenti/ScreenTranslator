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

    func store(_ request: IntentHandoffRequest) throws {
        try ensureStoreDirectoryExists()
        let encodedRequest = try encoder.encode(request)
        try encodedRequest.write(to: storeURL, options: .atomic)
    }

    func store(_ input: ScreenshotInput) throws {
        try store(
            IntentHandoffRequest(
                screenshot: input,
                launchBehavior: .openInApp
            )
        )
    }

    func consumeLatestRequest() throws -> IntentHandoffRequest? {
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            return nil
        }

        guard let request = try loadLatestRequest() else {
            return nil
        }

        try? FileManager.default.removeItem(at: storeURL)
        return request
    }

    func consumeLatestInput() throws -> ScreenshotInput? {
        try consumeLatestRequest()?.screenshot
    }

    func peekLatestRequest() throws -> IntentHandoffRequest? {
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            return nil
        }

        return try loadLatestRequest()
    }

    func peekLatestInput() throws -> ScreenshotInput? {
        try peekLatestRequest()?.screenshot
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

    private func loadLatestRequest() throws -> IntentHandoffRequest? {
        do {
            let data = try Data(contentsOf: storeURL)
            let request = try decodeRequest(from: data)

            guard isFresh(request) else {
                try? FileManager.default.removeItem(at: storeURL)
                return nil
            }

            return request
        } catch {
            try? FileManager.default.removeItem(at: storeURL)
            throw AppError.intentInputFailure
        }
    }

    private func decodeRequest(from data: Data) throws -> IntentHandoffRequest {
        if let request = try? decoder.decode(IntentHandoffRequest.self, from: data) {
            return request
        }

        let input = try decoder.decode(ScreenshotInput.self, from: data)
        return IntentHandoffRequest(
            screenshot: input,
            launchBehavior: .openInApp
        )
    }

    private func isFresh(_ request: IntentHandoffRequest) -> Bool {
        now().timeIntervalSince(request.screenshot.timestamp) <= maxPendingAge
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
