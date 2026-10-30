# ScreenTranslator 2026 Re-architecture Plan

**Audit date:** 2026-08-20  
**Repository:** `/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator`  
**Scope:** forensic audit and migration plan only. No production code was changed and no migration work was implemented.

## A. Executive Summary

ScreenTranslator already has a credible screenshot-processing foundation: it accepts screenshots from the app or Shortcuts, normalizes them, runs accurate Apple Vision OCR, groups observations into logical text blocks, and renders translated text back onto the image. Those parts are real, buildable, and mostly worth keeping.

Translation is not in the same state. There are currently three overlapping implementations:

1. The foreground app uses Apple's on-device `Translation` framework, hard-coded to Simplified Chinese to Russian.
2. Quick Look uses a development-only LAN request to a Mac FastAPI server running HY-MT1.5 Q4_K_M. It also carries large dictionary, CEDICT, prioritization, diagnostics, rendering, and fallback implementations accumulated during earlier experiments.
3. An uncommitted local llama.cpp harness can load an arbitrary side-loaded GGUF, keep one native session alive, generate text, and export benchmark reports. It is CPU-only, uses a generic prompt instead of the model's embedded chat template, and contains extensive cleanup patches added to compensate for a small unidentified test model. The repository contains no durable evidence that Hy-MT itself ran successfully on an iPhone.

The final product should converge to one path:

```text
Screenshot input
  -> existing image normalization
  -> existing Vision OCR
  -> one unified layout/grouping pass
  -> adaptive translation block preparation
  -> one actor-owned Hy-MT2/llama.cpp engine
  -> stable-ID result mapping
  -> existing production overlay renderer
  -> PNG/result view
```

The recommended first model is Tencent **Hy-MT2-1.8B Q4_K_M**, not the smaller experimental formats. Q4_K_M is approximately 1.13 GB, is supported by current mainline llama.cpp, and can use Metal. Tencent's 1.25-bit STQ model is an important secondary candidate because it is approximately 462 MB, but as of this audit it requires open llama.cpp PR #22836, has an ARM NEON CPU kernel only, and has no Metal path. The 2-bit Q2_0c release depends on a different draft PR and SME2-oriented kernels; current mainline Q2_0 support does not make that Q2_0c file compatible.

The next implementation must begin with a small, isolated, real-iPhone proof. It must compare English and Russian quality, cold/warm memory, and screenshot-sized latency before any production path is replaced. If Q4 cannot meet the memory gate, test the pinned STQ branch next. Do not retain the remote server, dictionaries, Apple translation, and experimental runtime as permanent fallbacks.

## B. Current Git State

### Repository identity

| Item | Observed value |
|---|---|
| Path | `/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator` |
| Branch | `main` |
| HEAD | `19d01e24aadd45847b277c2626308927a4cc3638` |
| Tracking | `origin/main` |
| Origin | `https://github.com/alenti/ScreenTranslator.git` |

### Working tree

The working tree is **substantially dirty**. The current tree, rather than `HEAD`, contains the Hy-MT server changes and local llama experiment evaluated in this report.

Tracked modifications include:

- `Features/Settings/SettingsView.swift`
- the Quick Look diagnostics, local-MT client/config/provider, block preparer, OCR mapper, and English provider
- `ScreenTranslator.xcodeproj/project.pbxproj`
- the OPUS/Hy-MT server README, Python implementation, requirements, CLI, and tracked OPUS model binary

Important untracked work includes:

- `Config/OnDeviceLlamaBridge.xcconfig`
- `Core/Services/OnDeviceMT/`
- `Features/OnDeviceMT/`
- `LocalLlama/`
- `LocalModels/`
- `ScreenTranslator-Bridging-Header.h`
- `tools/on_device_llama/`
- the Hy-MT server provider files
- all pre-existing files in `docs/`

These are user changes and must be preserved. The first implementation stage must stop if the owner has not checkpointed or otherwise intentionally preserved this state. This audit did not reset, commit, push, branch, or delete it.

### Relevant history

The repository has only five visible commits:

| Commit | Meaning reconstructed from diff/history |
|---|---|
| `19d01e2` | Git LFS configuration for `.bin` files |
| `d25928f` | OPUS Chinese-to-English Mac server and client path |
| `7b1ebd8` | Quick Look return flow, OCR diagnostics, dictionary/CEDICT work |
| `e1ac052` | Main app architecture: input, OCR, grouping, Apple translation, overlay |
| `8805113` | Initial project |

The committed baseline ends at the OPUS server. The Hy-MT1.5 server conversion and on-device llama.cpp work are uncommitted experiments.

### Project/build state observed during the audit

- One app target, one unit-test target, and one UI-test target; schemes are `ScreenTranslator`, `ScreenTranslatorTests`, and `ScreenTranslatorUITests`.
- No Swift Package dependency or `Package.resolved` exists.
- App deployment target is iOS 18.0; test targets use 18.5. Swift is version 5 and Objective-C++ is compiled as C++20.
- The Debug app configuration includes local llama headers/static libraries and `SCREENTRANSLATOR_LLAMA_CPP_ENABLED=1`. Release compiles the bridge without those local libraries or the enable define.
- No effective app entitlements are configured. `Info.plist` permits local networking and arbitrary local-network loads and declares a local-network usage string; those permissions exist for the Mac backend.
- `xcodebuild build`, Release, generic iOS Simulator: **succeeded**, with four unused-function/variable warnings in the disabled native bridge and missing modern iPad icon warnings.
- The `ScreenTranslator` test scheme: **succeeded** with three unique UI tests and six executions (the launch test ran four times). Xcode repeatedly logged an LLDB-version error and one cloned test runner launch failure, but another clone completed the tests.
- The `ScreenTranslatorTests` scheme: **failed before building tests** because `TEST_HOST` points to `ScreenTranslator.app/ScreenTranslator`, while the actual product is `ChinaTap Screen Translator.app/ChinaTap Screen Translator`. Therefore the existing unit tests were not executed by the current scheme.
- `tools/dictionaries/test_quicklook_lookup_pipeline.py`: **failed** at line 604 with `NameError: name 'sys' is not defined`. It is a script-style harness, not a discovered unittest suite.
- No physical-device test was run in this audit.

## C. Current Architecture

### C.1 Entry points and input

`ScreenTranslatorApp.swift` creates `AppEnvironment`, installs `AppServices.live()`, and hosts an invisible Apple `TranslationSession` task. `AppCoordinator` consumes pending intent handoffs when the app becomes active.

There are seven advertised App Intents:

| Intent | File | Current behavior |
|---|---|---|
| `TranslateScreenshotIntent` | `Intents/TranslateScreenshotIntent.swift` | Copies the input file, stores the screenshot in Application Support, opens the app, runs the foreground pipeline. |
| `FloatingScreenTranslateIntent` | same | Same handoff with a floating-result route; opens the app. |
| `QuickLookTranslateScreenshotIntent` | same | Runs OCR, translation, and PNG rendering inside `perform()` without opening the app. |
| `QuickLookDebugOCRIntent` | `Intents/QuickLookDebugOCRIntent.swift` | Returns OCR diagnostics as a PNG. |
| `QuickLookEchoScreenshotIntent` | `Intents/QuickLookEchoScreenshotIntent.swift` | Debug return-path probe. |
| `QuickLookDirectEchoScreenshotIntent` | `Intents/QuickLookDirectEchoScreenshotIntent.swift` | Debug data-return probe. |
| `QuickLookTinyPNGIntent` | `Intents/QuickLookTinyPNGIntent.swift` | Debug minimal-PNG probe. |

