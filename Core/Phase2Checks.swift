#if DEBUG
import UIKit
import AppIntents
import Vision

// Explicit DEBUG launch modes; Release has no entry point. Export/layout exercise the production geometry functions.
enum Phase2Checks {
    @MainActor static func run(environment: AppEnvironment, mode: String) async {
        let previousIdleTimer = UIApplication.shared.isIdleTimerDisabled
        UIApplication.shared.isIdleTimerDisabled = true
        defer { UIApplication.shared.isIdleTimerDisabled = previousIdleTimer }
        let root = documents.appendingPathComponent("\(ProcessInfo.processInfo.environment["PHASE2_OUTPUT"] ?? "Phase2Reports")/\(mode)")
        do {
            guard ["quality","ocr","export","layout","route","ui","contract","presentation","verify-model"].contains(mode) else { throw failure("Unknown Phase2 check mode") }
            try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
            try writeJSON(["running":true,"mode":mode],to:root.appendingPathComponent("status.json"))
            if mode == "verify-model" {
                UIDevice.current.isBatteryMonitoringEnabled = true
                try await environment.engine.verifyInstalledModel()
                try writeJSON(["completed":true,"manifest":try modelManifest(),"counters":await environment.engine.diagnosticCounters,
                               "iOS":UIDevice.current.systemVersion,"lowPowerMode":ProcessInfo.processInfo.isLowPowerModeEnabled,
                               "batteryState":UIDevice.current.batteryState.rawValue],to:root.appendingPathComponent("status.json"))
                return
            }
            if mode == "route" || mode == "ui" || mode == "contract" {
                try await routes(environment,root:root,interactive:mode == "ui",replay:mode == "contract")
                try writeJSON(["completed":true,"mode":mode],to:root.appendingPathComponent("status.json")); return
            }
            if mode == "presentation" {
                let result = try recordedResult()
                let input = ScreenshotInput(id:result.requestID,imageData:result.original.pngData()!,size:result.original.size,orientation:.up,sourceMetadata:.scaffold)
                environment.coordinator.showFloatingPreview(job:ProcessingJob(id:input.id,input:input))
                environment.processingViewModel.presentRegressionResult(result,job:ProcessingJob(id:input.id,input:input))
                let before = await environment.engine.diagnosticCounters
                let deadline = Date().addingTimeInterval(90)
                while environment.coordinator.route == .floatingPreview && Date() < deadline { try await Task.sleep(for:.milliseconds(100)) }
                let after = await environment.engine.diagnosticCounters
                assert(before == after)
                if environment.coordinator.route == .result { assert(environment.coordinator.processedScreenshot?.renderedImage === result.renderedImage) }
                try writeJSON(["completed":true,"provenance":"recorded real MT output; presentation only","route":String(describing:environment.coordinator.route),"before":before,"after":after,"sameImage":environment.coordinator.processedScreenshot?.renderedImage === result.renderedImage],to:root.appendingPathComponent("report.json"))
                try writeJSON(["completed":true,"mode":mode],to:root.appendingPathComponent("status.json"))
                return
            }
            let corpus = documents.appendingPathComponent(ProcessInfo.processInfo.environment["PHASE2_CORPUS"] ?? "Phase2Corpus")
            let cases = try FileManager.default.contentsOfDirectory(at:corpus,includingPropertiesForKeys:nil).filter { $0.hasDirectoryPath }.sorted { $0.path < $1.path }
            var summary: [[String:Any]] = []
            for folder in cases {
                guard let image = UIImage(contentsOfFile:folder.appendingPathComponent("original.png").path), let cg = image.cgImage else { throw failure("Invalid regression PNG") }
                let out = root.appendingPathComponent(folder.lastPathComponent)
                try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
                try Data(contentsOf:folder.appendingPathComponent("original.png")).write(to:out.appendingPathComponent("original.png"),options:.atomic)
                if mode == "ocr" {
                    var experiments: [[String:Any]] = []
                    for correction in [false,true] {
                        for languages in [["zh-Hans","zh-Hant","en-US"],["zh-Hans","en-US"]] {
                            let start = Date()
                            let observations = try readScreenshotText(cg) { $0.usesLanguageCorrection = correction; $0.recognitionLanguages = languages }
                            experiments.append(["correction":correction,"languages":languages,"ocrMs":Date().timeIntervalSince(start)*1000,"observations":observations.map(\.diagnostic)])
                        }
                    }
                    try writeJSON(experiments,to:out.appendingPathComponent("experiments.json"))
                    continue
                }
                let ocrStart = Date()
                let observations = classifyScreenshotText(try readScreenshotText(cg),size:image.size)
                let ocrMs = Date().timeIntervalSince(ocrStart)*1000
                let groupingStart = Date()
                let groups = groupText(observations)
                let groupingMs = Date().timeIntervalSince(groupingStart)*1000
                try savePNG(annotated(image,observations:observations,groups:[]),to:out.appendingPathComponent("vision-observations.png"))
                try savePNG(annotated(image,observations:observations,groups:groups),to:out.appendingPathComponent("grouping-debug.png"))
                if mode == "layout" {
                    var runs: [[String:Any]] = []
                    for language in TargetLanguage.allCases {
                        let mt = try JSONSerialization.jsonObject(with:Data(contentsOf:folder.appendingPathComponent("mt-\(language.rawValue).json"))) as! [String:Any]
                        let rows = mt["blocks"] as! [[String:Any]]
                        var outputs: [Int:String] = [:]
                        for group in groups {
                            guard let row = rows.first(where: { $0["id"] as? Int == group.id && $0["source"] as? String == group.text }),
                                  let translation = row["translation"] as? String else { throw failure("No live MT record matching group \(group.id) in \(folder.lastPathComponent)") }
                            outputs[group.id] = translation
                        }
                        let start = Date()
                        let placements = layoutScreenshotOverlays(groups,observations:observations,outputs:outputs,size:image.size)
                        let rendered = renderScreenshotOverlays(image,placements:placements,outputs:outputs)
                        let renderMs = Date().timeIntervalSince(start)*1000
                        let metrics = overlayMetrics(placements,observations:observations,blocks:groups,size:image.size)
                        assert(metrics["panelIntersections"] as? Int == 0 && metrics["unrelatedSourceOverlap"] as? Int == 0 && metrics["boundsViolations"] as? Int == 0)
                        let run: [String:Any] = ["target":language.rawValue,"layoutMetrics":metrics,"renderMs":renderMs,"translationMs":mt["translationMs"]!,
                            "translationProvenance":mt["provenance"]!,"outputs":outputs.map { ["id":$0.key,"text":$0.value] as [String:Any] }]
                        runs.append(run)
                        try savePNG(rendered,to:out.appendingPathComponent("translated-result-\(language == .english ? "en" : "ru").png"))
                    }
                    var report = runs[0]
                    report["runs"] = runs; report["ocr"] = observations.map(\.diagnostic); report["groups"] = groups.map(\.diagnostic)
                    report["groupingMetrics"] = groupingMetrics(observations,blocks:groups); report["ocrMs"] = ocrMs; report["groupingMs"] = groupingMs
                    report["pipelineProvenance"] = "production iOS geometry with separately generated macOS native translations; not an iOS end-to-end run"
                    report["totalMs"] = NSNull()
                    try writeJSON(report,to:out.appendingPathComponent("report.json")); continue
                }
                if mode == "export" {
                    try writeJSON(["ocr":observations.map(\.diagnostic),"groups":groups.map(\.diagnostic),
                                   "groupingMetrics":groupingMetrics(observations,blocks:groups),"ocrMs":ocrMs,"groupingMs":groupingMs],
                                  to:out.appendingPathComponent("report.json"))
                    continue
                }
                var reports: [[String:Any]] = []
                for language in TargetLanguage.allCases {
                    try writeJSON(["running":folder.lastPathComponent,"language":language.rawValue],to:root.appendingPathComponent("status.json"))
                    let result = try await ScreenshotProcessor.process(image,to:language,engine:environment.engine)
                    try savePNG(result.image,to:out.appendingPathComponent("translated-result-\(language == .english ? "en" : "ru").png"))
                    reports.append(result.report)
                    let metrics = result.report["layoutMetrics"] as! [String:Any]
                    assert(metrics["panelIntersections"] as? Int == 0)
                    assert(metrics["unrelatedSourceOverlap"] as? Int == 0)
                    assert(metrics["boundsViolations"] as? Int == 0)
                    try writeJSON(["runs":reports],to:out.appendingPathComponent("report.json"))
                    print("PHASE2_QUALITY \(folder.lastPathComponent) \(language.rawValue) complete")
                }
                summary.append(["case":folder.lastPathComponent,"runs":reports])
                try writeJSON(summary,to:root.appendingPathComponent("index.json"))
            }
            try writeJSON(["completed":true,"iOS":UIDevice.current.systemVersion,"counters":await environment.engine.diagnosticCounters],to:root.appendingPathComponent("status.json"))
        } catch {
            try? writeJSON(["completed":false,"error":error.localizedDescription],to:root.appendingPathComponent("status.json"))
            print("PHASE2_FAILED \(error.localizedDescription)")
        }
    }

