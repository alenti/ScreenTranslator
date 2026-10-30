# On-Device Hy-MT / AngelSlim Feasibility Plan

Audit date: 2026-05-18

This document audits the current ScreenTranslator / ChinaTap Quick Look
translation pipeline and lays out a safe plan for investigating true on-device
Hy-MT inference on iPhone. It intentionally does not propose changing AppIntent
signatures, OCR, grouping, overlay rendering, dictionary runtime behavior, or
the working Mac backend path in the first implementation phase.

## Executive Summary

Running Hy-MT fully on iPhone is plausible for a personal prototype, but not yet
a low-risk drop-in replacement for the current Mac HTTP backend.

The current app is in a good architectural position because Quick Look already
concentrates neural MT behind a small provider/client path:

```text
Shortcut / AppIntent
-> QuickLookIntentRunner
-> VisionOCRService
-> QuickLookMTBlockPreparer
-> QuickLookLocalMTTranslationProvider
-> QuickLookLocalMTClient
-> Mac FastAPI /translateBlocks
-> QuickLookOCRBlockMapper
-> QuickLookOverlayRenderer
-> IntentFile PNG for Quick Look
```

The risky part is not Swift plumbing. The risky part is the inference runtime:
AngelSlim is primarily a model compression toolkit plus released model weights.
The 1.25-bit Hy-MT model depends on a custom `STQ1_0` quantization/kernel path.
The current repo's Mac backend already treats the old 1.25-bit GGUF as blocked
because tested llama.cpp runtimes rejected it as an unsupported GGUF type. As of
this audit, AngelSlim/Tencent have published an upstream llama.cpp PR for
`STQ1_0`, but that PR is open and the documented run command is CPU-only
(`-ngl 0`). That is not something to wire into a Quick Look AppIntent before a
tiny isolated iOS smoke test proves model load, tokenization, generation,
memory, and latency.

Recommended path:

1. Keep `remoteMacHyMT` as the default working backend.
2. Add an optional backend abstraction later, with `remoteMacHyMT`,
   `onDeviceHyMTExperiment`, and `disabled`.
3. Build a separate on-device smoke test first, outside the screenshot pipeline.
4. Start with llama.cpp iOS and a known tiny GGUF model to prove the bridge.
5. Then test Hy-MT Q4_K_M or 2-bit GGUF where runtime support is standard enough.
6. Only after that test AngelSlim 1.25-bit with the `STQ1_0` llama.cpp branch.

## Sources Checked

Local repository:

- `Intents/TranslateScreenshotIntent.swift`
- `Intents/QuickLookDebugOCRIntent.swift`
- `Intents/AppShortcutsProvider.swift`
- `Intents/QuickLook/QuickLookIntentRunner.swift`
- `Intents/QuickLook/QuickLookLocalMTConfig.swift`
- `Intents/QuickLook/QuickLookMTBlockPreparer.swift`
- `Intents/QuickLook/QuickLookLocalMTClient.swift`
- `Intents/QuickLook/QuickLookLocalMTTranslationProvider.swift`
- `Intents/QuickLook/QuickLookOCRBlockMapper.swift`
- `Intents/QuickLook/QuickLookOverlayRenderer.swift`
- `Intents/QuickLook/QuickLookTextBlockGrouper.swift`
- `Intents/QuickLook/QuickLookCJKTextDetector.swift`
- `Core/Services/OCR/VisionOCRService.swift`
- `Core/Services/OCR/OCRRequestFactory.swift`
- `Core/Services/Translation/OnDeviceTranslationService.swift`
- `Core/Protocols/TranslationServiceProtocol.swift`
- `App/AppServices.swift`
- `Features/Processing/ProcessingOrchestrator.swift`
- `tools/opus_mt_server/server.py`
- `tools/opus_mt_server/hymt_engine.py`
- `tools/opus_mt_server/provider_registry.py`
- `tools/opus_mt_server/translation_types.py`
- `tools/opus_mt_server/README.md`

External sources:

- Tencent AngelSlim: https://github.com/tencent/AngelSlim
- AngelSlim Hy-MT1.5 1.25-bit model card:
  https://huggingface.co/AngelSlim/Hy-MT1.5-1.8B-1.25bit
- AngelSlim/Tencent 1.25-bit GGUF card:
  https://huggingface.co/tencent/Hy-MT1.5-1.8B-1.25bit-GGUF
- AngelSlim 2-bit GGUF card:
  https://huggingface.co/AngelSlim/Hy-MT1.5-1.8B-2bit-GGUF
- llama.cpp STQ1_0 PR:
  https://github.com/ggml-org/llama.cpp/pull/22836
- MLC LLM iOS docs:
  https://github.com/mlc-ai/mlc-llm/blob/main/docs/deploy/ios.rst
- ExecuTorch iOS LLM docs:
  https://docs.pytorch.org/executorch/1.0/llm/run-on-ios.html
- Core ML Tools ML Program docs:
  https://apple.github.io/coremltools/docs-guides/source/convert-to-ml-program.html

## Current Project Map

### AppIntent and Shortcut Entry Points

- `Intents/TranslateScreenshotIntent.swift`
  - `TranslateScreenshotIntent` stores a screenshot and opens the main app
    processing flow.
  - `QuickLookTranslateScreenshotIntent` accepts an `IntentFile` image and
    returns an `IntentFile` PNG through `QuickLookIntentRunner(mode:
    .translated)`.
  - `FloatingScreenTranslateIntent` stores a screenshot and opens the floating
    preview flow.
  - These signatures should not change.

