# Advanced AI compression and screenshot translation speed

Research cutoff: October 18, 2026. Execution continued October 20–22, 2026 (Asia/Shanghai).

**PARTIAL — no safe smaller model or raw-inference runtime winner; exact in-memory caching is physically validated in the shared pipeline.** A cache-enabled original Release is installed for final actual Shortcut acceptance; original 7B weights/runtime and application data are preserved. Development model/runtime experiments use the separate Next bundle. No commit, push, reset, clean, stash, Phase 3 cleanup, server translation or external screenshot upload.

Evidence root: `/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/advanced-ai-20261018/`. Public research metadata, source archives, logs, immutable weight provenance, native checks and physical JSON/PNG exports live there. Private source screenshots and model responses are outside Git. Repository fixtures contain only constructed phrases.

## A. Baseline and measured bottleneck

Reference: Hy-MT2-7B-Q4_K_M, **4,624,648,896 bytes**, SHA256 `9f96256500f3fc1ab4d64336b58f52a949a95ad7516b0c229476eef782f9f77b`. llama.cpp v0.6.0 `d81235049384534c167caea52b85a694f6103d14`, Metal, one actor/model/context, p8, 6144 unified KV slots, reserved prefix sequence 8, exact token-prefix sharing, packed independent prefill, stable IDs and reference sampling (k20 / p0.6 / temperature0.7 / penalty1.05 / seed42 / EOG / limit512).

The actual historical warm Release request `13F65CD0…` took 24.542 s receipt→PNG, 24.410 s processor, 23.919 s translation. Its native timings are 20.036 s decode (83.8% of native time), 2.837 s total prefill including 0.436 s prefix (11.9%), and 0.998 s sampling (4.2%). It has 1,013 logical prompt tokens / 424 output tokens in five waves (8/8/8/8/3), nominal thermal, no memory warning. OCR 0.351 s / grouping 0.00017 s / render 0.097 s. Model preparation was <0.001 s. The remaining ~0.132 s between processor and PNG return is not all attributed to PNG encoding because input/export/serialization also contribute.

Do not multiply a published attention-kernel speedup by this whole latency. Decode weight traffic and low sequence occupancy dominate this short-context workload. Baseline F16 KV allocation is **768 MiB** at 6144 tokens (confirmed in actual runtime logs); the mapped weight buffers are ~4.4 GiB. KV allocation, resident model pages and iOS charged footprint are different quantities. The previous warm Release endpoint was resident 5,428 MiB / footprint 1,005 MiB, not a one-gigabyte total model working set. No GPU hardware counter or absolute continuous memory peak was collected.

### Screenshot identity boundary

The exact historical successful Release PNG was not exported by that privacy-restricted action; its report has geometry/token counters, not input pixels or input SHA. An archived adjacent diagnostic screenshot exists (`DB4675FF…/input.png`, SHA256 `511153ffd2d5ab1151d8dcb532f871e48b6df14eb68763608a83deadafd21b92`). It replays as 35 groups / 424 output tokens but is **not asserted to be pixel-identical to the 24.542 s receipt**. New before/after comparisons use this same archived PNG SHA, and the two values are kept separate from historical receipt-to-PNG.

Additional fixed private images: seller chat SHA `59eef81bb74b32231c57491abe40eaac68ffcf24770f9cc4942553023f06bfa2`; dense41 `f24dada0cd9735e239975b6252b3af0a616557124d756b11553b9ce77f1b363c`; current acceptance product `6e2a10b031ee77c65f695683c156e7399a5865bd1fc5843f28ce099252998cca`. OCR/grouping/layout implementations are unchanged. Comparison harness rejects changed OCR strings and records full rendered coverage, warnings and tokens.

## B. Primary-source research shortlist

Verdicts distinguish a runnable implementation from a validated iPhone production choice. Expected benefits below are engineering estimates until measured.

