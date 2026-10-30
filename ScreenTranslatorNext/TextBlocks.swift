import Foundation
import CoreGraphics

enum TargetLanguage: String, CaseIterable, Codable, Sendable {
    case english, russian
    var title: String { self == .english ? "English" : "Russian" }
    var promptName: String { self == .english ? "英语" : "俄语" }
}

struct OCRBlock {
    let id: Int
    var text: String
    var rect: CGRect
    var observations: [Int]
    var confidence: Float = 1
    var candidates: [TextCandidate] = []
    var exclusion: String?
    var lineHeight: CGFloat = 0
    var relationships: [GroupingLink] = []
}

struct TextCandidate { let text: String; let confidence: Float }
struct GroupingLink { let from: Int; let to: Int; let reason: String }

func rectValues(_ rect: CGRect) -> [CGFloat] { [rect.minX, rect.minY, rect.width, rect.height] }

extension OCRBlock {
    var diagnostic: [String: Any] {
        ["id":id, "text":text, "rect":rectValues(rect), "observations":observations,
         "confidence":confidence, "candidates":candidates.map { ["text":$0.text,"confidence":$0.confidence] as [String:Any] },
         "exclusion":exclusion ?? NSNull(), "lineHeight":lineHeight,
         "relationships":relationships.map { ["from":$0.from,"to":$0.to,"reason":$0.reason] as [String:Any] }]
    }
}

func containsChinese(_ text: String) -> Bool {
    text.unicodeScalars.contains { scalar in
        (0x3400...0x4DBF).contains(scalar.value) || (0x4E00...0x9FFF).contains(scalar.value)
            || (0xF900...0xFAFF).contains(scalar.value) || (0x20000...0x323AF).contains(scalar.value)
    }
}

func groupText(_ observations: [OCRBlock]) -> [OCRBlock] {
    var rows: [OCRBlock] = []
    for item in readingOrdered(observations.filter({ $0.exclusion == nil })) {
        if let index = rows.lastIndex(where: { row in
            let overlap = min(row.rect.maxY, item.rect.maxY) - max(row.rect.minY, item.rect.minY)
            let gap = max(row.rect.minX, item.rect.minX) - min(row.rect.maxX, item.rect.maxX)
            let h = max(row.rect.height,item.rect.height)
            let mixed = containsChinese(row.text) != containsChinese(item.text)
            return overlap > min(row.rect.height, item.rect.height) * 0.7
                && min(row.rect.height,item.rect.height) / h > 0.65
                && gap >= -h * 0.1 && gap < h * (mixed ? 1.2 : 0.35)
        }) {
            let before = item.rect.minX < rows[index].rect.minX
            rows[index].text = before ? item.text + " " + rows[index].text : rows[index].text + " " + item.text
            rows[index].rect = rows[index].rect.union(item.rect)
            rows[index].relationships += item.relationships + [GroupingLink(from:rows[index].observations.last!,to:item.observations.first!,reason:"same-row fragments")]
            rows[index].observations += item.observations
            rows[index].confidence = min(rows[index].confidence,item.confidence)
            rows[index].lineHeight = max(rows[index].lineHeight,item.rect.height)
        } else { rows.append(item) }
    }
    var blocks: [OCRBlock] = []
    func hasRowPeer(_ row: OCRBlock) -> Bool {
        rows.contains { other in
            other.id != row.id && !other.observations.contains(row.id)
                && abs(other.rect.midY-row.rect.midY) < min(other.rect.height,row.rect.height)*0.65
                && (other.rect.maxX < row.rect.minX || other.rect.minX > row.rect.maxX)
        }
    }
    for row in readingOrdered(rows) {
        if let last = blocks.last {
            let h = row.rect.height, previousHeight = last.lineHeight > 0 ? last.lineHeight : last.rect.height
            let gap = row.rect.minY-last.rect.maxY
            let leftAligned = abs(last.rect.minX-row.rect.minX) < h*0.6
            let centered = abs(last.rect.midX-row.rect.midX) < h*0.65 && row.rect.width < last.rect.width*0.95
            let overlap = min(last.rect.maxX,row.rect.maxX)-max(last.rect.minX,row.rect.minX)
            let terminates = "。！？!?".contains(last.text.last ?? " ")
            if !terminates && (leftAligned || centered) && gap >= -h*0.25 && gap < h*0.7
                && min(h,previousHeight)/max(h,previousHeight) > 0.65
                && last.rect.width > h*7.5 && overlap > min(last.rect.width,row.rect.width)*0.7
                && !hasRowPeer(row) && !hasRowPeer(last) {
            let separator = containsChinese(String(last.text.suffix(1))) && containsChinese(String(row.text.prefix(1))) ? "" : "\n"
            blocks[blocks.count - 1].text += separator + row.text
            blocks[blocks.count - 1].rect = last.rect.union(row.rect)
            blocks[blocks.count - 1].relationships += row.relationships + [GroupingLink(from:last.observations.last!,to:row.observations.first!,reason:centered ? "center-aligned wrapped lines" : "left-aligned wrapped lines")]
            blocks[blocks.count - 1].observations += row.observations
            blocks[blocks.count - 1].lineHeight = max(previousHeight,h)
            blocks[blocks.count - 1].confidence = min(last.confidence,row.confidence)
            continue
            }
        }
        blocks.append(row)
    }
    // ponytail: O(n²) geometry; screenshot-sized input, no semantic grouping or dictionaries.
    return blocks.filter { containsChinese($0.text) }
}

