"""Compile actual DEBUG native methods on Mac; correctness only, never iPhone timing evidence."""
import pathlib, subprocess, sys, json, re

repo = pathlib.Path(__file__).resolve().parents[2]
out = pathlib.Path(sys.argv[1]).resolve()
model = pathlib.Path(sys.argv[2]).resolve()
corpus = pathlib.Path(sys.argv[3]).resolve()
out.mkdir(parents=True, exist_ok=True)
source = (repo / 'ScreenTranslatorNext/Runtime/source').resolve()
host = repo.parent / 'BuildArtifacts/oct2026/runtime/host/bin'
include = out / 'include/llama'
include.mkdir(parents=True, exist_ok=True)
for name, origin in [('llama.h', source/'include/llama.h'), ('ggml-backend.h', source/'ggml/include/ggml-backend.h')]:
    if not (include/name).exists(): (include/name).symlink_to(origin)
reference = json.loads((corpus/'chat/reference.json').read_text())
messages = ['将以下文本翻译为英语，注意只需要输出翻译后的结果，不要额外解释：\n'+b.get('maskedSource', b['source']) for b in reference['blocks']]
(out/'messages.json').write_text(json.dumps(messages, ensure_ascii=False))
driver = out/'checks.mm'
driver.write_text(r'''
#import <Foundation/Foundation.h>
#import "HyMTNative.h"
#include <cassert>
#include <initializer_list>
int main(int argc, char **argv) { @autoreleasepool {
    HyMTNative *engine=[HyMTNative new];[engine beginRequest];
    NSDictionary *load=[engine load:@(argv[1])];assert(load[@"error"]==nil);
    NSArray *messages=[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:@(argv[2])] options:0 error:nil];
    NSMutableArray *results=[NSMutableArray array];
    for(int p:{1,2,4}) {
        NSDictionary *ctx=[engine benchmarkContext:p];assert(ctx[@"error"]==nil);
        for(bool prefix:{false,true}) {
          for(bool packed:{false,true}) {
            NSDictionary *result=[engine benchmarkGenerate:messages options:@{@"prefix":@(prefix),@"greedy":@YES,@"dynamic":@NO,@"batchPrefill":@(packed)}];
            assert(result[@"error"]==nil);NSArray *rows=result[@"rows"];assert(rows.count==messages.count);
            for(NSUInteger i=0;i<rows.count;i++) {assert([rows[i][@"index"] unsignedIntegerValue]==i);assert([rows[i][@"eog"] boolValue]);}
            [results addObject:@{@"parallel":@(p),@"prefix":@(prefix),@"packedPrefill":@(packed),@"result":result}];
            NSData *data=[NSJSONSerialization dataWithJSONObject:results options:NSJSONWritingPrettyPrinted error:nil];[data writeToFile:@(argv[3]) atomically:YES];
        }
        }
    }
    [engine unload];printf("PASS native independent mapping/EOG/prefix, Mac correctness only\n");
} }
''')
cmd=['xcrun','clang++','-std=c++17','-fobjc-arc','-O3','-DDEBUG=1',str(repo/'ScreenTranslatorNext/HyMTNative.mm'),str(driver),
     '-I'+str(repo/'ScreenTranslatorNext'),'-I'+str(include.parent),'-I'+str(source/'include'),'-I'+str(source/'ggml/include'),
     '-I'+str(source/'common'),'-I'+str(source/'vendor'),'-L'+str(host),'-lllama','-lllama-common','-lggml','-lggml-base',
     '-framework','Foundation','-framework','Metal','-Wl,-rpath,'+str(host),'-o',str(out/'checks')]
subprocess.run(cmd,check=True)
subprocess.run([str(out/'checks'),str(model),str(out/'messages.json'),str(out/'checks.json')],check=True)
results=json.loads((out/'checks.json').read_text())
baseline=[r['text'] for r in results[0]['result']['rows']]
comparison=[{'parallel':r['parallel'],'prefix':r['prefix'],'sameGreedyText':[x['text'] for x in r['result']['rows']]==baseline} for r in results]
(out/'text-equivalence.json').write_text(json.dumps(comparison,indent=2))
for result in results:
    for message,row in zip(messages,result['result']['rows']):
        assert re.findall(r'\[\[P\d+\]\]',message)==re.findall(r'\[\[P\d+\]\]',row['text']), 'Protected span mismatch'
for p in [1,2,4]:
    pair=[r for r in results if r['parallel']==p and not r['packedPrefill']]
    assert [x['text'] for x in pair[0]['result']['rows']]==[x['text'] for x in pair[1]['result']['rows']], 'Prefix copy changed text'
print('PASS p1/2/4 mapping, EOG, protected spans, prefix and packed-prefill; numerical text changes recorded separately')
