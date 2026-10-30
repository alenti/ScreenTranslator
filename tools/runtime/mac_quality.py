"""DEBUG component test: compile the actual HyMTNative + verbatim Swift actor on macOS.

No app backend. Produces live EN/RU regression outputs when physical iOS is unavailable.
Usage: python3 tools/runtime/mac_quality.py <production-geometry-export> <output-directory>
"""
import pathlib, subprocess, sys, hashlib, json

repo = pathlib.Path(__file__).resolve().parents[2]
art = repo.parent / 'BuildArtifacts/oct2026'
out = pathlib.Path(sys.argv[2]).resolve()
out.mkdir(parents=True, exist_ok=True)
runtime = art / 'runtime/host/bin'
source = (repo / 'ScreenTranslatorNext/Runtime/source').resolve()
include = out / 'include/llama'
include.mkdir(parents=True, exist_ok=True)
for name, origin in [('llama.h', source / 'include/llama.h'), ('ggml-backend.h', source / 'ggml/include/ggml-backend.h')]:
    if not (include / name).exists(): (include / name).symlink_to(origin)
native = repo / 'ScreenTranslatorNext/HyMTNative.mm'
subprocess.run(['xcrun', 'clang++', '-std=c++17', '-fobjc-arc', '-O3', '-DDEBUG=1', '-c', str(native), '-o', str(out / 'native.o'),
                '-I'+str(include.parent), '-I'+str(source/'include'), '-I'+str(source/'ggml/include'),
                '-I'+str(source/'common'), '-I'+str(source/'vendor')], check=True)
