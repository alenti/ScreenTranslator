import Foundation
import OSLog
import SQLite3

struct QuickLookEnglishDictionaryHit: Equatable {
    let source: String
    let englishDisplay: String
    let englishRaw: String
    let pinyin: String
    let sourceKind: String
    let priority: Int
    let selectionReason: String
    let matchKind: QuickLookDictionaryMatchKind
}

final class QuickLookCEDICTStore: @unchecked Sendable {
    static let shared = QuickLookCEDICTStore()

    private let databaseURL: URL?
    private let logger = Logger(
        subsystem: "AlenShamatov.ScreenTranslator",
        category: "QuickLookDictionary"
    )

    var isAvailable: Bool {
        databaseURL != nil
    }

    init(bundle: Bundle = .main) {
        let url = bundle.url(
            forResource: "QuickLookCEDICTGeneral_v2",
            withExtension: "sqlite"
        )
            ?? bundle.url(
                forResource: "QuickLookCEDICTGeneral_v2",
                withExtension: "sqlite",
                subdirectory: "Dictionaries"
            )
            ?? bundle.url(
                forResource: "QuickLookCEDICTGeneral_v2",
                withExtension: "sqlite",
                subdirectory: "Resources/Dictionaries"
            )

        self.databaseURL = url

        if let url {
            let fileSize = (
                try? FileManager.default
                    .attributesOfItem(atPath: url.path)[.size] as? NSNumber
            )?.intValue ?? 0
            logger.info(
                "Quick Look English dictionary DB opened path=\(url.lastPathComponent, privacy: .public), bytes=\(fileSize)"
            )
        } else {
            logger.error("Quick Look English dictionary DB missing from bundle")
        }
    }

    func lookupExact(_ sourceCompact: String) -> QuickLookEnglishDictionaryHit? {
        guard sourceCompact.isEmpty == false else {
            return nil
        }

        return query(
            terms: [sourceCompact],
            limit: 1
        ).first.map { row in
            row.hit(
                matchKind: row.sourceKind == "app_phrase_override"
                    ? .phraseOverride
                    : .exact
            )
        }
    }

    func lookupSegments(
        in sourceCompact: String,
        maxSegments: Int = 3
    ) -> [QuickLookEnglishDictionaryHit] {
        let candidates = segmentCandidates(in: sourceCompact)

        guard candidates.isEmpty == false else {
            return []
        }

        let rowsBySource = Dictionary(
            grouping: query(terms: Array(Set(candidates.map(\.term)))),
            by: \.sourceCompact
        )
        var matchedCandidates: [QuickLookSegmentCandidateHit] = []

        for candidate in candidates {
            guard let row = rowsBySource[candidate.term]?.first else {
                continue
            }

            matchedCandidates.append(
                QuickLookSegmentCandidateHit(
                    candidate: candidate,
                    hit: row.hit(matchKind: .segment)
                )
            )
        }

        matchedCandidates.sort { lhs, rhs in
            if lhs.hit.sourceKind != rhs.hit.sourceKind {
                return lhs.hit.sourceKind == "app_phrase_override"
            }

            if lhs.candidate.length != rhs.candidate.length {
                return lhs.candidate.length > rhs.candidate.length
            }

            if lhs.hit.priority != rhs.hit.priority {
                return lhs.hit.priority > rhs.hit.priority
            }

            return lhs.candidate.start < rhs.candidate.start
        }

        var occupied = IndexSet()
        var selected: [QuickLookSegmentCandidateHit] = []

        for candidateHit in matchedCandidates {
            let range = candidateHit.candidate.start
                ..< (candidateHit.candidate.start + candidateHit.candidate.length)

            guard occupied.intersection(IndexSet(integersIn: range)).isEmpty else {
                continue
            }

            occupied.insert(integersIn: range)
            selected.append(candidateHit)

            if selected.count >= maxSegments {
                break
            }
        }

        return selected
            .sorted { $0.candidate.start < $1.candidate.start }
            .map(\.hit)
    }