`IntentInputDecoder` reads and deep-copies the `IntentFile` bytes before the system invalidates the input URL. `TemporaryImageStore` writes a JSON-encoded handoff in Application Support. This handoff is a useful, simple boundary and should remain.

### C.2 Foreground app pipeline

`AppServices.live()` currently wires:

```text
ScreenshotNormalizer
  -> VisionOCRService
  -> TextGroupingService(BoundingBoxGrouper + TextBlockComposer)
  -> OnDeviceTranslationService (Apple Translation)
  -> OverlayRenderer
  -> ProcessingOrchestrator
```

`ProcessingOrchestrator` executes the stages in order and publishes a `ProcessingState`. A renderer failure can produce a placeholder result, so a rendering problem is not always surfaced as a hard pipeline failure.

### C.3 OCR

The OCR implementation is in `Core/Services/OCR/`:

- `OCRRequestFactory` creates `VNRecognizeTextRequest` with `.accurate` recognition.
- Recognition languages are `zh-Hans` and `zh-Hant`.
- Language correction is disabled and `minimumTextHeight` is zero.
- `VisionOCRService` uses only the top candidate per observation.
- There is no application confidence threshold in the main OCR path.
- Vision's normalized bottom-left rectangles are projected to top-left pixel coordinates.
- Observations are sorted by vertical position and then x position, using a row tolerance of `max(1.2% of image height, 8 px)`.
- `ScreenshotNormalizer` and `ImageOrientationResolver` standardize orientation and pixel dimensions; there is no contrast, sharpening, thresholding, or other OCR image enhancement.

The Quick Look path runs the same Vision request but then applies its own CJK/substance/confidence filters before translation.

### C.4 Text grouping

There are two different grouping systems.

The main `BoundingBoxGrouper` and `TextBlockComposer`:

- form rows from vertical overlap and center-distance checks;
- merge neighbors using horizontal-gap thresholds adjusted for CJK, Latin, and mixed script;
- avoid joining isolated short UI labels too aggressively;
- then merge compatible rows into paragraphs/blocks using alignment, column, compact-UI, and vertical-gap rules;
- reconstruct text without spaces between CJK/punctuation, with gap-based spaces for Latin, and newlines between rows;
- assign the union rectangle as the final `TextBlock.frame`.

This is geometry-aware and tested, but it does not assign semantic block types.

`QuickLookTextBlockGrouper` is a second heuristic implementation. It assigns `chatBubble`, `paragraph`, `uiLabel`, `button`, `productCard`, `addressBlock`, or `unknown` using geometry and keywords. These labels then affect priority, layout, and token limits. It is not true visual bubble/card detection and it duplicates the main grouping responsibility.

### C.5 Translation paths

#### Foreground Apple Translation

`OnDeviceTranslationService`, `TranslationBatchBuilder`, `TranslationLanguageManager`, and `TranslationSessionBroker` use Apple's `Translation` framework.

- Pair is hard-coded to `zh-Hans -> ru` in `TranslationSessionBroker`.
- Each `TextBlock` becomes one request with a stable UUID client identifier.
- All requests are submitted in one `session.translations(from:)` call.
- Results are mapped by client ID, with source-text/order fallbacks.
- Translation timeout is 20 seconds; language-pack preparation timeout is 180 seconds.
- Unsupported/missing-pack errors are mapped to app errors.
- There is no English production path.

#### Quick Look remote Hy-MT

`QuickLookLocalMTConfig` enables `.remoteHyMT` in both Debug and Release and contains a hard-coded development URL, `http://192.168.1.54:8766`.

`QuickLookLocalMTClient` calls:

- `GET /health` with a 1.25-second health timeout;
- `POST /translateBlocks` for Chinese-to-English translation;
- 8-second request timeout and up to 14 seconds of active full-coverage budget.

`QuickLookLocalMTTranslationProvider` processes blocks sequentially with `requestBatchSize = 1`. It retains partial results, fails fast on connection failures, and has no general retry policy.

The server in `tools/opus_mt_server/server.py` now exposes the matching FastAPI endpoints. `hymt_engine.py` loads the local HY-MT1.5 Q4_K_M GGUF through `llama-cpp-python`, serializes calls with one lock, and retries once by reloading after `llama_decode returned`. Its prompt is hand-written rather than built from the GGUF chat template. The old CTranslate2 OPUS implementation and model remain, but selecting the OPUS provider now returns a development error.

#### Quick Look dictionary path

`QuickLookEnglishTranslationProvider.swift` contains approximately 1,100 lines of phrase overrides, OCR corrections, numeric/product patterns, and CEDICT fallbacks. `QuickLookLocalDictionaryTranslationProvider.swift` contains approximately 900 lines of hard-coded Chinese-to-Russian rules. `QuickLookCEDICTStore` opens the bundled SQLite file read-only and performs exact or segmented lookups up to eight characters.

`useDomainDictionaryRuntime` is currently false, so dictionary output is not the active final rendering path. The code remains intertwined with routing and diagnostics.

#### Experimental on-device path

Debug builds expose `.onDeviceExperimental`. `QuickLookLocalMTTranslationProvider` calls `OnDeviceLlamaSmokeTestService`, which loads `Documents/tiny-test.gguf`, applies category-specific prompt profiles and token caps, performs deadline-aware per-block generation, validates output, and may retry. This is not the default Quick Look path.

### C.6 Result mapping and rendering

The main renderer is split into `OverlayLayoutEngine`, `OverlayTextFitter`, `OverlayImageComposer`, and `OverlayRenderer`:

- maps `TranslationBlock.sourceBlockID` back to `TextBlock.frame`;
- proposes card dimensions near the source geometry;
- fits system semibold text from 22 pt down to 12 pt;
- moves/resizes cards to resolve collisions;
- draws black rounded cards with white text over the original image;
- returns a PNG-backed `OverlayRenderResult`.

The Quick Look path duplicates this in `QuickLookOCRBlockMapper` and the approximately 1,900-line `QuickLookOverlayRenderer`. It chooses among dictionary pills, local-MT replacements, short bubbles, and paragraph cards, runs its own collision/truncation logic, and returns a data-backed PNG through `QuickLookIntentFileFactory`. Error and timeout paths may return a generated fallback PNG instead of a translation.

### C.7 Local llama.cpp implementation

The local experiment is technically substantive:

- `OnDeviceLlamaBridge.h/.mm` wraps the llama C API in Objective-C++.
- `OnDeviceLlamaNativeRuntime.swift` bridges the native methods to Swift async calls.
- `OnDeviceLlamaSmokeTestService.swift` supplies prompts, validation, cleanup, smoke cases, session operations, and Quick Look integration.
- `OnDeviceMTDebugViewModel.swift` imports a model, runs single/all/profile benchmarks, records runtime metadata, and exports JSON and Markdown.
- `OnDeviceMTDebugView.swift` is the manual test UI.

The bridge owns one global persistent model/context/sampler protected by a mutex. Backend initialization occurs once. It can load, generate, report resident memory, query status, and unload. Generation clears the context and sampler, tokenizes the entire prompt, performs token-by-token decode, and stops on EOG or case-insensitive string matches. There is no prefix/KV reuse between blocks and no parallel generation.

Current native settings are `n_ctx = 512`, `n_batch = 512`, greedy sampling, `n_gpu_layers = 0`, and no explicit thread count. The local build script disables Metal, Accelerate, and OpenMP. The stored llama.cpp revision is `45b455e66fc09abed65b7d52d42a4a29ba0d45d6` (2026-05-18). Separate device/simulator static libraries and copied public headers are stored under `LocalLlama/`.

