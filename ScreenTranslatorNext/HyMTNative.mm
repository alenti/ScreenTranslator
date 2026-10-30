#import "HyMTNative.h"
#import <Metal/Metal.h>
#import <mach/mach.h>
#include <llama/llama.h>
#include <llama/ggml-backend.h>
#include "jinja/lexer.h"
#include "jinja/parser.h"
#include "jinja/runtime.h"
#include "json.h"
#include <atomic>
#include <chrono>
#include <cstring>
#include <mutex>
#include <string>
#include <vector>

namespace {
using Clock = std::chrono::steady_clock;
double ms(Clock::time_point start) { return std::chrono::duration<double, std::milli>(Clock::now()-start).count(); }
NSDictionary *error(NSString *message) { return @{@"error":message}; }
std::mutex logMutex;
std::string runtimeLog;
void logRuntime(ggml_log_level, const char *text, void *) {
    std::lock_guard<std::mutex> lock(logMutex);
    if (runtimeLog.size() < 100000 || std::strstr(text,"layers to GPU")) runtimeLog += text;
    fputs(text, stderr);
}
std::string modelPrompt(llama_model *model, NSString *message) {
    const auto vocab = llama_model_get_vocab(model);
    const char *tmpl = llama_model_chat_template(model, nullptr);
    if (!tmpl || !*tmpl) throw std::runtime_error("Missing embedded Jinja template");
    jinja::lexer lexer;
    auto tokens = lexer.tokenize(tmpl);
    auto program = jinja::parse_from_tokens(tokens);
    jinja::context context(tokens.source);
    const common_json input = {{"messages",common_json::array({{{"role","user"},{"content",message.UTF8String}}})},
        {"add_generation_prompt",true},{"bos_token",""},{"eos_token",""},{"enable_thinking",false}};
    jinja::global_from_json(context,input,false);
    jinja::runtime runtime(context);
    auto prompt = jinja::runtime::gather_string_parts(runtime.execute(program))->as_string().str();
    // Match upstream common/chat.cpp: avoid double BOS/EOS when tokenizer adds them.
    for (bool bos : {true, false}) {
        if (!(bos ? llama_vocab_get_add_bos(vocab) : llama_vocab_get_add_eos(vocab))) continue;
        auto token = bos ? llama_vocab_bos(vocab) : llama_vocab_eos(vocab);
        if (token == LLAMA_TOKEN_NULL) continue;
        const std::string marker = llama_vocab_get_text(vocab, token);
        if (!marker.empty() && prompt.size() >= marker.size()) {
            if (bos && prompt.compare(0,marker.size(),marker)==0) prompt.erase(0,marker.size());
            if (!bos && prompt.compare(prompt.size()-marker.size(),marker.size(),marker)==0) prompt.resize(prompt.size()-marker.size());
        }
    }
    return prompt;
}
}

@interface HyMTNative ()
- (NSDictionary *)generateSequences:(NSArray<NSString *> *)messages ids:(NSArray<NSNumber *> *)ids options:(nullable NSDictionary *)options progress:(void (^ _Nullable)(NSInteger))progress;
@end