- `Intents/QuickLookDebugOCRIntent.swift`
  - `QuickLookDebugOCRIntent` returns a diagnostic OCR PNG through
    `QuickLookIntentRunner(mode: .debug)`.

- `Intents/QuickLookEchoScreenshotIntent.swift`
- `Intents/QuickLookDirectEchoScreenshotIntent.swift`
- `Intents/QuickLookTinyPNGIntent.swift`
  - Debug/echo Quick Look probes used to validate Shortcuts/Quick Look file
    return behavior.

- `Intents/AppShortcutsProvider.swift`
  - Registers normal, floating, Quick Look, OCR debug, and echo shortcuts.

### Quick Look Runner

- `Intents/QuickLook/QuickLookIntentRunner.swift`
  - Owns the Quick Look execution path.
  - Decodes the `IntentFile` with `IntentInputDecoder`.
  - Runs Vision OCR inside a 15 second timeout wrapper.
  - Fast-paths no-CJK screenshots into a fallback PNG message.
  - Calls `QuickLookOverlayRenderer` for translated mode.
  - Calls `QuickLookDiagnosticsRenderer` for debug mode.
  - Always returns a PNG `IntentFile` through `QuickLookIntentFileFactory`.
  - Catches timeout/errors and returns a fallback PNG instead of crashing.

### OCR Pipeline

- `Core/Services/OCR/OCRRequestFactory.swift`
  - Creates `VNRecognizeTextRequest`.
  - Uses `.accurate` recognition.
  - Sets recognition languages to `zh-Hans` and `zh-Hant`.
  - Disables language correction.

- `Core/Services/OCR/VisionOCRService.swift`
  - Runs Vision OCR on a user-initiated serial queue.
  - Converts `VNRecognizedTextObservation` normalized boxes into screenshot
    pixel coordinates.
  - Sorts observations by row/column and assigns `lineIndex`.
  - Returns `[OCRTextObservation]`.

### Grouping

- General app flow:
  - `Core/Services/Grouping/BoundingBoxGrouper.swift`
  - `Core/Services/Grouping/TextBlockComposer.swift`
  - `Core/Services/Grouping/TextGroupingService.swift`
  - Covered by unit tests for CJK row merging, column separation, compact UI
    label separation, and commerce metadata fragmentation.

- Quick Look flow:
  - `Intents/QuickLook/QuickLookTextBlockGrouper.swift`
  - Groups CJK OCR lines into `QuickLookTextGroup`.
  - Classifies groups as `chatBubble`, `paragraph`, `uiLabel`, `button`,
    `productCard`, `addressBlock`, or `unknown`.
  - Preserves child frames and child text for grouped overlay rendering.

### MT Block Preparation

- `Intents/QuickLook/QuickLookMTBlockPreparer.swift`
  - Filters OCR observations down to non-empty, CJK, substantive, confident,
    valid-frame candidates.
  - Groups lines using `QuickLookTextBlockGrouper`.
  - Routes each group to local MT, dictionary, CEDICT, or skip.
  - With `QuickLookLocalMTConfig.useDomainDictionaryRuntime == false`, routes
    eligible groups directly to Hy-MT as `HYMT_PRIMARY`.
  - With `QuickLookLocalMTConfig.fullCoverageHyMTTestMode == true`, bypasses
    priority capping and sends all eligible non-noise CJK groups.
  - Builds `QuickLookMTPreparedBlock` with `id`, source text, kind, frames,
    route, priority metadata, and `QuickLookMTBlock` request projection.

### Quick Look Local MT Provider and Client

- `Intents/QuickLook/QuickLookLocalMTConfig.swift`
  - `isEnabled = true`
  - `baseURL = http://192.168.1.54:8766`
  - request timeout: 8 seconds
  - health timeout: 1.25 seconds
  - normal translation time budget: 8.75 seconds
  - full coverage time budget: 14 seconds
  - `fullCoverageHyMTTestMode = true`
  - normal max blocks: 22
  - debug max blocks: 30
  - `requestBatchSize = 1`
  - `useDomainDictionaryRuntime = false`
  - `prioritySelectionDisabled` and `maxBlockLimitDisabled` are derived from
    full coverage mode.

- `Intents/QuickLook/QuickLookLocalMTClient.swift`
  - Defines the HTTP JSON contract used by the iPhone.
  - `POST /translateBlocks` request:
    - `sourceLang`
    - `targetLang`
    - `blocks: [{ id, text, kind }]`
  - Response:
    - `provider`
    - `translations: [{ id, sourceText, translatedText, rawTranslatedText,
      latencyMs, provider }]`
    - `totalLatencyMs`
  - `GET /health` response supports `ok`, provider fields, model path,
    device/compute metadata, errors, and nested provider health.
  - Maps connection errors into structured fail-fast reasons.

- `Intents/QuickLook/QuickLookLocalMTTranslationProvider.swift`
  - Performs health preflight before sending any batch.
  - Splits requests by `requestBatchSize`.
  - Enforces active translation time budget before starting each batch.
  - Tracks successful translations, failed IDs, skipped-by-budget count,
    fail-fast state, and client duration.
  - Converts backend hits into `QuickLookDictionaryTranslation` with
    `.localMT` match kind so the rest of the overlay pipeline can reuse the
    dictionary-shaped output.
  - Fails without throwing to the AppIntent path.

### Block Mapping, Quality Checks, and Overlay Selection