The implementation does **not** apply the GGUF Jinja chat template, measure TTFT or token throughput directly, react to memory warnings, or provide a production model manager. `OnDeviceLlamaSmokeTestService` compensates with multiple custom prompt profiles, section stripping, prompt-residue removal, quote/list cleanup, first-line selection, duplicate removal, CJK-ratio checks, and known Chinese-fragment patches.

## D. What We Previously Built

### Working production-like functionality

- Screenshot handoff from Shortcuts to the foreground app.
- Image normalization and Vision OCR.
- Geometry-based grouping and block composition.
- Chinese-to-Russian foreground translation through Apple's local language pack.
- Main overlay layout, text fitting, image composition, and result UI.
- Quick Look data-backed PNG return path.

### Successful experiments

- The committed OPUS Mac server/client path established that a Shortcut could send OCR text over the LAN and receive block results.
- The current Hy-MT1.5 Q4 server implementation is consistent end to end and its README reports successful Q4 operation. There is no checked-in raw benchmark artifact, so exact quality and speed are not independently reproducible from the repository alone.
- The native bridge compiles, links in Debug, implements real llama.cpp calls, retains a session, and exposes model/memory/report tooling. This is more than a conceptual spike.

### Failed or unproven experiments

- The HY-MT1.5 1.25-bit model failed in the Mac server with `invalid ggml type 42`; the old llama.cpp runtime did not support its quantization.
- The local iPhone experiment used whatever file was imported as `Documents/tiny-test.gguf`. `LocalModels/README.md` explicitly permits an arbitrary small test model, while phase documents refer inconsistently to approximately 498 MB and 522 MB. No model repository revision, SHA-256, raw result file, device identity, or measured run is checked in. **Hy-MT-on-iPhone is therefore not verified.**
- No real-device result proves current cold load, RSS, peak memory, TTFT, tokens/second, 10/30-block latency, or App Intent completion.
- The unit-test scheme is presently unable to locate its host, so source-level grouping/renderer tests are not currently runnable through that scheme.

### Temporary hacks

- Hard-coded LAN IP, full-coverage flags, per-category deadlines, and batch size one.
- Large dictionary and phrase-correction tables.
- Multiple local-model prompt profiles and string stop sequences.
- CJK output substitutions and extensive cleanup of prompt leakage/explanations.
- Duplicate grouping, mapping, rendering, diagnostics, and translation abstractions in the Quick Look path.
- Seven App Intents, four of which are return-path/debug probes.

### Dead or obsolete code

- The OPUS provider/model remains after the server changed to Hy-MT.
- The Chinese-to-Russian Quick Look dictionary is not part of the active English route.
- Dictionary routing remains even though `useDomainDictionaryRuntime = false`.
- Old phase documents describe incremental experiments, not a current production plan.
- The copied static llama libraries and headers are a build artifact, not an appropriate reproducible dependency mechanism.

## E. Current Local-Inference Status

What is confirmed today:

1. The current dirty tree compiles for Debug and Release simulators.
2. The Objective-C++ wrapper implements real llama.cpp model/context/sampler operations.
3. One serialized model session can remain loaded within one app process.
4. A Debug UI can side-load a GGUF and produce/share JSON and Markdown reports at runtime.
5. The Mac Hy-MT1.5 Q4 path has a complete server/client implementation.

What is not confirmed:

1. No repository artifact proves that a Hy-MT model was loaded on an iPhone.
2. No physical-device benchmark results are retained.
3. The current local libraries explicitly disable Metal and Accelerate.
4. The pinned May llama.cpp revision predates the current Hy-MT2 and mainline Q2_0 work.
5. The generic raw prompt and string-stop approach does not follow Hy-MT2's embedded chat template.
6. There is no production lifecycle, model download, checksum, storage-space, memory-pressure, or failure-recovery implementation.
7. Process warmth and the persistent session cannot be assumed across App Intent invocations.

The correct conclusion is: **the repository proves a useful native runtime harness, not a production on-device Hy-MT engine.**

## F. August 2026 External Research

### F.1 Hy-MT family and model releases