processor = (repo / 'ScreenTranslatorNext/ScreenshotProcessor.swift').read_text()
actor = processor[processor.index('// A replacement cancels'):processor.index('func modelManifest')]
verify = processor[processor.index('func verifyModel'):processor.index('func savePNG')]
helpers = processor[processor.index('func checked'):processor.index('var documents:')]
core = 'import Foundation\nimport CryptoKit\n' + actor + verify + helpers
(out / 'SharedMT.swift').write_text(core)
driver = r'''
import Foundation
var documents: URL { URL(fileURLWithPath:CommandLine.arguments[2]) }
func modelManifest() throws -> [String:Any] { try JSONSerialization.jsonObject(with:Data(contentsOf:documents.appendingPathComponent("model.json"))) as! [String:Any] }
func writeJSON(_ value: Any, to url: URL) throws { try JSONSerialization.data(withJSONObject:value,options:[.prettyPrinted,.sortedKeys]).write(to:url,options:.atomic) }
@main struct NativeQuality {
    static func main() async throws {
        let root = URL(fileURLWithPath:CommandLine.arguments[1]), engine = HyMTTranslator()
        let cases = try FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:nil).filter { $0.hasDirectoryPath }.sorted { $0.path < $1.path }
        try await engine.beginRequest()
        let load = try await engine.prepare()
        try writeJSON(load,to:documents.appendingPathComponent("load.json"))
        if CommandLine.arguments.contains("--recovery-check") {
            try await engine.beginRequest()
            do {
                _ = try await engine.translateBatch([(id:7, source:String(repeating:"测试",count:15000))],to:.english) { _ in }
                throw failure("Oversize input unexpectedly accepted")
            } catch {
                guard !(await engine.isLoaded) else { throw failure("Native failure retained an unusable loaded context") }
            }
            try await engine.beginRequest()
            _ = try await engine.prepare()
            let retried = try await engine.translateBatch([(id:91,source:"搜索")],to:.english) { _ in }
            let counters = await engine.diagnosticCounters
            guard let rows = retried["rows"] as? [[String:Any]], rows.count == 1,
                  rows[0]["id"] as? Int == 91, rows[0]["eog"] as? Bool == true,
                  counters["loads"] == 2 else { throw failure("Recovery/load/mapping check failed") }
            try writeJSON(["passed":true,"counters":counters,"retry":retried,
                           "scope":"Host actual actor/native non-cancellation failure unload and successful next request; not an injected physical GPU fault"],
                          to:documents.appendingPathComponent("recovery-check.json"))
            print("PASS native failure unload and next request recovery")
            return
        }
        for folder in cases {
            guard let data = try? Data(contentsOf:folder.appendingPathComponent("report.json")),
                  let report = try JSONSerialization.jsonObject(with:data) as? [String:Any],
                  let groups = report["groups"] as? [[String:Any]] else { continue }
            let destination = documents.appendingPathComponent(folder.lastPathComponent)
            try FileManager.default.createDirectory(at:destination,withIntermediateDirectories:true)
            for language in TargetLanguage.allCases {
                let outputURL = destination.appendingPathComponent(language.rawValue+".json")
                if let data = try? Data(contentsOf:outputURL),
                   let previous = try JSONSerialization.jsonObject(with:data) as? [String:Any],
                   let batch = previous["nativeBatch"] as? [String:Any], batch["parallel"] as? Int == 8,
                   let rows = previous["blocks"] as? [[String:Any]], rows.count == groups.count,
                   groups.allSatisfy({ group in rows.contains { $0["id"] as? Int == group["id"] as? Int && $0["source"] as? String == group["text"] as? String && $0["translation"] is String } }) { continue }
                try await engine.beginRequest()
                var rows: [[String:Any]] = []
                let start = Date()
                let spans = try groups.map { try ProtectedSpans($0["text"] as! String) }
                let generated = try await engine.translateBatch(groups.enumerated().map { (id:$0.element["id"] as! Int,source:spans[$0.offset].input) },to:language) { _ in }
                let generations = generated["rows"] as! [[String:Any]]
                guard generations.count == groups.count else { throw failure("Result count mismatch") }
                for (index,group) in groups.enumerated() {
                    var row: [String:Any] = ["id":group["id"]!,"source":group["text"]!]
                    do {
                        let output = generations[index]
                        guard output["id"] as? Int == group["id"] as? Int else { throw failure("Source/result ID mismatch") }
                        row["generation"] = output; row["translation"] = try spans[index].restore(output["text"] as! String)
                    } catch { row["error"] = error.localizedDescription }
                    rows.append(row)
                    try writeJSON(["target":language.rawValue,"blocks":rows,"nativeBatch":generated,"translationMs":Date().timeIntervalSince(start)*1000,"provenance":"live macOS component test of the actual HyMTTranslator actor and HyMTNative; NOT physical iPhone inference"],to:destination.appendingPathComponent(language.rawValue+".json"))
                }
                print("MAC_QUALITY \(folder.lastPathComponent) \(language.rawValue) complete")
            }
        }
    }
}
'''
(out / 'Driver.swift').write_text(driver)
(out / 'model.json').write_bytes((repo / 'ScreenTranslatorNext/model.json').read_bytes())
model = out / 'model.gguf'
if not model.exists(): subprocess.run(['cp', '-c', str(art/'models/Hy-MT2-7B-Q4_K_M.gguf'), str(model)], check=True)
cmd = ['xcrun','swiftc','-D','DEBUG','-Xcc','-DDEBUG=1','-O','-import-objc-header',str(repo/'ScreenTranslatorNext/HyMTNative.h'),
       str(repo/'ScreenTranslatorNext/TextBlocks.swift'),str(out/'SharedMT.swift'),str(out/'Driver.swift'),str(out/'native.o'),
       '-L'+str(runtime),'-lllama','-lllama-common','-lggml','-lggml-base','-lc++','-framework','Foundation','-framework','Metal',
       '-Xlinker','-rpath','-Xlinker',str(runtime),'-o',str(out/'native-quality')]
subprocess.run(cmd,check=True)
(out/'source-proof.json').write_text(json.dumps({'nativeSHA256':hashlib.sha256(native.read_bytes()).hexdigest(),
    'actorSHA256':hashlib.sha256(actor.encode()).hexdigest(),'actorCopiedVerbatim':True,'runtime':'d81235049384534c167caea52b85a694f6103d14'},indent=2))
subprocess.run([str(out/'native-quality'),str(pathlib.Path(sys.argv[1]).resolve()),str(out),*sys.argv[3:]],check=True)
