"""Exercise the fixed production p8 path on Mac; correctness, not iPhone speed."""
import json, pathlib, subprocess, sys

repo = pathlib.Path(__file__).resolve().parents[2]
out, model = map(pathlib.Path, sys.argv[1:3])
out.mkdir(parents=True, exist_ok=True)
source = (repo/'ScreenTranslatorNext/Runtime/source').resolve()
native = pathlib.Path(sys.argv[3]).resolve() if len(sys.argv)>3 else repo/'ScreenTranslatorNext/HyMTNative.mm'
host = repo.parent/'BuildArtifacts/oct2026/runtime/host/bin'
include = out/'include/llama'
include.mkdir(parents=True, exist_ok=True)
for name, origin in [('llama.h', source/'include/llama.h'), ('ggml-backend.h', source/'ggml/include/ggml-backend.h')]:
    if not (include/name).exists(): (include/name).symlink_to(origin)
driver = out/'checks.mm'
driver.write_text(r'''
#import <Foundation/Foundation.h>
#import "HyMTNative.h"
#include <cassert>
int main(int argc, char **argv) { @autoreleasepool {
    HyMTNative *engine=[HyMTNative new];[engine beginRequest];
    NSDictionary *load=[engine load:@(argv[1])];assert(load[@"error"]==nil);
    assert([load[@"context"] intValue]==6144 && [load[@"parallel"] intValue]==8);
    NSArray *sources=@[@"搜索",@"购物车",@"请不要发货，先退款。",@"免费安装",@"价格是[[P0]]，尺寸[[P1]]。",@"谢谢",@"新品",@"政府补贴",@"国家补贴"];
    NSMutableArray *requests=[NSMutableArray array];
    for(NSUInteger i=0;i<sources.count;++i)[requests addObject:@{@"id":@(101+i*13),@"message":[@"将以下文本翻译为英语，注意只需要输出翻译后的结果，不要额外解释：\n" stringByAppendingString:sources[i]]}];
    auto run=[&] { [engine beginRequest];return [engine generateBatch:requests progress:nil]; };
    NSDictionary *baseline=run();assert(baseline[@"error"]==nil);
    NSArray *rows=baseline[@"rows"];assert(rows.count==requests.count && [baseline[@"waves"] count]==2);
    for(NSUInteger i=0;i<rows.count;++i) { assert([rows[i][@"id"] isEqual:requests[i][@"id"]]);assert([rows[i][@"index"] unsignedIntegerValue]==i);assert([rows[i][@"eog"] boolValue]);assert([rows[i][@"limit"] intValue]==512); }
    assert([rows[4][@"text"] containsString:@"[[P0]]"] && [rows[4][@"text"] containsString:@"[[P1]]"]);
    NSMutableArray *checks=[NSMutableArray array];
    for(NSString *phase in @[@"beforePrefix",@"prefix",@"prefill",@"decode",@"betweenWaves"]) {
        [engine cancelAtStageForTesting:phase];NSDictionary *cancelled=run();
        assert([cancelled[@"cancelled"] boolValue] && [cancelled[@"nativeSafeExit"] boolValue]);
        NSDictionary *retried=run();assert(retried[@"error"]==nil);
        for(NSUInteger i=0;i<rows.count;++i)assert([rows[i][@"text"] isEqual:retried[@"rows"][i][@"text"]]);
        [checks addObject:@{@"stage":phase,@"safeExit":@YES,@"retrySameOutput":@YES}];
    }
    NSMutableArray *large=[NSMutableArray array];NSString *body=[@"这个价格最实惠了，主要是您要1000个一个版，我们要分趟上机，这样的开机成本就比较大，单价就会高。" stringByPaddingToLength:1600 withString:@"这个价格最实惠了，我们要分趟上机。" startingAtIndex:0];
    for(int i=0;i<8;++i)[large addObject:@{@"id":@(i),@"message":[NSString stringWithFormat:@"将以下文本翻译为英语，注意只需要输出翻译后的结果，不要额外解释：\n编号%d：%@",i,body]}];
    [engine beginRequest];[engine cancelAtStageForTesting:@"wave"];
    NSDictionary *split=[engine generateBatch:large progress:nil];assert([split[@"cancelled"] boolValue]);
    NSDictionary *wave=[split[@"plannedWaves"] firstObject];assert([wave[@"ids"] count]>0 && [wave[@"ids"] count]<8 && [wave[@"reservedTokens"] intValue]<6144);
    NSDictionary *duplicate=[engine generateBatch:@[requests[0],requests[0]] progress:nil];assert(duplicate[@"error"]);
    NSDictionary *empty=[engine generateBatch:@[] progress:nil];assert(empty[@"error"]);
    [engine beginRequest];
    NSString *oversize=[@"测试" stringByPaddingToLength:30000 withString:@"测试" startingAtIndex:0];
    NSDictionary *capacity=[engine generateBatch:@[@{@"id":@1,@"message":oversize}] progress:nil];assert(capacity[@"error"] && [capacity[@"nativeSafeExit"] boolValue]);
    assert(run()[@"error"]==nil);
    NSDictionary *continuous=@{};NSMutableArray *refillChecks=[NSMutableArray array];
    if(baseline[@"decodeSteps"]) {
    NSMutableArray *messages=[NSMutableArray array];for(NSDictionary *r in requests)[messages addObject:r[@"message"]];
    NSDictionary *options=@{@"prefix":@YES,@"batchPrefill":@YES,@"refill":@YES,@"longestFirst":@YES};
    auto refill=[&] { [engine beginRequest];return [engine benchmarkGenerate:messages options:options]; };
    continuous=refill();assert(continuous[@"error"]==nil);
    assert([continuous[@"rows"] count]==requests.count);
    for(NSUInteger i=0;i<rows.count;++i) {auto row=continuous[@"rows"][i];assert([row[@"index"] unsignedIntegerValue]==i && [row[@"id"] unsignedIntegerValue]==i && [row[@"eog"] boolValue]);}

    for(NSString *phase in @[@"beforePrefix",@"prefix",@"prefill",@"decode",@"betweenWaves"]) {
        [engine cancelAtStageForTesting:phase];NSDictionary *cancelled=refill();
        assert([cancelled[@"cancelled"] boolValue] && [cancelled[@"nativeSafeExit"] boolValue]);
        NSDictionary *retried=refill();assert(retried[@"error"]==nil);
        for(NSUInteger i=0;i<rows.count;++i)assert([continuous[@"rows"][i][@"text"] isEqual:retried[@"rows"][i][@"text"]]);
        [refillChecks addObject:@{@"stage":phase,@"safeExit":@YES,@"retrySameOutput":@YES}];
    }
    }
    NSDictionary *report=@{@"passed":@YES,@"provenance":@"Mac production-native correctness only; no iPhone speed claim",@"load":load,@"baseline":baseline,@"refill":continuous,@"refillCancellation":refillChecks,@"cancellation":checks,@"capacitySplit":wave,@"duplicateIDRejected":@YES,@"emptyRejected":@YES,@"oversizeRejected":@YES};
    [[NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:nil] writeToFile:@(argv[2]) atomically:YES];
    [engine unload];printf("PASS production p8, ID/prefix/packed/EOG/spans, five cancellation stages, bounded split, retry, capacity/input failures\n");
} }
''')
subprocess.run(['xcrun','clang++','-std=c++17','-fobjc-arc','-O3','-DDEBUG=1',str(native),str(driver),
    '-I'+str(repo/'ScreenTranslatorNext'),'-I'+str(include.parent),'-I'+str(source/'include'),'-I'+str(source/'ggml/include'),
    '-I'+str(source/'common'),'-I'+str(source/'vendor'),'-L'+str(host),'-lllama','-lllama-common','-lggml','-lggml-base',
    '-framework','Foundation','-framework','Metal','-Wl,-rpath,'+str(host),'-o',str(out/'checks')],check=True)
subprocess.run([str(out/'checks'),str(model.resolve()),str(out/'report.json')],check=True)
