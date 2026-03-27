import Foundation
import Translation

struct OnDeviceTranslationService: TranslationServiceProtocol {
    let languageManager: TranslationLanguageManager
    let batchBuilder: TranslationBatchBuilder
    let sessionBroker: TranslationSessionBroker

    func translate(blocks: [TextBlock]) async throws -> [TranslationBlock] {
        let batch = batchBuilder.buildBatch(from: blocks)
        guard batch.isEmpty == false else {
            return []
        }

        let readiness = await languageManager.refreshReadiness()

        switch readiness {
        case .ready:
            break
        case .needsPreparation, .unknown:
            throw AppError.missingLanguagePack
        case .unsupported:
            throw AppError.translationUnavailable
        }

        do {
            let results = try await sessionBroker.translate(batch: batch)
            return batchBuilder.makeTranslationBlocks(
                from: batch,
                results: results
            )
        } catch {
            throw TranslationFailureMapper.mapRuntimeError(error)
        }
    }
}

final class TranslationSessionBroker {
    enum BrokerError: Error, Equatable {
        case operationTimedOut
    }

    struct ResultItem: Equatable, Sendable {
        let clientIdentifier: String?
        let sourceText: String
        let translatedText: String
    }

    static let sourceLanguage = Locale.Language(identifier: "zh-Hans")
    static let targetLanguage = Locale.Language(identifier: "ru")

    private enum Operation {
        case prepare(
            id: UUID,
            continuation: CheckedContinuation<Void, Error>
        )
        case translate(
            id: UUID,
            batch: [TranslationBatchBuilder.BatchItem],
            continuation: CheckedContinuation<[ResultItem], Error>
        )
    }

    private let stream: AsyncStream<Operation>
    private let continuation: AsyncStream<Operation>.Continuation
    private let stateLock: NSLock
    private let translationTimeoutNanoseconds: UInt64
    private let preparationTimeoutNanoseconds: UInt64
    private var isRunning: Bool
    private var timeoutTasks: [UUID: Task<Void, Never>]

    init(
        translationTimeout: TimeInterval = 20,
        preparationTimeout: TimeInterval = 180
    ) {
        var continuation: AsyncStream<Operation>.Continuation?
        self.stream = AsyncStream<Operation> { streamContinuation in
            continuation = streamContinuation
        }
        self.continuation = continuation!
        self.stateLock = NSLock()
        self.translationTimeoutNanoseconds = Self.nanoseconds(
            from: translationTimeout
        )
        self.preparationTimeoutNanoseconds = Self.nanoseconds(
            from: preparationTimeout
        )
        self.isRunning = false
        self.timeoutTasks = [:]
    }

    func translate(
        batch: [TranslationBatchBuilder.BatchItem]
    ) async throws -> [ResultItem] {
        let operationID = UUID()

        return try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<[ResultItem], Error>) in
            scheduleTimeout(
                for: operationID,
                timeoutNanoseconds: translationTimeoutNanoseconds,
                continuation: continuation
            )
            self.continuation.yield(
                .translate(
                    id: operationID,
                    batch: batch,
                    continuation: continuation
                )
            )
        }
    }

    func prepareTranslation() async throws {
        let operationID = UUID()

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            scheduleTimeout(
                for: operationID,
                timeoutNanoseconds: preparationTimeoutNanoseconds,
                continuation: continuation
            )
            self.continuation.yield(
                .prepare(
                    id: operationID,
                    continuation: continuation
                )
            )
        }
    }

    func run(with session: TranslationSession) async {
        guard beginRunningSessionLoop() else {
            return
        }

        defer {
            endRunningSessionLoop()
        }

        var iterator = stream.makeAsyncIterator()

        while Task.isCancelled == false, let operation = await iterator.next() {
            switch operation {
            case .prepare(let operationID, let continuation):
                do {
                    try await session.prepareTranslation()
                    complete(
                        operationID: operationID,
                        continuation: continuation,
                        result: .success(())
                    )
                } catch {
                    complete(
                        operationID: operationID,
                        continuation: continuation,
                        result: .failure(error)
                    )
                }
            case .translate(let operationID, let batch, let continuation):
                do {
                    let requests = batch.map { item in
                        TranslationSession.Request(
                            sourceText: item.sourceText,
                            clientIdentifier: item.clientIdentifier
                        )
                    }
                    let responses = try await session.translations(from: requests)
                    let results = responses.map { response in
                        ResultItem(
                            clientIdentifier: response.clientIdentifier,
                            sourceText: response.sourceText,
                            translatedText: response.targetText
                        )
                    }

                    complete(
                        operationID: operationID,
                        continuation: continuation,
                        result: .success(results)
                    )
                } catch {
                    complete(
                        operationID: operationID,
                        continuation: continuation,
                        result: .failure(error)
                    )
                }
            }
        }
    }

    private func beginRunningSessionLoop() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }

        guard isRunning == false else {
            return false
        }

        isRunning = true
        return true
    }

    private func endRunningSessionLoop() {
        stateLock.lock()
        isRunning = false
        stateLock.unlock()
    }

    private func scheduleTimeout<T>(
        for operationID: UUID,
        timeoutNanoseconds: UInt64,
        continuation: CheckedContinuation<T, Error>
    ) {
        let timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
            } catch {
                return
            }

            guard let self else {
                return
            }

            guard claimCompletionSlot(for: operationID) else {
                return
            }

            continuation.resume(
                throwing: BrokerError.operationTimedOut
            )
        }

        registerTimeoutTask(timeoutTask, for: operationID)
    }

    private func complete<T>(
        operationID: UUID,
        continuation: CheckedContinuation<T, Error>,
        result: Result<T, Error>
    ) {
        guard claimCompletionSlot(for: operationID) else {
            return
        }

        continuation.resume(with: result)
    }

    private func registerTimeoutTask(
        _ task: Task<Void, Never>,
        for operationID: UUID
    ) {
        stateLock.lock()
        timeoutTasks[operationID] = task
        stateLock.unlock()
    }

    private func claimCompletionSlot(for operationID: UUID) -> Bool {
        stateLock.lock()
        let timeoutTask = timeoutTasks.removeValue(forKey: operationID)
        stateLock.unlock()

        guard let timeoutTask else {
            return false
        }

        timeoutTask.cancel()
        return true
    }

    private static func nanoseconds(from timeInterval: TimeInterval) -> UInt64 {
        let clampedInterval = max(timeInterval, 0)
        let nanoseconds = clampedInterval * 1_000_000_000
        return UInt64(min(nanoseconds, Double(UInt64.max)))
    }
}
