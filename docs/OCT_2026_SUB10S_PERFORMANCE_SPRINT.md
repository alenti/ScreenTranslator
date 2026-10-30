# ScreenTranslator — Sub-10s Performance Sprint

Started 2026-10-09; physical comparison completed 2026-10-10, Asia/Shanghai.

**Verdict: PASS for warm ordinary Chinese → English on the tested real corpus, using the existing 7B model. Recommend 7B ONLY with independent batched decoding, common-prefix KV reuse and packed prefill.** This is a performance experiment in DEBUG Next, not a completed production integration or Shortcut acceptance.

The final 7B configuration completed the 15-block product document in **5.96 s median (5.38–6.65 s)** and the seven-block seller chat in **8.01 s median (6.67–8.51 s)**. All three confirmation repetitions of each were under 10 s, with all accepted blocks generated and rendered, no exact cache and no block budget. The dense 41/65-block feeds took **10.39/18.36 s** in one final configuration run each. Dense visible coverage remains a separate layout limitation.

1.8B Q4 is substantially faster: confirmed product/chat medians **1.81/2.06 s**, dense 41/65 medians **3.48/5.84 s**. Its semantic errors in discounts and Russian replacement/action direction make it a weaker default. Greedy did not resolve that gate. There is no need to accept this quality loss to reach the primary EN target with 7B.

## Evidence and preserved baseline

Repository: `/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator`.
HEAD remains `19d01e24aadd45847b277c2626308927a4cc3638`. Existing dirty work was recorded before edits. Final comparison of 34,851 baseline file hashes finds **zero deleted baseline files and six changed existing source/project files**, all identified in section 13. No reset, clean, stash, checkout-over-work, staging, commit, push or Phase 3 deletion occurred.

Read and inspected: fresh reboot, Phase 1, Phase 2 OCR quality and physical user acceptance reports, plus actual current native/actor/OCR/grouping/layout code. Runtime, reference manifest, 7B weights, prompt, protected spans and reference sampling were preserved. No old translator, dictionary, server, LoRA or speculative draft was used.

All private raw screenshots, outputs, console logs, plans and derived data stay outside Git at:
`/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/sub10s/`.

- [Raw physical summary, 168 runs](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/sub10s/physical/performance-summary.json)
- [Final comparison CSV](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/sub10s/physical/final-comparison.csv)
- [3,980 block-level profiles](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/sub10s/physical/block-profile.csv)
- [Exact corpus/mapping checks](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/sub10s/corpus-comparison-checks.json)
- [Final medians, speedups and counters](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/sub10s/final-metrics.json)

These are 168 executions of five fixed real images, not 168 independent screen types. There are also 80 physical semantic outputs from ten constructed sentences across eight model/language/configuration sets. Those sentences are quality checks only and never enter screenshot speed statistics.

## Physical device and measurement contract

Physical iPhone 17 Pro Max / `iPhone18,2`, UDID `00008150-001475EC2E98C01C`, iOS **26.5.1 / 23F81**. Native reports identify **Apple A19 Pro GPU**, Metal backend and full layer offload. Pinned runtime is **llama.cpp v0.6.0, d81235049384534c167caea52b85a694f6103d14**. No duplicate model/engine was introduced: one loaded native model and one actor, with its single context configured for independent sequences.

Low Power Mode was OFF in every recorded run. iPhone Mirroring was closed. Despite the requested unplugged setup, telemetry shows `batteryState=2` (charging) throughout; these are **wired/charging measurements**. Main confirmations start at thermal state 0 (nominal). Earlier baseline/parallel trials start at 1 (fair); a few dense trials end at 2 (serious). One early p2 dense65 run started serious and is retained as raw evidence, not a preferred comparison. Thermal waits and the user cooling the phone allowed nominal confirmations. No clock/utilization percentage was measured.

Warm totals begin after SHA verification, model load, warmup and context construction. They include production OCR, filtering, grouping, protected-span work, translation, layout and rendering. They exclude PNG export/report serialization, screenshot capture, AppIntent handoff and viewer presentation. This is **warm processing end-to-end**, not a measured physical Action Button latency. Cache and skipped-block results are labelled separately.

Each report includes original/result PNG, image SHA, observations, frozen groups/IDs, block inputs/outputs, stage timings, EOG, error/fit/collision/bounds metrics, thermal, battery, memory and configuration. Corpus checks prove identical PNGs and ID/source-string sets across all comparisons. Shared decode time allocated to individual sequences is explicitly amortized; it is not a separate GPU measurement per block.

Final representative preparation samples, excluded from warm totals:

| Model/session | Verify | Load | Warmup |
|---|---:|---:|---:|
| 7B baseline | 3.004 s | 0.276 s | 0.556 s |
| 7B final confirmation | 1.889 s | 0.282 s | 0.549 s |
| 1.8B final confirmation | 0.756 s | 0.133 s | 0.149 s |

These process restarts can benefit from OS file/page cache; they are not fresh-boot worst-case cold-launch guarantees. No cold Shortcut timing was tested.

### Fixed real corpus

| Case | Provenance | Accepted Chinese groups | Limitation |
|---|---|---:|---|
| spec | Physical acceptance cup-capacity/options capture, request `8B71A018…` | 7 | One small capacity label cannot fit |
| product | Phase 1 physical Chinese cup-lid PDF screenshot | 15 | Authentic product document, not live Taobao product-detail page |
| chat | Physical seller conversation, request `248EDF07…` | 7 | Long customer bubbles and seller setup-cost reply |
| dense41 | Physical Taobao home feed, request `B145769C…` | 41 | Two safe-fit omissions |
| dense65 | Different physical Taobao home feed, request `C197D5EC…` | 65 | Fourteen safe-fit omissions; some corrupt small OCR |

