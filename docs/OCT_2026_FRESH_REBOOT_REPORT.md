# October 2026 Fresh Reboot Report

Date: 2026-10-07, Asia/Shanghai. **Verdict: GO WITH PERFORMANCE WORK.**

The separate ScreenTranslatorNext app has run the complete local pipeline on the physical iPhone 17 Pro Max: image → Vision OCR → geometric grouping → Hy-MT2-7B Q4_K_M → stable block-ID mapping → overlay → PNG and visible image. The final batch completed 11 screenshots and 98 translated blocks, with zero generation/EOG failures, protected-span failures, render-fit errors, overlay intersections, or memory warnings.

The user changed the input requirement to “сделай сам себе такие карточки”. Therefore all four inputs are explicitly **synthetic development cards**, generated as images and recognized by actual Vision on the phone. No authentic Taobao/Pinduoduo/chat screenshot was supplied or tested. This is a working development baseline, with no claim of production quality on arbitrary screenshots.

## Current repository state

Repository: `/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator`. Branch `main`; HEAD and `origin/main` both `19d01e24aadd45847b277c2626308927a4cc3638`; remote `https://github.com/alenti/ScreenTranslator.git`. The parent directory is also a separate dirty Git repository; implementation stayed inside the requested nested repository.

Before changes, recorded `git status`, `git status --short`, `git diff --stat`, `git log --oneline --decorate -n 30`, `git branch -vv`, and `git remote -v`. The nested repository had 17 modified tracked files: Settings, Quick Look surfaces, application/project entry points, and old server files. Its diff was 3,934 insertions and 244 deletions. Untracked native inference experiments, LocalLlama, LocalModels, reports and tooling were also present. [Exact initial commands and outputs](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/repository-before.json).

The visible history still has five commits and the same HEAD as the August reports. No new committed application architecture was inferred from file dates. The old target still uses its mixed Apple Translation/Quick Look/Mac paths; August native harnesses remain available. The current experiment adds a separate project, fresh runtime and measurements without replacing those paths.

SHA256 verification proved **all 196 pre-existing tracked and non-ignored untracked files unchanged**, including the dirty old `.pbxproj`, old native sources, reports and model/server files. No reset, clean, stash, checkout-over-files, deletion of legacy files, commit, push, PR, or CI change occurred. [Preservation evidence](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/repository-preservation.json).

Read the four historical reports: rearchitecture plan, Stage 1, Stage 1A and Stage 1B. Useful lessons were embedded-Jinja formatting, Russian seller-chat errors, context leakage and exact value preservation. Their A15 performance, August pin and training proposal were not carried forward.

## Current upstream state

Official live API responses and source inspection were refreshed on October 7 Shanghai time. GitHub MCP was attempted but returned `USER_NOT_LOGGED_IN`; official public GitHub REST, official Hugging Face metadata and primary-source browsing provided the evidence. [Raw API snapshot](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/upstream.json).