    private func query(
        terms: [String],
        limit: Int? = nil
    ) -> [QuickLookCEDICTRow] {
        guard let databaseURL else {
            return []
        }

        let uniqueTerms = Array(Set(terms.filter { $0.isEmpty == false }))

        guard uniqueTerms.isEmpty == false else {
            return []
        }

        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX

        guard sqlite3_open_v2(databaseURL.path, &database, flags, nil) == SQLITE_OK,
              let database else {
            logger.error("Quick Look English dictionary DB open failed")
            return []
        }

        defer {
            sqlite3_close(database)
        }

        let placeholders = uniqueTerms.map { _ in "?" }.joined(separator: ",")
        let limitClause = limit.map { " LIMIT \($0)" } ?? ""
        let sql = """
        SELECT simplified, traditional, sourceCompact, pinyin, englishRaw, \
        englishDisplay, sourceKind, priority, selectionReason
        FROM entries
        WHERE sourceCompact IN (\(placeholders))
        ORDER BY
            CASE WHEN sourceKind = 'app_phrase_override' THEN 2 ELSE 1 END DESC,
            priority DESC,
            length(sourceCompact) DESC
        \(limitClause)
        """

        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            logger.error("Quick Look English dictionary query prepare failed")
            return []
        }

        defer {
            sqlite3_finalize(statement)
        }

        let sqliteTransient = unsafeBitCast(
            -1,
            to: sqlite3_destructor_type.self
        )

        for (index, term) in uniqueTerms.enumerated() {
            sqlite3_bind_text(
                statement,
                Int32(index + 1),
                term,
                -1,
                sqliteTransient
            )
        }

        var rows: [QuickLookCEDICTRow] = []

        while sqlite3_step(statement) == SQLITE_ROW {
            rows.append(QuickLookCEDICTRow(statement: statement))
        }

        return rows
    }

    private func segmentCandidates(
        in sourceCompact: String
    ) -> [QuickLookSegmentCandidate] {
        let characters = Array(sourceCompact)

        guard characters.count >= 2 else {
            return []
        }

        let maxLength = min(8, characters.count)
        var candidates: [QuickLookSegmentCandidate] = []

        for start in characters.indices {
            let remaining = characters.count - start
            let candidateMaxLength = min(maxLength, remaining)

            guard candidateMaxLength >= 2 else {
                continue
            }

            for length in stride(from: candidateMaxLength, through: 2, by: -1) {
                let end = start + length
                let term = String(characters[start..<end])

                guard isUsefulSegmentCandidate(term) else {
                    continue
                }

                candidates.append(
                    QuickLookSegmentCandidate(
                        term: term,
                        start: start,
                        length: length
                    )
                )
            }
        }

        return candidates
    }

    private func isUsefulSegmentCandidate(_ term: String) -> Bool {
        guard term.count >= 2 else {
            return false
        }

        return term.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(Int(scalar.value))
        }
    }
}

private struct QuickLookCEDICTRow: Equatable {
    let simplified: String
    let traditional: String
    let sourceCompact: String
    let pinyin: String
    let englishRaw: String
    let englishDisplay: String
    let sourceKind: String
    let priority: Int
    let selectionReason: String

    init(statement: OpaquePointer) {
        self.simplified = Self.text(statement, index: 0)
        self.traditional = Self.text(statement, index: 1)
        self.sourceCompact = Self.text(statement, index: 2)
        self.pinyin = Self.text(statement, index: 3)
        self.englishRaw = Self.text(statement, index: 4)
        self.englishDisplay = Self.text(statement, index: 5)
        self.sourceKind = Self.text(statement, index: 6)
        self.priority = Int(sqlite3_column_int(statement, 7))
        self.selectionReason = Self.text(statement, index: 8)
    }

    func hit(matchKind: QuickLookDictionaryMatchKind) -> QuickLookEnglishDictionaryHit {
        QuickLookEnglishDictionaryHit(
            source: simplified.isEmpty ? sourceCompact : simplified,
            englishDisplay: englishDisplay,
            englishRaw: englishRaw,
            pinyin: pinyin,
            sourceKind: sourceKind,
            priority: priority,
            selectionReason: selectionReason,
            matchKind: matchKind
        )
    }

    private static func text(
        _ statement: OpaquePointer,
        index: Int32
    ) -> String {
        guard let pointer = sqlite3_column_text(statement, index) else {
            return ""
        }

        return String(cString: pointer)
    }
}

private struct QuickLookSegmentCandidate: Equatable {
    let term: String
    let start: Int
    let length: Int
}

private struct QuickLookSegmentCandidateHit: Equatable {
    let candidate: QuickLookSegmentCandidate
    let hit: QuickLookEnglishDictionaryHit
}