- `Intents/QuickLook/QuickLookOCRBlockMapper.swift`
  - Calls `QuickLookMTBlockPreparer`.
  - Calls `QuickLookLocalMTTranslationProvider`.
  - Accepts Hy-MT hits as translated overlay candidates.
  - With dictionary runtime disabled, skips unknown dictionary/CEDICT routes
    instead of re-enabling CC-CEDICT.
  - Suspicious-output checks are only active when dictionary runtime is enabled.
    In the current full-coverage Hy-MT test mode, Hy-MT sentence output is
    effectively trusted.
  - Rejects low-quality dictionary fallback for sentence-like blocks when that
    fallback is too short.
  - Tracks rich diagnostics: CJK count, route counts, local MT hits, failures,
    budget skips, rendered grouped translations, and lookup duration.

- `Intents/QuickLook/QuickLookOverlayRenderer.swift`
  - Converts `QuickLookOCRBlock` candidates into rendered overlays.
  - Chooses render mode:
    - `localMTTextReplacement` for long chat/paragraph/address blocks.
    - `localMTParagraphCard` for longer grouped text.
    - `localMTShortBubble` for short local MT lines.
    - `dictionaryPill` for dictionary/single/debug sources.
  - Draws directly into a PNG over the original screenshot.
  - Preserves the Quick Look return path.

### Existing Normal App Translation Abstraction

- `Core/Protocols/TranslationServiceProtocol.swift`
  - Generic app-level protocol: `translate(blocks:)`.

- `Core/Services/Translation/OnDeviceTranslationService.swift`
  - Uses Apple's `Translation` framework through `TranslationSessionBroker`.
  - Current normal app path targets `zh-Hans` to `ru`, not the Quick Look
    `zh` to `en` Hy-MT path.
  - This is not a Hy-MT runtime abstraction.

- `App/AppServices.swift`
  - Wires the normal app flow to `OnDeviceTranslationService`.
  - Quick Look bypasses this service graph and uses its own concrete
    `QuickLookLocalMTTranslationProvider`.

Current gap: Quick Look has a concrete remote HTTP provider but not a generic
translation backend abstraction.

## Current Translation Pipeline Summary

Normal Quick Look translation mode:

```text
QuickLookTranslateScreenshotIntent.perform()
-> QuickLookIntentRunner.run(mode: .translated)
-> IntentInputDecoder.snapshot/decode
-> VisionOCRService.recognizeText()
-> count CJK observations
-> QuickLookOverlayRenderer.renderPNGData()
-> QuickLookOCRBlockMapper.makeBlocks()
-> QuickLookMTBlockPreparer.prepare()
-> QuickLookLocalMTTranslationProvider.translate()
-> QuickLookLocalMTClient.checkHealth()
-> QuickLookLocalMTClient.translateBlocks()
-> QuickLookOCRBlockMapper accepts MT hits
-> QuickLookOverlayRenderer renders local MT overlays
-> QuickLookIntentFileFactory.makePNGFile()
```

Debug Quick Look OCR mode:

```text
QuickLookDebugOCRIntent.perform()
-> QuickLookIntentRunner.run(mode: .debug)
-> VisionOCRService.recognizeText()
-> QuickLookDiagnosticsRenderer.renderPNGData()
-> Quick Look PNG return
```

Failure behavior:

- Quick Look runner catches timeout and general errors.
- Local MT provider health-checks the Mac backend before the first translation
  request.
- Connection failures trigger fail-fast instead of repeated timeout loops.
- Missing translations produce skipped overlay candidates, not user-visible
  crashes.

## Current Mac Backend Contract Summary

Backend root: `tools/opus_mt_server`.

### Server

- `server.py`
  - FastAPI app named `ScreenTranslator Hy-MT Local Translation Server`.
  - Startup calls `ProviderRegistry.load_startup_providers()`.
  - `GET /health` returns registry health.
  - `POST /translateBlocks` validates `sourceLang=zh` and `targetLang=en`.
  - Resolves provider from optional `provider` field.
  - Translates all request block texts through `provider.translate_texts(texts)`.
  - Zips original blocks to translation results and returns stable block IDs.

### Request JSON

```json
{
  "provider": "hymt",
  "sourceLang": "zh",
  "targetLang": "en",
  "blocks": [
    {
      "id": "group_0",
      "text": "网络错误，请重试",
      "kind": "chatBubble"
    }
  ]
}
```

`provider` is optional. Missing, `auto`, `hymt`, `hy-mt`, and `hymt-gguf` route
to Hy-MT. `opus` now returns a controlled development error.

### Response JSON

```json
{
  "provider": "hymt-gguf",
  "translations": [
    {
      "id": "group_0",
      "sourceText": "网络错误，请重试",
      "translatedText": "Network error, please try again.",
      "rawTranslatedText": "Network error, please try again.",
      "latencyMs": 420,
      "provider": "hymt-gguf"
    }
  ],
  "totalLatencyMs": 421
}
```

### Model Loading

- `hymt_engine.py`
  - Default model directory:
    `tools/opus_mt_server/models/hymt-1.8b-q4_k_m-gguf`
  - Default compatible model file currently present locally:
    `HY-MT1.5-1.8B-Q4_K_M.gguf` around 1.1 GB.
  - Legacy blocked model file currently present locally:
    `Hy-MT1.5-1.8B-1.25bit.gguf` around 440 MB.
  - Uses `llama_cpp.Llama` from `llama-cpp-python`.
  - Default settings:
    - `n_ctx = 2048`
    - `n_threads = max(os.cpu_count() - 1, 1)` unless overridden
    - `n_gpu_layers = -1`
    - `max_tokens = 512`
    - `temperature = 0.0`
    - `top_p = 0.95`
    - stop strings: `\nChinese:`, `\n\nChinese:`, `</s>`