- Latest observed [Hy-MT2 family](https://github.com/Tencent-Hunyuan/Hy-MT2): 1.8B, 7B and 30B-A3B, announced May 21, 2026. Current repository HEAD `ff1903ecaa724e10951a23c16817a2413c752b35`.
- [AngelSlim](https://github.com/Tencent/AngelSlim) HEAD `6c0e1957748023e69db701d421c49d1c2ee2f09c`. Its newer September Hy4 work does not establish a new Hy-MT release.
- Official standard [1.8B inventory](https://huggingface.co/api/models/tencent/Hy-MT2-1.8B-GGUF?blobs=true) and [7B inventory](https://huggingface.co/api/models/tencent/Hy-MT2-7B-GGUF?blobs=true) offer Q4_K_M, Q6_K and Q8_0. No standard Q2_K/Q3_K/Q5_K file appears in these inventories. “2Bit” is a separate format.
- 1.25-bit STQ [PR #22836](https://github.com/ggml-org/llama.cpp/pull/22836) and 2-bit [PR #19357](https://github.com/ggml-org/llama.cpp/pull/19357) remain open/unmerged. Their CPU NEON/SME2 paths do not provide the mature Metal path selected here. No STQ branch was integrated.
- Current stable [llama.cpp v0.6.0](https://github.com/ggml-org/llama.cpp/releases/tag/v0.6.0), published October 5, is pinned to the dereferenced release tag commit, not `master` or GitHub `target_commitish`. Newer b11445 is a prerelease.
- The A19/M5 Metal language-version fix [#27461](https://github.com/ggml-org/llama.cpp/pull/27461) is merged and included. Its still-open issue was not treated as an unfixed blocker. [STQ Metal exclusion #28067](https://github.com/ggml-org/llama.cpp/pull/28067) remains open.

## Model and short Mac decision

| Candidate | Official repository revision | Bytes | SHA256 |
|---|---|---:|---|
| 1.8B Q4_K_M | `tencent/Hy-MT2-1.8B-GGUF`, `a0c709d9fac510f2c807aa3af52872340dc37a4a` | 1,133,080,448 | `dc5f44fcf1fa496ee7ad725982c0c8c553a4de00259b53af84c4b89fb0c06699` |
| 1.8B Q6_K | same | 1,474,785,120 | `d98fe604dec1f28f58f80d7d560f7177e584d3b8e5835862687660e5ff97cb40` |
| **Selected 7B Q4_K_M** | `tencent/Hy-MT2-7B-GGUF`, `ab8472660ac61fac25f1af43fac2599d52a8a775` | **4,624,648,896** | `9f96256500f3fc1ab4d64336b58f52a949a95ad7516b0c229476eef782f9f77b` |

Selected filename: `Hy-MT2-7B-Q4_K_M.gguf`, about 4.31 GiB. Exactly one model is supported by the new app's pinned manifest; it is side-loaded as `Documents/model.gguf`, size/SHA verified on the device, and excluded from Git. [App model manifest](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator/ScreenTranslatorNext/model.json).

Ran the five requested hard cases in EN/RU with the official Chinese instruction and sampling. Q4 produced Russian “сфотографируйте видео … отправим вам его”; Q6 produced “снятите видео … вместо того, чтобы просто отправить обратно”. These are fresh failed outputs, not inherited August conclusions. Both initially used installed Homebrew llama.cpp 0.4.1; the discriminating seller reply was repeated on freshly built v0.6.0 and reproduced both failures.

7B was screened on freshly built v0.6.0 before app integration. It gave “снимите видео с неисправностью … отправим вам замену”, understandable packaging text and UI text. This was a quick sanity decision, not a scored reference evaluation or a giant bake-off. The customer request still loses the specificity of “parts” in Russian, and the English seller reply is ambiguous about the object being resent. [Raw Mac screens and comparison](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator/docs/benchmarks/oct2026_fresh_reboot.json), [v0.6.0 1.8B recheck](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/current-runtime-1.8b-recheck.json).

The app uses the model's own embedded **7B Jinja template**, which differs from 1.8B, no system prompt, full Chinese target names `英语`/`俄语`, temperature 0.7, top-p 0.6, top-k 20, repetition penalty 1.05 and seed 42. [Official inference guidance](https://github.com/Tencent-Hunyuan/Hy-MT2#inference-and-deployment). Generation is bounded to 512 output tokens and context 2048 for screenshot blocks; exhausting the limit is a visible failure. Stop is model EOG, with no string stop rules or semantic cleanup.

## New clean target

New independent project/scheme: [ScreenTranslatorNext.xcodeproj](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator/ScreenTranslatorNext/ScreenTranslatorNext.xcodeproj). Bundle `AlenShamatov.ScreenTranslatorNext`, team `XWSTFX7FZU`, iOS deployment 18.0, SwiftUI. It coexists with the old app and uses a distinct data container.

| File | Ownership |
|---|---|
| [ScreenTranslatorNextApp.swift](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator/ScreenTranslatorNext/ScreenTranslatorNextApp.swift) | PhotosPicker, EN/RU, Translate/Cancel, GGUF import, original/result preview, PNG share, diagnostics |
| [ScreenshotProcessor.swift](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator/ScreenTranslatorNext/ScreenshotProcessor.swift) | one actor owning native inference; streamed model validation; direct Vision and overlay pipeline |
| [TextBlocks.swift](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator/ScreenTranslatorNext/TextBlocks.swift) | block IDs/rectangles/observation ownership, geometric row joining, exact protected spans |
| [HyMTNative.mm](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator/ScreenTranslatorNext/HyMTNative.mm) and [header](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator/ScreenTranslatorNext/HyMTNative.h) | model/context/sampler/tokenizer/Jinja, one synchronous inference, atomic cancellation, unload, memory and Metal evidence |
| [DeviceBenchmark.swift](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator/ScreenTranslatorNext/DeviceBenchmark.swift) | four image cards × EN/RU, three consecutive repeats, per-case original/result/JSON |

Reused concepts from current code: accurate Vision top candidate; bottom-left-to-top-left coordinates; geometric fragment/row association; union rectangles; attributed-string fitting; native image composition; stable IDs and device diagnostics. No legacy source is shared or copied wholesale. The 885-line grouper, 730-line layout engine and Quick Look backend were replaced in this experiment with the compact direct path.

Normalize by physically redrawing the oriented UIImage once, rather than relabeling unrotated pixels. Translate only Chinese-containing groups. Numeric/Latin-only observations remain untouched. One block's generation maps back by its original ID, with observation IDs recorded. A compact span mechanism masks units, dimensions, prices and Latin identifiers, then requires each placeholder exactly once in order before restoration. It does not translate or repair semantics. Forty-three protected-span instances passed.

The renderer keeps panels anchored to source rectangles, fits word-wrapped text from at most 48 down to 18 pixels, uses opaque white panels, and exposes failures with red source outlines. JSON records every overlay rectangle. All final layouts were checked for intersections and all eight distinct EN/RU results visually inspected. Panels sometimes extend beyond the original bubble/card, and original styling is simplified; text remains readable and ownership recognizable.

## Runtime

Release `v0.6.0 / b11429`; commit **`d81235049384534c167caea52b85a694f6103d14`**. Source archive SHA256 **`6b58785f0a82898f4c3442417ff962e2d4b231b1bee5d033902ad90b27901e14`**, size 37,887,730 bytes. [Exact source](https://codeload.github.com/ggml-org/llama.cpp/tar.gz/d81235049384534c167caea52b85a694f6103d14).

[build.sh](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator/tools/runtime/build.sh) verifies the archive and every extracted source file, then uses the official `./build-xcframework.sh ios-device ios-sim` in its dedicated fresh source directory. Release runtime: Metal ON, embedded Metal library ON, Accelerate ON, OpenMP OFF, native host-specific instructions OFF. XCFramework has iOS ARM64 and simulator ARM64+x86_64 slices. The app and same-source Jinja sidecar target ARM64 only; Intel simulator execution is not supported by this experiment.

Official packaging excludes common/Jinja. A small static sidecar compiles seven same-revision upstream sources: five Jinja sources, `unicode.cpp`, `json.cpp`. The ObjC++ wrapper directly evaluates the embedded template, including upstream BOS/EOS de-duplication. No manually copied old static runtime is linked. Generated artifacts/symlinks live under ignored `Runtime/` and sibling `BuildArtifacts/oct2026/runtime`.

Device framework binary SHA256: `80f88972aa4f891212717e10b0a4e6067d5fd01a5e50ab01d9ea8b873459cab4`. [Full file and sidecar hashes/build manifest](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/runtime/manifest.json).

Model loading requests mmap and all GPU layers. Native state is actor-owned and blocks decode sequentially. Cancellation checks an atomic flag between native decode calls; it cannot interrupt an in-flight Metal operation. Samplers are freed after each generation; context is freed before model on unload; prefill/generation failures and invalid UTF-8 are surfaced. Current `llama_sampler_sample` already accepts the sampled token, so it is not accepted twice.

Actual phone proof: **Apple A19 Pro GPU**, `offloaded 33/33 layers to GPU`; 32 model layers reported by API. CPU-mapped model buffer 410.69 MiB, Metal-mapped model buffer 4,403.24 MiB, Metal KV cache 256 MiB. [On-device preparation evidence](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/prepare-final.json), [console](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/device-console-final.log).

## Physical device and startup

Physical product `iPhone18,2` / iPhone 17 Pro Max; UDID `00008150-001475EC2E98C01C`; iOS **26.5.1 / 23F81**, six CPU cores, Developer Mode enabled. App-reported physical memory **12,262,113,280 bytes**. Low Power Mode **false**. The phone was charging during visible captures; no system power setting was changed.

First successful process began nominal (`0`), ended fair (`1`), and completed all 11 cases. It recorded model/context load 5,832 ms and warmup 854 ms, after a 2,999 ms streamed SHA verification. The final corrected batch began already fair after the preceding batch, and moved to serious (`2`); it was not a cold thermal comparison. Final SHA verification 2,964 ms, cached model/context load 270 ms, warmup 549 ms. No separate per-stage CPU/GPU allocation peak or continuously sampled peak memory is claimed.

An initial launch terminated with signal 9 before inference. The original FileHandle/Data chunk loop was replaced by a reusable 4 MiB InputStream buffer, bounding input buffering and avoiding potential autorelease accumulation; verification subsequently completed at about 20 MiB footprint before loading. No matching app crash/jetsam reason was retrieved for that initial PID, so its OS termination cause is unclassified. A 00:57 system jetsam event showed background process cleanup, while ScreenTranslatorNext was active/frontmost with no kill reason. Neither successful 11-case process terminated, and the final run reported zero memory warnings. Raw diagnostic evidence is retained locally.

## E2E results

Final run `8910EA07-050C-4AD3-8615-B820EC4C63FF`, October 7 **01:03:45–01:07:35 Shanghai time**. Each row uses actual Vision output from the 1170×2532 synthetic input, not manually injected text. Translation time excludes preloaded startup. Full time includes normalization, OCR, grouping, translation and render, but excludes PNG export/report I/O.

| Card | Target | OCR observations | Chinese groups | OCR ms | Translation s | Render ms | Full s | Footprint / resident MiB | Generated tokens | Generation tok/s | Thermal |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| A product/UI | EN | 14 | 8 | 354.7 | 6.24 | 17.0 | 6.64 | 426.9 / 4921.1 | 50 | 8.09 | 1 → 1 |
| A product/UI | RU | 14 | 8 | 129.0 | 12.25 | 20.5 | 12.41 | 428.2 / 4923.9 | 117 | 9.61 | 1 → 1 |
| B dense commerce | EN | 23 | 18 | 280.4 | 18.01 | 9.3 | 18.31 | 431.8 / 4930.0 | 133 | 7.45 | 1 → 1 |
| B dense commerce | RU | 23 | 18 | 257.2 | 35.69 | 10.6 | 35.97 | 432.4 / 4930.9 | 314 | 8.84 | 1 → 2 |
| C seller chat | EN | 14 | 4 | 227.9 | 8.95 | 12.5 | 9.21 | 432.0 / 4931.8 | 74 | 8.30 | 2 → 2 |
| C seller chat | RU | 14 | 4 | 158.2 | 16.68 | 7.8 | 16.86 | 432.2 / 4932.1 | 151 | 9.07 | 2 → 2 |
| D paragraph/spec | EN | 16 | 7 | 279.2 | 22.27 | 16.3 | 22.58 | 436.6 / 4938.2 | 187 | 8.43 | 2 → 2 |
| D paragraph/spec | RU | 16 | 7 | 268.3 | 51.58 | 21.1 | 51.88 | 438.7 / 4940.4 | 458 | 8.89 | 2 → 2 |
| A consecutive 1 | RU | 14 | 8 | 199.3 | 16.66 | 12.4 | 16.88 | 438.4 / 4940.5 | 117 | 7.06 | 2 → 2 |
| A consecutive 2 | RU | 14 | 8 | 209.3 | 16.85 | 10.7 | 17.08 | 438.4 / 4940.5 | 117 | 6.98 | 2 → 2 |
| A consecutive 3 | RU | 14 | 8 | 209.1 | 17.11 | 17.3 | 17.35 | 438.4 / 4940.6 | 117 | 6.87 | 2 → 2 |

Errors on every final row: **zero** generation errors, placeholder errors, render-fit errors and overlay intersections. Generation throughput is summed output tokens divided by summed native generation time, including sampling and token decoding. Full screenshot latency is the useful product measurement.

App footprint and resident memory are distinct. Final screenshot endpoints were approximately 427–439 MiB footprint and 4,921–4,941 MiB resident; end-of-export footprint was 449.6 MiB. Read-only mmap/Metal model memory is not represented by footprint alone. The three consecutive RU rows plateaued around 438.4 MiB footprint and 4,940.5 MiB resident; this short test is not proof of long-run leak freedom.

| Output | Original | Final translated PNG | Raw OCR/mapping/report |
|---|---|---|---|
| A product/UI EN | [Original](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/00-A_product_ui-english-original.png) | [Result](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/00-A_product_ui-english-result.png) | [OCR, strings and timings](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/00-A_product_ui-english.json) |
| A product/UI RU | [Original](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/01-A_product_ui-russian-original.png) | [Result](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/01-A_product_ui-russian-result.png) | [OCR, strings and timings](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/01-A_product_ui-russian.json) |
| B dense commerce EN | [Original](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/02-B_dense_commerce-english-original.png) | [Result](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/02-B_dense_commerce-english-result.png) | [OCR, strings and timings](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/02-B_dense_commerce-english.json) |
| B dense commerce RU | [Original](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/03-B_dense_commerce-russian-original.png) | [Result](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/03-B_dense_commerce-russian-result.png) | [OCR, strings and timings](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/03-B_dense_commerce-russian.json) |
| C seller chat EN | [Original](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/04-C_seller_chat-english-original.png) | [Result](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/04-C_seller_chat-english-result.png) | [OCR, strings and timings](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/04-C_seller_chat-english.json) |
| C seller chat RU | [Original](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/05-C_seller_chat-russian-original.png) | [Result](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/05-C_seller_chat-russian-result.png) | [OCR, strings and timings](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/05-C_seller_chat-russian.json) |
| D paragraph/spec EN | [Original](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/06-D_packaging_spec-english-original.png) | [Result](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/06-D_packaging_spec-english-result.png) | [OCR, strings and timings](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/06-D_packaging_spec-english.json) |
| D paragraph/spec RU | [Original](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/07-D_packaging_spec-russian-original.png) | [Result](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/07-D_packaging_spec-russian-result.png) | [OCR, strings and timings](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/e2e-final/07-D_packaging_spec-russian.json) |

A: product/UI meanings are useful; RU stock text “Наличие в наличии” is awkward. Pure price remains unchanged. B: all 18 Chinese rows mapped independently; values remain exact as recognized, but Russian wording is sometimes literal. C: the final four messages retain video/replacement and address meaning; Russian maps “order model” to “order number” and the customer request omits “parts”. D: long packaging paragraphs remain coherent, international transport and protection details survive, and mixed values are preserved. The machine JSON contains every unmodified model output.

Vision recognized printed `260×80cm` as `260x80cm` on these images. Span protection preserves the **OCR input** exactly; it does not claim pixel-level OCR correctness or silently replace `x` with `×`.

The first full image run exposed a grouping defect: a short final OCR line was left separate. That made `灯不` / `亮` separate requests and caused chat panel overlap. Fixed the shared geometric rule to join an aligned nearby short last line following a wide line, concatenate adjacent Chinese wrap fragments, and added the actual phone OCR rectangles to the runnable check. Final C grouping changed **8 → 4**, with zero intersections. No semantic correction, conversation context or extra prompt was added.

## Code-size and reduction review

App: **4 Swift files + 1 Objective-C++ file + 1 header, 625 lines including comments/blank lines**. Across app and tooling there are 6 new Swift files (the other two are the card generator and check runner), 1 ObjC++ file and 1 header. Runtime/project/build metadata and scripts are additional, separate from app LOC.

Dedicated reduction pass retained only required ownership, measurement and image state. It avoided a ViewModel, DI/service locator, provider factory/enums, translator protocol, DTO layers, context system, fallback routes and configurable classifier. The Jinja C malloc/free wrapper and copied libraries were avoided by a direct upstream call. Task.detached wrappers and unsafe preview force-unwrapping were removed. Header types were tightened to ordinary Swift dictionaries. Generated artifacts and Python bytecode are ignored.

No old production code was removed. Changes made after device evidence were the grouping root-cause fix, opaque panels, recorded overlay rectangles, bounded hashing and cancellation propagation in the development batch. They reuse the same pipeline; there is no benchmark-only translator.

[Runnable checks](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator/tools/runtime/checks.swift) passed separated-label handling, source observation ownership, actual wrapped chat OCR, CJK filtering, exact technical spans and malformed/extra placeholder rejection. The signed physical Release build and ARM64 simulator Release build both succeeded. The only final build warning was skipped AppIntents metadata extraction because this app has no AppIntents dependency. PhotosPicker/import/ShareLink are standard native flows; their individual interactive operations were not all exercised manually on the phone. Physical image execution used the development batch entry point through the same processor.

Scoped manual ownership/path/network review found local fixed model paths, SHA-before-load/import, context-before-model freeing, bounded generation, sampler freeing, and no app translation network code, embedded secret, Apple Translation fallback, dictionary, regex semantic repair or Quick Look dependency. This is not a repository-wide security audit.

## Reproduce

From the nested repository:

```bash
bash tools/runtime/build.sh
python3 tools/runtime/fetch_model.py
swiftc ScreenTranslatorNext/TextBlocks.swift tools/runtime/checks.swift -o /tmp/screen-translator-next-checks
/tmp/screen-translator-next-checks
bash tools/runtime/install.sh 00008150-001475EC2E98C01C ../BuildArtifacts/oct2026/models/Hy-MT2-7B-Q4_K_M.gguf --benchmark
```

[install.sh](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator/tools/runtime/install.sh) builds/signs the separate app, verifies and copies the pinned model, generates/copies the four cards and launches the batch. [make_cards.swift](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator/tools/runtime/make_cards.swift) has no hard-coded translations. Model/download/build happen on the Mac; **OCR and every translation happen locally on the phone**, with no Mac translation server or HTTP backend.

To retrieve evidence:

```bash
xcrun devicectl device copy from --device 00008150-001475EC2E98C01C --domain-type appDataContainer --domain-identifier AlenShamatov.ScreenTranslatorNext --source Documents/RebootReports --destination ../BuildArtifacts/oct2026/exported-reports
```

Full [machine-readable report](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator/docs/benchmarks/oct2026_fresh_reboot.json) includes the runtime/model pins, source/output hashes, all strings, native generation timings, previous/current Git evidence and validation checks.

## Verdict

**GO WITH PERFORMANCE WORK.** The chosen Hy-MT2-7B Metal configuration produces a useful local experimental screenshot translator on iPhone 17 Pro Max for the user-requested image cards. It now reaches the final image and preserves mapping. It is not ready to replace the production app: RU dense/paragraph cases take 36–52 seconds; the same RU product card grows from 12.41 to 17.35 seconds after sustained work (about 40%); thermal state reaches serious. Quality also retains the specific untranslated-meaning/awkward-wording issues listed above. Authentic app screenshot behavior remains untested.

## Exact next major action

**Profile sustained 7B Metal inference on this iPhone to reduce translation latency and thermal throttling while preserving model quality.** This next stage has not started. No LoRA, STQ work, model-family switch or legacy migration was begun.