[Tencent's official Hy-MT2 model card](https://huggingface.co/tencent/Hy-MT2-1.8B) records:

- HY-MT1.5 release: 2025-12-30.
- Hy-MT2 release: 2026-05-21.
- Hy-MT2 sizes: 1.8B dense, 7B dense, and 30B-A3B MoE.
- Chinese, English, and Russian are explicitly supported. The page summary says 36 languages; the prose says 33. This discrepancy does not affect the required pair.
- Hy-MT2-1.8B is `HunYuanDenseV1ForCausalLM`: 2,038,515,712 parameters, 32 layers, hidden size 2,048, 16 attention heads, 4 KV heads, vocabulary 120,818, BF16 source weights approximately 4.08 GB.
- The official prompt uses full language names and requests only the translation. The tokenizer's embedded Jinja chat template must wrap that user message; the model has no default system prompt.
- Tencent's published 1.8B/7B sampling baseline is temperature 0.7, top-p 0.6, top-k 20, repetition penalty 1.05. Its 4,096 output-token ceiling is a general maximum, not an appropriate screenshot default.

Hy-MT2 is the relevant current family. Hy-MT1.5 remains useful historical evidence but should not anchor a new implementation.

The serious mobile candidates compare as follows:

| Family/artifact | Languages and quality evidence | Runtime/iOS implications | RAM and distribution conclusion |
|---|---|---|---|
| [HY-MT1.5-1.8B](https://huggingface.co/tencent/HY-MT1.5-1.8B), released 2025-12-30 | Same 1.8B dense family generation, includes Chinese/English/Russian; the repository's Q4 server is the only local project evidence. Hy-MT2 supersedes it in Tencent's current published evaluation. | Ordinary Q4 runs in llama.cpp; the old 1.25-bit file failed in this repository. | The local Q4 is approximately 1.1 GB plus runtime allocations. It uses the restrictive [Tencent HY Community License](https://huggingface.co/tencent/HY-MT1.5-1.8B/blob/main/License.txt), not Apache-2.0. Do not select it for a new product. |
| Hy-MT2-1.8B Q4_K_M | Current official 1.8B model; all required languages; least aggressive practical mobile quantization and therefore the strongest shipping-quality candidate. Project quality is not yet measured. | Current llama.cpp CPU/Metal and embedded chat template; official iOS XCFramework path. | At least 1.13 GB of mapped weights plus KV, compute buffers, and backend allocations. The Section L 1.8/2.2 GB gates are deliberately provisional. Apache-2.0. |
| Hy-MT2-1.8B STQ 1.25-bit | Same base model/languages/template; Tencent reports strong compression, but this project has no EN/RU quality evidence for the quantization. | Open custom llama.cpp branch; ARM NEON CPU only; no Metal; real iPhone unverified. | 462 MB weights plus CPU/KV/compute allocations. A lower file size should reduce storage and likely working-set pressure, but no defensible iPhone peak-RAM figure exists yet. Apache-2.0. |
| Hy-MT2-1.8B Q2_0c 2-bit | Same base model/languages/template; no project quality evidence. | Draft custom branch with SME2-oriented kernels, no demonstrated iPhone/Metal path. | 601 MB weights plus runtime allocations. Not integration-ready even though it is larger than STQ and smaller than Q4. Apache-2.0 on the published repository. |

Hy-MT2 7B and 30B-A3B are not serious iPhone candidates for this product: their parameter/storage/working-set cost is unnecessary for short screenshot blocks, and no official iOS low-bit path outweighs the 1.8B option.

### F.2 Official GGUF choices

The model metadata below was verified against the Hugging Face API on the audit date.

| Candidate | Repository revision | File size | SHA-256 | Runtime status |
|---|---|---:|---|---|
| [Q4_K_M](https://huggingface.co/tencent/Hy-MT2-1.8B-GGUF) | `1cd5208700acedef4ef93019b6cfc148b8522d45` | 1,133,080,448 B | `dc5f44fcf1fa496ee7ad725982c0c8c553a4de00259b53af84c4b89fb0c06699` | Current mainline llama.cpp; CPU and Metal. |
| Q6_K | same | 1,474,785,120 B | `d98fe604dec1f28f58f80d7d560f7177e584d3b8e5835862687660e5ff97cb40` | Current mainline; larger reference option. |
| Q8_0 | same | 1,908,528,192 B | `5c3fe0b1408a5ceb0143184ef247b11b579c525f4b02b060e6c851bb76fef1a4` | Current mainline; reference-quality GGUF. |
| [1.25-bit STQ](https://huggingface.co/tencent/Hy-MT2-1.8B-1.25Bit-GGUF) | `9df5c824a00a744fb0512a29c640466f4d97dfb0` | 461,860,800 B | `cc497fe8f033b52b3b8b00a7669e9661435432f9d4cd43f7ed24400c01507a93` | Requires open PR #22836; CPU/NEON, `-ngl 0`; no Metal. |
| [2-bit Q2_0c](https://huggingface.co/AngelSlim/Hy-MT2-1.8B-2Bit-GGUF) | `2245b9ea2bdd68a67b21b44db9564e7d32fc3bc6` | 600,534,880 B for the original file | `dcc33bbae9b28d923c8c76a64f6157840841d26f8774f3dfd770d5fabeeb1cd7` | Requires draft PR #19357; SME2-oriented; no demonstrated iPhone path. |

Tencent's [AngelSlim](https://github.com/Tencent/AngelSlim) is the compression toolkit and publication home for the extreme low-bit work; it is not a separate proven iOS runtime.

### F.3 STQ/STQ1_0 findings

1. **Merged?** No. [llama.cpp PR #22836](https://github.com/ggml-org/llama.cpp/pull/22836) remains open.
2. **Required branch/revision?** The canonical head on 2026-08-20 is `sjl623:STQ_0` at `1e411d8f5a1e23525fa3265dfb4bd76265465397`.
3. **Obsolete?** No successor has replaced it; the official Tencent 1.25-bit card still links that PR.
4. **Updated Tencent runtime?** No separate Tencent iOS runtime was found. The official path still instructs users to build the PR and run CPU-only with `-ngl 0 --jinja`.
5. **Metal?** No STQ Metal kernel exists in that PR.
6. **iPhone ARM64 CPU?** The PR has an ARM NEON `vec_dot` kernel, so the instruction set path is plausible on iPhone ARM64. A compatible build and actual performance remain **unverified on iPhone**.
7. **SME/SME2?** Not required by STQ. SME2 belongs to the separate Q2_0c work. Apple does not publish a dependable app-facing guarantee that the required SME2 path is available on the supported shipping-iPhone range, so it cannot be an architecture assumption.
8. **Best choice?** Not initially. It minimizes storage but loses Metal and relies on an unmerged branch. Upstream discussion also shows that its decode gains do not guarantee faster prefill; mature Q4 matrix kernels can be faster on some ARM devices.
9. **Is 2-bit easier/faster?** No. The official 2-bit model depends on draft [PR #19357](https://github.com/ggml-org/llama.cpp/pull/19357), head `2af64dd00a6689a7bfaf69b4768a944d0ec6bade`, for Q2_0c and SME2 kernels. It is a higher integration risk than STQ for iPhone.
10. **Newer quantization?** Mainline llama.cpp merged standard Q2_0 CPU support in [PR #24448](https://github.com/ggml-org/llama.cpp/pull/24448), merge `bec4772f6a2527d371557b5d2032641e5ff7619c`, and Metal support in [PR #25419](https://github.com/ggml-org/llama.cpp/pull/25419), merge `14d3ba45f3369e75a308212399cfada5d349883b`. That standard Q2_0 layout is not Tencent's Q2_0c layout and does not make the official 600 MB file loadable. A future official standard-Q2_0 Hy-MT2 conversion could become attractive, but it is not today's supported artifact.

### F.4 llama.cpp on iOS

The locally copied runtime is pinned to `45b455e...`. Current upstream `master` was `b062ba735e5e15817f6a1dbdb84717ee3097f619` during this audit.

The clean integration is a **pinned XCFramework built from the upstream script**, not committed headers/static archives and not vendored source. The official [`build-xcframework.sh`](https://github.com/ggml-org/llama.cpp/blob/master/build-xcframework.sh) builds iOS device and simulator slices, enables Metal, and embeds the Metal library. The official [`llama.swiftui` example](https://github.com/ggml-org/llama.cpp/tree/master/examples/llama.swiftui) demonstrates adding that XCFramework to an iOS app.

Recommendation:

- pin one exact upstream commit in a small build manifest/script;
- build `llama.xcframework` outside Git and make it a reproducible local/CI artifact;
- keep only the narrow C API surface required by the app;
- retain a thin Objective-C++ bridge if it materially simplifies error conversion and Swift interop;
- have one Swift actor own model/context/sampler and every C call;
- use Metal for Q4 and keep one context; no custom backend abstraction is required.

A remote binary package is not justified until release/build automation exists. A source Swift Package would substantially increase Xcode build time and does not remove the need to pin native flags and Metal assets. Manually copied static libraries recreate the current reproducibility problem.

### F.5 Other runtimes

- [MLC LLM](https://github.com/mlc-ai/mlc-llm/blob/main/docs/deploy/ios.rst) has a real iOS Swift SDK and Metal-oriented deployment, but Hy-MT2 would need a new conversion/model definition/template and it does not support Tencent's published STQ or Q2_0c formats.
- [ExecuTorch](https://docs.pytorch.org/executorch/stable/llm/getting-started.html) has mobile LLM and Apple integration, but no official Hy-MT2 export/quantization path was found.
- [Core ML Tools](https://apple.github.io/coremltools/docs-guides/source/target-conversion-formats.html) provides general conversion, not a supported Hy-MT2 causal-LM package or the required low-bit kernels.
- [MLX Swift](https://github.com/ml-explore/mlx-swift) is a viable Apple-platform library, but there is no official Hy-MT2/AngelSlim mobile artifact and adopting it would add conversion/runtime work without measured benefit.

There is no strong current evidence to leave llama.cpp.

### F.6 App Intents and model storage

An Apple App Intents engineer states that `perform()` receives [30 seconds of CPU runtime](https://developer.apple.com/forums/thread/832170). That is an execution budget, not an app SLA. Process reuse, a retained model, and a warm context are not guaranteed. A cold 1.13 GB model load plus OCR, generation for many blocks, rendering, and PNG serialization is therefore a high-risk background Quick Look design.

Apple now provides `LongRunningIntent`, but relying on a newly introduced API would require an availability/deployment decision and still would not solve memory or user-experience problems for iOS 18 users. It should not be used to justify the current background architecture.

For model delivery, [Managed/Apple-hosted Background Assets](https://developer.apple.com/documentation/backgroundassets/downloading-apple-hosted-asset-packs) is attractive for ML models, independent updates, and large asset packs, but managed asset packs require apps targeting iOS 26 or later. This project targets iOS 18.0. [On-Demand Resources are deprecated beginning with iOS 27](https://developer.apple.com/help/app-store-connect/reference/app-uploads/on-demand-resources-size-limits/), so a new design should not adopt ODR.

The production storage choice for the current deployment floor is therefore: download one versioned model after installation using a background `URLSession`, validate it, and atomically install it in Application Support. Revisit Apple-hosted Background Assets only if the minimum deployment target becomes iOS 26+.

### F.7 Privacy and licensing

- Today, foreground Apple Translation stays on device, but Quick Look sends OCR text over the local network to a Mac. Removing that backend makes the translation path local and allows removal of the local-network usage string and arbitrary local-network transport allowance, after verifying no other feature needs them.
- Hy-MT2 base and official GGUF repositories identify the license as Apache-2.0 and include an official [`LICENSE.txt`](https://huggingface.co/tencent/Hy-MT2-1.8B/blob/main/LICENSE.txt). This is materially different from the older HY-MT1.5 custom community license. Retain the Apache license/NOTICE obligations and have distribution counsel review App Store/model-hosting use; this report is not legal advice.
- llama.cpp uses the [MIT license](https://github.com/ggml-org/llama.cpp/blob/master/LICENSE); retain its notice.
- The [CC-CEDICT download page](https://www.mdbg.net/chinese/dictionary?page=cedict) currently identifies CC BY-SA 4.0, while older CC-CEDICT pages have referenced 3.0. The derived SQLite file has no checked-in source date, transformation manifest, or reliable notice chain. Preserve notices until it is deleted and do not ship it without provenance review.
- A downloaded GGUF must have an explicit model revision, SHA-256, license copy, and download origin. Do not commit it to Git or Git LFS.

## G. Model Decision

```text
Recommended model:                 Tencent Hy-MT2-1.8B
Recommended quantization:          Q4_K_M
Recommended runtime:               llama.cpp XCFramework with Metal
Recommended pinned upstream:       b062ba735e5e15817f6a1dbdb84717ee3097f619
Recommended model revision:        1cd5208700acedef4ef93019b6cfc148b8522d45
Recommended model SHA-256:          dc5f44fcf1fa496ee7ad725982c0c8c553a4de00259b53af84c4b89fb0c06699
Recommended prompt/template:        GGUF embedded Jinja chat template; one user message; no system prompt
Recommended EN instruction target:  English
Recommended RU instruction target:  Russian
```

The pinned runtime is an audit-date starting point, not permission to track `master`. Stage 1 must record that exact source, build options, XCFramework checksum, and any pin change.

Use the official user instruction verbatim in English:

```text
Translate the following text into {full target language name}. Note that you should only output the translated result without any additional explanation:
{source text}
```

Then apply the embedded template with a generation prompt. Stop on model EOG/EOS tokens, not guessed English/Chinese substrings.

Initial generation experiment for both EN and RU:

- Official baseline: temperature 0.7, top-p 0.6, top-k 20, repetition penalty 1.05, fixed seed.
- Deterministic comparison: greedy, fixed seed.
- Screenshot-specific output cap: derive from source length, normally 16–96 new tokens, hard maximum 160 for the golden long paragraph.
- Select one setting only after Stage 1 scores raw EN and RU output. Do not assume greedy is better merely because it is deterministic.

Initial runtime experiment:

- `n_ctx = 2048`; reduce only after the longest individual and micro-batch prompts are measured.
- `n_batch = 256`, `n_ubatch = 128` as starting values, then measure.
- Metal enabled and all supported layers offloaded for Q4.
- mmap enabled.
- one context, one request at a time; clear KV/context between independent generation calls.
- start with four CPU threads for non-Metal work, but treat thread count as a device-specific benchmark parameter, not a product constant.
- one short warm-up generation after load.

### Secondary fallback

If Q4 fails the physical-device peak-memory or stability gate, test **Tencent Hy-MT2-1.8B 1.25-bit STQ** at model revision `9df5c824...` against llama.cpp PR #22836 head `1e411d8...`. It is a fallback candidate, not a second production backend. It must meet the same EN/RU quality and latency gates on the same phone. If selected, the final app pins that fork and removes Q4-specific migration code.

Do not test Q2_0c before STQ unless PR #19357 is replaced by a documented iPhone-compatible CPU/Metal path. Its smaller file alone is not evidence of lower end-to-end latency.

### Reference candidate

Use the official Hy-MT2-1.8B Q8_0 GGUF on the Mac benchmark runner as the same-family quality reference. It is not the iPhone shipping candidate.

## H. New Architecture

### H.1 Final production flow

```text
TranslateScreenshotIntent / app picker
             |
             v
      ScreenshotNormalizer       (keep)
             |
             v
        VisionOCRService         (keep)
             |
             v
   TextGroupingService           (keep, selectively improve)
             |
             v
 TranslationBlockPreparer        (new, small)
             |
             v
      HyMTTranslationEngine      (new actor; sole production translator)
             |
             v
   TranslationResultMapper       (new or folded into preparer/result type)
             |
             v
        OverlayRenderer          (keep/refactor)
             |
             v
      PNG + ResultOverlayView
```

Avoid a service/factory hierarchy. One narrow protocol is justified only as the test seam already used by `ProcessingOrchestrator`; the shipping app should have exactly one implementation.

### H.2 Data contract

Use one language-aware batch method:

```swift
func translate(
    blocks: [TranslationRequestBlock],
    from source: TranslationLanguage,
    to target: TranslationLanguage
) async throws -> [TranslationResult]
```

Initially support `.chineseSimplified`, `.english`, and `.russian`, with only Chinese as a source. Every request/result carries the stable OCR block ID and exact source text. Unsupported pairs fail explicitly.

### H.3 Engine lifecycle

`HyMTTranslationEngine` should be an actor because one llama context is not safe for concurrent mutation. It owns the model, context, sampler configuration, and state:

```text
unloaded -> loading -> warming -> ready -> unloading -> unloaded
                         |          |
                         +-> failed <-+
```

Rules:

- `load`: validate manifest, size, SHA-256, available storage, and GGUF metadata before initializing llama.cpp.
- `warm`: run one representative short translation and record its time; failure makes the engine unavailable.
- `translate`: serialize calls, honor cancellation between decode steps, reset KV/context for every independent prompt, and return only raw decoded content plus metrics.
- `unload`: wait for/abort active work safely, free sampler/context/model, and update state.
- memory warning: cancel queued work and unload when idle; never race native deallocation with decode.
- fatal native/decode error: free the session once and allow one explicit reload. Do not silently loop.
- app backgrounding: do not assume unload is always needed, but do not promise session persistence. Measure foreground/background transitions on device.

### H.4 Prompting, batching, and output validation

Do not port the current prompt profiles or cleanup pipeline. Start with:

```text
embedded Hy-MT2 Jinja template
  -> official one-message translation instruction
  -> EOG/EOS termination
  -> trim outer whitespace only
  -> validate
```

Validation should reject, not creatively repair:

- empty output;
- repeated prompt/instruction leakage;
- missing or duplicate batch IDs;
- changed protected numbers, units, currency, or Latin model identifiers;
- excessive target-inappropriate CJK residue;
- output length far outside a measured source-relative bound.

Retry one failed item individually once. If it still fails, return a per-block failure for the UI; do not insert dictionary text or hard-coded patches.

Use **adaptive semantic micro-batching**:

- combine 4–8 short compatible UI labels into one official delimiter-preservation prompt with stable numeric IDs;
- keep chat messages, address/logistics blocks, and paragraphs separate unless they form one existing logical block;
- cap total micro-batch prompt around 256–384 tokens initially;
- never mix English and Russian targets in one call;
- validate exact ID count/order and retry malformed members individually;
- compare this with single-block inference in Stage 1 before making it the default.

This reduces repeated template/prefill overhead while containing alignment and cross-item contamination risk. A single 30-item prompt is not recommended.

### H.5 Model storage

Development:

- keep an explicit Debug-only importer;
- copy into `Application Support/Models/<model-id>/<revision>/`, not Documents;
- display revision, file size, and computed hash before running.

Production on the current iOS 18 floor:

- download a signed/versioned manifest over HTTPS using background `URLSession`;
- download to a temporary file, verify free space, byte count, and SHA-256, then atomically move to Application Support;
- exclude the redownloadable model from backup;
- keep the previous version only until the new file verifies and no engine owns it, then remove it;
- surface progress, cancellation, offline state, and insufficient-space errors;
- store license/notice metadata with the model version.

One shipping model is enough. Do not ship Q4 and STQ together.

### H.6 App Intent UX

The reliable production route should be the existing app-opening intent:

```text
Shortcut receives screenshot -> persists it -> opens app -> foreground engine translates -> result view
```

This is compatible with cold model load, progress UI, model download, memory pressure, and cancellation. Keep the floating result presentation if it adds real UX value; it should use the same pipeline.

Background translated Quick Look should be `UNKNOWN — NEEDS TEST` until the final chosen model completes cold and warm physical-device runs with substantial margin inside the observed App Intent budget. If it cannot do so, delete that intent. Do not retain the Mac server or a second translator to preserve it. OCR-only diagnostics can remain Debug-only.

## I. Migration / Deletion Map

### I.1 File/component classification

| File/component | Classification | Decision |
|---|---|---|
| `ScreenTranslatorApp.swift`, `App/AppEnvironment.swift`, coordinator/container | KEEP BUT REFACTOR | Remove Apple `TranslationSession` hosting; retain app lifecycle and intent consumption. |
| `App/AppServices.swift` | KEEP BUT REFACTOR | Wire the one Hy-MT engine and unified pipeline directly. No backend factory. |
| `IntentInputDecoder`, `IntentResultRouter`, `TemporaryImageStore` | KEEP | Safe file deep-copy and foreground handoff solve real lifecycle constraints. |
| `TranslateScreenshotIntent`, `FloatingScreenTranslateIntent` | KEEP BUT REFACTOR | Keep foreground invocation; update deprecated/opening behavior to the current App Intents execution API during implementation. |
| `QuickLookTranslateScreenshotIntent` and `QuickLookIntentRunner` | UNKNOWN — NEEDS TEST | Keep only if the final model meets cold/warm physical App Intent gates. Otherwise delete. |
| Echo/direct-echo/tiny-PNG intents | DELETE | Historical transport probes should not ship or appear in shortcut metadata. |
| `QuickLookDebugOCRIntent` | KEEP AS DEVELOPMENT TOOL | Gate with `#if DEBUG`; it helps validate Vision geometry. |
| `ScreenshotNormalizer`, `ImageOrientationResolver`, `ScreenshotInputBuilder` | KEEP | Focused, native, and tested. |
| `OCRRequestFactory`, `VisionOCRService` | KEEP BUT REFACTOR | Keep Vision configuration; add explicit observed confidence telemetry before deciding on a threshold. |
| `BoundingBoxGrouper`, `TextBlockComposer`, `TextGroupingService` | KEEP BUT REFACTOR | This is the best grouping base. Add only screenshot cases proven by the golden set. |
| `QuickLookCJKTextDetector` | KEEP BUT REFACTOR | Move the small reusable scalar detection into the unified preparer; delete the duplicate file afterward. |
| `QuickLookTextBlockGrouper` | REPLACE | Keyword/geometry semantic hints may inform tests, but a second grouping pipeline must not remain. |
| `TranslationServiceProtocol` | KEEP BUT REFACTOR | Preserve one test seam and make it language-aware/batch-aware. One production conformer only. |
| Apple `OnDeviceTranslationService`, `TranslationLanguageManager`, `TranslationSessionBroker` | DELETE AFTER NEW ENGINE WORKS | Wrong model path and hard-coded RU pair; retaining it would create a permanent fallback. |
| `TranslationBatchBuilder` | REPLACE | Rebuild as the small adaptive block preparer with IDs/languages/micro-batches. |
| `QuickLookLocalMTConfig` | DELETE EARLY/THEN REMOVE | Remove LAN URL and flags immediately once Stage 1 no longer needs the remote test; final file should disappear. |
| `QuickLookLocalMTClient` | DELETE AFTER NEW ENGINE WORKS | HTTP/LAN is obsolete in a local-only product. |
| `QuickLookLocalMTTranslationProvider` | REPLACE | Route any accepted Quick Look execution to the same engine; do not preserve provider modes. |
| `QuickLookMTBlockPreparer`, `QuickLookOCRBlockMapper` | REPLACE | Useful requirements, but duplicated routing/mapping must collapse into the shared preparer and stable-ID mapper. |
| `QuickLookEnglishTranslationProvider` | DELETE | Hard-coded translations and OCR corrections mask model/OCR defects and cannot scale to RU. |
| `QuickLookLocalDictionaryTranslationProvider` | DELETE | Large inactive hand-authored RU implementation conflicts with one model path. |
| `QuickLookCEDICTStore`, SQLite resource, dictionary build tools | DELETE AFTER NEW ENGINE WORKS | Inactive final route, provenance burden, and unnecessary fallback if Hy-MT2 passes quality. |
| `OverlayLayoutEngine`, `OverlayTextFitter`, `OverlayImageComposer`, `OverlayRenderer` | KEEP BUT REFACTOR | Keep the modular main renderer; add golden image tests and explicit failure propagation. |
| `QuickLookOverlayRenderer` | REPLACE/DELETE | Port only proven layout behavior into the main renderer; remove the 1,900-line duplicate. |
| Quick Look diagnostics models/renderer | DELETE or DEBUG-only | Keep only the minimum OCR/layout inspector needed during migration. Never ship the large backend-specific diagnostic surface. |
| `OnDeviceLlamaBridge.h/.mm` | REPLACE | Reuse C-API learning, but implement a smaller template-aware, cancellable, Metal-capable bridge against the pinned XCFramework. |
| `OnDeviceLlamaNativeRuntime.swift` | REPLACE | Fold into the actor-owned engine; avoid an extra runtime abstraction with one implementation. |
| `OnDeviceLlamaSmokeTestService.swift` | DELETE AFTER STAGE 1 | Replace with a narrow benchmark runner. Do not port prompt profiles or cleanup patches. |
| `OnDeviceMTDebugView/ViewModel` | REPLACE AS DEVELOPMENT TOOL | Keep one compact benchmark screen/report schema; discard profile explosion and model-patching UI. |
| `LocalLlama/` and `Config/OnDeviceLlamaBridge.xcconfig` | REPLACE | Use a reproducible pinned XCFramework artifact; do not commit copied libraries/headers. |
| `tools/on_device_llama/build_llama_ios_static.sh` | REPLACE | One script should fetch/check the exact pin and call the upstream XCFramework builder. |
| `LocalModels/README.md` | KEEP BUT REFACTOR | Document the manifest/hash workflow; no model file in Git. |
| `tools/opus_mt_server/` and all local model directories | DELETE AFTER STAGE 2 | Remote Mac and OPUS/Hy-MT1.5 models are not the final architecture. Preserve a Q8 reference CLI only if Stage 1 actively uses it, then move it to a focused benchmark tool. |
| Existing `docs/on_device_*` phase files | DELETE/ARCHIVE AFTER MIGRATION | Historical reasoning conflicts with verified current state. This report supersedes them. |
| Core unit tests | KEEP BUT REPAIR | Correct `TEST_HOST`, then keep the grouping/input/rendering tests. |
| Current UI launch tests | KEEP BUT REDUCE | They prove launch only; add a few real screenshot flows instead of more scaffolding. |

### I.2 Deletion order

#### DELETE EARLY

After the dirty worktree is safely checkpointed and Stage 1 has its isolated harness:

- three echo/tiny-PNG intents and their shortcut phrases;
- the hard-coded LAN URL from production configuration;
- tracked/generated model binaries and local virtual environments from repository scope; ensure they remain ignored;
- stale unused OPUS selection flag/code if the reference runner does not use it.

#### DELETE AFTER NEW ENGINE WORKS

- FastAPI server, HTTP client, OPUS/HY-MT1.5 files, and local-network permissions;
- Apple Translation service/session/language-pack UI;
- dictionary providers, CEDICT store/database/build scripts, and fallback routing;
- old prompt profiles, string stop lists, cleanup/CJK patches, and retry heuristics;
- duplicate Quick Look grouper/preparer/mapper/renderer/diagnostics;
- copied static libraries, headers, xcconfigs, and old build script;
- background Quick Look translation if it fails its explicit gate.

#### KEEP AS DEVELOPMENT TOOL

- one minimal OCR/geometry diagnostic intent, Debug-only;
- one compact physical-device benchmark screen and JSON/Markdown exporter;
- Debug-only model importer with verified revision/hash;
- a Mac Q8 reference runner if it remains used by the golden quality comparison.

#### KEEP IN PRODUCTION

- screenshot handoff/input normalization;
- Vision OCR;
- one text grouping/layout analyzer;
- one Hy-MT translation engine;
- one result mapper and one overlay renderer;
- foreground app/Shortcut result flow;
- model download/verification/lifecycle UI.

## J. Main Integration Stages

Every stage ends with one committed/reportable evidence set before the next begins. The report must include Git state, device/iOS, model repository/revision/hash, runtime commit/build flags, load/warm time, RSS before/after/peak, TTFT, generation latency and tokens/second, end-to-end latency, test inputs, raw outputs, minimally normalized outputs, pass/fail, crashes, timeouts, thermal state, and warnings.

### Stage 1 — Baseline and real-iPhone model proof

**Scope**

- First require the owner to checkpoint the current dirty tree; do not guess which uncommitted experiments are disposable.
- Repair the unit-test host only if needed to establish the baseline; do not otherwise refactor production.
- Build a pinned Metal XCFramework from llama.cpp `b062ba...`.
- Replace the current generic model test only inside the Debug benchmark harness.
- Download/verify Hy-MT2 Q4_K_M and use its embedded Jinja template.
- Run the golden EN/RU cases on one named physical iPhone.
- Compare official sampling vs greedy and single-block vs short-label micro-batches.
- If Q4 fails memory/stability, repeat the same suite with STQ PR `1e411d8...`; do not integrate both.

**Code areas**

`Core/Services/OnDeviceMT/`, `Features/OnDeviceMT/`, the bridging header, project linkage, and one reproducible runtime build script. No foreground pipeline wiring.

**Success criteria**

- Correct model/runtime hashes and raw output captured.
- EN and RU meet the Section K quality gates without semantic patch dictionaries.
- No crash/jetsam across 20 repeated mixed cases.
- One model meets the provisional memory and latency gates in Section L or produces enough data to set honest revised gates.
- Template, sampling, context, token caps, thread count, and batching decision are frozen in the report.

**Stop conditions**

- Q4 and STQ both exceed viable memory/latency or fail material EN/RU quality.
- Required runtime branch cannot be built reproducibly for device and simulator.
- Raw output requires the current large cleanup/patch system to pass.

**Required report**

`STAGE_1_HYMT2_IPHONE_PROOF.md` plus machine-readable JSON and hashes.

### Stage 2 — Replace the translation core

**Scope**

- Implement the actor-owned engine for the single Stage 1 winner.
- Make the translation request/result contract language-aware.
- Implement the small adaptive preparer and stable-ID mapping.
- Wire `ProcessingOrchestrator` to the new engine for EN and RU.
- Retain raw validation and one individual retry; port no legacy cleanup.
- Add golden unit/integration tests and fix the test scheme.

**Removals**

- Apple Translation session/service and language-pack preparation UI once foreground Hy-MT passes.
- Current on-device smoke-test prompt profiles, known CJK patches, and redundant runtime abstraction.

**Success criteria**

- All unit/integration tests run and pass.
- Golden EN/RU outputs meet meaning/number/format gates on device.
- Stable result IDs map 100% to their source blocks.
- Cancellation and load/unload/reload paths complete without native crashes.
- No second production translator is wired.

**Stop conditions**

- Data loss/mis-mapping, nondeterministic native crashes, or memory growth remains unresolved.
- Quality falls materially below Stage 1 when real OCR blocks replace clean text.

**Required report**

`STAGE_2_TRANSLATION_CORE_REPORT.md` with clean-text and OCR-text raw outputs.

### Stage 3 — Full screenshot integration and legacy removal

**Scope**

- Use the main grouping and renderer for the entire foreground screenshot flow.
- Port only Quick Look layout/grouping behavior demonstrated to improve golden screenshots.
- Add target-language selection to settings without separate pipelines.
- Run real screenshot E2E cases on physical hardware.
- Decide the Quick Look translated-intent gate using cold/warm measurements.

**Removals**

- FastAPI/HTTP/LAN backend and network permissions.
- dictionary/CEDICT runtime and hard-coded translation providers.
- duplicate Quick Look grouper/preparer/mapper/renderer/diagnostics.
- echo/debug transport intents.
- background translated Quick Look intent if it misses its gate.

**Success criteria**

- One production code path from both app and accepted intents.
- Overlay geometry remains associated with the correct source block in every golden screenshot.
- EN/RU E2E meaning and number gates pass.
- No screenshot text leaves the device.
- Repository contains no large model/server/environment artifacts.

**Stop conditions**

- Overlay mapping corrupts text ownership or essential source content becomes unreadable.
- Background Quick Look requires a second translator/backend to be reliable; delete that UX instead.

**Required report**

`STAGE_3_SCREENSHOT_E2E_AND_DELETION_REPORT.md`, including before/after file inventory and privacy verification.

### Stage 4 — Model delivery and production hardening

**Scope**

- Implement the HTTPS manifest/background download and atomic Application Support install.
- Add storage checks, checksum, version transition, backup exclusion, progress, offline handling, and license notices.
- Tune the already-selected context/batch/thread settings only from physical measurements.
- Run cold/warm, memory-pressure, cancel/retry, background/foreground, thermal, and repeated-run suites.
- Remove the final superseded phase documents and benchmark scaffolding.

**Success criteria**

- Interrupted or corrupt downloads never replace a valid installed model.
- Fifty repeated screenshot translations have no crash, timeout, or monotonic RSS growth greater than 10% after returning to idle.
- Final targets in Section L are met on the declared supported-device floor, or product requirements are explicitly revised.
- Release build and all unit/UI/E2E tests pass from a fresh checkout plus documented model acquisition.

**Stop conditions**

- Download integrity/storage behavior risks losing a previously working model.
- The chosen supported-device floor cannot meet memory or latency requirements.

**Required report**

`STAGE_4_FINAL_PRODUCTION_REPORT.md` with final architecture/deletion confirmation.

## K. Testing Strategy

### K.1 Golden translation set

Each item runs Chinese-to-English and Chinese-to-Russian. Store source, protected spans, human reference meaning, raw model output, normalized output, and reviewer result. References are quality guides, not exact-string requirements except protected data and IDs.

| Category | Required examples |
|---|---|
| Basic UI | `加入购物车`; `立即购买`; `配送至`; `联系客服`; `网络错误，请重试` |
| Product options | `已选：暖白光 3000K，54W，260×80cm；20件`; `颜色分类：奶油白 加厚款（含安装配件）` |
| Logistics | `这批货物后续还有国际运输，请务必做好非常牢固的包装，并在外箱注明货物名称。` |
| Seller chat | `您好，我收到货后发现有一个灯不亮，可以补发配件吗？`; `可以的，麻烦拍一下故障视频，我们今天给您补发。` |
| Long paragraph | One 60–150 Chinese-character product/logistics paragraph captured from a real screenshot and checked for OCR accuracy. |
| Numbers/units | `260×80cm`; `20件`; `¥135`; `3000K`; `54W`; a combined price/quantity/spec sentence. |
| Mixed script | `Apple MagSafe 兼容，型号 ST-54W，支持 USB-C`; `Nike Air Max 黑色 42码` |
| OCR noise | A small fixed set from `real_ocr_misses.txt`, but scored separately so OCR failure is not mislabeled model failure. |
| Micro-batch | IDs `[1]` through `[8]` containing short UI labels, plus one deliberately mixed UI/chat batch that should be split by the preparer. |

### K.2 Translation acceptance criteria

- **Meaning:** at least 95% of reviewed blocks preserve the essential meaning in each target language; zero critical reversals involving price, quantity, negation, shipping, or action.
- **Protected data:** 100% preservation of numbers, decimal punctuation, dimensions, currency, temperature/color values, wattage, brand names, and model identifiers in this small golden set.
- **Hallucination:** zero invented product attributes, commitments, quantities, people, or actions.
- **Language:** no unexplained source-language CJK residue in EN/RU, except protected brand/model text; proper target language throughout.
- **Formatting:** micro-batch IDs/count/order preserved 100%; one result per requested block; no prompt or explanation leakage.
- **Cleanup:** only outer-whitespace normalization is allowed for the initial acceptance run. Any additional rule requires a failing golden example and a focused test.

### K.3 Screenshot E2E set

Retain at least 12 source screenshots, with consent and sensitive details removed:

- 3 commerce/product-option pages;
- 2 cart/checkout pages with price and quantity;
- 2 seller chat pages;
- 2 logistics/address/instructions pages;
- 1 dense long-text page;
- 1 mixed Chinese/English brand/model page;
- 1 low-contrast or small-font OCR stress page.

For each screenshot, store expected OCR blocks/rectangles, grouping relationships, protected spans, expected target meaning, and visual reference assertions. Validate both languages on each image. Image tests should compare block ownership, overlap, clipping, and legibility rather than require pixel-identical antialiasing.

### K.4 Required non-quality tests

- corrupt/wrong-hash/not-enough-space/interrupted model download;
- load while loading, translate while unloaded, cancellation during decode, unload after cancellation, one recovery after failure;
- memory-warning while idle and while generating;
- app background/foreground and process cold launch;
- 1, 10, 30, and 40 useful OCR blocks;
- single-block versus adaptive micro-batch A/B on the same inputs;
- Debug and Release device builds plus arm64 simulator build;
- foreground App Intent from a real Shortcut; background Quick Look only if still under evaluation.

## L. Performance Targets

The repository contains no trustworthy physical-device baseline. The figures below are **provisional product gates**, not measured claims. Stage 1 must record the phone model, iOS, thermal state, power mode, model/runtime hashes, raw tokens, and three or more repetitions before accepting or revising them. Upstream desktop/Android PR numbers are not iPhone targets.

| Metric | Preferred gate | Hard stop/review gate |
|---|---:|---:|
| Q4 cold model load + first warm-up | <= 5 s | > 10 s |
| Ready RSS increase | <= 1.8 GB | > 2.2 GB peak or any jetsam |
| Short UI label, warm, one item | median <= 0.8 s; p95 <= 1.5 s | p95 > 2.5 s |
| 50–100 Chinese-character chat, warm | p95 <= 3.5 s | p95 > 6 s |
| 10 useful blocks, adaptive | p95 <= 5 s | p95 > 9 s |
| 30 useful blocks, adaptive | p95 <= 12 s | p95 > 20 s |
| Warm full screenshot: OCR through PNG | p95 <= 15 s | p95 > 22 s |
| Cold foreground screenshot | p95 <= 25 s | p95 > 35 s |
| Repeated runs | 50 runs, no crash/timeout; idle RSS drift <= 10% | any repeatable crash/jetsam or unbounded growth |

Additional required measurements, without invented pass numbers until Stage 1:

- time to first token;
- prompt-processing tokens/second and generation tokens/second;
- peak temporary memory during prefill and decode;
- Q4 single-item versus micro-batch latency/quality;
- official sampling versus greedy quality/variance;
- thermal state and performance at runs 1, 10, 20, and 50.

Background translated Quick Look may ship only if, on the supported-device floor, 100 consecutive real Shortcut invocations have zero timeouts and cold p95 is at least 8 seconds inside the effective system budget. Warm-process numbers alone do not qualify it.

## M. Risks / Blockers

| Rank | Risk | Why it matters | Required response |
|---:|---|---|---|
| 1 | Q4 memory/peak allocation on real iPhone | The 1.13 GB file plus runtime/KV/prefill/Metal allocations may cross the usable process envelope. | Stage 1 physical peak/RSS/jetsam test; STQ is the next candidate, not a permanent fallback. |
| 2 | Background App Intent lifecycle | Cold model load and 10–40 blocks may not fit a reliable `perform()` window; process warmth is not guaranteed. | Prefer foreground handoff; delete translated Quick Look if it misses the gate. |
| 3 | STQ dependency risk | The 462 MB option is CPU-only and pinned to an open PR; smaller storage may have slower prefill and higher maintenance cost. | Use only after Q4 fails; pin exact head and benchmark the same phone/cases. |
| 4 | EN/RU low-bit quality | Quantization and micro-batching can alter numbers, omit labels, or leak instructions, especially for Russian. | Raw bilingual golden set, Q8 reference, protected-span validation, individual retry only. |
| 5 | Dirty, weakly evidenced repository state | Important local work is uncommitted; prior documents make physical-device claims without reproducible artifacts; unit tests do not run. | Owner checkpoint first; repair baseline; every stage records Git/model/runtime/device evidence. |
| 6 | Model distribution/license/provenance | A 1.13 GB model needs reliable updates, notices, and integrity; CEDICT provenance is unclear. | Versioned HTTPS manifest, SHA-256, Application Support install, license review/notices, remove CEDICT. |
| 7 | OCR/grouping versus model blame | Bad source grouping can look like poor translation and lead to new prompt hacks. | Preserve raw OCR/group IDs and score OCR, grouping, translation, and rendering independently. |

The 2-bit Q2_0c path is not a current blocker because it is not on the recommended path. Do not spend implementation time on it unless upstream changes materially.

## N. Exact Recommended Next Action

**Perform Stage 1 only: build an isolated, reproducible real-iPhone benchmark of Tencent Hy-MT2-1.8B Q4_K_M using llama.cpp `b062ba735e5e15817f6a1dbdb84717ee3097f619` as a Metal-enabled XCFramework, the model's embedded Jinja template, and the Section K EN/RU golden set; produce the complete Stage 1 report before changing the production screenshot pipeline.**

Before touching files, verify that the repository owner has safely checkpointed the current dirty working tree. Do not implement STQ in parallel. Move to STQ PR `1e411d8...` only if the Q4 physical-device memory/stability gate fails.