| Technology / date | Actual target and implementation | Practical verdict / boundary |
|---|---|---|
| [TurboQuant / PolarQuant / QJL](https://research.google/blog/turboquant-redefining-ai-efficiency-with-extreme-compression/) / 2026-03-24 | KV/vector compression, not baseline GGUF weight compression. TheTom/llama-cpp-turboquant ca28b4bc0e531635d83fe530c6e6e8d694c4330d; MIT; third-party experimental Metal fork; NOT merged full PolarQuant in upstream | **READY TO TEST; TESTED, NOT SELECTED** — Isolated actual iPhone Metal test completed: KV 768->150.13 MiB, but 35-group 29.785s / chat12.061s; no weight file reduction |
| [Splash Attention](https://github.com/jax-ml/jax/tree/main/jax/experimental/pallas/ops/tpu/splash_attention) / live source through cutoff | Sparse Flash Attention TPU/Pallas kernel.  | **INCOMPATIBLE WITH THIS DEVICE** — Imports pallas.tpu, lane/sublane TPU layout; not a Metal/iOS kernel |
| [Metal FlashAttention / latest llama.cpp](https://github.com/ggml-org/llama.cpp/releases/tag/v0.7.0) / 2026-10-15 | attention and few-row quantized matmul compute. 620d2225cc436ab0b001e3200e590e3b286ef9ab; isolated iOS-device XCFramework built | **READY TO TEST; TESTED, NOT SELECTED** — New BF16 tensor-API FA, 128/96 head kernels, few-row MMA; isolated physical run supplied no consistent speedup; MoE-cache and unrelated-model MTP do not accelerate this dense Hy-MT2 automatically |
| [Apple LLM in a Flash](https://machinelearning.apple.com/research/efficient-large-language) / 2023-12 | flash-storage weight I/O / limited RAM.  | **NOT USEFUL FOR THIS WORKLOAD** — Our warm weights already mmap-resident; storage paging is not a free decode speedup; pruning/recovery and specialized weight layout needed |
| [Importance-aware GGUF Q3 / IQ2 / IQ3](https://github.com/ggml-org/llama.cpp/blob/620d2225cc436ab0b001e3200e590e3b286ef9ab/tools/quantize/quantize.cpp) / v0.7.0 2026-10-15 | model weights, disk/bandwidth tradeoff.  | **READY TO TEST; TESTED, REJECTED** — Q3_K_M and IQ2_XS created from official BF16 + calibration; both fail new physical RU critical-commerce cases. Metal support does not guarantee faster decode or semantic safety |
| [AWQ / GPTQ / HQQ](https://github.com/mit-han-lab/llm-awq) / live implementation reviewed | calibrated weight quantization.  | **RESEARCH ONLY** — CUDA TinyChat/GPTQ packing is not a drop-in Metal GGUF kernel. HQQ/MLX conversion needs independent quality/runtime checks; no current ready Hy-MT2 iOS artifact established |
| [AQLM / learned additive codebooks](https://github.com/Vahe1994/AQLM) / live implementation reviewed | weight compression with optimization/training.  | **RESEARCH ONLY** — Original training/inference stack uses CUDA; no verified production iOS Hy-MT2 codebook runtime |
| [AngelSlim STQ 2-bit / 1.25-bit](https://github.com/ggml-org/llama.cpp/pull/22836) / open PR checked 2026-10-18 | quantization-aware compressed weights / sparse ternary format.  | **REQUIRES SMALL PORT** — Official 1.8B files metadata 600534880 / 461860800 bytes; PR unmerged, ARM NEON CPU, no Metal files in PR. Existing 1.8B commerce-quality failure not solved by more aggressive compression |
| [Vocabulary / output-head trimming](https://huggingface.co/tencent/Hy-MT2-7B/blob/9b0eb4e8f001def3e5ff6469a0ac96fdb39ec223/config.json) / official pinned artifact | embedding/output computation and weights.  | **REQUIRES CALIBRATION** — 128167 x 4096 tied embeddings: about 525M parameters, ~7% of dense parameter count, not most of 7B. Safe token remapping/Unicode coverage must be verified; output Cyrillic and original mixed product codes required |
| [Pruning / language-pair distillation / QAT](https://github.com/Tencent/AngelSlim) / live implementation reviewed | smaller model architecture / recovery training.  | **RESEARCH ONLY** — Requires data, recovery/evaluation, likely external GPU; no training/rental started. Independent commerce references needed, not uncorrected teacher labels |
| [TranslateGemma 4B specialist](https://blog.google/innovation-and-ai/technology/developers-tools/translategemma/) / 2026-01-15 | smaller task-trained model family.  | **RESEARCH ONLY** — Official weights manually gated at google/translategemma-4b-it revision 10042cb0e6e7fdce748996a71dc3dc432a4e0c89; custom Gemma terms and template; not downloaded through an unverified community quant or unauthorized login |
| [MLX / MLX-Swift](https://github.com/ml-explore/mlx-swift-lm/blob/48114eedf3c3d4a682a6b1d644cc5af5c2945d10/Libraries/MLXLLM/Models/Hunyuan.swift) / source inspected at cutoff | alternative native Apple GPU runtime.  | **REQUIRES SMALL PORT** — Hunyuan attention/QK norm/dynamic NTK implementation exists; complete Hy-MT2 template, quantization and independent batching still require a validated iOS port. Mac throughput is not iPhone evidence; no automatic ANE gain |
| [Core ML stateful compressed transformer](https://apple.github.io/coremltools/docs-guides/source/stateful-models.html) / current official guide | graph conversion, stateful KV, GPU/ANE placement.  | **RESEARCH ONLY** — Stateful autoregressive KV supported. No verified ready Hy-MT2 conversion found; dynamic RoPE/QK norm/batch-mask/state/export must be checked. Compression support does not prove full ANE residency or background GPU permission |
| [LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM/tree/v0.18.0/samples/ios_and_mac) / v0.18.0 2026-10-06 | alternative CPU/Metal execution and converter.  | **RESEARCH ONLY** — Swift iOS >=15 and prebuilt Metal accelerator exist. No ready Hy-MT2 exporter found in inspected converter tree; not an iOS-incompatible runtime, but not a proven drop-in model conversion |
| [Speculative / Medusa / MTP / early exit](https://github.com/ggml-org/llama.cpp/releases/tag/v0.7.0) / 2026-10-15 | fewer target decode steps with verified drafts.  | **RESEARCH ONLY** — No compatible Hy-MT2 draft/MTP-head artifact established; 1.8B cannot simply share 7B token IDs. Added draft/context overhead is not assumed useful for short translations; prompt lookup has little repeated target text |
| Bounded exact-result memory / identical-source dedup (local experiment; no external screenshot upload) / 2026-10-20 implementation | avoid repeated validated inference; not raw model acceleration.  | **READY TO TEST; SHARED PIPELINE PASS** — Physical EN35/RU7 repeat results completed; full manifest/template/prompt/language/source keys; strict span validation; 256 entries / 1 MiB in RAM; clear on model unload. Experimental same-screenshot coalescing separately labeled |
| Targeted validation retry (local bridge experiment) / 2026-10-20 implementation | protected-span recovery only.  | **READY TO TEST; TESTED, REJECTED** — Did not recover the real omitted span. Independent next native request, same model/prompt, <=3s budget checked before/after decode commands; GPU work joins safely. No semantic guessed restoration or removed checks |
| [Supported background execution](https://developer.apple.com/documentation/metal/preparing-your-metal-app-to-run-in-the-background) / installed iOS 26.5.1 behavior + official guide | OS process/GPU lifecycle.  | **RESEARCH ONLY** — Existing BackgroundExecutionNotPermitted is real. Faster inference/caching may reduce exposure, but no duration or universal 30s OS budget is asserted. No private entitlements/keep-alive or foreground UX replacement. |

Google's March paper addresses compressed KV/vector data; the cited H100 attention result is not a demonstrated A19 Pro end-to-end improvement. Our isolated third-party TurboQuant fork uses PolarQuant/WHT-style cache types and is not represented as a Google-maintained or fully merged upstream implementation. CPU/CUDA/Vulkan Hadamard support in upstream is not equivalent to a complete production Metal PolarQuant port. The fork is MIT; its separate Python research repository is Apache-2.0. Fork status/license/source are archived, and custom iOS kernels must still pass the actual model's quality gates.

Splash's inspected implementation explicitly imports `pallas.tpu` and uses TPU lane/sublane layout. Apple “LLM in a Flash” concerns storage-aware inference under insufficient RAM; adding paging to already resident warm weights has no established benefit here. Current v0.7.0 MoE expert caching and new-model MTP are not automatically applicable to this dense architecture.

AWQ, GPTQ and HQQ are weight optimization/packing approaches, not interchangeable GGUF type names. AQLM needs its additive-codebook runtime and recovery work. A compression ratio alone proves neither Metal acceleration nor commerce quality. The practical first low-bit path here is native GGUF importance-aware quantization with verified BF16 inputs, not an arbitrary community binary.

## C. ZH→EN/RU specialization and training scope

The official model has 128,167 vocabulary entries, hidden width 4096, tied input/output embeddings, 32 layers, QK normalization and dynamic RoPE. The tied vocabulary matrix is about 525 million parameters, roughly 7% of the dense model. Removing half its rows would therefore remove only about 3.5% of parameters, not half the model; disk savings depend on that tensor's existing quantization. Language representations in the transformer/FFN layers are distributed. Deleting language names cannot remove most weights.

Vocabulary trimming is possible without full retraining only after coverage calibration and exact token/ID/tensor remapping; Chinese rare characters, Cyrillic subwords, Latin product codes, Unicode and prompt/control tokens must survive. This is not implemented as a risky tokenizer surgery. Layer/width pruning needs recovery fine-tuning; LoRA/adapter merging alone does not reduce dense parameter count or disk size. Sequence-length specialization can reduce KV/runtime buffers but not weight bytes (context is already only 6144).

A teacher→student specialist could be smaller, but training is a separate resource decision. A concrete pilot would need tens of thousands of independently reviewed commerce pairs, adversarial held-outs and a small GPU trial before any broad distillation run. A 1.8B LoRA pilot might use one 24–48 GB accelerator for hours; full distillation/recovery can need 80 GB-class GPU days. At an illustrative $1–5/GPU-hour, an 8–24-hour pilot is $8–120 compute, and 2–7 full-GPU days is $48–840 per GPU before review/data costs; these are arithmetic planning assumptions, **not live vendor quotes or an authorized purchase**. No GPU rental, paid dataset, training or teacher-output bulk labeling was started. The known 7B discount and shipping errors must not become ground truth.

TranslateGemma 4B is a relevant genuinely task-trained smaller architecture, not a generic small chat model. The official repository inspected is manually gated; no license acceptance/login or unverified community conversion was substituted. Its specialized language-code template and Gemma license require separate handling. Existing October physical 1.8B Q4 evidence already has discount and Russian action errors; neither STQ's smaller bytes nor older speed claims override that gate.

## D. Reproducible compression artifacts

Official BF16 source: `tencent/Hy-MT2-7B@9b0eb4e8f001def3e5ff6469a0ac96fdb39ec223`, Apache-2.0. Four safetensors shards were independently size/SHA-verified against immutable Hub metadata. `tools/runtime/advanced_models.py` reproduces the download and writes per-file provenance; it never installs a model.

Upstream v0.7.0 converter produced `models/Hy-MT2-7B-BF16.gguf`, 15,017,204,576 bytes / 354 tensors. Its embedded chat template, EOS=3 and BOS=127958 match the official Q4 GGUF; the converter's duplicate-EOS warning resolves to the same final metadata. Importance statistics were collected from **the original Q4 reference's activations**, not misrepresented as BF16 calibration: 16 chunks × 256 tokens of constructed EN/RU commerce text. This inexpensive exploratory matrix is not a claim of a representative large production corpus.

Calibration has separate public-style product/quantity/discount/refund/spec/code/UI samples, including placeholder examples. `commerce_holdouts.json` has 24 source-disjoint adversarial phrases, evaluated separately EN/RU. Intended meanings were reviewed by the coding assistant, not independently human-certified. No user screenshot/text was uploaded for evaluation. Full output review is separate from the teacher's wording.

Commands (from repository, evidence prefix abbreviated as `$ART`):

```sh
python3 tools/runtime/advanced_models.py "$ART/models/Hy-MT2-7B-BF16"
# same-revision upstream converter, recorded Python environment
python convert_hf_to_gguf.py "$ART/models/Hy-MT2-7B-BF16" --outtype bf16 --outfile "$ART/models/Hy-MT2-7B-BF16.gguf"
llama-imatrix -m REFERENCE_Q4 -f "$ART/calibration.txt" -o "$ART/commerce-imatrix.gguf" --chunks 16 -c 256 -b 256 -ub 128 -ngl 99 --no-ppl
llama-quantize --imatrix "$ART/commerce-imatrix.gguf" "$ART/models/Hy-MT2-7B-BF16.gguf" "$ART/models/Hy-MT2-7B-Q3_K_M-commerce.gguf" Q3_K_M 4
llama-quantize --imatrix "$ART/commerce-imatrix.gguf" "$ART/models/Hy-MT2-7B-BF16.gguf" "$ART/models/Hy-MT2-7B-IQ2_XS-commerce.gguf" IQ2_XS 4
```

Q3_K_M is **3,792,604,288 bytes**, SHA256 `c95766103e1572074b84627ccb74b2137a71c207b8c753f16af2d45cf2637732`, measured **17.99% smaller**, not ≤2.5 GB. It is separate in Next `Documents/AdvancedModels/`; original `Documents/model.gguf` was not overwritten. IQ2_XS completed: **2,432,870,816 bytes**, SHA256 `f6c7b1c3d033142171e2d2867b1365f2bdb5a03eacdd4e2e1777f913c6f7c5ae`, **47.3934% smaller**. This meets the ≤2.5 GB artifact target but fails the commerce-quality gate. Both files were generated from verified official BF16 with upstream v0.7.0 quantize + the recorded importance matrix, never substituted over the original application model. The downloaded full Tencent `LICENSE.txt` explicitly states Apache License 2.0; this was checked against the file, not only Hub metadata.

## E. Physical tests so far

Actual iPhone 17 Pro Max / iPhone18,2 / iOS 26.5.1, UDID `00008150-001475EC2E98C01C`, native logs identify Apple A19 Pro GPU. Mac logs identify Apple M5 and are labeled host correctness/quality only. Tests resumed over Wi-Fi; no Simulator or Mac speed is called physical iPhone speed. No Mirroring capture is used. Phone thermal state and LPM gate actual comparison runs; a run reaching serious heat is stopped rather than silently averaged into a nominal comparison.

| Runtime / scheduler | Fixed archived 35-group PNG total | Chat EN total | Dense41 EN total | Boundary |
|---|---:|---:|---:|---|
| v0.6 / waves, first set | 19.852 s | 7.996 s | 12.028 s | warm model, all blocks, cache off, nominal→nominal |
| v0.6 / continuous refill, first set | 19.823 s | 9.287 s | 11.410 s | same PNG/strings; 35-group output 428 vs 424 tokens, not byte-identical |
| v0.6 / waves, second set | 25.142 s | 9.524 s | 13.145 s | later thermal/DVFS variation; no exact clocks claim |
| v0.6 / refill, second set | 21.982 s | incomplete set | incomplete set | last reports retained; not a complete repeated median |
| v0.7 / waves | 24.837 s | 9.558 s | 13.130 s | nominal→fair then fair; does not establish a runtime speedup |
| v0.7 / longest-first waves | 20.634 s | 10.018 s | not completed | fair→fair on 35, chat ended serious; subsequent benchmark gate stopped |

These are pipeline replay totals, **not OS receipt-to-PNG or Action Button-to-visible measurements**. The full first v0.6 sample records active-slot time-weighted occupancy 29.6%→49.7% on the 35-group PNG, but refill prefill grows 2.281→4.981 s and decode drops 15.994→13.529 s. Its end-to-end benefit is negligible there; do not promote refill merely because occupancy improves. A long block produces 94–98 tokens and remains a straggler. Longest-first is a separate measured experiment; source length is only a predictor and output changes remain subject to quality review. No p12/p16/context growth was attempted without a capacity reason.

## F. Meaning-based quality findings

No aggregate score conceals the following errors:

| Source / intended meaning | Original Q4 | Compressed/runtime candidate | Disposition |
|---|---|---|---|
| `优惠85折，不包邮。` → 15% off, shipping excluded | EN says 20% off; RU correct 15% | Q3 EN same wrong 20%; Turbo3 EN says 25% | Existing reference commerce error retained; neither candidate fixes it |
| `原价200元，八五折后170元，便宜30元。` → original200, final170, saving30 / 15% | Q4 RU correctly says 15% | **Q3 RU says 25%**, retaining prices200/170 | **NEW CRITICAL COMMERCE ERROR, reproduced on physical iPhone**; production model promotion rejected |
| `今天付款，后天发货，不是后天到货。` → dispatch day-after-tomorrow, not arrival | EN ambiguous “won’t arrive until then” | Turbo3 EN invents arrival the following day | New shipping commitment risk; not waved away as style |
| Protected product heading with `promax / Magsafe / pro` | Known model omission of P0 in actual prior physical batch | Strict checks and original-pixel last resort retained | No guessed restoration; bounded independent retry failed the actual case; not promoted |

Host screening ran 24 constructed EN + 24 RU outputs per configuration for Q4, Q3, IQ2_XS, 1.8B Q4 and Turbo3 using the actual bridge and unchanged ProtectedSpans; no structural span failure occurred in that limited constructed set. This does not erase the real screenshot omission. Q3's new 25% RU error is also physically confirmed in `physical-q3-03/quality.json`. The separate meaning review covers **240 outputs** (five configurations × 24 held-outs × EN/RU) in `semantic-review.json`. It is an assistant review, not a human-certified acceptance set. Screening expected meanings are assistant-authored, not an externally certified benchmark.

## G. Implementations and safeguards

- The existing bounded-wave production native path remains the reference. DEBUG-only continuous refill, longest-first and command-boundary retry-budget experiments use public llama.cpp sequence memory APIs and the same independent samplers/EOG/IDs. No second model context or natural-language block concatenation.
- Native host checks pass original p8 mapping/capacity and cancellation at five stages, then the refill/longest-first cancellation/retry checks. Host speed is not the iPhone table. A deadline checks before/after synchronous decode; an in-flight GPU command is joined safely, not falsely claimed instantaneously preemptible.
- An isolated v0.7.0 iOS XCFramework and matching Jinja library were built through `advanced_runtime.py`; production Runtime symlinks were not changed. The third-party TurboQuant fork is isolated separately. Its Mac actual-model Metal experiment allocates **150.13 MiB KV** versus 768 MiB, while the **same 4.625 GB weight file remains unchanged**. Physical iPhone TurboQuant compatibility is confirmed, with slower measured translation; it was not selected.
- A small actor-owned exact translation memory is implemented provisionally: complete model manifest (hash/runtime/sampling/context/limit), actual embedded template, exact prompt/language and NFC source are in the SHA key; only EOG/ID/span-validated outputs enter it. 256 entries / 1 MiB, RAM only, clear on unload/import/native failure/memory-pressure unload. No persistent chat database, dictionary, network lookup or approximate match. Cache hits are labeled and never used as raw inference speed.
- Production cache processing validates pending-result IDs against the pending order, restores cached masked output against current exact-source spans, and retains original image pixels on rejected blocks. Full viewer still reuses its ProcessedScreenshot. Same-screenshot coalescing is a separate DEBUG comparison; no silent block budget.
- Updated cache isolation/strict-validation/eviction tests pass in the current unit/UI run (**19 passed / 0 failed**, `cache-tests.xcresult`). Physical shared-pipeline cache is now confirmed EN/RU; bounded retry was rejected. Actual Shortcut acceptance of the installed cache-enabled original Release is recorded separately below.

## H. Current decision and remaining work

**No compressed model has passed quality promotion.** Q3 is materially smaller but has a new physical RU discount error; IQ2_XS meets the size target but has a new physical Russian 85% discount error; it is rejected. Simple refill gives no sufficient 35-block benefit. v0.7/LPT evidence is limited by thermal state and does not justify a blind runtime replacement. Original 7B and pinned native/runtime are retained; the only proposed production improvement is exact validated in-memory reuse.

Research, model creation, physical compatibility experiments and reduction of losing native prototypes are complete. Final remaining gate: actual system Shortcut and A/B lifecycle acceptance of the installed original cache-enabled Release. No unseen-dense ≤10s raw-speed claim is made.


## I. Completed quality and cache experiments

Physical IQ2 `quality.json` reproduces `优惠85折，不包邮。` → **«Скидка 85%, доставка не бесплатна.»** The reference RU says 15%. IQ2 also changes `17pro` into `pro17` in a host EN hold-out while retaining individual placeholder values: structural span validation is necessary but does not certify semantic association. Its EN shipping hold-out changes the dispatch day. Q3's separate physical 25%/15% failure is likewise a hard rejection, not a wording preference. Existing 1.8B Q4 screening has four critical RU errors and two critical EN errors; more aggressive official STQ compression does not repair those semantics.

A same-fork F16 control was added to separate TurboQuant effects from fork/runtime drift. In 24 outputs per language, Turbo3 differs from that F16 control in 12 EN / 16 RU outputs. The shipping-day commitment error already exists in the fork's F16 control, so it cannot honestly be attributed solely to 3-bit KV. Conversely the fork F16 control produces a new RU 25% discount where Turbo3 says 15%; neither fork is a demonstrated safe replacement for the pinned reference. Raw control outputs are retained separately. KV reduction alone is not a quality or latency win.

The targeted-retry test uses the same model/template/prompt and strict EOG/span checks, with ≤3s admission/command-boundary budget. On the actual 30-group input it still yields 29 validated translations; total 20.047s raw → 26.273s including failed retry in that development round. A command already executing must join safely, so the soft 3s budget is not a hard wall-clock preemption guarantee. The failed experiment remains an isolated patch, not production behavior.

In round04 the actual shared ScreenshotProcessor successfully used the new exact memory: 30-group first pass 24.984s, then 29 cache hits + one uncached invalid block, total 6.144s with 53 freshly generated tokens instead of 450. This is **4.07× faster for that repeated input**, but the repeat ended at serious thermal state and a large Wi-Fi model copy overlapped part of the development round. It is useful correctness evidence, not a clean matched raw-throughput comparison. The missing product heading is still Chinese with an explicit partial warning: a cache does not repair a failed translation.

The next archived 35-group image hit 16 previously validated strings out of 35 (45.7%) from the preceding 30-group input; only 19 new generations / 302 output tokens were needed, versus all 35 / 424 without cache. The chat had zero cross-screen hits. These are measured overlaps for these inputs, not a general market-wide hit-rate claim. No production same-screenshot coalescing was added; its extra scheduling/output changes were not needed to establish exact-memory behavior.

The restored production native source is byte-identical to the task baseline SHA256 `1d9248763d90…`; native p8 mapping/prefix/packed/EOG/capacity and five cancellation stages + retry pass (`native-final/report.json`). Job ownership's 100 replacements + retry pass. Original Debug and Release compile successfully. Model manifest, original runtime links, OCR, grouper, overlay layout and Xcode project hashes match the task baseline. The 19 unit/UI tests pass on Simulator (separate from actual physical inference). New experiments are portable `advanced_native.patch` / external projects; they are not compiled into the production native bridge.


## J. Resume checkpoint — October 20, 01:52 Asia/Shanghai

The iPhone is **connected over Wi-Fi**, not a cable (CoreDevice list confirms physical iPhone18,2). The last diagnostic is LPM off, battery 35%, unplugged, thermal nominal. Next was relaunched with the restored production native bridge and DEBUG-only `AdvancedHeartbeat.json`. Its initial sampled UIKit state was **1 / inactive**, and the heartbeat stopped advancing. A further non-terminating `--activate` attempt resumed the heartbeat, but the new sample is **2 / background**, not active. This is evidence that these launches did not establish an active, progressing benchmark; it does not prove a native cache deadlock, a universal iOS timeout, or TurboQuant incompatibility. Device launch success is not test completion. The user was asked to open Next on the unlocked physical screen; no screenshot capture or Mirroring is requested.

Rounds05/07/08/09 have no completed final comparison and are excluded from speed tables. IQ2 round06 completed its physical semantic hold-outs (85% error above), but not the screenshot timing suite, before the diagnostic restart. The Turbo3 iOS app built, installed and launched, but did not finish model warmup before the diagnostic restart; **iPhone TurboQuant latency/quality remains unverified**. Host KV allocation is real but not substituted for phone memory. Partial folders and launch/console logs are preserved. Two LLDB CLI attempts did not actually attach to a stopped process; they supply no stack-trace diagnosis.

Original Release is still the accepted pre-experiment installation; no candidate model or new cache-enabled original Release was installed. Original application data/model were never cleared. The cache-enabled original Debug/Release builds and tests pass, but installation and actual system Shortcut cold/warm/X/cancel/retry remain a promotion gate. No new Action Button-to-visible timing is available. Keep the current installed production configuration until that gate succeeds.

### Compact decision table at checkpoint

| Candidate | Weight bytes | iPhone raw 35 / chat / dense41 | Cache / coverage | Quality / disposition |
|---|---:|---|---|---|
| Q4 v0.6 bounded p8 | 4,624,648,896 | 19.852 / 7.996 / 12.028s first matched set | off; all requested blocks | reference retained; known baseline semantic errors remain |
| Q4 v0.6 continuous refill | same | 19.823 / 9.287 / 11.410s | off; all blocks | no consistent useful end-to-end gain; isolated only |
| Q4 v0.7 bounded p8 | same | 24.837 / 9.558 / 13.130s | off; all blocks | thermal/state differences; no proved speed win |
| Q4 v0.7 longest-source first | same | 20.634 / 10.018 / incomplete | off; all requested blocks | chat ended serious heat; not selected |
| Q3 importance-aware | 3,792,604,288 | not completed / not claimed | off | new physical RU critical discount error; reject |
| IQ2_XS importance-aware | 2,432,870,816 | not completed / not claimed | off | new physical RU critical discount error; reject |
| Q4 + third-party Turbo3 KV | same | not completed / not claimed | off | isolated iOS build ready; host/fork quality drift; no promotion |
| Q4 + exact memory, 30-group screen repeat | same | different 30-group input: 24.984→6.144s | 29/30 hits; 29/30 valid blocks; partial warning retained | actual shared pipeline, thermal/transfer-confounded development result; not raw speed |

Selected production weight-size reduction remains **0%**. The reproducible IQ2 artifact is 47.39% smaller but is not a selected model. No ≤10s unseen 35-block claim, no new cold/warm system Quick Look latency, and no new physical Release acceptance is made.


## K. Completed physical resume — October 22, 2026

The user opened Next on the physical screen. The first view-owned DEBUG `.task` returned Swift.CancellationError (thermal nominal); this is excluded from timing results. Benchmark ownership was moved into the existing retained `job` task, with duplicate-start guard, usable Cancel and stage diagnostics. **Production ScreenshotProcessor/native cancellation was not relaxed.** The corrected stand completed rounds10,11,12. This supports a benchmark-lifecycle fix, not an assertion that every earlier background stall had the same cause.

### Matched original 7B + exact memory

| Screenshot / language | First pass / no cache hits | Exact repeat | Cache hits / fresh output tokens | Thermal | Output equivalence |
|---|---:|---:|---|---|---|
| Archived35 EN, SHA511153ff… | **22.763s** | **0.495s** | 0→35 hits; 424→0 tokens | nominal→nominal both | all35 restored strings and final PNG byte-identical |
| Seller chat7 RU, SHA59eef81b… | **13.556s** | **0.319s** | 0→7 hits; 380→0 tokens | fair→fair both | all7 restored strings and final PNG byte-identical |

These are **warm prepared-model ScreenshotProcessor totals**, not receipt-to-PNG or Action Button-to-visible system timings. No model file copy or competing inference ran during either comparison. EN repeat is 45.95× / RU42.53× faster for these repeated screenshots; this is explicitly a cache effect, not raw decoding acceleration. Counters remain generations35→35 and7→7, while requests/OCR/grouping/render each increase by one. `cache-confirmed-summary.json` checks exact translation and PNG equivalence. A single load report precedes each session; DEBUG benchmarkLoad does not increment the normal prepare load counter, so its reported zero is **not** proof of zero model loads. No memory warnings occurred.

EN OCR0.402→0.370s, translation22.121→0.006s, render0.189→0.075s. RU first/repeat preserve 100% drawn Chinese source area. EN35 has one existing fit warning: 35 translated but34 drawn, 99.24% source area /98.95% Chinese characters rendered. Both passes have zero panel intersections, unrelated-source overlaps and bound violations. The identical warning is retained honestly; no block was skipped to manufacture speed and no layout algorithm was changed.

Endpoint memory (not absolute peak): EN first/repeat charged footprint1000.90/1017.79MiB, resident1714.02/1729.16MiB; RU964.05/979.18MiB footprint,5458.34/5472.44MiB resident. Resident counters vary substantially with mapped-page accounting; they must not be mistaken for the weight-file bytes or KV allocation. Cache's configured string budget remains1MiB plus bounded dictionary overhead. No hardware GPU counters/continuous peak are claimed.

### Actual isolated TurboQuant iPhone result

Fork ca28b4bc… uses the same4,624,648,896-byte Q4 weights, p8,6144context, prefix+packed and reference sampling. Load log proves **Apple A19 Pro GPU / Metal, KV150.13MiB**, versus baseline768MiB (80.45% KV reduction). Load3.919s and verification1.652s excluded from warm table. First warmup completed EOG (`Add to cart`).

| Input | Total | Translation | Fresh output tokens | Temperature | Endpoint charged / resident |
|---|---:|---:|---:|---|---|
| Same archived35 EN |29.785s|29.089s|420|fair→fair|379.18 /4704.89MiB|
| Same chat7 EN |12.061s|11.736s|198|fair→fair|376.30 /4708.42MiB|

All requested blocks translated; no memory warning. This separate fork/control does **not** prove exact-output equality or an isolated kernel-only effect. It is slower than the pinned reference in these available runs, so no repeated large matrix or promotion is justified. Physical short hold-outs retained the reference's incorrect EN20% for85折; full host fork/control review already exposes semantic drift. KV memory reduction is real; weight reduction and latency improvement are not.

### Verification and delivered code

- Original application Debug/Release builds succeeded with the baseline native bridge and proposed exact memory. Release has one llama.framework and the byte-identical original model manifest; no automatic PERF_MODE entry in the original app.
- Unit/UI xcresult:19 passed,0failed, Simulator. This is not physical UI acceptance. No production/tested cache code changed since that run.
- Baseline native p8/sequence IDs/EOG/prefix/packed/capacity/five cancellation stages/retry PASS; host correctness evidence only. Ownership checks rerun:100 replacements, safe join, scoped cancellation and retry PASS.
- Existing geometry artifacts revalidated in `geometry-resume22/structural-checks.json`:16EN/RUcases PASS. These are structural checks of archived outputs; unchanged OCR/group/layout hashes prove this task did not redesign them.
- `git diff --check` PASS. No commit/push, destructive Git commands, model/container clear, private screenshot upload or paid training.
- New production code: `ScreenTranslatorNext/ScreenshotProcessor.swift` — one small exact-memory value type plus actor-owned lookup/insertion and pending-ID mapping in the existing processor. Unit cache isolation/eviction/invalid-span tests live in `Tests/Unit/ScreenTranslatorScaffoldTests.swift`.
- DEBUG-only changes: `PerformanceSprint.swift`, `ScreenTranslatorNextApp.swift` benchmark task ownership/heartbeat/diagnostic export; no benchmark launch in Release. Losing native changes were removed from production and retained reproducibly only in `tools/runtime/advanced_native.patch` / external isolated builds.
- Reproducibility scripts/fixtures: `advanced_models.py`, `advanced_runtime.py`, `advanced_quality.py`, `commerce_calibration.json`, `commerce_holdouts.json`; existing native and job-ownership drivers updated to exercise the selected source. No provider framework, extra production model/context, selector UI, persistent chat cache or dictionary was added.

### Recommendation

**KEEP CURRENT PRODUCTION model/runtime; add only the proven exact in-memory reuse after system acceptance.** This is a cache improvement outside the report's model/runtime option labels, not a claim that a new runtime won. No safe ≤2.5GB EN/RU model was selected. Original 7B Q4 size4.625GB, selected weight reduction0%, original p8 bounded scheduler and F16KV768MiB remain. The historical24.542s successful input lacks a pixel hash; the new matched35comparison is22.763→0.495s first/repeat, not proof that its historical raw latency fell45×.

Remaining constraints: first-time dense requests still take about20–30s on these cases and remain exposed to supported iOS background-GPU lifecycle restrictions; protected-span omission is not repaired by the rejected retry or cache; one EN tiny-label fit warning remains; adversarial commerce translations require independent references before training or model substitution. A training/distillation project would need separate reviewed data/resources; no rental was started. Final actual Shortcut acceptance follows below.


## L. Installed Release acceptance gate

The original cache-enabled Release was installed on October22 without uninstalling or clearing its container. Installed build artifact: bundle `AlenShamatov.ScreenTranslator`, executable SHA256 `d22028f464bc3d8f98081704a0b936664d77d55faf583c39aefddc9157c7a15f`; manifest remains original. The isolated Next inference process was terminated first, so no second resident model was intentionally kept for the acceptance test. The original app was **not** prelaunched from Mac or attached to a console. The actual OS Shortcut must create its own process, preserving the accepted background UX.

The user was asked to run Fast7B Quick Look twice on the same Chinese screen and close with native X. At the final log inventory, no post-install request had yet been recorded. Earlier October21/22 request folders are historical and are not counted as cache-enabled Release acceptance. **Actual Shortcut / X→source / OS cancellation-retry / RouteA / RouteB acceptance of this build: pending, not PASS and not a reproduced FAIL.** These gates resume from this installed build after the user's reply; no model search or long performance sprint needs repeating.

Exact next action: collect those real Release receipts/reports, verify cache-hit counters and unchanged protected-span/PNG return contract, then one cancellation→retry and A/B→FullViewer reuse check. If a headless first run fails, classify the observed error and preserve logs before changing anything; do not substitute a foreground benchmark or private keep-alive.