    static func diagnosticBlock(_ row: [String:Any]) -> OCRBlock {
        let r = (row["rect"] as! [NSNumber]).map(\.doubleValue)
        return OCRBlock(id:row["id"] as! Int,text:row["text"] as! String,
                       rect:CGRect(x:r[0],y:r[1],width:r[2],height:r[3]),observations:row["observations"] as! [Int],
                       confidence:(row["confidence"] as? NSNumber)?.floatValue ?? 1,exclusion:row["exclusion"] as? String)
    }

    static func annotated(_ image: UIImage, observations: [OCRBlock], groups: [OCRBlock]) -> UIImage {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size:image.size,format:format).image { context in
            image.draw(at:.zero)
            for observation in observations {
                let color: UIColor = observation.exclusion == nil ? .systemCyan : .systemRed
                color.setStroke(); context.cgContext.setLineWidth(2); context.cgContext.stroke(observation.rect)
                let label = "O\(observation.id) \(String(format:"%.2f",observation.confidence))" + (observation.exclusion == nil ? "" : " ignored")
                (label as NSString).draw(at:observation.rect.origin,withAttributes:[.font:UIFont.systemFont(ofSize:14),.foregroundColor:color,.backgroundColor:UIColor.black])
            }
            for group in groups {
                let color = UIColor(hue:CGFloat((group.id*137)%360)/360,saturation:0.8,brightness:0.8,alpha:1)
                color.setStroke(); context.cgContext.setLineWidth(4); context.cgContext.stroke(group.rect)
                ("G\(group.id): \(group.observations)" as NSString).draw(at:CGPoint(x:group.rect.minX,y:max(0,group.rect.minY-22)),withAttributes:[.font:UIFont.systemFont(ofSize:20),.foregroundColor:color,.backgroundColor:UIColor.white])
                let members = observations.filter { group.observations.contains($0.id) }.sorted(by:readingOrder)
                for pair in zip(members,members.dropFirst()) {
                    context.cgContext.move(to:CGPoint(x:pair.0.rect.midX,y:pair.0.rect.midY))
                    context.cgContext.addLine(to:CGPoint(x:pair.1.rect.midX,y:pair.1.rect.midY)); context.cgContext.strokePath()
                }
            }
        }
    }

    static func recordedResult(requestID: UUID = UUID()) throws -> ProcessedScreenshot {
        let root = documents.appendingPathComponent("Phase2Replay")
        guard let original = UIImage(contentsOfFile:root.appendingPathComponent("original.png").path),
              let image = UIImage(contentsOfFile:root.appendingPathComponent("translated-result.png").path),
              let report = try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("report.json"))) as? [String:Any],
              let groups = report["groups"] as? [[String:Any]], let outputs = report["outputs"] as? [[String:Any]] else { throw failure("Missing recorded result fixture") }
        let metrics = report["layoutMetrics"] as! [String:Any], layouts = metrics["placements"] as! [[String:Any]]
        let warnings = (metrics["failedPlacements"] as? [[String:Any]] ?? []).map { ProcessingWarning(blockID:$0["id"] as! Int,stage:.rendering,message:$0["reason"] as! String) }
        func rect(_ values: [Double]) -> CGRect { CGRect(x:values[0],y:values[1],width:values[2],height:values[3]) }
        let blocks = groups.map { group -> ProcessedBlock in
            let id = group["id"] as! Int
            return ProcessedBlock(id:id,sourceText:group["text"] as! String,
                translatedText:outputs.first { $0["id"] as? Int == id }?["text"] as? String,
                sourceRect:rect(group["rect"] as! [Double]),renderedRect:(layouts.first { $0["id"] as? Int == id }?["rect"] as? [Double]).map(rect),failure:warnings.first { $0.blockID == id })
        }
        return ProcessedScreenshot(requestID:requestID,targetLanguage:TargetLanguage(rawValue:report["target"] as! String)!,originalImage:original,renderedImage:image,blocks:blocks,warnings:warnings,report:report)
    }

    @MainActor static func routes(_ environment: AppEnvironment, root: URL, interactive: Bool, replay: Bool = false) async throws {
        let corpus = ProcessInfo.processInfo.environment["PHASE2_CORPUS"] ?? "Phase2Corpus"
        let sourceCase = ProcessInfo.processInfo.environment["PHASE2_ROUTE_SOURCE"] ?? "real-action-pdf"
        let source = documents.appendingPathComponent("\(corpus)/\(sourceCase)/original.png")
        let data = try Data(contentsOf:source)
        let previousTarget = environment.settingsViewModel.localTarget
        defer { environment.settingsViewModel.localTarget = previousTarget }
        environment.settingsViewModel.localTarget = .english
        let foregroundDeadline = Date().addingTimeInterval(10)
        while (!environment.isActive || UIApplication.shared.applicationState != .active) && Date() < foregroundDeadline { try await Task.sleep(for:.milliseconds(100)) }
        guard environment.isActive, UIApplication.shared.applicationState == .active else { throw failure("Route harness requires foreground app") }
        func handoff(_ imageData: Data = data) async throws -> UUID {
            let previousID = environment.coordinator.activeJob?.id
            let intent = FloatingScreenTranslateIntent()
            intent.screenshot = IntentFile(data:imageData,filename:"phase2.png",type:.png)
            _ = try await intent.perform()
            await environment.consumePendingScreenshotIfNeeded()
            let deadline = Date().addingTimeInterval(10)
            while (environment.coordinator.activeJob == nil || environment.coordinator.activeJob?.id == previousID) && Date() < deadline { try await Task.sleep(for:.milliseconds(50)) }
            guard let id = environment.coordinator.activeJob?.id else { throw failure("Handoff not consumed") }
            assert(environment.coordinator.route == .floatingPreview)
            return id
        }
        func completed(_ id: UUID) async throws -> ProcessedScreenshot {
            let deadline = Date().addingTimeInterval(240)
            while Date() < deadline {
                if let result = environment.coordinator.processedScreenshot, result.requestID == id { return result }
                if environment.processingViewModel.state == .failed { throw failure(environment.processingViewModel.activeError?.detail ?? "failed") }
                try await Task.sleep(for:.milliseconds(100))
            }
            throw failure("Route test timed out")
        }
        let first = try await handoff()
        if replay {
            environment.processingViewModel.cancelCurrentJob()
            assert(environment.processingViewModel.state == .cancelled)
            environment.processingViewModel.retryCurrentJob()
            let replacement = try await handoff()
            assert(replacement != first)
            environment.processingViewModel.cancelCurrentJob()
            let result = try recordedResult(requestID:replacement), job = environment.coordinator.activeJob!
            environment.processingViewModel.presentRegressionResult(result,job:job)
            assert(environment.coordinator.route == .floatingPreview)
            let before = await environment.engine.diagnosticCounters
            environment.coordinator.openFullViewer()
            assert(environment.coordinator.processedScreenshot?.renderedImage === result.renderedImage)
            let after = await environment.engine.diagnosticCounters
            assert(before == after)
            environment.closeTranslation(); environment.coordinator.releaseLastResult()
            assert(environment.coordinator.route == .idle)
            try writeJSON(["completed":true,"provenance":"real intent.perform handoff/cancel/retry/replacement; recorded completed DTO injected for presentation only, inference NOT validated",
                           "beforeOpenFull":before,"afterOpenFull":after,"sameRenderedImage":true,"dismissed":true],to:root.appendingPathComponent("report.json"))
            return
        }
        if interactive {
            try writeJSON(["started":true,"requestID":first.uuidString],to:root.appendingPathComponent("status.json"))
            let deadline = Date().addingTimeInterval(300)
            while environment.coordinator.processedScreenshot == nil && Date() < deadline {
                try await Task.sleep(for:.milliseconds(100))
            }
            guard let result = environment.coordinator.processedScreenshot else { throw failure("UI result timed out") }
            let counters = await environment.engine.diagnosticCounters
            try writeJSON(["completed":true,"counters":counters],to:root.appendingPathComponent("status.json"))
            while environment.coordinator.route == .floatingPreview && Date() < deadline { try await Task.sleep(for:.milliseconds(100)) }
            let after = await environment.engine.diagnosticCounters
            assert(counters == after)
            if environment.coordinator.route == .result { assert(environment.coordinator.processedScreenshot?.renderedImage === result.renderedImage) }
            try writeJSON(["completed":true,"route":String(describing:environment.coordinator.route),"before":counters,"after":after,"sameImage":environment.coordinator.processedScreenshot?.renderedImage === result.renderedImage],to:root.appendingPathComponent("ui-actions.json"))
            return
        }
        func inNativeTranslation() async throws {
            let deadline = Date().addingTimeInterval(120)
            while Date() < deadline {
                if environment.processingViewModel.state == .translating, environment.processingViewModel.translatedCount >= 2 { return }
                if environment.processingViewModel.state == .failed { throw failure(environment.processingViewModel.activeError?.detail ?? "failed") }
                try await Task.sleep(for:.milliseconds(25))
            }
            throw failure("Native progress did not reach two completed sequences")
        }
        try await inNativeTranslation()
        environment.processingViewModel.cancelCurrentJob()
        assert(environment.processingViewModel.state == .cancelled)
        environment.processingViewModel.retryCurrentJob()
        let retried = try await completed(first)
        assert(retried.report["modelReused"] as? Bool == true)
        await environment.engine.clearTranslationMemoryForChecks() // Exercise native replacement even after the preceding retry populated exact memory.
        _ = try await handoff()
        try await inNativeTranslation()
        let replacementData: Data
        if let replacementCase = ProcessInfo.processInfo.environment["PHASE2_ROUTE_REPLACEMENT"] {
            replacementData = try Data(contentsOf:documents.appendingPathComponent("\(corpus)/\(replacementCase)/original.png"))
            assert(replacementData != data)
        } else { replacementData = data }
        let replacement = try await handoff(replacementData)
        let result = try await completed(replacement)
        assert(result.requestID != first)
        assert(environment.coordinator.route == .floatingPreview)
        let before = await environment.engine.diagnosticCounters
        environment.coordinator.openFullViewer()
        assert(environment.coordinator.route == .result)
        assert(environment.coordinator.processedScreenshot?.renderedImage === result.renderedImage)
        assert(environment.coordinator.processedScreenshot?.requestID == result.requestID)
        let after = await environment.engine.diagnosticCounters
        assert(before == after)
        try savePNG(result.image,to:root.appendingPathComponent("floating-result.png"))
        environment.closeTranslation(); environment.coordinator.releaseLastResult()
        assert(environment.coordinator.route == .idle && environment.coordinator.processedScreenshot == nil)
        try writeJSON(["completed":true,"checks":["intent.perform handoff","floating progress","cancel","retry","rapid replacement","floating result","same UIImage full viewer","zero extra requests/generations/loads","dismiss"],
                       "beforeOpenFull":before,"afterOpenFull":after,"retriedResult":retried.report,"differentReplacementPixels":replacementData != data,"result":result.report],to:root.appendingPathComponent("report.json"))
    }
}
#endif
