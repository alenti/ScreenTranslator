# Fast 7B production integration and real Quick Look feasibility — 2026-10-10

Verdict: **production fast 7B PASS; actual system Quick Look feasibility PASS, including cold and warm model sessions**. This report distinguishes production-core tests, direct intent handoff tests and actual OS Shortcut execution. The file-return probe remains DEBUG-only; it is not a completed Release Quick Look migration. No Phase 3 deletion, production translation cache, commit or push.

## 1. Production integration

The original ScreenTranslator now calls one `HyMTTranslator.translateBatch` operation for the screenshot's grouped blocks. It uses the same native implementation as the selected sprint result. The former per-block production loop is removed; the old single-generation bridge is DEBUG-only. Vision, grouping, protected spans, the approximately 1 px chat geometry tolerance, renderer and typed `ProcessedScreenshot` viewer contract are preserved.

The model remains Hy-MT2-7B-Q4_K_M, 4,624,648,896 bytes, SHA256 `9f96256500f3fc1ab4d64336b58f52a949a95ad7516b0c229476eef782f9f77b`. Successful on-device preparation verifies the installed model against that manifest. Runtime remains llama.cpp v0.6.0, commit `d81235049384534c167caea52b85a694f6103d14`; no runtime rebuild or replacement was needed.

Private evidence root: `../BuildArtifacts/oct2026/fast7b-production/`. `baseline/` contains full git status/diff/log/HEAD and source hashes. Starting HEAD is `19d01e24aadd45847b277c2626308927a4cc3638`. Existing dirty work was preserved. No reset, clean, stash, checkout-over-files or model recopy was used.

## 2. Native architecture

One app-owned actor owns one native model and context. Full independent prompts retain the exact Chinese instruction and embedded template. Every request carries its original integer block ID; every output carries both that ID and its original array index. Completion order never determines ownership.

At most eight independent sequences run in a wave, with separate sampler state, positions, output buffers, EOG validation and protected-span restoration. Sampling is unchanged: top-k 20, top-p 0.6, temperature 0.7, repeat penalty 1.05, seed 42, output limit 512. Independent OCR blocks are never concatenated into a single natural-language prompt.

The shared native helper is used by production and DEBUG comparisons; production exposes no parallelism, prefix, greedy, dynamic-limit or model-selection options. Samplers are freed at EOG; slot KV is cleared at wave boundaries, preserving the tested decode mechanism.

## 3. Context and KV configuration

Context is 6,144 tokens, nine sequence IDs, unified KV, batch 256, microbatch 128, four CPU threads. Sequence 8 is reserved for the exact common token prefix. Complete prompts are tokenized first; no string-prefix slicing is used.

Prefix is prefetched once per screenshot, copied with public sequence-memory APIs, and reused across bounded waves. Independent suffix tokens are packed with explicit sequence/position/last-logits bookkeeping. Each wave conservatively reserves the prefix plus every suffix and full 512-token output allowance. A wave is split before it can exceed context capacity. A single oversized prompt fails visibly; another context is never allocated.

Native failures explicitly cover capacity, prefill/decode, logits ownership, UTF-8, missing EOG/output limit and duplicate IDs. Swift additionally validates result count/ID/index and protected spans. No sequential or legacy translation fallback masks failure.

## 4. Cancellation and replacement

Native cancellation is checked before prefix, after prefix/prefill/decode and between waves. Error return synchronizes GPU work, clears all sequence state and frees samplers before returning. `beginRequest` synchronizes/clears the previous KV state before resetting cancellation; unload synchronizes before freeing the context.

The existing Swift replacement barrier remains: cancel task/native work, await the preceding task's safe exit, then start the next request. Run/request IDs reject stale publications. Background cancellation/unload policy remains unchanged.

Physical coordinator test used a 65-block screenshot, cancelled after native completion progress had begun, successfully retried, then cancelled another dense run and replaced it with different chat pixels. Safe processing exit was 70.33 ms for Cancel and 103.79 ms for replacement. The new chat result won; no old result was accepted. One model load served all four requests.