No synthetic card enters the physical speed table. This corpus covers chat, product text, dense UI and specifications, but has no separate ordinary UI-only screenshot or new live product-detail capture. The ordinary EN conclusion is strongest for the actual product document and chat; broader app/page generalization still needs user acceptance.

## 1. True bottleneck breakdown

The reference actor completes every block sequentially. Each block rerenders the same embedded template, tokenizes, clears KV, prefills the complete prompt, creates the sampler and decodes its output. OCR/grouping/rendering are small compared with that work.

**Timing correction:** the first instrumented baseline let asynchronous GPU work finish inside `llama_sampler_sample`, falsely attributing the wait to sampling. Explicit `llama_synchronize` after prefill/decode produced `synchronized-v2`. The five initial v1 runs remain archived, but their sampling/prefill breakdown is excluded from the decision. Historical acceptance timers also cannot support the earlier claim that prefill was negligible.

| 7B sequential EN | Blocks | Logical input/output tokens | Prefill | Decode wall | Sampling | Translation | Total |
|---|---:|---:|---:|---:|---:|---:|---:|
| spec | 7 | 210 / 90 | 2.259 s | 6.476 s | 0.205 s | 8.946 s | 9.330 s |
| product | 15 | 459 / 186 | 5.465 s | 15.291 s | 0.488 s | 21.252 s | 21.553 s |
| chat | 7 | 283 / 199 | 3.251 s | 17.478 s | 0.560 s | 21.298 s | 21.599 s |
| dense41 | 41 | 1,017 / 261 | 20.521 s | 22.970 s | 0.943 s | 44.463 s | 45.014 s |
| dense65 | 65 | 1,622 / 449 | 32.212 s | 39.757 s | 1.628 s | 73.641 s | 74.292 s |

Prefill is about 26% of product, 15% of chat, 46% of dense41 and 44% of dense65 translation time. Decode remains dominant for long chat output. Actual sampler CPU work is about 2–3%, not the dominant blocker. Tokenization is recorded per block and remains millisecond-scale. The large costs are repeated independent prefills, unbatched decode, output length and 7B weight traffic. Both prefix/prefill batching and decode batching are justified by the measurements.

## 2. Controlled 7B sequential baseline

`round1-7b-baseline-v2` exercises the same production `ScreenshotProcessor.process` and actor translation path after model preparation. Stable groups are frozen for subsequent experiments. All five cases generated every accepted block without generation errors, using the unchanged Chinese instruction, embedded 7B template, span protection and EOG handling.

Reference sampling throughout selected configurations: top-k **20**, top-p **0.6**, temperature **0.7**, repeat penalty **1.05**, seed **42**. Max output remains **512** in the selected path. This report labels it reference sampling rather than inferring runtime GGUF metadata defaults.

No 7B production route/settings were switched to an alternative model or benchmark path. The original phone app was not reinstalled during this sprint.

## 3. Independent parallel sequence experiment

