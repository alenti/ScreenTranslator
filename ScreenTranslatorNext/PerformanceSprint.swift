#if DEBUG
import UIKit
import CryptoKit

enum PerformanceSprint {
    static func checks(corpus: URL) throws {
        let a=try cacheKey("测试",target:.english,model:"a",options:["greedy":false])
        let keys=try [cacheKey("测试",target:.russian,model:"a",options:["greedy":false]),
                      cacheKey("测试",target:.english,model:"b",options:["greedy":false]),
                      cacheKey("测试",target:.english,model:"a",options:["greedy":true]),
                      cacheKey("测试2",target:.english,model:"a",options:["greedy":false])]
        assert(keys.allSatisfy { $0 != a })
        let report=try JSONSerialization.jsonObject(with:Data(contentsOf:corpus.appendingPathComponent("chat/reference.json"))) as! [String:Any]
        func block(_ row:[String:Any])->OCRBlock {
            let r=(row["rect"] as! [NSNumber]).map(\.doubleValue)
            return OCRBlock(id:row["id"] as! Int,text:row["text"] as! String,rect:CGRect(x:r[0],y:r[1],width:r[2],height:r[3]),observations:row["observations"] as! [Int],confidence:(row["confidence"] as? NSNumber)?.floatValue ?? 1,exclusion:row["exclusion"] as? String,lineHeight:(row["lineHeight"] as? NSNumber)?.doubleValue ?? 0)
        }
        let groups=(report["groups"] as! [[String:Any]]).map(block),observations=(report["ocr"] as! [[String:Any]]).map(block)
        let outputs=Dictionary(uniqueKeysWithValues:(report["blocks"] as! [[String:Any]]).map { ($0["id"] as! Int,$0["translation"] as! String) })
        let size=UIImage(contentsOfFile:corpus.appendingPathComponent("chat/original.png").path)!.size
        let placements=layoutScreenshotOverlays(groups,observations:observations,outputs:outputs,size:size)
        let metrics=overlayMetrics(placements,observations:observations,blocks:groups,size:size)
        assert(metrics["fitFailures"] as! Int == 0,"Real chat still omitted")
        for key in ["panelIntersections","unrelatedSourceOverlap","boundsViolations"] { assert(metrics[key] as! Int == 0) }
        try writeJSON(["passed":true,"realChatLayout":metrics,"cacheIsolation":true],to:documents.appendingPathComponent("PerfChecks.json"))
    }
    static func priority(_ b: OCRBlock) -> Double {
        let chinese=b.text.unicodeScalars.filter { containsChinese(String($0)) }.count
        return Double(b.rect.width*b.rect.height)*Double(max(0.2,b.confidence))*min(1,Double(chinese)/3)
    }
    static func cacheKey(_ source: String, target: TargetLanguage, model: String, options: [String:Any]) throws -> String {
        let config=try JSONSerialization.data(withJSONObject:options,options:.sortedKeys)
        return SHA256.hash(data:Data((model+"|HyMT-native-template-v1|"+target.rawValue+"|"+source.precomposedStringWithCanonicalMapping).utf8)+config).map { String(format:"%02x",$0) }.joined()
    }
    @MainActor static func run(engine: HyMTTranslator, warnings: () -> Int, progress: (String,UIImage?) -> Void) async {
        let inputRoot=documents.appendingPathComponent(ProcessInfo.processInfo.environment["PERF_CORPUS"] ?? "PerfCorpus"),root=documents.appendingPathComponent("PerfReports")
        var cache: [String:String]=[:], cacheOrder:[String]=[]
        var frozen: [String:[String]]=[:]
        do {
            UIDevice.current.isBatteryMonitoringEnabled=true
            try writeJSON(["thermal":ProcessInfo.processInfo.thermalState.rawValue,"lowPowerMode":ProcessInfo.processInfo.isLowPowerModeEnabled,"batteryState":UIDevice.current.batteryState.rawValue,"batteryLevel":UIDevice.current.batteryLevel],to:documents.appendingPathComponent("AdvancedDeviceState.json"))
            try checks(corpus:inputRoot)
            if ProcessInfo.processInfo.environment["PERF_MODE"] == "checks" { progress("Checks passed",nil);return }
            UIApplication.shared.isIdleTimerDisabled=true;UIDevice.current.isBatteryMonitoringEnabled=true
            let heartbeat = Task { @MainActor in
                while !Task.isCancelled {
                    try? writeJSON(["uptime":ProcessInfo.processInfo.systemUptime,"applicationState":UIApplication.shared.applicationState.rawValue,
                                    "thermal":ProcessInfo.processInfo.thermalState.rawValue,"batteryLevel":UIDevice.current.batteryLevel],
                                   to:documents.appendingPathComponent("AdvancedHeartbeat.json"))
                    do { try await Task.sleep(for:.seconds(5)) } catch { break }
                }
            }
            defer { heartbeat.cancel() }
            // DEBUG batch session stays awake between rounds; closing the app restores system idle behavior.
            defer { UIApplication.shared.isIdleTimerDisabled = ProcessInfo.processInfo.environment["PERF_MODE"] == "1" }
            try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
            let planName=ProcessInfo.processInfo.environment["PERF_PLAN"] ?? "PerfPlan.json"
            let plan=try JSONSerialization.jsonObject(with:Data(contentsOf:documents.appendingPathComponent(planName))) as! [String:Any]
            let manifest=plan["manifest"] as! [String:Any],round=plan["round"] as! String
            let cacheIdentity=try JSONSerialization.data(withJSONObject:manifest,options:.sortedKeys).base64EncodedString()
            let folder=root.appendingPathComponent(round);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            let freezeFolder=root.appendingPathComponent("FrozenGroups");try FileManager.default.createDirectory(at:freezeFolder,withIntermediateDirectories:true)
            for name in plan["cases"] as! [String] {
                if let data=try? Data(contentsOf:freezeFolder.appendingPathComponent(name+".json")),let strings=try JSONSerialization.jsonObject(with:data) as? [String] { frozen[name]=strings }
            }
            let modelURL=documents.appendingPathComponent(plan["modelPath"] as! String)
            guard !ProcessInfo.processInfo.isLowPowerModeEnabled else { throw failure("Low Power Mode is enabled; inference comparison was not started") }
            progress("Verifying and warming \(manifest["filename"]!)",nil)
            let loaded=try await engine.benchmarkLoad(modelURL,manifest:manifest)
            try writeJSON(loaded,to:folder.appendingPathComponent("load.json"))
            if let sources=plan["qualitySources"] as? [String] {
                let language=TargetLanguage(rawValue:plan["qualityTarget"] as? String ?? "english")!
                let options:[String:Any]=["prefix":plan["qualityPrefix"] as? Bool ?? false,"greedy":plan["qualityGreedy"] as? Bool ?? false,"dynamic":false,"batchPrefill":plan["qualityBatchPrefill"] as? Bool ?? false]
                let spans=try sources.map { try ProtectedSpans($0) }
                var generated:[String:Any]
                if plan["qualityExactBaseline"] as? Bool == true {
                    var rows:[[String:Any]]=[]
                    for (i,span) in spans.enumerated() { var row=try await engine.translate(span.input,to:language);row["index"]=i;rows.append(row) }
                    generated=["rows":rows,"exactBaseline":true]
                } else {
                    _=try await engine.benchmarkContext(plan["qualityParallel"] as? Int ?? 1)
                    generated=try await engine.benchmarkGenerate(spans.map { "将以下文本翻译为\(language.promptName)，注意只需要输出翻译后的结果，不要额外解释：\n\($0.input)" },options:options)
                }
                let rows=generated["rows"] as! [[String:Any]]
                guard rows.count==sources.count else { throw failure("Quality row mapping mismatch") }
                let outputs=try rows.enumerated().map { i,row -> [String:Any] in
                    guard row["index"] as? Int==i else { throw failure("Quality ID mismatch") }
                    var result:[String:Any]=["id":i,"source":sources[i],"generation":row]
                    do { result["translation"]=try spans[i].restore(row["text"] as! String) }
                    catch { result["error"]=error.localizedDescription }
                    return result
                }
                try writeJSON(["model":manifest,"target":language.rawValue,"outputs":outputs,"native":generated,
                               "provenance":"physical text-only semantic holdouts; excluded from screenshot performance table"],to:folder.appendingPathComponent("quality.json"))
            }
            let cases=plan["cases"] as! [String],variants=plan["variants"] as! [[String:Any]]
            var index:[[String:Any]]=[]
            for config in variants {
                let label=config["name"] as! String,p=config["parallel"] as? Int ?? 1
                let exact=config["exactBaseline"] as? Bool ?? false
                let options:[String:Any]=["prefix":config["prefix"] as? Bool ?? false,"greedy":config["greedy"] as? Bool ?? false,"dynamic":config["dynamic"] as? Bool ?? false,"batchPrefill":config["batchPrefill"] as? Bool ?? false,"refill":config["refill"] as? Bool ?? false,"longestFirst":config["longestFirst"] as? Bool ?? false]
                let useCache=config["cache"] as? Bool ?? false,repeats=useCache ? 2 : 1
                if !exact {
                    let context=try await engine.benchmarkContext(p)
                    try writeJSON(context,to:folder.appendingPathComponent(label+"-context.json"))
                    let warmup=try await engine.benchmarkGenerate(["将以下文本翻译为英语，注意只需要输出翻译后的结果，不要额外解释：\n加入购物车"],options:options)
                    if config["refill"] as? Bool == true || config["longestFirst"] as? Bool == true || (config["retryBudgetMs"] as? Double ?? 0)>0 {
                        guard warmup["decodeSteps"] != nil else { throw failure("This experiment requires the isolated advanced_native.patch build; production native was left unchanged") }
                    }
                }
                for repetition in 0..<repeats { for name in cases {
                    try Task.checkCancellation()
                    let thermalDeadline=Date().addingTimeInterval(120)
                    while ProcessInfo.processInfo.thermalState.rawValue>1 && Date()<thermalDeadline { progress("Cooling (thermal \(ProcessInfo.processInfo.thermalState.rawValue))",nil);try await Task.sleep(for:.seconds(5)) }
                    guard ProcessInfo.processInfo.thermalState.rawValue<=1,ProcessInfo.processInfo.isLowPowerModeEnabled==false else { throw failure("Benchmark stopped: thermal=\(ProcessInfo.processInfo.thermalState.rawValue), lowPowerMode=\(ProcessInfo.processInfo.isLowPowerModeEnabled), batteryState=\(UIDevice.current.batteryState.rawValue)") }
                    let target=TargetLanguage(rawValue:config["target"] as? String ?? "english")!
                    let jobName="\(label)-\(name)-\(target.rawValue)-\(repetition)"
                    let out=folder.appendingPathComponent(jobName);try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
                    progress("\(round): \(jobName)",nil)
                    try writeJSON(["running":jobName,"thermal":ProcessInfo.processInfo.thermalState.rawValue],to:root.appendingPathComponent("status.json"))
                    let data=try Data(contentsOf:inputRoot.appendingPathComponent(name+"/original.png"))
                    guard let original=UIImage(data:data) else { throw failure("Invalid corpus PNG") }
                    let t=Date(),thermal=ProcessInfo.processInfo.thermalState.rawValue,memory=HyMTNative.memory(),warningBefore=warnings()
                    var report:[String:Any]=["configuration":config,"case":name,"model":manifest,"cacheRepetition":repetition,"thermalBefore":thermal,"memoryBefore":memory,"iOS":UIDevice.current.systemVersion,"physicalMemoryBytes":ProcessInfo.processInfo.physicalMemory,"batteryState":UIDevice.current.batteryState.rawValue,"lowPowerMode":ProcessInfo.processInfo.isLowPowerModeEnabled,"inputSHA256":SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()]
                    var rendered:UIImage
                    if exact {
                        let result=try await ScreenshotProcessor.process(original,to:target,engine:engine) { stage in
                            try? writeJSON(["stage":String(describing:stage),"taskCancelled":Task.isCancelled],to:out.appendingPathComponent("stage.json"))
                        }
                        report.merge(result.report){_,new in new};rendered=result.renderedImage
                        report["blocks"]=(result.report["blocks"] as! [[String:Any]]).map { block in
                            var b=block;b["sourceCharacters"]=(b["source"] as! String).count;return b
                        }
                        let strings=(result.report["groups"] as! [[String:Any]]).map{ $0["text"] as! String }
                        if let old=frozen[name] { guard old==strings else { throw failure("OCR groups changed; comparison invalid") } } else { frozen[name]=strings }
                        report["blocksRequested"]=strings.count;report["blocksTranslated"]=(result.report["blocks"] as! [[String:Any]]).filter{$0["translation"] != nil}.count
                        report["coverage"]=["blocksPercent":100,"charactersPercent":100,"sourceAreaPercent":100]
                        let native=result.report["nativeBatch"] as? [String:Any] ?? [:]
                        report["cacheHits"]=native["cacheHits"] ?? 0;report["cacheMisses"]=native["cacheMisses"] ?? strings.count
                        report["cacheStatus"]=(native["cacheHits"] as? Int ?? 0)>0 ? "app-owned-validated-exact-cache" : "app-owned-exact-cache-empty"
                        report["preparationExcluded"]=true
                    } else {
                        let format=UIGraphicsImageRendererFormat();format.scale=1;format.opaque=true
                        let size=CGSize(width:original.size.width*original.scale,height:original.size.height*original.scale)
                        let image=UIGraphicsImageRenderer(size:size,format:format).image{_ in original.draw(in:CGRect(origin:.zero,size:size))}
                        let ot=Date();let observations=classifyScreenshotText(try readScreenshotText(image.cgImage!),size:size);let ocrMs=Date().timeIntervalSince(ot)*1000
                        let gt=Date();let all=groupText(observations);let groupingMs=Date().timeIntervalSince(gt)*1000
                        let strings=all.map(\.text)
                        if let old=frozen[name] { guard old==strings else { throw failure("OCR groups changed; comparison invalid") } } else { frozen[name]=strings }
                        let budget=config["budget"] as? Int ?? all.count
                        let selected=Set(all.sorted { let a=priority($0),b=priority($1);return a==b ? $0.id<$1.id : a>b }.prefix(budget).map(\.id))
                        let blocks=all.filter { selected.contains($0.id) }
                        let mt=Date();var outputs:[Int:String]=[:],rows:[[String:Any]]=[],pending:[OCRBlock]=[],messages:[String]=[],spans:[Int:ProtectedSpans]=[:],keys:[Int:String]=[:],leaders:[String:Int]=[:],duplicates:[Int:Int]=[:]
                        for b in blocks {
                            let span=try ProtectedSpans(b.text);spans[b.id]=span
                            let key=try cacheKey(b.text,target:target,model:cacheIdentity,options:options);keys[b.id]=key
                            if useCache,let hit=cache[key] {outputs[b.id]=hit;rows.append(["id":b.id,"source":b.text,"translation":hit,"cacheHit":true])}
                            else if config["deduplicate"] as? Bool == true,let leader=leaders[key] { duplicates[b.id]=leader }
                            else { leaders[key]=b.id;pending.append(b);messages.append("将以下文本翻译为\(target.promptName)，注意只需要输出翻译后的结果，不要额外解释：\n\(span.input)") }
                        }
                        var native:[String:Any]=[:]
                        if !pending.isEmpty {
                            native=try await engine.benchmarkGenerate(messages,options:options)
                            let generated=native["rows"] as! [[String:Any]];guard generated.count==pending.count else { throw failure("Native block count mismatch") }
                            let retryStop=Date().addingTimeInterval(min(3000,max(0,config["retryBudgetMs"] as? Double ?? 0))/1000)
                            for (i,b) in pending.enumerated() {
                                guard generated[i]["index"] as? Int==i else { throw failure("Native block ID mismatch") }
                                var row=generated[i];row["id"]=b.id;row["source"]=b.text;row["sourceCharacters"]=b.text.count;row["cacheHit"]=false
                                var validated:String?
                                do { validated=try spans[b.id]!.restore(row["text"] as! String) }
                                catch {
                                    row["error"]=error.localizedDescription
                                    let remaining=retryStop.timeIntervalSinceNow*1000
                                    if remaining>100 {
                                        do {
                                            var retryOptions=options;retryOptions["budgetMs"]=remaining
                                            let retry=try await engine.benchmarkGenerate([messages[i]],options:retryOptions)
                                            row["retryNative"]=retry
                                            guard let result=(retry["rows"] as? [[String:Any]])?.first,result["index"] as? Int==0,result["eog"] as? Bool==true else { throw failure("Retry mapping/EOG mismatch") }
                                            validated=try spans[b.id]!.restore(result["text"] as! String)
                                            row.removeValue(forKey:"error");row["retrySucceeded"]=true
                                        } catch { row["retryError"]=error.localizedDescription }
                                    }
                                }
                                if let output=validated { outputs[b.id]=output;row["translation"]=output
                                    if useCache { if cache[keys[b.id]!] == nil { cacheOrder.append(keys[b.id]!) };cache[keys[b.id]!]=output
                                        while cacheOrder.count>256 || cache.reduce(0,{ $0+$1.key.utf8.count+$1.value.utf8.count })>1_048_576 { cache.removeValue(forKey:cacheOrder.removeFirst()) } }
                                }
                                rows.append(row)
                            }
                        }
                        for b in blocks where duplicates[b.id] != nil {
                            let leader=duplicates[b.id]!
                            if let output=outputs[leader] { outputs[b.id]=output;rows.append(["id":b.id,"source":b.text,"translation":output,"deduplicatedFrom":leader,"cacheHit":false]) }
                            else { rows.append(["id":b.id,"source":b.text,"error":"Identical source leader did not produce a validated translation","deduplicatedFrom":leader]) }
                        }
                        let translationMs=Date().timeIntervalSince(mt)*1000,rt=Date()
                        let placements=layoutScreenshotOverlays(all,observations:observations,outputs:outputs,size:size)
                        rendered=renderScreenshotOverlays(image,placements:placements,outputs:outputs)
                        let chars=all.reduce(0){$0+$1.text.filter{containsChinese(String($0))}.count}, selectedChars=blocks.reduce(0){$0+$1.text.filter{containsChinese(String($0))}.count}
                        let area=all.reduce(CGFloat(0)){$0+$1.rect.width*$1.rect.height},selectedArea=blocks.reduce(CGFloat(0)){$0+$1.rect.width*$1.rect.height}
                        report["groups"]=all.map(\.diagnostic);report["ocr"]=observations.map(\.diagnostic)
                        report["blocks"]=rows;report["native"]=native
                        report["ocrMs"]=ocrMs;report["groupingMs"]=groupingMs;report["translationMs"]=translationMs
                        report["renderMs"]=Date().timeIntervalSince(rt)*1000;report["totalMs"]=Date().timeIntervalSince(t)*1000
                        report["layoutMetrics"]=overlayMetrics(placements,observations:observations,blocks:all,size:size)
                        report["blocksRequested"]=blocks.count;report["blocksTranslated"]=outputs.count;report["allBlocks"]=all.count
                        let blockCoverage=Double(blocks.count)/Double(all.count)*100
                        let characterCoverage=Double(selectedChars)/Double(max(1,chars))*100
                        let areaCoverage=Double(selectedArea)/max(1.0,Double(area))*100
                        report["coverage"]=["blocksPercent":blockCoverage,"charactersPercent":characterCoverage,"sourceAreaPercent":areaCoverage] as [String:Double]
                        report["cacheStatus"]=useCache ? (repetition==0 ? "first-pass-exact-cache" : "repeated-pass-exact-cache") : "off"
                        report["cacheHits"]=blocks.count-pending.count-duplicates.count;report["cacheMisses"]=pending.count;report["deduplicatedBlocks"]=duplicates.count;report["preparationExcluded"]=true
                    }
                    report["thermalAfter"]=ProcessInfo.processInfo.thermalState.rawValue;report["memoryEnd"]=HyMTNative.memory();report["memoryWarnings"]=warnings()-warningBefore
                    let diagnosticGroups=report["groups"] as! [[String:Any]], outputRows=report["blocks"] as! [[String:Any]]
                    let generatedIDs=Set(outputRows.filter { $0["translation"] is String }.map { $0["id"] as! Int })
                    let drawnIDs=Set(((report["layoutMetrics"] as! [String:Any])["placements"] as! [[String:Any]]).map { $0["id"] as! Int })
                    func coverage(_ ids: Set<Int>) -> [String:Double] {
                        var totalArea=0.0,chosenArea=0.0,totalCharacters=0,chosenCharacters=0
                        for group in diagnosticGroups {
                            let r=(group["rect"] as! [NSNumber]).map(\.doubleValue), area=r[2]*r[3]
                            let n=(group["text"] as! String).filter { containsChinese(String($0)) }.count
                            totalArea+=area;totalCharacters+=n
                            if ids.contains(group["id"] as! Int) { chosenArea+=area;chosenCharacters+=n }
                        }
                        return ["sourceAreaPercent":chosenArea/max(1,totalArea)*100,"charactersPercent":Double(chosenCharacters)/Double(max(1,totalCharacters))*100,
                                "blocksPercent":Double(ids.count)/Double(max(1,diagnosticGroups.count))*100]
                    }
                    report["generatedCoverage"]=coverage(generatedIDs);report["renderedCoverage"]=coverage(drawnIDs)
                    if let strings=frozen[name] { try writeJSON(strings,to:freezeFolder.appendingPathComponent(name+".json")) }
                    guard warnings()==warningBefore else { throw failure("Memory warning: prune this context") }
                    try writeJSON(report,to:out.appendingPathComponent("report.json"));try data.write(to:out.appendingPathComponent("original.png"));try savePNG(rendered,to:out.appendingPathComponent("result.png"))
                    index.append(["job":jobName,"totalMs":report["totalMs"]!,"translated":report["blocksTranslated"]!]);try writeJSON(index,to:folder.appendingPathComponent("index.json"))
                    progress("Finished \(jobName): \(Int((report["totalMs"] as! Double)/1000)) s",rendered)
                    print("PERF_COMPLETE \(jobName) \(report["totalMs"]!)")
                }}
            }
            try writeJSON(["complete":true,"round":round,"runs":index],to:root.appendingPathComponent("status.json"))
            progress("Performance round complete",nil)
        } catch {
            let counters=await engine.diagnosticCounters
            try? writeJSON(["complete":false,"error":error.localizedDescription,"taskCancelled":Task.isCancelled,"engineCounters":counters,"thermal":ProcessInfo.processInfo.thermalState.rawValue,"lowPowerMode":ProcessInfo.processInfo.isLowPowerModeEnabled,"batteryState":UIDevice.current.batteryState.rawValue],to:root.appendingPathComponent("status.json"));progress(error.localizedDescription,nil);print("PERF_ERROR \(error.localizedDescription)")
        }
    }
}
#endif