### Prompt Format

Current backend prompt:

```text
Translate the following Chinese text into natural English. Only output the English translation, no explanation.

Chinese:
{source}

English:
```

The AngelSlim/HF model cards show chat-template/Jinja usage for official
llama.cpp examples. The current backend's plain completion prompt works in the
tested Mac path, but an on-device runtime should re-check whether official
chat-template formatting improves quality or latency.

### Post-Processing

`HyMTGGUFTranslator._clean_translation()`:

- Trims whitespace.
- Removes leading `English:`, `Translation:`, or `Translated text:`.
- Strips surrounding quotes/backticks.
- Cuts off accidental `Chinese:` or `Source:` continuation.
- Collapses whitespace.

### Suspicious and Quality Checks

Backend:

- Does not perform semantic quality checks beyond cleaning.
- Classifies unsupported 1.25-bit GGUF errors into
  `unsupported_gguf_quantization`.
- Retries once by reloading if a decode error contains `llama_decode returned`.

iOS:

- Performs missing-hit handling, fail-fast accounting, and optional suspicious
  checks in `QuickLookOCRBlockMapper`.
- Current full-coverage Hy-MT mode with dictionary runtime disabled mostly
  accepts Hy-MT output and skips dictionary fallback paths.

### Batching

- iOS sends batches of size 1 in the current successful test mode.
- Server accepts an array of blocks but translates them sequentially in
  `HyMTGGUFTranslator.translate_texts`.
- There is no true server-side parallel batch decoding.
- The provider uses a lock, so concurrent requests serialize around one model
  context.

## AngelSlim and Model Feasibility Analysis

### What AngelSlim Provides

AngelSlim is a compression toolkit and collection of compression/deployment
recipes. It is not an iOS inference runtime that can be dropped into an Xcode
project. The repo's README focuses on quantization, speculative decoding,
offline Python inference, and serving through runtimes such as vLLM/SGLang.

For this project, AngelSlim is useful as:

- The source of compressed Hy-MT model weights.
- Documentation of 1.25-bit Sherry/STQ quantization.
- A pointer to custom llama.cpp kernel work.
- A model-card source for prompt/template details and benchmark claims.

It is not useful as:

- A Swift package.
- A Core ML model package.
- A stable iOS runtime.
- A replacement for llama.cpp/MLC/ExecuTorch integration work.

### Model Formats Observed

HF `AngelSlim/Hy-MT1.5-1.8B-1.25bit`:

- Safetensors weights, about 4.08 GB in the file listing.
- `tokenizer.json`, `tokenizer_config.json`, `special_tokens_map.json`.
- `chat_template.jinja`.
- Hunyuan dense causal LM config:
  - architecture: `HunYuanDenseV1ForCausalLM`
  - hidden size: 2048
  - layers: 32
  - attention heads: 16
  - KV heads: 4
  - vocab size: 120818
  - max position embeddings: 262144
  - dtype: bfloat16

HF GGUF variants:

- `AngelSlim/Hy-MT1.5-1.8B-1.25bit-GGUF`
- `tencent/Hy-MT1.5-1.8B-1.25bit-GGUF`
- `AngelSlim/Hy-MT1.5-1.8B-2bit-GGUF`
- Current backend-compatible `tencent/HY-MT1.5-1.8B-GGUF`
  Q4_K_M file is already used locally on Mac.

### Can the HF 1.25-Bit Model Be Used Directly on iOS?

No, not directly.

Reasons:

- The safetensors model is not an iOS runtime format.
- The model architecture is Hunyuan-specific, not a Core ML-ready standard app
  model.
- The 1.25-bit compactness depends on custom STQ/Sherry layout and kernels.
- The GGUF file requires llama.cpp support for `STQ1_0`.
- The upstream llama.cpp STQ1_0 PR is open as of this audit.
- The documented 1.25-bit run path uses CPU-only llama.cpp (`-ngl 0`), so
  Metal offload should not be assumed.
- The current repo already recorded failure with tested llama.cpp runtimes:
  invalid/unsupported GGUF type 42.

### Conversion Realism

#### GGUF / llama.cpp

Most realistic first on-device route. It aligns with the current Mac backend
and existing model files. The blocker is the exact quantization:

- Q4_K_M works on Mac and is llama.cpp-standard, but the model file is about
  1.1 GB before app packaging overhead and runtime memory.
- 1.25-bit is appropriately sized for mobile packaging, but requires the
  `STQ1_0` branch and iOS ARM64 validation.
- 2-bit GGUF is smaller than Q4 and larger than 1.25-bit, but its card says
  optimized for SME2-capable devices and the llama.cpp kernel is still "coming
  soon"; iPhone A-series support must be measured, not assumed.

#### Core ML

Possible only as a longer research effort. Real blockers:

- Need PyTorch/HF support for `HunYuanDenseV1ForCausalLM`.
- Need to express token-by-token autoregressive generation outside or inside
  Core ML.
- Need tokenizer/template integration in Swift.
- Custom 1.25-bit STQ quantization is not a Core ML weight format.
- BF16/FP16 Core ML package is likely too large and memory-heavy for Quick Look.
- ANE acceleration is unlikely unless the model graph maps cleanly to supported
  Core ML ops and precision.

#### MLC-LLM / Metal