## 5. Route A physical results

Actual Action Button → existing normal Shortcut → original app → production p8 → full viewer was executed on a live WeChat seller chat. User: «перевод стал заметно быстрее - меня перекинуло в приложение. Полный view и прогресс появились».

Request `898CCD73-4E3E-46CD-A446-0A20F8476810`, run `D2B2FE68-7A8E-4D82-B625-2A047FF42265`: EN, nine groups, two waves, 257 prompt tokens / 108 output tokens, 5.977 s translation, 4.842 s preparation, 11.234 s processor total, modelReused=false, zero memory warnings. Raw input was inspected: authentic non-black chat screenshot. The user also ran a warm repeat, a dense Taobao tire product-detail screen and its specification/options sheet; all completed. User: «очень плотный экран сработал ,страница товара тоже».

## 6. Route B physical results and full viewer reuse

Autonomous physical test invokes `FloatingScreenTranslateIntent.perform()`, persists/consumes the handoff, then exercises the real coordinator, processing view model, production engine and result DTO. This is **not** an OS-dispatched Shortcut invocation.

Checks passed: floating route/progress, cancel, successful Retry, different-image rapid replacement, floating result, Full Viewer reuse and dismissal. Retried dense65: 17.326 s total / 16.576 s translation, 65 groups. Replacement chat: 9.240 s total / 8.915 s translation, seven groups, warm model.

Full Viewer before/after counters are identical: requests=4, generations=202, loads=1, OCR=4, grouping=4, rendering=2. Same `UIImage` object and request ID were asserted. No OCR, translation, load or rendering was repeated. Actual Action Button B also completed on the live nine-group chat: request `8296E2BD-8682-4EC1-8C26-5DAD81DB685C`, 8.992 s processor total. Its Full Viewer counters stayed requests=5, generations=80, loads=4, OCR=5, grouping=5, rendering=5, with identical request/UIImage. User confirmed a fast transition, but reiterated that this foreground lightweight UI is not the desired floating UX. This is a functional B PASS, not acceptance of the final UX.

## 7. English physical timings

These are the **original app**, real saved input pixels and production processor, not the Next benchmark. Translation time now excludes separately measured model preparation; processor total includes it. All accepted blocks are generated, without exact cache or block skipping.

| Case | Blocks | OCR ms | Group ms | Prepare s | Translation s | Render ms | Total s | Reused | Prompt/output tokens |
|---|---:|---:|---:|---:|---:|---:|---:|---|---|
| Seller chat | 7 | 256 | 0.54 | 9.930 | 6.283 | 38 | 16.512 | No | 283 / 200 |
| Dense41 | 41 | 226 | 0.65 | 0.000 | 12.423 | 255 | 12.909 | Yes | 1,017 / 261 |
| Product document | 15 | 168 | 0.15 | 2.836 | 6.001 | 96 | 9.106 | No | 459 / 186 |
| Dense65 Retry, route B | 65 | 268 | 3.76 | 0.032 | 16.576 | 409 | 17.326 | Yes | 1,622 / 449 |
| Chat replacement, route B | 7 | 230 | 1.16 | 0.026 | 8.915 | 39 | 9.240 | Yes | 283 / 200 |

The saved “product” case is the authentic cup-lid document, not a fresh Taobao product-detail page. Physical A live chat adds a different real screen. Initial cold preparation includes hash verification, model/context creation, kernel initialization and warmup; it must not be reported as warm raw inference latency.

Actual OS Shortcut A/B runs:

| Actual route / input | Blocks | Preparation s | Translation s | Processor total s | Model reused | Fit warnings |
|---|---:|---:|---:|---:|---|---:|
| A / Taobao options sheet | 25 | 3.949 | 6.726 | 11.196 | False | 3 |
| A / warm chat repeat | 9 | 0.001 | 5.938 | 6.211 | True | 0 |
| A / WeChat chat | 9 | 4.842 | 5.977 | 11.234 | False | 0 |
| A / dense Taobao tire product | 28 | 9.730 | 18.891 | 29.243 | False | 0 |
| B / WeChat chat | 9 | 2.786 | 5.923 | 8.992 | False | 0 |