The pinned public API was checked in actual source, including batch token/position/sequence IDs, independent logits indexes, `n_seq_max`, unified KV and sequence memory ownership. The live upstream snapshot was archived at `71ad0590f4808b6202f9213d166913858c73b1bc`; the runtime used for all results remains the pinned build. Implementation follows the public [llama.h](https://github.com/ggml-org/llama.cpp/blob/d81235049384534c167caea52b85a694f6103d14/include/llama.h) and [parallel example](https://github.com/ggml-org/llama.cpp/blob/d81235049384534c167caea52b85a694f6103d14/examples/parallel/parallel.cpp).

Each OCR block has its own complete prompt, sampler, sequence ID, token position and result ID. A decode batch contains one next token per active independent sequence. This never combines unrelated blocks into one natural-language prompt. Deterministic bounded waves clear retired slot KV before reuse. No continuous-refill scheduler or general backend architecture was added.

| EN total seconds | spec | product | chat | dense41 | dense65 |
|---|---:|---:|---:|---:|---:|
| 7B production sequential | 9.33 | 21.55 | 21.60 | 45.01 | 74.29 |
| 7B p2 | 7.28 | 17.40 | 18.57 | 44.94 | 54.47* |
| 7B p4 bounded | 5.87 | 12.33 | 15.30 | 28.83 | 50.86 |
| 7B p8 bounded | 4.29 | 9.12 | 9.28 | 23.99 | 46.06 |
| 7B p8 + prefix | 3.74 | 7.27 | 8.33 | 15.64 | 25.83 |
| 7B p8 + prefix + packed prefill | 2.90 | 5.22 | 6.58 | 10.39 | 18.36 |

*The early p2 dense65 starts at thermal 2; not used as evidence of a nominal winning speed. Rows are individual full-corpus rounds, not matched-temperature statistical estimates. Confirmation repetitions below supply the selected ordinary-screen range.*

The first p4 context of 10,240 tokens required about 1,280 MiB KV and failed allocation; that configuration was stopped, not called PASS. The winning shared context is **6,144 tokens**, with eight active sequence slots plus a reserved prefix sequence. A conservative capacity check reserves each wave's input suffix and maximum output; capacity/EOG errors fail explicitly. Arbitrarily long eight-block waves may be rejected rather than exceeding memory. No warning occurred in the 168 completed records; that does not turn the failed large-context trial into a safe result.

p8 is the practical winner among tested levels. No p16 or second model/context was attempted. Native/Metal numerical batching can change sampled wording even at the same seed; stable ID mapping was exact, not guaranteed byte-identical prose.

## 4. Prefix reuse and packed prefill

Complete prompts are tokenized first. Their exact common **token** prefix is prefetched once into a reserved sequence, and public `llama_memory_seq_cp` shares its KV ownership with each independent sequence. Suffixes resume at correct positions; samplers accept the full original input. The usual EN common prefix is 19 tokens. Prefix state is retained across waves within one screenshot and cleared at the next screenshot. No fragile text-prefix slicing or runtime-internal hack is used.

7B p8 dense41 improves **23.99 → 15.64 s**, dense65 **46.06 → 25.83 s** with prefix; 1.8B independent control dense41 **5.26 → 3.67 s**, dense65 **8.46 → 5.99 s**. Different rounds can have thermal/DVFS variation; the magnitude and repeated runs establish practical value, not an exact causal percentage at identical clocks.

Prefix-only 7B confirmation chat runs were **8.25, 8.98, 10.26 s**, so a single early sub-10 result was insufficient. The added small packed-prefill branch fills a shared `llama_batch` with independent suffix tokens and tracks each sequence's last-prompt logits index. This reduces many short separate GPU submissions while preserving separate prompts. It changes the full-corpus 7B prefix run **15.64 → 10.39 s** on dense41 and **25.83 → 18.36 s** on dense65.

Native Mac correctness checks cover p1/p2/p4 × prefix on/off × packed on/off, EOG, protected tokens and index mapping; physical p8 uses the same code. Mac timings never enter the speed decision. The final three physical product/chat confirmations all pass, so both **prefix reuse and parallel decoding are useful**. Packed prefill is required for the strongest 7B recommendation.

## 5. Official 1.8B artifact and current-device quality

The official [Tencent Hy-MT2-1.8B GGUF](https://huggingface.co/tencent/Hy-MT2-1.8B-GGUF) was obtained at a recorded revision and verified. No August benchmark or community quantization determines the decision.

| Model | Bytes / decimal GB | Official revision | SHA256 |
|---|---|---|---|
| Hy-MT2-7B-Q4_K_M | 4,624,648,896 / 4.625 | `ab8472660ac61fac25f1af43fac2599d52a8a775` | `9f96256500f3fc1ab4d64336b58f52a949a95ad7516b0c229476eef782f9f77b` |
| Hy-MT2-1.8B-Q4_K_M | 1,133,080,448 / 1.133 | `a0c709d9fac510f2c807aa3af52872340dc37a4a` | `dc5f44fcf1fa496ee7ad725982c0c8c553a4de00259b53af84c4b89fb0c06699` |

1.8B uses its own embedded model template, the same Chinese instruction and protected-span restoration. It resides in the separate Next `PerfModels` path; the original app's 7B `Documents/model.gguf` was never addressed for model replacement.

The real product quantities/weights/temperature, seller/customer negotiation direction and major quantities generally survive 1.8B. Named entities and compact UI labels degrade. Final p8 prefix examples include national subsidy becoming `Guoben`, factory becoming `Taohangshan`, Messages becoming News, and a bathroom heater becoming a fan. These are meaningful errors rather than style preferences.

## 6. 1.8B performance, sampling and output limits

| EN total seconds | spec | product | chat | dense41 | dense65 |
|---|---:|---:|---:|---:|---:|
| 1.8B production sequential | 2.36 | 4.84 | 4.38 | 9.11 | 16.64 |
| 1.8B p2 | 1.81 | 3.56 | 3.44 | 7.09 | 12.38 |
| 1.8B p4 | 1.54 | 2.97 | 3.24 | 7.16 | 11.83 |
| 1.8B p8 | 1.27 | 2.26 | 2.04 | 5.22 | 8.44 |
| Independent p8 control | 1.29 | 2.26 | 2.04 | 5.26 | 8.46 |
| Same independent round + prefix | 1.08 | 1.83 | 2.10 | 3.67 | 5.99 |
| Same independent round + greedy, no prefix | 1.32 | 2.54 | 2.28 | 6.04 | 10.01 |
| Same independent round + dynamic limit, no prefix | 1.32 | 2.90 | 2.67 | 6.59 | 10.42 |
| p8 + prefix + packed, one-off | 0.94 | 1.64 | 2.26 | 3.26 | 5.04 |

Round 3 isolates prefix, greedy and dynamic limits as separate switches. Later jobs run at different thermal/frequency conditions, so their larger totals do not establish that a nonbinding token cap itself slows the model. Greedy changed wording/output count but did not demonstrate a useful speed gain and introduced a Russian actor reversal; it is rejected. Dynamic `min(512, max(32, sourceTokens × 4 + 16))` terminates explicitly on limit exhaustion without EOG. Every completed dynamic output reached EOG, and unchanged normal output lengths showed **no demonstrated latency saving**. Selected decoding keeps the reference sampler and 512 ceiling.

No artificial truncation, prompt rewrite or verbose-text stripping was used. The RU outputs genuinely take more tokens: final 7B chat **380** vs EN **200**; dense65 **964** vs **449**. Russian remains a slower mode.

### Confirmation repetitions, warm/cache off/all blocks

| Configuration/case | Repetitions | Median total | Observed range | Generated/rendered source area |
|---|---:|---:|---:|---:|
| 7B packed product | 3 | **5.961 s** | 5.376–6.651 s | 100% / 100% |
| 7B packed chat | 3 | **8.008 s** | 6.666–8.512 s | 100% / 100% |
| 7B packed spec | 3 | 2.898 s | 2.804–3.386 s | 100% / 89.8% |
| 1.8B prefix product | 3 | 1.809 s | 1.696–2.271 s | 100% / 100% |
| 1.8B prefix chat | 3 | 2.059 s | 1.943–2.170 s | 100% / 100% |
| 1.8B prefix dense41 | 3 | 3.478 s | 3.100–3.683 s | 100% / 98.7% |
| 1.8B prefix dense65 | 3 | 5.842 s | 5.098–6.323 s | 100% / 75.2% |

The confirmed 7B product is EXCELLENT; chat is PASS, with its median just above the 8 s stretch threshold. Dense41 is within preferred 15 s and dense65 within the potentially acceptable 20 s performance target, but dense65 visible coverage is insufficient for a 90% screen-quality claim. Dense final 7B timings are one run each, not a confirmation median.

### Russian, one full-corpus final run each

| Configuration | spec | product | chat | dense41 | dense65 |
|---|---:|---:|---:|---:|---:|
| 7B p8 prefix + packed | 3.57 s | 11.56 s | 17.00 s | 23.10 s | 35.15 s |
| 1.8B p8 prefix | 1.08 s | 2.92 s | 3.66 s | 6.59 s | 10.54 s |

The sub-10 conclusion applies to primary EN, not Russian. 1.8B RU speed does not erase its semantic gate failures.

## 7. Exact translation cache and real duplication

The DEBUG cache is a bounded FIFO of **512 model-generated results**, in memory for the benchmark session. Keys contain SHA256 model identity, language, exact NFC source, embedded-template/prompt version and decode/experimental configuration. Only successfully span-restored outputs enter it. Different language/model/config/source keys were checked for isolation. No dictionary, approximate matching, semantic replacement or server is involved.

Current frozen corpus: **135 blocks, 106 unique exact source strings, 29 duplicate occurrences**. A perfect upfront deduplication would avoid 21.5% of generations across these files. The implemented cache checks the pending wave before filling it, so same-screenshot repetitions are not coalesced. Observed first traversal therefore saves **22/135 (16.3%)** generations, with 22 hits in dense65 after dense41. This is the measured result, not the theoretical maximum.

Repeat traversal hits **135/135 (100%)**. The 7B cache repeat totals are **0.24–0.54 s**, still including OCR/layout/rendering, but with zero translation inference. Same-config chat first cache pass **10.873 s → 0.244 s**, **44.6×** faster. Dense41 has the largest measured same-config repeat ratio, **49.5×**. 1.8B repeats take **0.18–0.47 s**. These are exact repeat-screen product gains, not raw inference speeds or guarantees for a new page. Cached output inherits model errors.

Cache state is explicitly labelled in all tables. It is useful for back-and-forth UI and retries but insufficient as the core sub-10 strategy; the selected 7B result meets the target with cache OFF. Cache measurements predate packed prefill and must not be relabelled as packed-cache measurements.

## 8. Geometry-only fast block coverage

Experimental priority uses source rectangle area, OCR confidence and Chinese character count, with stable ID tie breaking. No app-specific words or semantic dictionary are used. Skipped text keeps original pixels. All/budget15/20/25/30 were actually run on the best 1.8B prefix path.

| Budget | dense41 requested area | dense41 rendered area | dense41 total | dense65 requested area | dense65 rendered area | dense65 total |
|---|---:|---:|---:|---:|---:|---:|
| 15 | 65.6% | 65.6% | 2.02 s | 37.1% | 32.4% | 1.88 s |
| 20 | 75.7% | 75.7% | 2.74 s | 47.0% | 41.0% | 2.43 s |
| 25 | 85.7% | 85.7% | 3.02 s | 55.0% | 49.0% | 2.97 s |
| 30 | 91.6% | 91.6% | 3.59 s | 70.1% | 55.8% | 3.45 s |
| all | 100% | 98.7% | 3.35 s | 100% | 75.2% | 5.70 s |

Top30 dense41 covers **87.2%** of Chinese characters, dense65 only **50.7%**. Area means summed rectangles of accepted Chinese source groups, not 90% of all meaningful screenshot pixels. The “all” and budget jobs can differ with thermal/clock state; top30 is not asserted faster when its recorded total exceeds all-control.

Budgeting is **not useful for the selected production recommendation**: 7B already passes ordinary EN with all blocks, 1.8B already passes dense raw inference, and dense65 budgeting loses too much content. It is retained only as an explicit DEBUG comparison switch; no silent production skipping was added.

## 9. Quantization and pruned experiments

**Q3: NOT TESTED. STQ/AngelSlim: NOT TESTED.** Q4 already reaches the primary objective with acceptable reference-model continuity, so the conditional lower-bit rounds were pruned. No experimental branch or CPU-only STQ runtime was integrated; no STQ compatibility/merge-status claim is made. There was no speculative draft implementation, tokenizer compatibility assumption, LoRA, model-family change or new quantization provenance to report.

## 10. Required physical iPhone comparison table

The table below contains actual representative physical records. For confirmed configurations the row is the run nearest the three-run median total; its token/stage/memory values belong to that actual run. Dense final 7B rows are one-off full-corpus observations. All timing rows are EN.

Logical input tokens include each complete prompt; prefix reuse reduces evaluated work rather than the logical input column. Aggregate tok/s is total newly generated output tokens divided by translation wall time. It is not per-sequence decode throughput. Exact cache rows show zero newly generated tokens.

Memory values are **MiB**: native end-of-wave sampled footprint / post-render endpoint footprint / endpoint resident. This is not continuous peak monitoring. “Not sampled” is intentional for sequential/cache-only paths. File-backed/mapped model pages make resident much larger than iOS charged footprint; these quantities are not interchangeable or proof of a low total memory requirement. Thermal 0/1/2 means nominal/fair/serious. Semantic error counts apply to reviewed actual screenshot outputs; “not individually rated” avoids fabricating per-configuration quality acceptance.

| Configuration | Case | Model GB | Parallel | Prefix | Packed prefill | Decode | Requested / translated | Generated / rendered area % | Cache | Input / output tokens | Translation s | Total s | Aggregate tok/s | Native wave peak / endpoint footprint / endpoint resident MiB | Thermal before > after | Material screen errors |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Current 7B sequential | spec | 4.625 | 1 | False | False | reference sampled | 7 / 7 | 100.0 / 89.8 | off | 210 / 90 | 8.946 | 9.330 | 10.1 | not sampled / 443 / 4938 | 1 > 1 | 0 |
| Current 7B sequential | product | 4.625 | 1 | False | False | reference sampled | 15 / 15 | 100.0 / 100.0 | off | 459 / 186 | 21.252 | 21.553 | 8.8 | not sampled / 460 / 4959 | 1 > 1 | 0 |
| Current 7B sequential | chat | 4.625 | 1 | False | False | reference sampled | 7 / 7 | 100.0 / 100.0 | off | 283 / 199 | 21.298 | 21.599 | 9.3 | not sampled / 457 / 4960 | 1 > 1 | 1 |
| Current 7B sequential | dense41 | 4.625 | 1 | False | False | reference sampled | 41 / 41 | 100.0 / 98.7 | off | 1017 / 261 | 44.463 | 45.014 | 5.9 | not sampled / 529 / 5034 | 1 > 1 | 0 |
| Current 7B sequential | dense65 | 4.625 | 1 | False | False | reference sampled | 65 / 65 | 100.0 / 75.2 | off | 1622 / 449 | 73.641 | 74.292 | 6.1 | not sampled / 598 / 5106 | 1 > 1 | 1 |
| 7B p8 without prefix | spec | 4.625 | 8 | False | False | reference sampled | 7 / 7 | 100.0 / 89.8 | off | 210 / 90 | 3.960 | 4.286 | 22.7 | 944 / 967 / 5452 | 1 > 1 | not individually rated |
| 7B p8 without prefix | product | 4.625 | 8 | False | False | reference sampled | 15 / 15 | 100.0 / 100.0 | off | 459 / 186 | 8.843 | 9.121 | 21.0 | 965 / 991 / 5485 | 1 > 1 | not individually rated |
| 7B p8 without prefix | chat | 4.625 | 8 | False | False | reference sampled | 7 / 7 | 100.0 / 100.0 | off | 283 / 200 | 9.052 | 9.277 | 22.1 | 964 / 979 / 5488 | 1 > 1 | not individually rated |
| 7B p8 without prefix | dense41 | 4.625 | 8 | False | False | reference sampled | 41 / 41 | 100.0 / 98.7 | off | 1017 / 261 | 23.502 | 23.992 | 11.1 | 1002 / 1095 / 5611 | 1 > 1 | not individually rated |
| 7B p8 without prefix | dense65 | 4.625 | 8 | False | False | reference sampled | 65 / 65 | 100.0 / 75.2 | off | 1622 / 449 | 45.403 | 46.058 | 9.9 | 1080 / 1159 / 5712 | 1 > 2 | not individually rated |
| Best 7B / selected fast overall | spec | 4.625 | 8 | True | True | reference sampled | 7 / 7 | 100.0 / 89.8 | off | 210 / 90 | 2.702 | 2.898 | 33.3 | 976 / 991 / 5499 | 0 > 0 | 0 |
| Best 7B / selected fast overall | product | 4.625 | 8 | True | True | reference sampled | 15 / 15 | 100.0 / 100.0 | off | 459 / 186 | 5.694 | 5.961 | 32.7 | 984 / 998 / 5510 | 0 > 0 | 0 |
| Best 7B / selected fast overall | chat | 4.625 | 8 | True | True | reference sampled | 7 / 7 | 100.0 / 100.0 | off | 283 / 200 | 7.769 | 8.008 | 25.7 | 967 / 981 / 5500 | 0 > 0 | 1 |
| Best 7B / selected fast overall | dense41 | 4.625 | 8 | True | True | reference sampled | 41 / 41 | 100.0 / 98.7 | off | 1017 / 261 | 9.907 | 10.389 | 26.3 | 1017 / 1110 / 5583 | 0 > 0 | 0 |
| Best 7B / selected fast overall | dense65 | 4.625 | 8 | True | True | reference sampled | 65 / 65 | 100.0 / 75.2 | off | 1622 / 449 | 17.634 | 18.359 | 25.5 | 1107 / 1186 / 5684 | 0 > 0 | 2 |
| 1.8B sequential | spec | 1.133 | 1 | False | False | reference sampled | 7 / 7 | 100.0 / 89.8 | off | 194 / 76 | 2.023 | 2.363 | 37.6 | not sampled / 306 / 1461 | 1 > 1 | not individually rated |
| 1.8B sequential | product | 1.133 | 1 | False | False | reference sampled | 15 / 15 | 100.0 / 100.0 | off | 447 / 178 | 4.571 | 4.841 | 38.9 | not sampled / 312 / 1477 | 1 > 1 | not individually rated |
| 1.8B sequential | chat | 1.133 | 1 | False | False | reference sampled | 7 / 7 | 100.0 / 100.0 | off | 274 / 186 | 4.155 | 4.376 | 44.8 | not sampled / 307 / 1478 | 1 > 1 | not individually rated |
| 1.8B sequential | dense41 | 1.133 | 1 | False | False | reference sampled | 41 / 41 | 100.0 / 98.7 | off | 995 / 244 | 8.656 | 9.111 | 28.2 | not sampled / 385 / 1557 | 1 > 1 | not individually rated |
| 1.8B sequential | dense65 | 1.133 | 1 | False | False | reference sampled | 65 / 65 | 100.0 / 75.2 | off | 1594 / 417 | 16.028 | 16.638 | 26.0 | not sampled / 447 / 1622 | 1 > 1 | not individually rated |
| 1.8B p8 without prefix | spec | 1.133 | 8 | False | False | reference sampled | 7 / 7 | 100.0 / 89.8 | off | 194 / 76 | 0.985 | 1.272 | 77.2 | 672 / 695 / 1851 | 1 > 1 | not individually rated |
| 1.8B p8 without prefix | product | 1.133 | 8 | False | False | reference sampled | 15 / 15 | 100.0 / 100.0 | off | 447 / 178 | 2.007 | 2.263 | 88.7 | 717 / 729 / 1888 | 1 > 1 | not individually rated |
| 1.8B p8 without prefix | chat | 1.133 | 8 | False | False | reference sampled | 7 / 7 | 100.0 / 100.0 | off | 274 / 186 | 1.826 | 2.037 | 101.9 | 698 / 712 / 1891 | 1 > 1 | not individually rated |
| 1.8B p8 without prefix | dense41 | 1.133 | 8 | False | False | reference sampled | 41 / 41 | 100.0 / 98.7 | off | 995 / 244 | 4.830 | 5.218 | 50.5 | 727 / 816 / 1999 | 1 > 1 | not individually rated |
| 1.8B p8 without prefix | dense65 | 1.133 | 8 | False | False | reference sampled | 65 / 65 | 100.0 / 75.2 | off | 1594 / 417 | 7.909 | 8.437 | 52.7 | 834 / 898 / 2094 | 1 > 1 | not individually rated |
| Confirmed 1.8B prefix | spec | 1.133 | 8 | True | False | reference sampled | 7 / 7 | 100.0 / 89.8 | off | 194 / 76 | 0.734 | 0.933 | 103.6 | 844 / 844 / 2125 | 0 > 0 | 0 |
| Confirmed 1.8B prefix | product | 1.133 | 8 | True | False | reference sampled | 15 / 15 | 100.0 / 100.0 | off | 447 / 178 | 1.558 | 1.809 | 114.2 | 886 / 868 / 2123 | 0 > 0 | 0 |
| Confirmed 1.8B prefix | chat | 1.133 | 8 | True | False | reference sampled | 7 / 7 | 100.0 / 100.0 | off | 274 / 186 | 1.835 | 2.059 | 101.3 | 820 / 835 / 2107 | 0 > 0 | 0 |
| Confirmed 1.8B prefix | dense41 | 1.133 | 8 | True | False | reference sampled | 41 / 41 | 100.0 / 98.7 | off | 995 / 244 | 3.157 | 3.478 | 77.3 | 849 / 822 / 2095 | 0 > 0 | 5 |
| Confirmed 1.8B prefix | dense65 | 1.133 | 8 | True | False | reference sampled | 65 / 65 | 100.0 / 75.2 | off | 1594 / 417 | 5.380 | 5.842 | 77.5 | 853 / 830 / 2112 | 0 > 0 | 5 |
| 1.8B packed one-off | spec | 1.133 | 8 | True | True | reference sampled | 7 / 7 | 100.0 / 89.8 | off | 194 / 76 | 0.621 | 0.944 | 122.4 | 711 / 720 / 1868 | 0 > 0 | not individually rated |
| 1.8B packed one-off | product | 1.133 | 8 | True | True | reference sampled | 15 / 15 | 100.0 / 100.0 | off | 447 / 178 | 1.368 | 1.644 | 130.1 | 729 / 740 / 1894 | 0 > 0 | not individually rated |
| 1.8B packed one-off | chat | 1.133 | 8 | True | True | reference sampled | 7 / 7 | 100.0 / 100.0 | off | 274 / 186 | 2.028 | 2.262 | 91.7 | 691 / 706 / 1887 | 0 > 0 | not individually rated |
| 1.8B packed one-off | dense41 | 1.133 | 8 | True | True | reference sampled | 41 / 41 | 100.0 / 98.7 | off | 995 / 244 | 2.802 | 3.260 | 87.1 | 734 / 818 / 2002 | 0 > 0 | not individually rated |
| 1.8B packed one-off | dense65 | 1.133 | 8 | True | True | reference sampled | 65 / 65 | 100.0 / 75.2 | off | 1594 / 417 | 4.480 | 5.036 | 93.1 | 838 / 901 / 2099 | 0 > 0 | not individually rated |
| 7B exact-cache repeat | spec | 4.625 | 8 | True | False | reference sampled | 7 / 7 | 100.0 / 89.8 | repeated-pass-exact-cache | 0 / 0 | 0.001 | 0.267 | 0.0 | not sampled / 1215 / 5615 | 1 > 1 | inherited cached output |
| 7B exact-cache repeat | product | 4.625 | 8 | True | False | reference sampled | 15 / 15 | 100.0 / 100.0 | repeated-pass-exact-cache | 0 / 0 | 0.001 | 0.271 | 0.0 | not sampled / 1261 / 5658 | 1 > 1 | inherited cached output |
| 7B exact-cache repeat | chat | 4.625 | 8 | True | False | reference sampled | 7 / 7 | 100.0 / 100.0 | repeated-pass-exact-cache | 0 / 0 | 0.001 | 0.244 | 0.0 | not sampled / 1315 / 5720 | 1 > 1 | inherited cached output |
| 7B exact-cache repeat | dense41 | 4.625 | 8 | True | False | reference sampled | 41 / 41 | 100.0 / 98.7 | repeated-pass-exact-cache | 0 / 0 | 0.004 | 0.366 | 0.0 | not sampled / 1325 / 5790 | 1 > 1 | inherited cached output |
| 7B exact-cache repeat | dense65 | 4.625 | 8 | True | False | reference sampled | 65 / 65 | 100.0 / 75.2 | repeated-pass-exact-cache | 0 / 0 | 0.006 | 0.541 | 0.0 | not sampled / 1359 / 5838 | 1 > 1 | inherited cached output |

Full machine-readable runs, all p2/p4/p8 trials, greedy/dynamic, cache and budgets remain in the linked summary. All 168 completed records have **0 generation errors, 0 reported memory warnings, 0 panel intersections, 0 unrelated-source overlaps and 0 bounds violations**. Failed context allocation/thermal-guard attempts are separate failures, not completed records.

## 11. Quality comparison against 7B

[Real aligned review](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/sub10s/real-quality-review.json) records all 135 final 7B-packed / confirmed 1.8B-prefix outputs with GOOD / UNDERSTANDABLE / MATERIAL ERROR and notes. The reviewer is the coding assistant, non-blind; this is not user acceptance or an independently validated accuracy score. Thirteen source groups contain ambiguous/corrupt OCR and are flagged separately.

| Reviewed clean real source groups (122) | GOOD | UNDERSTANDABLE | MATERIAL ERROR |
|---|---:|---:|---:|
| Final 7B packed | 109 | 11 | 2 |
| Confirmed 1.8B prefix | 102 | 11 | 9 |

The 7B clean-source errors are the existing chat setup-cost → shipping-cost error and one new dense height-adjustment → intensity-adjustment change. Across all 135 groups, including the ungradable/corrupt inputs, the recorded totals are 109/23/3 vs 102/23/10. The additional corrupt discount fragment is not assigned solely to the model. No invented OCR correction was applied.

Packed 7B differs from sequential 7B in only **four of 135** output strings: three cosmetic/uncertain changes and the material height/intensity change. All 20 EN/RU constructed 7B holdout outputs are byte-identical before/after packing. Parallel/prefill optimization nevertheless does not guarantee semantic or byte equivalence on arbitrary inputs.

[Physical semantic holdout review](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/sub10s/semantic-holdout-review.json):

| Ten holdouts per set | GOOD | UNDERSTANDABLE | MATERIAL ERROR |
|---|---:|---:|---:|
| Reference 7B EN | 8 | 1 | 1 |
| Packed 7B EN | 8 | 1 | 1 |
| Reference 7B RU | 9 | 1 | 0 |
| Packed 7B RU | 9 | 1 | 0 |
| 1.8B sampled EN | 6 | 2 | 2 |
| 1.8B sampled RU | 6 | 0 | 4 |
| 1.8B greedy EN | 7 | 2 | 1 |
| 1.8B greedy RU | 5 | 0 | 5 |

Concrete reproducible failures:

- `优惠85折，不包邮。` means **15% off** and shipping not included. 1.8B sampled EN gives **50% off**, greedy EN/RU gives **85% off**. Reference and packed 7B EN also give **20% off**, while 7B RU is correct. This existing 7B price-language limitation is retained honestly, not repaired with a rule.
- On the sentence with original100, final85, saving15, 1.8B sampled EN/RU says **85% discount** alongside the inconsistent final85. Greedy EN fixes that single sentence but not the shorter discount sentence.
- 1.8B greedy RU turns the customer's “can you resend parts?” into **“can we send parts?”**. Sampled/greedy RU also turns recording a fault video and resending parts into photographing/sending the video, and resending accessories into restoring them.
- Clear quantity/price/unit protected-span tests retain 3,000 vs 30,000, ¥135 and 260×80cm. Reference 7B still makes an unprotected causal/action error in the real seller setup-cost reply, so it is a reference, not a truth oracle.

The majority of 1.8B output is understandable and its speed is excellent, but systematic discount failures plus RU action errors fail the requested semantic gate for a single default commerce translator. This is current October physical evidence, not an inherited August verdict. No new dictionaries, correction rules or prompts were added to disguise errors.

## 12. Recommended product architecture and Quick Look feasibility

Recommend **Option A: 7B ONLY**, with the measured p8 / bounded shared KV / common-prefix / packed-prefill implementation and unchanged reference prompt/sampler. A two-model Instant/Accurate architecture adds model management and memory/lifecycle complexity without being necessary to meet ordinary EN on this corpus. Keep 1.8B as DEBUG evidence; do not add final settings or silently replace 7B.

For the recommended 7B, raw translation speedups against v2 sequential are **3.73× product / 2.74× chat** using confirmed medians; warm total speedups are **3.62× / 2.70×**. Dense full-corpus total improvements are **4.33× (41) / 4.05× (65)**. Experimental 1.8B prefix raw translation is **13.64× product / 11.60× chat**, but those speed numbers do not pass its quality gate. The best measured repeat-cache product gain is **49.5× dense41**, separately labelled; same-config chat repeat gain is 44.6×.

**Quick Look fast mode: MAYBE.** Model processing latency is now plausible for ordinary warm EN. Actual `Shortcut screenshot → local inference → returned PNG → system Quick Look` was **not invoked or migrated** in this sprint. Fresh-process verification/warmup, app/context lifecycle, memory and GPU eligibility under the real AppIntent execution mode remain separate gates. Current [AppIntent supported modes](https://developer.apple.com/documentation/appintents/appintent/supportedmodes) and [IntentFile](https://developer.apple.com/documentation/appintents/intentfile) describe the public routing/file contract; they do not establish a universal 15-second execution guarantee. The legacy 15 s guard is application code. Local SDK declares LongRunningIntent / requiresGPU for OS27+, which cannot be relied on for the physical **26.5.1** phone.

No claim is made that background 7B inference will be reliable merely because foreground warm processing is fast. The desired overlay over the source app with system Quick Look and Done remains a later UX/execution feasibility task; the current foreground lightweight screen was not redesigned here.

## 13. Code, small geometry fix and verification

Changed existing files relative to the sprint hash baseline:

- `ScreenTranslatorNext/HyMTNative.h/.mm`: DEBUG profiling, public independent-sequence/prefix/packed experiments; shared unchanged template-rendering helper; preserve Metal offload log after verbose metadata fills the bounded log.
- `ScreenTranslatorNext/ScreenshotProcessor.swift`: DEBUG actor entry points for the same loaded native instance.
- `ScreenTranslatorNext/ScreenTranslatorNextApp.swift`: explicit DEBUG launch environment only; no Release automatic benchmark, session idle handling.
- `ScreenTranslatorNext/ScreenTranslatorNext.xcodeproj/project.pbxproj`: include the DEBUG harness source.
- `ScreenTranslatorNext/OverlayLayout.swift`: minimal image-pixel edge tolerance described below.

Added `ScreenTranslatorNext/PerformanceSprint.swift` (202 lines), `tools/runtime/perf_native_checks.py` (60), `tools/runtime/perf_summary.py` (49), and this report. Existing snapshotted native/header/actor/app/project changes are +231/−28 lines; with the new harness/tools this is about **515 net code lines**, plus the small geometry fix, excluding reports and external benchmark plans/data. No production provider family, second OCR/grouper/renderer, settings hierarchy or model factory was introduced. Losing sampler/limit/budget switches remain confined to reproducible DEBUG experiments rather than production flows.

The real chat's approximately **0.84 image-pixel** OCR boundary contact is reproduced in the existing renderer. The minimal fix trims the source candidate up to **one image pixel** at that shared boundary and prevents tight-fit reconstruction from growing it back. The final overlap check stays strict; it does not permit panels to overlap or hide arbitrary coverage. Real chat baseline fit omissions **2 → 0** in the focused regression; 16 existing EN/RU structural regression cases pass. No broad OCR/grouping/layout redesign occurred. Other dense/spec fit warnings remain explicit and original pixels survive.

Final validation:

- Original ScreenTranslator generic-device **Debug and Release builds PASS**; Next **Release PASS**, plus the signed physical DEBUG benchmark already installed/executed.
- Release binaries have no benchmark native selectors or `PERF_MODE` entry point. Model manifest is included. Runtime/model baseline hashes remain unchanged.
- Native Mac independent/prefix/packed mapping/EOG/protected-token checks PASS; Mac timings excluded.
- DEBUG cache-isolation and real-chat geometry assertions PASS; 16 Simulator layout structural checks PASS, clearly non-physical.
- Every physical comparison uses matching PNG SHA and exact frozen source IDs; no generation/restore errors in completed reports.
- Normal 7B phone app model still has **4,624,648,896 bytes** and its pre-sprint modification timestamp `2026-10-06T16:46:09Z`. It was neither replaced nor reinstalled. Exact source model SHA was verified locally; this final listing is not a new device-side full hash assertion.
- Benchmark Next was relaunched without `PERF_MODE` after completion, restoring normal process idle behavior and releasing the benchmark session/model.

### Copy incident and recovery disclosure

During a plan-overwrite attempt I incorrectly used `devicectl copy to --remove-existing-content true`, which cleared the **experimental Next Documents** container. The original production bundle/container was never targeted. I stopped, disclosed the mistake and recovered from local archives before continuing. Unique plan filenames plus readback equality replaced overwrite attempts; the unsafe flag is not used by the runner.

**74 pre-existing cards/raw report files were restored and read back from the device with exact SHA256 matches**. Both exact model artifacts and corpus/physical exports were restored. The old cached `prepare.json` had no byte-identical archived source and was reconstructed from its corresponding archived preparation report; that old diagnostic is explicitly not an exact recovery. A duplicate p2 trial accidentally launched under a p4 log name has console-only timings after the incident; it is excluded from the final comparison. It is never relabelled p4. Fresh p4 bounded and all later measurements have complete raw exports. See [recovery readback proof](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/sub10s/recovery-readback-checks.json), `recovery-incident.json` and `recovery-proof.json`.

## 14. Exact next action and remaining gates

**Next implementation task: integrate the already measured 7B p8/common-prefix/packed native path into the original foreground shared actor/processor, preserving one model and the existing cancellation/replacement joins; then validate the normal and lightweight routes on the phone.** Move only the winning mechanism out of DEBUG, keep strict ID/capacity/span/EOG failures, and retain the current sequential path as a temporary development comparison until production-route acceptance. Add the bounded exact cache separately if desired after raw-path integration; do not make cached timings the acceptance criterion.

Do not begin Quick Look migration or Phase 3 as part of this sprint. No such implementation was started.

Remaining real risks/gates:

1. Production adoption and physical Shortcut end-to-end latency are not yet tested; autonomous Next results are processor evidence.
2. RU ordinary product/chat still take 11.56/17.00 s; the primary EN success does not establish sub-10 RU.
3. Dense65 renders only about **75.2% accepted source text area** even though 100% is generated; one spec row and two dense41 rows also remain safe-fit omissions. The large chat omission is fixed. Layout needs separate targeted acceptance, not silent destructive expansion.
4. Reference 7B has a reproducible short-discount error and a seller cost-cause error; packed numerical changes add one height/intensity error. No model-output financial truth guarantee is implied.
5. Five fixed real screenshots and three ordinary-screen repeats establish this corpus result, not all-app latency/quality. Measurements were charging and baseline thermal fair vs final nominal; device clocks were not controlled.
6. One reconstructed historical Next preparation diagnostic remains nonidentical after the disclosed copy incident; raw recovered screenshot/report files are verified exact.

**Stop point reached: full physical matrix, independent optimizations, cache/coverage experiments, English/Russian confirmation and quality comparison are complete. Recommendation: retain 7B, integrate the winning batching next; no Quick Look migration, legacy deletion, commit or push.**