Promising for iOS LLMs in general. MLC has an iOS Swift SDK, model packaging,
compiled model libraries, tokenizer libraries, and Metal support on Apple
A-series GPUs. Blockers:

- Hy-MT/Hunyuan architecture and tokenizer would need MLC conversion support.
- AngelSlim 1.25-bit STQ quantization is not known to be supported.
- Bringing a custom model through MLC is a compiler/runtime project, not a small
  app integration.

#### ExecuTorch

Worth tracking, but not the first path. ExecuTorch provides experimental iOS LLM
components and Swift bridging around `.pte` models and tokenizers. Blockers:

- Need export/lowering from the Hunyuan model to ExecuTorch `.pte`.
- Need quantization support matching Hy-MT 1.25-bit or an acceptable larger
  quantization.
- Need custom tokenizer and special token handling.
- This is likely harder than llama.cpp because the current backend is already
  GGUF/llama.cpp-shaped.

### License and Packaging Risks

AngelSlim toolkit code is Apache-2.0, but the Hy-MT model weights use the
Tencent HY Community License. Important risks:

- The license territory excludes the European Union, United Kingdom, and South
  Korea.
- Distribution to third parties has notice/disclosure obligations.
- Products/services using Tencent HY must disclose provider identity and
  non-affiliation.
- Use is subject to an acceptable-use policy.
- If products/services exceed 100M monthly active users, separate licensing is
  required.
- Outputs/results must not be used to improve another AI model other than
  Tencent HY or derivatives.

Conclusion:

- Personal prototype: reasonable after accepting the model license.
- TestFlight/internal testing: possible but needs explicit license review.
- App Store/global distribution: high legal/product risk until counsel reviews
  territory exclusions, notices, model packaging, and user disclosures.

## Runtime Path Comparison

| Path | Feasibility | Complexity | Expected iPhone performance | Size/memory risk | Swift integration | Quick Look timeout fit | Streaming | Current realism |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| A. llama.cpp iOS + GGUF | Highest | Medium to high | Unknown; good if small quant and warm model; Q4 may be slow/heavy | Q4 about 1.1 GB file plus KV/runtime; 1.25-bit about 440 MB but custom kernel | C/C++ bridge or XCFramework plus actor wrapper | Warm model maybe; cold load likely risky | Yes, via token callback | Best first prototype path |
| B. Core ML conversion | Low to medium | High | Could be good if graph converts and ANE/GPU used; uncertain | FP16/BF16 likely very large; custom STQ unsupported | Native Swift once converted | Cold load and autoregressive loop risky | Manual token loop possible | Not first path |
| C. MLC-LLM / Metal | Medium | High | Potentially good on Apple GPU for supported converted models | Needs MLC weights/libs; memory controlled by context/prefill settings | MLC Swift API exists | Possible after tuned compile | Yes | Good second research path if Hunyuan conversion works |
| D. ExecuTorch/mobile | Medium-low | High | Unknown for this model; depends on export/backend | `.pte` plus tokenizer; custom quant unknown | Official experimental Swift bridge exists | Unknown | Yes | Track, not first |
| E. Keep Mac backend fallback | Already working | Low | Proven: 12/12 in about 6s, 37/37 in about 8.4s in recent tests | iPhone memory low; Mac carries model | Already integrated | Proven within current mode | Batch-level only today | Must remain default |

### Path A: llama.cpp on iOS with GGUF

Pros:

- Same family as current backend.
- GGUF model files already exist locally.
- C API can be wrapped in Swift.
- llama.cpp has iOS examples and XCFramework/package patterns.
- Streaming token callbacks are realistic.

Cons:

- 1.25-bit depends on `STQ1_0` support not yet merged upstream.
- Current PR is CPU/NEON-focused; Metal offload should not be assumed.
- Q4_K_M package size is large.
- AppIntent extension-like execution has tight latency/memory expectations even
  though this is an app intent in the app target.
- Cold load may exceed Quick Look tolerance.

Recommendation:

- Use this path first, but only in a separate smoke test.
- Prove a tiny known GGUF on device before Hy-MT.
- Then test Q4_K_M, then 2-bit, then 1.25-bit STQ1_0.

### Path B: Core ML

Pros:

- Native Apple deployment story.
- Potential CPU/GPU/ANE scheduling.
- Model package can be bundled or downloaded.

Cons:

- Conversion burden is high.
- Hunyuan-specific architecture may need custom conversion work.
- Autoregressive generation and tokenizer/template handling remain app work.
- 1.25-bit compression advantage is likely lost.

Recommendation:

- Do not use as Phase 1.
- Revisit only if a community/Core ML conversion for Hy-MT/Hunyuan appears or
  if llama.cpp cannot meet AppIntent latency.

### Path C: MLC-LLM / Metal

Pros:

- Official iOS Swift SDK path.
- Metal on Apple A-series GPUs.
- Supports bundled weights and model packaging.
- Has knobs for context window and prefill chunk size.

Cons:

- Needs MLC-converted model weights and compiled model library.
- Hunyuan/Hy-MT support is not established in this repo.
- STQ1_0/AngelSlim quantization support is not established.

Recommendation:

- Promising for a Phase 2/3 research branch, not the first smoke test.

### Path D: ExecuTorch

Pros:

- Official iOS LLM runner exists with Swift bridging.
- Explicit load-before-generate API fits the desired warmup architecture.

Cons:

- Requires `.pte` model export.
- Custom quantization support is unknown.
- Less aligned with current GGUF backend.

Recommendation:

- Keep as a fallback research route if llama.cpp and MLC both block.

