"""Local semantic screening with the actual native bridge and ProtectedSpans.

Usage: advanced_quality.py MODEL OUTPUT [RUNTIME_SOURCE HOST_LIBRARY_DIRECTORY [KV_TYPE]]
Mac correctness/quality evidence only. Never installs or changes production models.
"""
import hashlib
import json
import pathlib
import subprocess
import sys

repo = pathlib.Path(__file__).resolve().parents[2]
model, output = (pathlib.Path(p).resolve() for p in sys.argv[1:3])
source = pathlib.Path(sys.argv[3]).resolve() if len(sys.argv) > 3 else (repo/'ScreenTranslatorNext/Runtime/source').resolve()
host = pathlib.Path(sys.argv[4]).resolve() if len(sys.argv) > 4 else repo.parent/'BuildArtifacts/oct2026/runtime/host/bin'
output.mkdir(parents=True, exist_ok=True)
include = output/'include/llama'
include.mkdir(parents=True, exist_ok=True)
for name, origin in [('llama.h', source/'include/llama.h'), ('ggml-backend.h', source/'ggml/include/ggml-backend.h')]:
    if not (include/name).exists(): (include/name).symlink_to(origin)
native = repo/'ScreenTranslatorNext/HyMTNative.mm'
kv = sys.argv[5] if len(sys.argv) > 5 else 'f16'
assert kv in ('f16', 'q8_0', 'turbo3')
if kv != 'f16' or not (source/'common/json.h').exists():
    text = native.read_text()
    if not (source/'common/json.h').exists():
        text = text.replace('#include "json.h"', '#include "nlohmann/json.hpp"\nusing common_json = nlohmann::ordered_json;')
    revision = source.name[-40:]
    if all(c in '0123456789abcdef' for c in revision):
        text = text.replace('d81235049384534c167caea52b85a694f6103d14', revision)
    if kv != 'f16':
        kind = {'q8_0': 'GGML_TYPE_Q8_0', 'turbo3': 'GGML_TYPE_TURBO3_0'}[kv]
        for declaration in ['auto cp = llama_context_default_params();', 'auto cp=llama_context_default_params();']:
            text = text.replace(declaration, declaration+f' cp.type_k={kind};cp.type_v={kind};cp.flash_attn_type=LLAMA_FLASH_ATTN_TYPE_ENABLED;')
    native = output/'Native.mm'
    native.write_text(text)
subprocess.run(['xcrun', 'clang++', '-std=c++17', '-fobjc-arc', '-O3', '-DDEBUG=1', '-c', str(native),
                '-o', str(output/'native.o'), '-I'+str(repo/'ScreenTranslatorNext'), '-I'+str(include.parent), '-I'+str(source/'include'),
                '-I'+str(source/'ggml/include'), '-I'+str(source/'common'), '-I'+str(source/'vendor')], check=True)
(output/'Main.swift').write_text(r'''
import Foundation
func checked(_ d: [String:Any]) throws -> [String:Any] { if let e=d["error"] as? String { throw failure(e) };return d }
func write(_ d: Any,_ name: String) throws {
    try JSONSerialization.data(withJSONObject:d,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:CommandLine.arguments[2]).appendingPathComponent(name),options:.atomic)
}
@main struct Screening {
 static func main() throws {
    let engine=HyMTNative();engine.beginRequest()
    let load=try checked(engine.load(CommandLine.arguments[1]));try write(load,"load.json")
    let suite=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[3]))) as! [String:Any]
    let cases=suite["cases"] as! [[String:Any]]
    let spans=try cases.map { try ProtectedSpans($0["source"] as! String) }
    for (language,name) in [("english","英语"),("russian","俄语")] {
        _=try checked(engine.benchmarkContext(8));engine.beginRequest()
        let messages=spans.map { "将以下文本翻译为\(name)，注意只需要输出翻译后的结果，不要额外解释：\n\($0.input)" }
        let result=try checked(engine.benchmarkGenerate(messages,options:["prefix":true,"batchPrefill":true]))
        let rows=result["rows"] as! [[String:Any]]
        guard rows.count==cases.count else { throw failure("Count mismatch") }
        var reviewed:[[String:Any]]=[]
        for (i,row) in rows.enumerated() {
            guard row["index"] as? Int==i,row["eog"] as? Bool==true else { throw failure("Mapping/EOG failure") }
            var item=cases[i];item["generation"]=row;item["maskedSource"]=spans[i].input
            do { item["translation"]=try spans[i].restore(row["text"] as! String) }
            catch { item["error"]=error.localizedDescription }
            reviewed.append(item)
        }
        try write(["language":language,"outputs":reviewed,"native":result,"boundary":"Mac actual native bridge and production protected spans, NOT physical iPhone performance"],language+".json")
        print("SCREENED \(language) \(rows.count)")
    }
    engine.unload()
 }
}
''')
subprocess.run(['xcrun','swiftc','-O','-D','DEBUG','-Xcc','-DDEBUG=1',
                '-import-objc-header',str(repo/'ScreenTranslatorNext/HyMTNative.h'),
                str(repo/'ScreenTranslatorNext/TextBlocks.swift'),str(output/'Main.swift'),str(output/'native.o'),
                '-L'+str(host),'-lllama','-lllama-common','-lggml','-lggml-base','-lc++',
                '-framework','Foundation','-framework','Metal','-Xlinker','-rpath','-Xlinker',str(host),
                '-o',str(output/'quality')],check=True)
(output/'provenance.json').write_text(json.dumps({
    'model':str(model),'modelBytes':model.stat().st_size,
    'nativeSHA256':hashlib.sha256(native.read_bytes()).hexdigest(),'runtimeSource':str(source),'kvType':kv,
    'protectedSpans': 'actual unchanged ScreenTranslatorNext/TextBlocks.swift',
    'heldout':str(repo/'tools/runtime/commerce_holdouts.json')},indent=2))
subprocess.run([str(output/'quality'),str(model),str(output),str(repo/'tools/runtime/commerce_holdouts.json')],check=True)