@implementation HyMTNative {
    llama_model *_model;
    llama_context *_context;
    std::atomic_bool _cancelled;
    int _parallel;
#if DEBUG
    std::string _cancelAtStage;
#endif
}
+ (NSDictionary *)memory {
    task_vm_info_data_t info{};
    mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
    if (task_info(mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count) != KERN_SUCCESS) return @{};
    return @{@"footprintMB":@(info.phys_footprint/1048576.0), @"residentMB":@(info.resident_size/1048576.0)};
}
- (void)cancel { _cancelled.store(true); }
- (void)beginRequest {
    if (_context) { llama_synchronize(_context); llama_memory_clear(llama_get_memory(_context),true); }
    _cancelled.store(false);
}
- (void)unload {
    if (_context) { llama_synchronize(_context); llama_free(_context); }
    if (_model) llama_model_free(_model);
    _context = nullptr; _model = nullptr;
    _parallel = 0;
}
- (void)dealloc { [self unload]; }
- (NSDictionary *)load:(NSString *)path {
    [self unload];
    static std::once_flag once;
    std::call_once(once, [] { llama_log_set(logRuntime, nullptr); ggml_backend_load_all(); llama_backend_init(); });
    { std::lock_guard<std::mutex> lock(logMutex); runtimeLog.clear(); }
    const auto start = Clock::now();
    auto params = llama_model_default_params();
    params.n_gpu_layers = -1;
    params.load_mode = LLAMA_LOAD_MODE_MMAP;
    params.progress_callback = [](float, void *state) { return !static_cast<std::atomic_bool *>(state)->load(); };
    params.progress_callback_user_data = &_cancelled;
    if (_cancelled.load()) return error(@"Cancelled");
    _model = llama_model_load_from_file(path.fileSystemRepresentation, params);
    if (!_model) return error(@"GGUF load failed");
    if (_cancelled.load()) { [self unload]; return error(@"Cancelled"); }
    auto cp = llama_context_default_params();
    cp.n_ctx = 6144; cp.n_seq_max = 9; cp.kv_unified = true;
    cp.n_batch = 256; cp.n_ubatch = 128;
    cp.n_threads = 4; cp.n_threads_batch = 4; cp.no_perf = false;
    _context = llama_init_from_model(_model, cp);
    if (!_context) { [self unload]; return error(@"Context creation failed"); }
    _parallel = 8;
    NSString *log;
    { std::lock_guard<std::mutex> lock(logMutex); log = @(runtimeLog.c_str()); }
    id<MTLDevice> gpu = MTLCreateSystemDefaultDevice();
    NSMutableArray *backends = [NSMutableArray array];
    for (size_t i=0; i<ggml_backend_dev_count(); ++i) {
        auto device = ggml_backend_dev_get(i);
        [backends addObject:@{@"name":@(ggml_backend_dev_name(device)), @"description":@(ggml_backend_dev_description(device))}];
    }
    if (!gpu || ![log containsString:@"layers to GPU"]) { [self unload]; return error(@"Metal offload was not confirmed by runtime logs"); }
    return @{@"loadMs":@(ms(start)), @"memory":[HyMTNative memory], @"metalDevice":gpu.name,
        @"backends":backends, @"offloadLog":log, @"layersRequested":@(-1), @"modelLayers":@(llama_model_n_layer(_model)),
        @"runtimeRevision":@"d81235049384534c167caea52b85a694f6103d14", @"context":@6144, @"parallel":@8, @"reservedPrefixSequence":@8, @"mmap":@YES,
        @"embeddedChatTemplate":@(llama_model_chat_template(_model, nullptr) ?: "")};
}
#if DEBUG
- (NSDictionary *)generate:(NSString *)message {
    if (!_context || message.length == 0) return error(@"Model is unloaded or input is empty");
    if (_cancelled.load()) return error(@"Cancelled");
    const auto start = Clock::now();
    std::string prompt;
    const auto vocab = llama_model_get_vocab(_model);
    try {
        prompt = modelPrompt(_model,message);
    } catch (const std::exception &e) { return error(@(e.what())); }
    #if DEBUG
    const auto tokenizeStart = Clock::now();
    double samplingMs = 0, decodeWallMs = 0;
    #endif
    int count = -llama_tokenize(vocab,prompt.data(),(int)prompt.size(),nullptr,0,true,true);
    const int limit = 512;
    if (count<=0 || count+limit>=2048) return error(@"Prompt exceeds the bounded 2048-token context");
    std::vector<llama_token> input(count);
    if (llama_tokenize(vocab,prompt.data(),(int)prompt.size(),input.data(),count,true,true)!=count) return error(@"Tokenization failed");
    #if DEBUG
    const double tokenizationMs = ms(tokenizeStart);
    std::string sourceText=message.UTF8String;auto newline=sourceText.find('\n');if(newline!=std::string::npos)sourceText=sourceText.substr(newline+1);
    const int sourceTokens=-llama_tokenize(vocab,sourceText.data(),(int)sourceText.size(),nullptr,0,false,true);
    #endif
    llama_memory_clear(llama_get_memory(_context),true);
    llama_perf_context_reset(_context);
    for (int offset=0; offset<count; offset+=256) {
        if (_cancelled.load()) return error(@"Cancelled");
        auto batch = llama_batch_get_one(input.data()+offset,std::min(256,count-offset));
        if (llama_decode(_context,batch)!=0) return error(@"Prefill decode failed");
        #if DEBUG
        llama_synchronize(_context);
        #endif
    }
    double prefillMs = ms(start);
    auto sampler = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(sampler,llama_sampler_init_penalties(llama_vocab_n_tokens(vocab),64,1.05f,0,0));
    llama_sampler_chain_add(sampler,llama_sampler_init_top_k(20));
    llama_sampler_chain_add(sampler,llama_sampler_init_top_p(0.6f,1));
    llama_sampler_chain_add(sampler,llama_sampler_init_temp(0.7f));
    llama_sampler_chain_add(sampler,llama_sampler_init_dist(42));
    for (auto token : input) llama_sampler_accept(sampler,token);
    std::string output;
    int generated=0;
    bool eog=false;
    NSString *problem=nil;
    const auto generationStart=Clock::now();
    while (generated<limit) {
        if (_cancelled.load()) { problem=@"Cancelled"; break; }
        #if DEBUG
        const auto sampleStart=Clock::now();
        #endif
        auto token=llama_sampler_sample(sampler,_context,-1); // sample also accepts, since v0.6
        #if DEBUG
        samplingMs += ms(sampleStart);
        #endif
        if (llama_vocab_is_eog(vocab,token)) { eog=true; break; }
        char bytes[256];
        int size=llama_token_to_piece(vocab,token,bytes,sizeof(bytes),0,false);
        if (size<0) {
            std::vector<char> large(-size);
            size=llama_token_to_piece(vocab,token,large.data(),(int)large.size(),0,false);
            if (size<0) { problem=@"Token decoding failed"; break; }
            output.append(large.data(),size);
        } else output.append(bytes,size);
        ++generated;
        auto batch=llama_batch_get_one(&token,1);
        #if DEBUG
        const auto decodeStart=Clock::now();
        #endif
        if (llama_decode(_context,batch)!=0) { problem=@"Generation decode failed"; break; }
        #if DEBUG
        llama_synchronize(_context);decodeWallMs += ms(decodeStart);
        #endif
    }
    double generationMs=ms(generationStart);
    llama_sampler_free(sampler);
    if (problem) return error(problem);
    if (!eog) return error(@"Generation limit reached without EOG; output rejected");
    NSString *text=[[NSString alloc] initWithBytes:output.data() length:output.size() encoding:NSUTF8StringEncoding];
    if (!text || text.length==0) return error(@"Empty or invalid UTF-8 output");
    auto perf=llama_perf_context(_context);
    return @{@"text":[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet],
        @"prompt":@(prompt.c_str()), @"promptTokens":@(count), @"generatedTokens":@(generated),
        @"prefillMs":@(prefillMs), @"generationMs":@(generationMs), @"totalMs":@(ms(start)),
        @"tokensPerSecond":@(generated/std::max(generationMs/1000.0,0.000001)),
        @"decodeMs":@(perf.t_eval_ms), @"eog":@(eog), @"memory":[HyMTNative memory]
        #if DEBUG
        ,@"tokenizationMs":@(tokenizationMs),@"samplingMs":@(samplingMs),@"decodeWallMs":@(decodeWallMs),@"promptDecodeMs":@(perf.t_p_eval_ms),@"sourceTokens":@(sourceTokens),@"timingVersion":@"synchronized-v2"
        #endif
    };
}
- (NSDictionary *)benchmarkContext:(NSInteger)parallel {
    if (!_model || parallel < 1 || parallel > 8) return error(@"Invalid benchmark model/parallelism");
    if (_context) llama_free(_context);
    auto cp = llama_context_default_params();
    cp.n_ctx = parallel == 1 ? 4096 : 6144; cp.n_seq_max = (uint32_t)parallel+1; cp.kv_unified = true;
    cp.n_batch = 256; cp.n_ubatch = 128; cp.n_threads = 4; cp.n_threads_batch = 4; cp.no_perf = false;
    _context = llama_init_from_model(_model,cp); _parallel = (int)parallel;
    if (!_context) return error(@"Benchmark context creation failed");
    return @{@"parallel":@(parallel),@"nContext":@(llama_n_ctx(_context)),@"nContextPerSequence":@(llama_n_ctx_seq(_context)),
             @"memory":[HyMTNative memory],@"reservedPrefixSequence":@(parallel)};
}
- (NSDictionary *)benchmarkGenerate:(NSArray<NSString *> *)messages options:(NSDictionary *)options {
    NSMutableArray *ids=[NSMutableArray array];for(NSUInteger i=0;i<messages.count;++i)[ids addObject:@(i)];
    return [self generateSequences:messages ids:ids options:options progress:nil];
}
- (void)cancelAtStageForTesting:(NSString *)stage { _cancelAtStage=stage.UTF8String; }
#endif
- (NSDictionary *)generateBatch:(NSArray<NSDictionary *> *)requests progress:(void (^)(NSInteger))progress {
    if (!_context || _parallel!=8) return error(@"Production batch requires the loaded p8 context");
    if (!requests.count) return error(@"Empty translation batch");
    NSMutableArray *messages=[NSMutableArray array],*ids=[NSMutableArray array];NSMutableSet *seen=[NSMutableSet set];
    for(NSDictionary *request in requests) {
        if(![request isKindOfClass:NSDictionary.class])return error(@"Invalid translation request");
        id identifier=request[@"id"],message=request[@"message"];
        if(![identifier isKindOfClass:NSNumber.class] || ![message isKindOfClass:NSString.class] || ![message length] || ![message UTF8String] || [seen containsObject:identifier])return error(@"Invalid/duplicate source ID or message");
        [seen addObject:identifier];[ids addObject:identifier];[messages addObject:message];
    }
    return [self generateSequences:messages ids:ids options:nil progress:progress];
}
- (NSDictionary *)generateSequences:(NSArray<NSString *> *)messages ids:(NSArray<NSNumber *> *)ids options:(NSDictionary *)options progress:(void (^)(NSInteger))progress {
    if (!_context || _parallel<1 || messages.count==0 || messages.count!=ids.count) return error(@"Invalid sequence mapping/context");
    const auto start = Clock::now(); const auto vocab = llama_model_get_vocab(_model);
    #if DEBUG
    const bool prefix = !options || [options[@"prefix"] boolValue], greedy = [options[@"greedy"] boolValue], dynamic = [options[@"dynamic"] boolValue];
    const bool batchPrefill = !options || [options[@"batchPrefill"] boolValue];
    #else
    const bool prefix=true,greedy=false,dynamic=false,batchPrefill=true;
    #endif
    struct Item {
        std::vector<llama_token> input; std::string output;
        int sourceTokens=0, limit=512, generated=0, lastLogit=-1, position=0;
        llama_token next; bool done=false, eog=false;
        double tokenizeMs=0, prefillMs=0, sampleMs=0, decodeShareMs=0, latencyMs=0;
        llama_sampler *sampler=nullptr; Clock::time_point began;
    };
    std::vector<Item> items(messages.count);
    double prefillTotal=0, decodeTotal=0, sampleTotal=0, prefixMs=0, peak=0;
    NSMutableArray *waves=[NSMutableArray array];
    auto cleanup = [&] { for (auto &s:items) if(s.sampler) { llama_sampler_free(s.sampler);s.sampler=nullptr; } };
    auto fail = [&](NSString *message)->NSDictionary * {
        llama_synchronize(_context);llama_memory_clear(llama_get_memory(_context),true);cleanup();
        return @{@"error":_cancelled.load()?[@"Cancelled: " stringByAppendingString:message]:message,@"cancelled":@(_cancelled.load()),@"nativeSafeExit":@YES,@"plannedWaves":waves};
    };
    try {
        for (NSUInteger i=0;i<messages.count;++i) {
            if(_cancelled.load())return fail(@"Tokenization cancelled");
            auto &s=items[i]; const auto t=Clock::now(); auto prompt=modelPrompt(_model,messages[i]);
            int n=-llama_tokenize(vocab,prompt.data(),(int)prompt.size(),nullptr,0,true,true);
            if(n<=0 || (uint64_t)n+512>=llama_n_ctx(_context)) return fail(@"Prompt and output cannot fit the shared context");
            s.input.resize(n);
            if(llama_tokenize(vocab,prompt.data(),(int)prompt.size(),s.input.data(),n,true,true)!=n) return fail(@"Prompt tokenization failed");
            std::string source=messages[i].UTF8String; auto nl=source.find('\n');if(nl!=std::string::npos)source=source.substr(nl+1);
            s.sourceTokens=-llama_tokenize(vocab,source.data(),(int)source.size(),nullptr,0,false,true);
            s.limit=dynamic?std::min(512,std::max(32,s.sourceTokens*4+16)):512;
            s.tokenizeMs=ms(t);
        }
    } catch(const std::exception &e) { return fail(@(e.what())); }
    size_t common=items[0].input.size()-1;
    for(auto &s:items) { common=std::min(common,s.input.size()-1);size_t j=0;while(j<common && s.input[j]==items[0].input[j])++j;common=j; }
    if(!prefix)common=0;
    auto mem=llama_get_memory(_context); llama_memory_clear(mem,true);
    auto batch=llama_batch_init(256,0,1);
    auto releaseFail=[&](NSString *message)->NSDictionary * { NSDictionary *problem=fail(message);llama_batch_free(batch);return problem; };
    auto add=[&](llama_token token,int pos,int seq,bool logits) {
        int b=batch.n_tokens++;batch.token[b]=token;batch.pos[b]=pos;batch.n_seq_id[b]=1;batch.seq_id[b][0]=seq;batch.logits[b]=logits;return b;
    };
    auto checkpoint=[&](const char *stage) {
        #if DEBUG
        if(_cancelAtStage==stage) { _cancelAtStage.clear();_cancelled.store(true); }
        #endif
        return !_cancelled.load();
    };
    auto decode=[&](const char *stage) {
        if(_cancelled.load() || llama_decode(_context,batch)!=0)return false;
        llama_synchronize(_context);return checkpoint(stage);
    };
    auto initializeSampler=[&](Item &s) {
        s.sampler=llama_sampler_chain_init(llama_sampler_chain_default_params());
        llama_sampler_chain_add(s.sampler,llama_sampler_init_penalties(llama_vocab_n_tokens(vocab),64,1.05f,0,0));
        if(greedy)llama_sampler_chain_add(s.sampler,llama_sampler_init_greedy());
        else {llama_sampler_chain_add(s.sampler,llama_sampler_init_top_k(20));llama_sampler_chain_add(s.sampler,llama_sampler_init_top_p(0.6f,1));llama_sampler_chain_add(s.sampler,llama_sampler_init_temp(0.7f));llama_sampler_chain_add(s.sampler,llama_sampler_init_dist(42));}
        for(auto token:s.input)llama_sampler_accept(s.sampler,token);
    };
    auto sample=[&](Item &s,int index,int slot) {
        if(index<0 || index>=batch.n_tokens || !batch.logits[index] || batch.n_seq_id[index]!=1 || batch.seq_id[index][0]!=slot || !llama_get_logits_ith(_context,index))return false;
        const auto t=Clock::now();s.next=llama_sampler_sample(s.sampler,_context,index);s.sampleMs+=ms(t);
        return s.next>=0 && s.next<llama_vocab_n_tokens(vocab);
    };
    if(!checkpoint("beforePrefix"))return releaseFail(@"Before prefix prefill");
    if(common) {
        const auto t=Clock::now();
        for(size_t o=0;o<common;o+=256) {batch.n_tokens=0;for(size_t j=o;j<std::min(common,o+256);++j)add(items[0].input[j],(int)j,_parallel,false);if(!decode("prefix"))return releaseFail(@"Prefix decode failed");}
        prefixMs=ms(t);prefillTotal+=prefixMs;
    }
    NSInteger completed=0;
    // shortcut: bounded waves, add continuous slot refill only if A19 timings justify it.
    for(size_t wave=0;wave<items.size();) {
        size_t count=0;
        size_t required=common;
        while(count<(size_t)_parallel && wave+count<items.size()) {
            size_t needed=items[wave+count].input.size()-common+items[wave+count].limit;
            if(required+needed>=llama_n_ctx(_context))break;
            required+=needed;++count;
        }
        if(!count)return releaseFail(@"Single sequence exceeds shared KV capacity");
        [waves addObject:@{@"ids":[ids subarrayWithRange:NSMakeRange(wave,count)],@"reservedTokens":@(required)}];
        if(!checkpoint("wave"))return releaseFail(@"Wave cancelled");
        for(int slot=0;slot<_parallel;++slot)if(!llama_memory_seq_rm(mem,slot,-1,-1))return releaseFail(@"Sequence removal failed");
        if(batchPrefill) {
            for(size_t slot=0;slot<count;++slot) {
                auto &s=items[wave+slot];s.began=Clock::now();s.position=(int)s.input.size();initializeSampler(s);
                if(common)llama_memory_seq_cp(mem,_parallel,(int)slot,0,(int)common);
            }
            size_t slot=0,position=common;
            while(slot<count) {
                batch.n_tokens=0;std::vector<int> tokensPerSlot(count,0);std::vector<std::pair<size_t,int>> endings;
                while(slot<count && batch.n_tokens<256) {
                    auto &s=items[wave+slot];bool last=position+1==s.input.size();
                    int index=add(s.input[position],(int)position,(int)slot,last);++tokensPerSlot[slot];++position;
                    if(last) { endings.emplace_back(slot,index);++slot;position=common; }
                }
                const auto t=Clock::now();if(!decode("prefill"))return releaseFail(@"Packed sequence prefill failed");double elapsed=ms(t);prefillTotal+=elapsed;
                for(size_t i=0;i<count;++i)items[wave+i].prefillMs+=elapsed*tokensPerSlot[i]/batch.n_tokens;
                for(auto ending:endings)if(!sample(items[wave+ending.first],ending.second,(int)ending.first))return releaseFail(@"Invalid packed logits mapping");
            }
        } else {
        for(size_t slot=0;slot<count;++slot) {
            auto &s=items[wave+slot];s.began=Clock::now();
            if(common)llama_memory_seq_cp(mem,_parallel,(int)slot,0,(int)common);
            const auto t=Clock::now();
            for(size_t o=common;o<s.input.size();o+=256) {
                batch.n_tokens=0;for(size_t j=o;j<std::min(s.input.size(),o+256);++j)add(s.input[j],(int)j,(int)slot,j+1==s.input.size());
                if(!decode("prefill"))return releaseFail(@"Sequence prefill failed");
            }
            s.prefillMs=ms(t);prefillTotal+=s.prefillMs;s.position=(int)s.input.size();
            initializeSampler(s);if(!sample(s,batch.n_tokens-1,(int)slot))return releaseFail(@"Invalid sequence logits mapping");
        }
        }
        while(true) {
            if(_cancelled.load())return releaseFail(@"Batched decode cancelled");
            batch.n_tokens=0;std::vector<size_t> active;
            for(size_t slot=0;slot<count;++slot) {
                auto &s=items[wave+slot];if(s.done)continue;
                if(llama_vocab_is_eog(vocab,s.next)) {s.eog=true;s.done=true;s.latencyMs=ms(s.began);llama_sampler_free(s.sampler);s.sampler=nullptr;++completed;if(progress)progress(completed);continue;}
                // A runaway sequence fails only its own block; the caller rejects rows without EOG.
                if(s.generated>=s.limit) {s.done=true;s.latencyMs=ms(s.began);llama_sampler_free(s.sampler);s.sampler=nullptr;++completed;if(progress)progress(completed);continue;}
                char bytes[256];int n=llama_token_to_piece(vocab,s.next,bytes,256,0,false);
                if(n<0) {std::vector<char> buf(-n);n=llama_token_to_piece(vocab,s.next,buf.data(),(int)buf.size(),0,false);if(n<0)return releaseFail(@"Token piece failed");s.output.append(buf.data(),n);}else s.output.append(bytes,n);
                ++s.generated;s.lastLogit=add(s.next,s.position++,(int)slot,true);active.push_back(wave+slot);
            }
            if(active.empty())break;
            auto t=Clock::now();if(!decode("decode"))return releaseFail(@"Batched decode failed/cancelled");double elapsed=ms(t);decodeTotal+=elapsed;
            for(auto i:active) {auto &s=items[i];s.decodeShareMs+=elapsed/active.size();if(!sample(s,s.lastLogit,(int)(i-wave)))return releaseFail(@"Invalid decode logits mapping");}
        }
        peak=std::max(peak,[[HyMTNative memory][@"footprintMB"] doubleValue]);
        wave+=count;
        if(wave<items.size() && !checkpoint("betweenWaves"))return releaseFail(@"Between waves");
    }
    llama_batch_free(batch);NSMutableArray *rows=[NSMutableArray array];int generated=0,inputs=0;
    for(size_t i=0;i<items.size();++i) {
        auto &s=items[i];NSString *text=[[NSString alloc]initWithBytes:s.output.data() length:s.output.size() encoding:NSUTF8StringEncoding];
        // Missing EOG or empty/invalid UTF-8 is reported per row; the caller turns it into a block warning.
        generated+=s.generated;inputs+=(int)s.input.size();sampleTotal+=s.sampleMs;
        [rows addObject:@{@"id":ids[i],@"index":@(i),@"text":[text ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet],@"sourceTokens":@(s.sourceTokens),@"promptTokens":@(s.input.size()),@"generatedTokens":@(s.generated),@"tokenizationMs":@(s.tokenizeMs),@"prefillMs":@(s.prefillMs),@"samplingMs":@(s.sampleMs),@"decodeShareMs":@(s.decodeShareMs),@"sequenceLatencyMs":@(s.latencyMs),@"tokensPerSecond":@(s.generated/std::max(s.latencyMs/1000,0.000001)),@"limit":@(s.limit),@"eog":@(s.eog)}];
    }
    llama_synchronize(_context);llama_memory_clear(mem,true);cleanup();double elapsed=ms(start);
    return @{@"rows":rows,@"totalMs":@(elapsed),@"prefillMs":@(prefillTotal),@"decodeMs":@(decodeTotal),@"samplingMs":@(sampleTotal),@"prefixMs":@(prefixMs),@"prefixTokens":@(common),@"inputTokens":@(inputs),@"outputTokens":@(generated),@"aggregateTokensPerSecond":@(generated/(elapsed/1000)),@"peakSampleFootprintMB":@(peak),@"memory":[HyMTNative memory],@"timingVersion":@"synchronized-v2",@"batchPrefill":@(batchPrefill),@"waves":waves,@"parallel":@(_parallel),@"context":@(llama_n_ctx(_context)),@"reservedPrefixSequence":@(_parallel)};
}
@end