### Path E: Remote Mac Fallback

Pros:

- Works today.
- Preserves quality and current successful full coverage behavior.
- Keeps Quick Look translator usable while local inference matures.

Cons:

- Requires Mac server, LAN IP, and network reachability.
- Not portable or fully private to the phone.

Recommendation:

- Keep as default until on-device path has repeated real-device success.

## Recommended Architecture

The current Quick Look provider should become a small backend orchestrator, but
only after the isolated on-device smoke test works.

### Modes

Add a Quick Look MT backend mode:

```swift
enum QuickLookMTBackendMode {
    case remoteMacHyMT
    case onDeviceHyMTExperiment
    case disabled
}
```

Required behavior:

- `remoteMacHyMT`
  - Current HTTP behavior.
  - Default mode.
  - Keeps health preflight, batch size, time budget, fail-fast, and diagnostics.

- `onDeviceHyMTExperiment`
  - Loads and calls a local model actor.
  - Off by default.
  - Must have its own short health/readiness probe.
  - Must fail fast if model assets/runtime are unavailable.
  - Must not loop through repeated cold-start attempts.

- `disabled`
  - Returns `.disabled` or passthrough/no-overlay behavior.
  - Useful for debugging OCR/overlay without neural MT.

### Protocol Shape

Suggested future protocol:

```swift
protocol QuickLookMTBackend: Sendable {
    var identifier: String { get }
    func checkAvailability(timeout: TimeInterval) async -> QuickLookMTBackendHealth
    func translate(
        blocks: [QuickLookMTBlock],
        sourceLanguage: String,
        targetLanguage: String,
        deadline: Date
    ) async throws -> QuickLookMTResponse
}
```

Suggested concrete backends:

- `RemoteMacHyMTBackend`
  - Wraps the existing `QuickLookLocalMTClient`.

- `OnDeviceHyMTExperimentalBackend`
  - Wraps `HyMTLocalEngine`.
  - Uses identical request/response structs where possible.

- `DisabledQuickLookMTBackend`
  - Returns no translations immediately.

Suggested orchestrator:

```swift
struct QuickLookMTBackendOrchestrator {
    let mode: QuickLookMTBackendMode
    let fallbackPolicy: QuickLookMTFallbackPolicy
    let remote: RemoteMacHyMTBackend
    let onDevice: OnDeviceHyMTExperimentalBackend
    let disabled: DisabledQuickLookMTBackend
}
```

Fallback policies:

```swift
enum QuickLookMTFallbackPolicy {
    case none
    case remoteIfOnDeviceUnavailable
    case noOverlayIfOnDeviceUnavailable
}
```

For development, use:

```text
mode = remoteMacHyMT
fallbackPolicy = none
```

For controlled local experiments:

```text
mode = onDeviceHyMTExperiment
fallbackPolicy = remoteIfOnDeviceUnavailable
```

For pure local profiling:

```text
mode = onDeviceHyMTExperiment
fallbackPolicy = noOverlayIfOnDeviceUnavailable
```

### On-Device Engine Shape

The local engine should be isolated behind an actor:

```swift
actor HyMTLocalEngine {
    enum State {
        case unloaded
        case loading
        case ready(modelID: String)
        case failed(reason: String, retryAfter: Date)
    }

    func loadIfNeeded(deadline: Date) async throws
    func warmupIfNeeded(deadline: Date) async throws
    func translate(_ text: String, deadline: Date) async throws -> String
    func unloadForMemoryPressure()
}
```

Design rules:

- One model context per process initially.
- Serialize generation until correctness and memory behavior are proven.
- Cache failed load state briefly to avoid repeated cold-start loops.
- Provide explicit load, warmup, translate, and unload telemetry.
- Do not load the model inside `QuickLookIntentRunner` until smoke tests prove
  load time and memory.
- Treat AppIntent cancellation/deadline as a first-class input.

### Configuration Rules

Do not change the current config values in this phase.

Future additions should preserve current behavior:

```swift
static let backendMode: QuickLookMTBackendMode = .remoteMacHyMT
static let onDeviceExperimentEnabled = false
static let onDeviceFallbackPolicy: QuickLookMTFallbackPolicy = .remoteIfOnDeviceUnavailable
static let onDeviceLoadTimeout: TimeInterval = 3.0
static let onDevicePerBlockTimeout: TimeInterval = 2.0
```

The values above are design placeholders, not implementation in this phase.

## Minimal First Prototype

The first prototype should not translate screenshots.

Goal:

```text
On a real iPhone, load a tiny local GGUF model, translate or generate from one
hardcoded Chinese string, log output, load time, peak/resident memory if
available, and latency.
```

Preferred sequence:

1. Create an isolated iOS smoke-test target or debug-only screen.
2. Integrate llama.cpp iOS using an XCFramework or local source package.
3. Bundle or side-load a tiny known GGUF model.
4. Run one hardcoded prompt:

   ```text
   Translate the following Chinese text into natural English. Only output the English translation, no explanation.

   Chinese:
   网络错误，请重试

   English:
   ```

5. Log:
   - runtime build/version
   - model file path and size
   - load start/end/duration
   - first token latency
   - total generation latency
   - generated token count
   - tokens/sec
   - memory before load, after load, after generation, after unload
   - final text
6. Keep this outside the Quick Look path until stable.

If the tiny model works:

1. Test the current Mac-compatible Q4_K_M Hy-MT GGUF on iPhone.
2. If Q4 is too large/slow, test 2-bit GGUF if llama.cpp support is usable.
3. Test 1.25-bit only with the `STQ1_0` branch and CPU-only settings first.
4. Compare prompt formatting:
   - Current plain completion prompt.
   - Official chat-template/Jinja prompt.
5. Only after repeated success, wire into `QuickLookMTBackendMode`.

## Risk Register

| Risk | Severity | Likelihood | Notes | Mitigation |
| --- | --- | --- | --- | --- |
| 1.25-bit GGUF unsupported in stable llama.cpp | High | High today | Current repo saw invalid GGUF type 42; PR #22836 is open | Test PR branch in isolated target only |
| CPU-only STQ1_0 too slow on iPhone | High | Medium | Official examples use `-ngl 0`; no Metal assumption | Measure on real device before Quick Look |
| Q4_K_M model too large for app/package/memory | High | Medium | Local file about 1.1 GB | Use only for lab test; do not ship |
| Cold model load exceeds Quick Look timeout | High | High | Quick Look runner has 15s total timeout | Warm engine outside Quick Look or keep remote fallback |
| Memory pressure kills AppIntent/app | High | Medium | Model plus KV/cache can exceed memory headroom | Small context, one context, unload on pressure |
| Tokenizer/template mismatch hurts quality | Medium | Medium | Current backend uses plain prompt; HF card has chat template | Compare prompts in smoke test |
| App Store license/compliance blockers | High | Medium | Tencent HY Community License has territory/disclosure limits | Legal review before distribution |
| Xcode/C++ integration instability | Medium | Medium | llama.cpp/Metal/CMake/XCFramework can churn | Isolate in package/target; pin commit |
| Repeated fallback loops cause latency | Medium | Medium | Local failure followed by remote fallback can exceed budget | Cache failures and use deadlines |
| Overlay regression from backend change | Medium | Low if scoped | Overlay expects same `QuickLookDictionaryTranslation` shape | Keep response contract identical |
| Dictionary runtime accidentally re-enabled | Medium | Low | User explicitly disabled it for final translations | Keep config unchanged; add tests if code changes |

## Phased Implementation Plan

### Phase 0: Documentation and Audit

Status: this document.

Rules:

- No source changes.
- No AppIntent signature changes.
- No Quick Look pipeline changes.
- Preserve Mac backend as default.

### Phase 1: Isolated llama.cpp iOS Smoke Test

Scope:

- New debug-only target/screen or separate sample target.
- llama.cpp integrated in the smallest possible way.
- Tiny GGUF model only.
- One hardcoded Chinese prompt.
- Logs and metrics only.

Acceptance criteria:

- Builds on simulator if possible and real iPhone at minimum.
- Loads tiny model without crash.
- Generates non-empty text.
- Reports load time, first token latency, total latency, tokens/sec, memory.
- Does not touch Quick Look.

### Phase 2: Hy-MT Lab Test Outside Quick Look

Scope:

- Reuse smoke-test harness.
- Test Q4_K_M GGUF first because it already works on Mac.
- Test 2-bit GGUF if runtime support is available.
- Test 1.25-bit STQ1_0 branch only after branch builds for iOS.

Acceptance criteria:

- One Chinese-to-English prompt works.
- Five representative OCR block prompts work.
- Load and generation metrics are captured.
- Quality is comparable enough to Mac backend on sample phrases.
- Memory remains below practical real-device limits.

### Phase 3: Backend Abstraction, Still Remote Default

Scope:

- Add Quick Look backend abstraction.
- Implement `RemoteMacHyMTBackend` by wrapping existing client.
- Add disabled backend.
- Keep `remoteMacHyMT` default.
- Unit test selection/fallback behavior.

Acceptance criteria:

- Existing full-coverage Hy-MT behavior remains unchanged.
- Existing request/response contract remains unchanged.
- `git diff` shows no AppIntent/OCR/overlay behavioral churn except injection
  points needed for backend selection.

### Phase 4: Experimental On-Device Backend

Scope:

- Add `OnDeviceHyMTExperimentalBackend`.
- Use `HyMTLocalEngine` actor.
- Feature flag off by default.
- Fallback policy configurable.
- Keep dictionary runtime disabled.

Acceptance criteria:

- If model assets are missing, failure is immediate and non-crashing.
- If local model fails, fallback follows configured policy.
- No repeated load attempts inside one Quick Look run.
- Remote mode still passes existing manual screenshot tests.

### Phase 5: Quick Look Real Screenshot Trial

Scope:

- Try one or two blocks first, not 37 blocks.
- Gradually increase block count.
- Compare against Mac backend output and overlay rendering.

Acceptance criteria:

- Short CJK UI label translates.
- Long chat bubble translates.
- Overlay rendering unchanged.
- Total Quick Look return time stays inside timeout on warm engine.
- Cold start behavior is documented and acceptable or avoided.

### Phase 6: Distribution Review

Scope:

- Model license review.
- App Store package size/on-demand resource strategy.
- User disclosure copy.
- Privacy language.
- Territory constraints.

Acceptance criteria:

- Written go/no-go decision for public distribution.

## Test Matrix

### Unit Tests After Backend Abstraction

| Area | Test |
| --- | --- |
| Backend mode selection | `.remoteMacHyMT` chooses HTTP backend |
| Backend mode selection | `.disabled` returns no translations immediately |
| On-device unavailable | Missing model returns fail-fast unavailable outcome |
| Fallback policy | On-device failure falls back to remote only when configured |
| Deadline handling | Backend refuses to start a batch after deadline |
| Response mapping | Backend translations still become `.localMT` dictionary-shaped hits |
| Dictionary disabled | Unknown CJK is skipped, not dictionary-rendered |
| Full coverage mode | Priority/max block caps remain disabled |

