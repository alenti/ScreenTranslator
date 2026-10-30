import UIKit

enum DeviceBenchmark {
    @MainActor static func run(engine: HyMTTranslator, warnings: () -> Int, progress: (String,UIImage?) -> Void) async {
        let folder = documents.appendingPathComponent("RebootReports/\(UUID().uuidString)")
        var hardware = utsname(); uname(&hardware)
        let identifier = withUnsafePointer(to: &hardware.machine) { $0.withMemoryRebound(to: CChar.self,capacity:1) { String(cString:$0) } }
        var report: [String:Any] = ["provenance":"synthetic cards explicitly requested by user; actual on-device Vision OCR",
            "hardware":identifier,"iOS":UIDevice.current.systemVersion,"physicalMemoryBytes":ProcessInfo.processInfo.physicalMemory,
            "lowPowerMode":ProcessInfo.processInfo.isLowPowerModeEnabled,"thermalStart":ProcessInfo.processInfo.thermalState.rawValue,
            "startedAt":ISO8601DateFormatter().string(from:Date()),"runs":[]]
        do {
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            try writeJSON(report,to:folder.appendingPathComponent("index.json"))
            progress("Verifying, loading and warming model…",nil)
            report["load"] = try await engine.prepare()
            let cards = try FileManager.default.contentsOfDirectory(at:documents.appendingPathComponent("Cards"),includingPropertiesForKeys:nil)
                .filter { $0.pathExtension.lowercased() == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            guard cards.count == 4 else { throw failure("Expected four synthetic A–D PNG cards in Documents/Cards") }
            let jobs = cards.flatMap { card in TargetLanguage.allCases.map { (card,$0) } } + (0..<3).map { _ in (cards[0],TargetLanguage.russian) }
            var runs: [[String:Any]] = []
            for (index,job) in jobs.enumerated() {
                try Task.checkCancellation()
                let name = String(format:"%02d",index) + "-" + job.0.deletingPathExtension().lastPathComponent + "-" + job.1.rawValue
                progress("\(index+1)/\(jobs.count): \(name)",nil)
                var row: [String:Any] = ["case":name,"thermalBefore":ProcessInfo.processInfo.thermalState.rawValue,
                    "memoryBefore":HyMTNative.memory(),"memoryWarningsBefore":warnings()]
                do {
                    guard let image = UIImage(contentsOfFile:job.0.path) else { throw failure("Invalid card PNG") }
                    let processed = try await ScreenshotProcessor.process(image,to:job.1,engine:engine)
                    row.merge(processed.report) { _,new in new }
                    try savePNG(processed.original,to:folder.appendingPathComponent(name+"-original.png"))
                    try savePNG(processed.image,to:folder.appendingPathComponent(name+"-result.png"))
                    row["resultFile"] = name+"-result.png"
                    progress("\(index+1)/\(jobs.count): \(name) finished",processed.image)
                } catch {
                    if Task.isCancelled { throw CancellationError() }
                    row["error"] = error.localizedDescription
                }
                row["memoryWarningsAfter"] = warnings()
                runs.append(row); report["runs"] = runs
                report["thermalNow"] = ProcessInfo.processInfo.thermalState.rawValue
                try writeJSON(row,to:folder.appendingPathComponent(name+".json"))
                try writeJSON(report,to:folder.appendingPathComponent("index.json"))
                print("NEXT_BENCHMARK \(name) complete")
            }
            report["completedAt"] = ISO8601DateFormatter().string(from:Date())
            report["memoryWarnings"] = warnings(); report["memoryEnd"] = HyMTNative.memory()
            try writeJSON(report,to:folder.appendingPathComponent("index.json"))
            progress("Benchmark complete: \(folder.lastPathComponent)",nil)
            print("NEXT_BENCHMARK_COMPLETE \(folder.lastPathComponent)")
        } catch {
            report["error"] = error.localizedDescription
            try? writeJSON(report,to:folder.appendingPathComponent("index.json"))
            progress(error.localizedDescription,nil)
            print("NEXT_BENCHMARK_FAILED \(error.localizedDescription)")
        }
    }
}