The 28-group live product screenshot is a different, text-heavy input: 384 output tokens and 15.91 s decode. It is not an apples-to-apples regression against the saved 15-group document. Native inference requested every group. Options retained three explicit fit warnings; all live completed cases had zero panel intersections/unrelated overlaps/bounds violations and zero memory warnings. No OCR/layout fix was made.

Action Button hardware press → visible viewer was not clocked. Processor totals exclude intent handoff and DEBUG PNG exports before presentation; they are not claimed as hardware-to-visible timings. Leaving the app preserves the prior background model-unload policy, so a fresh source-app invocation may require cold preparation. Warm repeat was physically confirmed separately.

## 8. Russian stability

Saved product document: 15 groups, 11.194 s translation / 11.444 s total, model reused. Saved seller chat: seven groups, 14.352 s translation / 14.680 s total, model reused. Dense41: 31.494 s translation / 32.145 s total. No generation, EOG, span restoration or sequence mapping error occurred.

## 9. Memory and thermal

Physical device is iPhone 17 Pro Max / iPhone18,2, UDID `00008150-001475EC2E98C01C`, iOS 26.5.1 (23F81), wired developer-enabled. Mirroring was closed; Low Power Mode was false in reports. Key completed runs were at fair thermal state (1). Live A battery state=2, charging. Actual Quick Look receipts were at nominal thermal state (0), Low Power Mode false. A/B notification counters recorded zero memory warnings; the headless probe did not separately instrument the memory-warning notification count, so no zero-warning claim is made for that counter. No probe termination or generation error occurred. The observed Quick Look endpoint footprint range was approximately 955–1,069 MiB; its process/model residency may be evicted by iOS between future invocations.

Endpoint footprint across completed automated cases was at most approximately 1,088 MiB. This is the process accounting metric, **not** the total model file allocation. Mapped model pages, Metal buffers and resident memory have different accounting; per-run endpoint resident and sampled native footprint are retained in `physical-metrics.json`. A sample is not an instrumented absolute peak.

One initial DEBUG corpus run stopped progressing after its first EN case; a diagnostic LLDB attempt ended the process with signal 9 without a usable backtrace. No crash file was returned. It is excluded from acceptance timings. The DEBUG corpus entry now disables auto-lock only while running and restores the previous setting; the complete repeated six-case run and lifecycle run succeeded. The original stall's exact cause is not proven.

## 10. Quality/output comparison

All 126 EN/RU translations across the three fixed cases matched the selected sprint p8/prefix/packed outputs exactly. There was no integration wording or mapping change. This does not reclassify known model mistranslations as correct. They remain translation-quality limitations documented in the sprint.

Layout produced zero panel intersections, zero unrelated-text overlaps and zero bounds violations. Chat and product had no fit warnings; dense41 retained two explicit fit warnings for each language. OCR/grouping/layout code was not redesigned.

## 11. Quick Look execution architecture research

The old Quick Look action is inspected only for the `IntentFile` input → translated PNG `IntentFile` output contract. Its runner/provider/OCR/grouping/renderer and custom 15 s guard will not be used by a probe.