### Smoke-Test Metrics

| Metric | Required |
| --- | --- |
| Model file size | Yes |
| Runtime commit/version | Yes |
| Device model/iOS version | Yes |
| Load latency | Yes |
| Warmup latency | Yes |
| First token latency | Yes |
| Total generation latency | Yes |
| Tokens/sec | Yes |
| Memory before/after load | Yes |
| Memory after generation | Yes |
| Output text | Yes |
| Error classification | Yes |

### Manual Screenshot Regression

| Scenario | Expected |
| --- | --- |
| No CJK screenshot | Existing "No Chinese text detected" fallback |
| Seller/chat screen | 12/12 Hy-MT blocks through remote default |
| Dense Taobao screen | 37/37 Hy-MT blocks through remote default while budget allows |
| Backend unavailable | Health preflight fail-fast, no crash |
| Debug OCR intent | Diagnostic PNG return unchanged |
| Echo intents | PNG return unchanged |

## Rollback Plan

Rollback must be simple:

1. Keep `remoteMacHyMT` as default until on-device is proven.
2. Keep the Mac FastAPI backend and `/translateBlocks` contract intact.
3. Keep on-device code behind a compile-time or runtime feature flag.
4. If local engine crashes, stalls, or regresses output, switch config back to:

   ```text
   backendMode = remoteMacHyMT
   onDeviceExperimentEnabled = false
   ```

5. If backend abstraction itself causes regressions, revert only the abstraction
   patch. Since Phase 1 and Phase 2 are isolated, they should not affect Quick
   Look.
6. Do not delete model/runtime experiments immediately; archive measurements so
   future runtime updates can be compared.

## Exact Next Codex Prompts for Phase 1 Prototype

Prompt 1: create a smoke-test implementation plan only.

```text
You are GPT-5.5 Codex acting as a senior iOS/Swift and on-device inference engineer.

Repository: /Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator

Read docs/on_device_hymt_feasibility_plan.md. Do not modify the Quick Look pipeline.
Create an implementation plan for Phase 1 only: an isolated llama.cpp iOS smoke test
that loads a tiny GGUF model, runs one hardcoded Chinese-to-English prompt, and logs
load time, memory, first-token latency, total latency, tokens/sec, and output.

Do not edit source code yet. Identify the least invasive target/package structure,
runtime integration option, model asset handling, and exact files that would change.
Return a step-by-step plan and risk checklist.
```

Prompt 2: implement only the tiny smoke-test scaffold.

```text
You are GPT-5.5 Codex acting as a senior iOS/Swift and on-device inference engineer.

Repository: /Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator

Read docs/on_device_hymt_feasibility_plan.md and the Phase 1 implementation plan.
Implement only the isolated smoke-test scaffold. Do not change AppIntent signatures,
OCR, Quick Look rendering, QuickLookLocalMTConfig defaults, dictionary runtime flags,
or the Mac backend. The scaffold should be unreachable from production Quick Look
unless explicitly launched from a debug-only path.

Use a tiny known GGUF model or a model-path stub if the model asset is not available.
Add logging hooks for load time, memory, first-token latency, total latency,
tokens/sec, and output. If llama.cpp is not integrated yet, create the Swift protocol
and stub runner so the UI/logging harness can compile without model inference.

Run safe checks and report every file changed.
```

Prompt 3: test Hy-MT GGUF outside Quick Look.

```text
You are GPT-5.5 Codex acting as an on-device inference engineer.

Repository: /Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator

Use the existing isolated smoke-test harness only. Do not touch the Quick Look
pipeline. Replace the tiny GGUF test asset with the current Hy-MT Q4_K_M GGUF path
or a documented side-loaded path. Run one hardcoded Chinese-to-English prompt and
five representative OCR block prompts. Measure load time, memory, first-token
latency, total latency, tokens/sec, output quality, and errors. Summarize whether
Q4_K_M is realistic on iPhone and whether to proceed to 2-bit or 1.25-bit.
```

Prompt 4: investigate STQ1_0 iOS branch.

```text
You are GPT-5.5 Codex acting as a llama.cpp mobile runtime engineer.

Repository: /Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator

Do not touch ScreenTranslator source yet. In a separate external build directory,
check whether llama.cpp PR #22836 or its successor can build for iOS arm64 with
STQ1_0 support. Record exact commit, build flags, whether the 1.25-bit Hy-MT GGUF
loads, whether generation works with -ngl 0, and measured latency/memory on a real
iPhone if available. Produce a markdown report before proposing any app integration.
```

## Go / No-Go Decision

Go for Phase 1:

- Yes. A tiny isolated llama.cpp iOS smoke test is the safest next step.

No-go for direct Quick Look integration now:

- The 1.25-bit path depends on unmerged/runtime-specific `STQ1_0` support.
- Q4_K_M is too large to assume acceptable for iPhone Quick Look.
- Cold-start and memory pressure are unmeasured.
- License/distribution constraints are not yet resolved.

Answer to the core question:

```text
We can realistically investigate moving Hy-MT onto iPhone, and a personal
prototype is plausible. The safest first implementation step is not screenshot
translation. It is an isolated llama.cpp iOS smoke test with a tiny GGUF model,
then measured Hy-MT GGUF tests, while preserving the current Mac backend as the
default working Quick Look path.
```
