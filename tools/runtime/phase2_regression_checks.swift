import Foundation
import CoreGraphics
import CryptoKit

@main struct Phase2RegressionChecks {
    static func main() throws {
        let root = URL(fileURLWithPath:CommandLine.arguments[1])
        let suite = try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[2]))) as! [[String:Any]]
        func rect(_ values: [Double]) -> CGRect { CGRect(x:values[0],y:values[1],width:values[2],height:values[3]) }
        func area(_ r: CGRect) -> CGFloat { r.isNull ? 0 : max(0,r.width)*max(0,r.height) }
        var checks: [[String:Any]] = []
        for fixture in suite {
            let id = fixture["id"] as! String, expected = fixture["expected"] as! [String:Any]
            let report = try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent(id+"/report.json"))) as! [String:Any]
            let original = try Data(contentsOf:root.appendingPathComponent(id+"/original.png"))
            assert(SHA256.hash(data:original).map { String(format:"%02x",$0) }.joined() == fixture["sha256"] as! String)
            let observations = report["ocr"] as! [[String:Any]], groups = report["groups"] as! [[String:Any]]
            func observationID(_ values: [Double]) -> Int {
                let target = rect(values)
                let match = observations.max { area(rect($0["rect"] as! [Double]).intersection(target)) < area(rect($1["rect"] as! [Double]).intersection(target)) }!
                assert(area(rect(match["rect"] as! [Double]).intersection(target))/area(target) > 0.4)
                return match["id"] as! Int
            }
            if let rects = expected["mustMergeRects"] as? [[Double]] {
                let ids = Set(rects.map(observationID))
                assert(groups.contains { ids.isSubset(of:Set($0["observations"] as! [Int])) },"Centered paragraph split: \(id)")
            }
            if let rects = expected["mustKeepSeparateRects"] as? [[Double]] {
                let ids = Set(rects.map(observationID))
                assert(ids.count == rects.count)
                assert(groups.allSatisfy { ids.intersection(Set($0["observations"] as! [Int])).count <= 1 },"Table cells merged: \(id)")
            }
            for heading in expected["readableHeadings"] as? [String] ?? [] {
                let compact = heading.filter { !$0.isWhitespace }
                assert(observations.contains { ($0["text"] as! String).filter { !$0.isWhitespace } == compact && $0["exclusion"] is NSNull })
            }
            let grouping = report["groupingMetrics"] as! [String:Any]
            assert((grouping["edgeClippedExclusions"] as! Int) >= (expected["minimumClippedExclusions"] as? Int ?? 0))
            for run in report["runs"] as! [[String:Any]] {
                let metrics = run["layoutMetrics"] as! [String:Any]
                for key in ["panelIntersections","unrelatedSourceOverlap","boundsViolations","fitFailures"] { assert(metrics[key] as! Int == 0,"\(id) \(run["target"]!) \(key)") }
                assert((metrics["placements"] as! [[String:Any]]).allSatisfy { ($0["areaRatio"] as! Double) <= expected["maximumPanelAreaRatio"] as! Double })
                checks.append(["case":id,"language":run["target"]!,"passed":true])
            }
        }
        let data = try JSONSerialization.data(withJSONObject:["passed":true,"runs":checks],options:[.prettyPrinted,.sortedKeys])
        try data.write(to:root.appendingPathComponent("structural-checks.json"))
        print("PASS: \(checks.count) EN/RU cases; centered paragraph, separate table cells, readable headings, clipped exclusions, zero collisions/coverage/bounds/fit failures")
    }
}