func readingOrder(_ a: OCRBlock, _ b: OCRBlock) -> Bool {
    (a.rect.minY,a.rect.minX,a.id) < (b.rect.minY,b.rect.minX,b.id)
}

func readingOrdered(_ items: [OCRBlock]) -> [OCRBlock] {
    var rows: [[OCRBlock]] = []
    for item in items.sorted(by:readingOrder) {
        if let anchor = rows.last?.first,
           item.rect.minY-anchor.rect.minY < min(item.rect.height,anchor.rect.height)*0.5,
           min(item.rect.maxY,anchor.rect.maxY)-max(item.rect.minY,anchor.rect.minY) > min(item.rect.height,anchor.rect.height)*0.5 {
            rows[rows.count-1].append(item)
        } else { rows.append([item]) }
    }
    return rows.flatMap { $0.sorted { ($0.rect.minX,$0.id) < ($1.rect.minX,$1.id) } }
}

func groupingMetrics(_ observations: [OCRBlock], blocks: [OCRBlock]) -> [String:Any] {
    let accepted = observations.filter { $0.exclusion == nil }
    return ["observationCount":observations.count,"acceptedObservationCount":accepted.count,
            "ignoredObservationCount":observations.count-accepted.count,"finalGroupCount":blocks.count,
            "meanObservationsPerGroup":Double(blocks.reduce(0) { $0+$1.observations.count })/Double(max(1,blocks.count)),
            "largestGroup":blocks.map { $0.observations.count }.max() ?? 0,
            "singleObservationGroups":blocks.filter { $0.observations.count == 1 }.count,
            "edgeClippedExclusions":observations.filter { $0.exclusion?.contains("edge-clipped") == true }.count,
            "untranslatedNonChineseObservations":accepted.filter { !containsChinese($0.text) && !blocks.flatMap(\.observations).contains($0.id) }.count]
}

struct ProtectedSpans {
    let input: String
    let spans: [String]
    init(_ source: String) throws {
        guard !source.contains("[[P") else { throw failure("Source contains reserved placeholder syntax") }
        let pattern = #"[¥￥$€₽]\s?\d+(?:[.,]\d+)?|\d+(?:[.,]\d+)?(?:\s?[×x]\s?\d+(?:[.,]\d+)?)+(?:\s?(?:mm|cm|m))?|\d+(?:[.,]\d+)?\s?(?:mAh|MHz|GHz|kg|K|W|V|mm|cm)\b|[A-Za-z][A-Za-z0-9]*(?:[-_][A-Za-z0-9]+)+|[A-Za-z]{2,}[A-Za-z0-9]*"#
        let regex = try NSRegularExpression(pattern: pattern)
        let string = source as NSString
        let matches = regex.matches(in: source, range: NSRange(location: 0, length: string.length))
        spans = matches.map { string.substring(with: $0.range) }
        var masked = source
        for (index, match) in matches.enumerated().reversed() {
            masked = (masked as NSString).replacingCharacters(in: match.range, with: "[[P\(index)]]")
        }
        input = masked
    }
    func restore(_ translated: String) throws -> String {
        let regex = try NSRegularExpression(pattern: #"\[\[P\d+\]\]"#)
        let string = translated as NSString
        let actual = regex.matches(in: translated, range: NSRange(location: 0, length: string.length))
            .map { string.substring(with: $0.range) }
        let expected = spans.indices.map { "[[P\($0)]]" }
        guard actual == expected else { throw failure("Protected spans corrupted: expected \(expected), received \(actual)") }
        var result = translated
        for index in spans.indices { result = result.replacingOccurrences(of: "[[P\(index)]]", with: spans[index]) }
        guard !result.contains("[[P") else { throw failure("Malformed protected placeholder") }
        return result
    }
}

func failure(_ message: String) -> NSError {
    NSError(domain: "ScreenTranslatorNext", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
}
