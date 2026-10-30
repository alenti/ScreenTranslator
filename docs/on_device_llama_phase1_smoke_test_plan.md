# Phase 1 On-Device llama.cpp Smoke-Test Plan

Date: 2026-05-19

This is the implementation plan for the first isolated on-device inference
probe. It follows `docs/on_device_hymt_feasibility_plan.md` and does not change
Quick Look, OCR, overlays, AppIntents, `QuickLookLocalMTClient`, or the Mac
Hy-MT backend.

## Chosen Path

Path A/B hybrid:

- Add a DEBUG-only SwiftUI screen inside the main app target.
- Add a small `OnDeviceMTService` boundary and a stub
  `OnDeviceLlamaSmokeTestService`.
- Do not vendor or link llama.cpp yet.
- Do not add model files.
- Return a clear failure result until llama.cpp is wired.

This keeps the app compiling while establishing the result shape, UI, model path,
prompt, and logging needed for the real iPhone smoke test.

## Current Scaffold

Files:

- `Core/Services/OnDeviceMT/OnDeviceLlamaSmokeTestService.swift`
- `Features/OnDeviceMT/OnDeviceMTDebugViewModel.swift`
- `Features/OnDeviceMT/OnDeviceMTDebugView.swift`
- `LocalModels/README.md`

The service exposes:

```swift
func runSmokeTest(
    modelURL: URL?,
    input: String
) async -> OnDeviceLlamaSmokeTestResult
```

The result includes:

- input text
- output text
- model path
- load duration
- generation duration
- total duration
- tokens generated
- memory notes
- success/failure status
- error message

The hardcoded input is:

```text
网络错误，请重试
```

Expected rough meaning:

```text
Network error, please try again.
```

The prompt is:

```text
Translate the following Chinese text into natural English. Only output the English translation, no explanation.

Chinese:
网络错误，请重试

English:
```

## Model Handling

Do not commit model files.

For real-device testing, side-load a tiny GGUF model into the app Documents
directory as:

```text
tiny-test.gguf
```

The smoke-test UI displays the resolved Documents path on device. This avoids
adding large binaries to the app bundle or git while the runtime is still
unproven.

## llama.cpp Integration Recommendation

Do not add llama.cpp as a blind vendored source drop in the app tree.

Recommended next step:

1. Clone llama.cpp outside the repo, for example:

   ```bash
   mkdir -p /Users/notnik_kg/Desktop/Programming/ScreenTranslator/External
   cd /Users/notnik_kg/Desktop/Programming/ScreenTranslator/External
   git clone https://github.com/ggml-org/llama.cpp.git
   ```

2. Pin a known commit in the eventual report.
3. Build an iOS arm64 static library or XCFramework from that external checkout.
4. Add only the built framework/library reference to Xcode once the minimal
   build is proven.
5. Add a tiny C/Objective-C++ wrapper with a very small Swift-facing API:

   ```swift
   protocol OnDeviceLlamaRuntime {
       func loadModel(at url: URL) throws
       func generate(prompt: String) throws -> OnDeviceLlamaGeneration
       func unload()
   }
   ```

6. Replace the stub path inside `OnDeviceLlamaSmokeTestService` with the runtime
   adapter.

Preferred packaging option for this project:

- External checkout plus local XCFramework/static library reference.

Why:

- Keeps the ScreenTranslator repo small.
- Avoids generated build artifacts and third-party source churn.
- Lets llama.cpp be pinned and rebuilt independently.
- Avoids touching Quick Look while runtime integration is still unstable.

Avoid for Phase 1:

- Git submodule inside this repo.
- Full source vendoring.
- Adding Hy-MT Q4 or AngelSlim model files.
- Attempting STQ1_0 / 1.25-bit support.

## Real iPhone Run Steps

After llama.cpp is linked:

1. Install the app on a real iPhone in Debug.
2. Side-load `tiny-test.gguf` into the app Documents directory.
3. Open the app.
4. Open Settings.
5. Open "On-Device MT Smoke Test".
6. Tap "Run Smoke Test".
7. Record:
   - model path
   - load duration
   - generation duration
   - total duration
   - tokens generated
   - memory notes
   - output text
   - error message, if any

## Acceptance Criteria

The first non-stub runtime test passes when:

- the app does not crash,
- the tiny GGUF loads,
- generation returns non-empty text,
- metrics are visible in the UI and logs,
- the Quick Look translator still uses the remote Mac backend unchanged.

## Risks

- The selected tiny GGUF may not be a translation model, so output quality is not
  meaningful in Phase 1.
- iOS linking may require Objective-C++ wrapper work and careful C++ standard
  settings.
- Simulator success is not enough; real-device arm64 behavior is the target.
- Model placement in Documents is manual until a later download/bundle strategy
  exists.
- Memory sampling is currently a placeholder and should be replaced with
  resident memory measurement during runtime integration.