iOS 26 supports `supportedModes` with background and immediate/deferred/dynamic foreground choices. Foreground execution brings the app forward and would alter the desired UX. [Apple's runtime documentation](https://developer.apple.com/documentation/appintents/configuring-the-runtime-behavior-of-your-app-intents) also explains that supported modes are preferences influenced by execution context.

[Apple's Metal background guidance](https://developer.apple.com/documentation/metal/preparing-your-metal-app-to-run-in-the-background) states that new command buffers submitted after entering background can fail with `notPermitted`. This was a specific execution risk to test, not a reason to infer failure. Installed SDK declarations mark `LongRunningIntent`, `performBackgroundTask` and `requiresGPU` as OS 27+, unavailable to this 26.5.1 device. A foreground benchmark cannot prove background AppIntent GPU eligibility. The actual OS-dispatched probe subsequently completed with `UIApplication.applicationState == .background` at receipt, while the user stayed in the source app. Seven real OS intent calls returned PNG successfully. No OS 27 API, explicit GPU entitlement workaround, app-opening handoff, old runner or background-task hack was used. This proves this device/OS/Shortcut configuration; it does not establish a universal background GPU guarantee.

## 12. Actual Shortcut configuration

A/B functional acceptance passed before adding the probe. `FastTranslateScreenshotIntent` is DEBUG-only, requests background execution and directly calls the production processor. `HyMTTranslator.shared` is also the actor used by `AppEnvironment`; no second actor/model/context is created by the probe. It returns `IntentFile(data: renderedPNG, filename: "translated.png", type: .png)` and never routes the ordinary viewer. No custom timeout or background GPU workaround is added.

A signed real Shortcut, `Fast7B Quick Look.shortcut`, was generated and copied to the original app Documents. Exactly three actions: `is.workflow.actions.takescreenshot` → `AlenShamatov.ScreenTranslator.FastTranslateScreenshotIntent` → `is.workflow.actions.previewdocument`. Explicit action-output UUIDs connect screenshot and translated PNG. Installed metadata supplies the intent identifier/team/bundle; signing with `shortcuts sign --mode anyone` succeeded after a transient first signing error. Release metadata excludes the probe. The user added the signed file and ran it through the OS, including Action Button from a WeChat chat and a dense Chinese screen. The original app console and persisted `received.json`/`status.json`/`report.json` record seven real executions. These are not direct `perform()` calls from a harness.

User: «остался в исходном чате - ошибок нет .вместо кнопки "done" есть в правом верхнем углу крестик - это даже лучше. Лишних кнопок не надо». Later: «все работает быстро. OCR работает отлично .Даже на плотном экране с множиством текста». The system close control is retained; no custom buttons were added.

## 13. Cold Quick Look result

**PASS cold-model functionality.** Initial model/kernel preparation was first exercised by a one-group screenshot of the Shortcuts library: 13.239 s intent → PNG, including 11.937 s preparation. That tiny input is not reported as ordinary screenshot performance.

For the representative cold-process test, the idle translator process PID 15115 was explicitly terminated with SIGTERM after completed output; a process inventory confirmed no translator process remained. The next real OS Shortcut started PID 15314 while the user stayed in WeChat. Request `B5A41F6C-5F5D-44D9-B276-E52CEBB760AC`: eight groups, initial applicationState=2/background, counters initially empty, modelReused=false, one model load, 2.820 s preparation, 4.891 s translation, 8.141 s processor, **8.181 s receipt → PNG return**. EOG/spans/ID mapping passed and no fit/collision warning occurred. This is a cold process/model with the OS file/kernel caches left intact, not a reboot-cold measurement.

## 14. Warm Quick Look result

**PASS warm-model functionality.** Three real WeChat Action Button runs in the first process used the same eight grouped source blocks, 273 prompt tokens / 155 output tokens. Receipt → PNG: **4.897, 4.761, 4.752 s** (median 4.761 s); processor: 4.712, 4.645, 4.683 s; translation: 4.338, 4.319, 4.364 s. Every run had modelReused=true and load count remained one. Exact-result cache was not called.

In the fresh process, two subsequent actual dense Chinese screens had 30 groups each: **12.567 and 11.963 s receipt → PNG**, 12.382/11.740 s processor, 11.680/11.134 s translation, 272/265 output tokens, modelReused=true, load count still one. All accepted groups generated; zero layout fit/collision/unrelated-text-overlap warnings in these two runs. User confirmed the preview worked quickly even on a dense screen.

## 15. Real wall time to visible Quick Look

**Exact hardware press → visible Quick Look wall time was not measured.** The user confirmed the visible system preview, retained source-app context and fast experience, but did not provide stopwatch numbers. Measured receipt → PNG times above include decode/input copy, processor and PNG encoding/export. They end immediately before `.result(value: IntentFile)`; OS return serialization and preview display are separate uninstrumented steps. No estimated handoff/display time or processor number is mislabeled as Action Button → visible time.

Closing uses the native top-right cross; the user confirmed remaining in the source chat and preferred it to Done. No app-home/settings/result navigation is part of the probe.

## 16. Validation, code and remaining gates

Original signed Debug, Original Release and Next Debug builds passed. Release contains `generateBatch:progress:` and one `llama.framework`; native benchmark/single-generation/test cancellation exports are absent. Model manifest in Release specifies context 6144 and unchanged model/runtime/sampling hashes.

Phase 1 checks passed on Simulator. All 16 Phase 2 geometry cases (eight inputs × EN/RU) passed on iOS 26.5 Simulator using production geometry with pinned recorded MT outputs. Mac native checks passed independent IDs, exact prefix mapping, packed prefill, EOG, spans, two waves, oversized-wave split, invalid/duplicate inputs and five cancellation checkpoints followed by exact-output retries. These host checks are correctness evidence, not iPhone speed evidence. `git diff --check` passed. Final `final-preservation.json` confirms unchanged HEAD, no missing baseline files and exact unchanged grouping/layout hashes. `final-checks.json`, `output-comparison.json`, `physical-metrics.json` and `quicklook-metrics.json` index the evidence. Release was rebuilt after the shared-actor change; its metadata contains no Fast Translate Screenshot probe and its binary exposes the production batch bridge without DEBUG native exports.

Changed surfaces: `App/AppEnvironment.swift` (same shared actor), `Intents/TranslateScreenshotIntent.swift` (DEBUG file-return probe), `HyMTNative.h/.mm`, `ScreenshotProcessor.swift`, `model.json`, processing progress display, DEBUG battery initialization/corpus automation in `ScreenTranslatorApp.swift` and `Core/Phase2Checks.swift`, and existing Mac quality caller. Added focused `tools/runtime/production_native_checks.py`. Shared helper avoids duplicate production native paths; old legacy files remain in place for Phase 3.

A/B actual Shortcut, full viewer identity, automated physical lifecycle and real Quick Look cold/warm feasibility passed. The fixed corpus preserves the reference outputs. No new quality/mapping failure was observed.

Remaining product work: the new file-return action is DEBUG-only; Release still contains the old Quick Look action/stack, deliberately not migrated or deleted in this task. Before production Quick Look replacement, apply the established one-request cancellation/replacement ownership to real OS intent execution and test OS cancellation, rapid repeated Shortcut dispatch, lock/background suspension and memory-pressure recovery. App-route lifecycle PASS does not substitute for those headless OS lifecycle checks. Warm background model retention was observed for these sessions, not guaranteed across OS eviction.

P1 latency: a dense live product detail took 18.891 s raw translation / 29.243 s cold processor; first kernel initialization can add around 12 s, while later cold preparation measured around 2.8–4.8 s. P1 layout: three options labels retained explicit fit warnings; no geometry rewrite was authorized. P2 measurement: precise Action Button → visible preview wall time remains uninstrumented. One initial corpus stall has no proven cause and is retained as a diagnostic limitation.

Phase 3 readiness: **NO** for bulk removal now. The desired Quick Look contract is physically feasible, but the Release action must be switched from the legacy stack and its OS lifecycle accepted before deleting that stack.

## 17. Exact next action

In the next separately authorized task, promote the proven file-return Quick Look action to Release, replace the old Quick Look translator call with the same shared production core, preserve native system close UX and add only the required single-request cancellation/replacement ownership. Validate actual cold/warm Action Button and OS lifecycle on this iPhone. Then decide Phase 3 deletion. No further migration, cache, model change, commit or push is performed here.
