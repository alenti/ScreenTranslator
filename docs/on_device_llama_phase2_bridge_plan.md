# Phase 2 On-Device llama.cpp Bridge Plan

Date: 2026-05-19

## Chosen Integration Path

Use an external llama.cpp checkout plus a separately built iOS static library or
XCFramework. Do not vendor llama.cpp source, do not add a git submodule in this
phase, and do not add model files.

This repo now contains only the thin app-facing bridge:

- `Core/Services/OnDeviceMT/Native/OnDeviceLlamaBridge.h`
- `Core/Services/OnDeviceMT/Native/OnDeviceLlamaBridge.mm`
- `Core/Services/OnDeviceMT/OnDeviceLlamaNativeRuntime.swift`
- `ScreenTranslator-Bridging-Header.h`

The bridge is callable from the DEBUG-only smoke-test service, but it still
returns a structured unavailable result until llama.cpp is linked and the real
load/generate calls are implemented.

## Why This Path

- Keeps the app repo small.
- Avoids committing generated third-party build products.
- Avoids changing Quick Look, OCR, overlays, AppIntent signatures, or the Mac
  Hy-MT backend.
- Lets llama.cpp be pinned and rebuilt outside this project before Xcode links
  it.
- Preserves a compiling fallback when the native runtime or model is missing.

## Current Runtime Behavior

1. `OnDeviceLlamaSmokeTestService` checks for `tiny-test.gguf`.
2. If the file is missing, the Swift service returns a structured failure.
3. If the file exists, Swift calls `OnDeviceLlamaNativeBridgeRuntime`.
4. The runtime calls `OnDeviceLlamaBridge.mm`.
5. The Objective-C++ bridge returns:
   - `success = false`
   - output text: `No generation was run.`
   - timings
   - model path
   - error: `llama.cpp runtime is not linked yet.`

This proves the Swift-to-native boundary without requiring llama.cpp to be
available in every checkout.

## Next Native Linking Step

Build llama.cpp outside this repo, for example:

```bash
mkdir -p /Users/notnik_kg/Desktop/Programming/ScreenTranslator/External
cd /Users/notnik_kg/Desktop/Programming/ScreenTranslator/External
git clone https://github.com/ggml-org/llama.cpp.git
cd llama.cpp
git rev-parse HEAD
```

Then create an iOS device build and simulator build, package them as an
XCFramework or a static library pair, and add only the local library reference to
Xcode. Keep that output outside git unless a later decision explicitly vendors a
small binary framework.

When the library is linked:

1. Add llama.cpp headers to the app target header search paths.
2. Add the static library/XCFramework to the app target link phase.
3. Define `SCREENTRANSLATOR_LLAMA_CPP_ENABLED=1` for Debug only.
4. Replace the guarded fallback in `OnDeviceLlamaBridge.mm` with real calls to:
   - load a GGUF model from `modelPath`
   - tokenize the prompt
   - run a small generation loop with `maxTokens`
   - detokenize output
   - unload/free context and model
5. Keep all errors mapped into `OnDeviceLlamaBridgeResult`.

## Tiny Model Placement

Do not commit models.

Place a tiny local GGUF named:

```text
tiny-test.gguf
```

in the app Documents directory. The DEBUG screen displays the exact path it will
read.

## Real iPhone Smoke Test

1. Build and install the Debug app on a real iPhone.
2. Put `tiny-test.gguf` in the app Documents directory.
3. Open the app.
4. Open Settings.
5. Tap `Open Smoke Test` under `On-Device MT Smoke Test`.
6. Tap `Run Smoke Test`.
7. Record output text, load duration, generation duration, total duration,
   tokens generated, memory notes, and any error.

## Acceptance Criteria For The First Real llama.cpp Run

- Missing model produces a visible error, not a crash.
- Invalid model produces a visible error, not a crash.
- Tiny GGUF model loads on a real iPhone.
- One hardcoded prompt using `网络错误，请重试` returns non-empty generated text.
- Quick Look still uses the remote Mac Hy-MT backend unchanged.

## Risks

- The simulator build passing does not prove iPhone memory or Metal behavior.
- llama.cpp iOS build flags may need adjustment for Metal and bitcode-free iOS
  app targets.
- A tiny general GGUF model may not translate well; quality is not a Phase 2
  success criterion.
- Future Hy-MT GGUF may need different tokenizer/prompt handling.
- AngelSlim 1.25-bit and `STQ1_0` remain out of scope.
