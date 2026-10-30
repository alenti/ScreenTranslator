# October 2026 migration — Phase 1

Updated: 2026-10-08, Asia/Shanghai. Scope: the original application's normal
`TranslateScreenshotIntent` flow only. No commit or push. Phase 2 has not started.

## Acceptance verdict

**PASS WITH QUALITY WORK.** The physical normal flow works through **Action
Button → existing Shortcut → original ScreenTranslator → new local core → full
viewer**. The user confirmed cold launch, rapid second invocation and an
already-open app; diagnostics corroborate cancellation, newer-request completion
and model reuse. EN/RU, cancel/retry, viewer, details, share and save passed.
No old translator was used for route A. Real screenshot OCR and overlay quality
remain imperfect: small rows do not fit and centered paragraph panels overlap.
This verdict establishes Phase 1 integration, not production translation quality
or an exhaustive lifecycle/stress guarantee.

## Repository state and preservation

Repository: `/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator`.
Original target/scheme: `ScreenTranslator`; product: `ChinaTap Screen Translator`;
bundle: `AlenShamatov.ScreenTranslator`. The separate Next target retains its identity.

HEAD at the start: `19d01e24aadd45847b277c2626308927a4cc3638`, `main` / `origin/main`.
There were already 17 modified tracked files, 3,934 insertions and 244 deletions,
and substantial untracked development work. The existing OPUS model change and
the existing Quick Look/server edits belong to that baseline, not this phase.

The complete initial status, short status, diff, diff stat, recent log and
216 file SHA-256 values are saved outside the repository in
`../BuildArtifacts/oct2026/migration-phase1/git-before/`.
At the current comparison, 22 baseline files changed intentionally, 194 retain
their exact initial hash, and none is missing. Quick Look translation files,
server files and existing model resources retain their initial hashes.

Changed existing files:

- `App/AppCoordinator.swift`, `App/AppEnvironment.swift`, `App/AppServices.swift`.
- `Core/Models/AppError.swift`, `Core/Services/Storage/TemporaryImageStore.swift`.
- `Features/Errors/ErrorViewModel.swift`.
- `Features/Processing/ProcessingView.swift`, `ProcessingViewModel.swift`.
- `Features/ResultOverlay/ResultOverlayView.swift`, `ResultOverlayViewModel.swift`.
- `Features/Settings/SettingsView.swift`, `SettingsViewModel.swift`.
- `Intents/TranslateScreenshotIntent.swift`, `ScreenTranslatorApp.swift`.
- `ScreenTranslator-Bridging-Header.h`, `ScreenTranslator.xcodeproj/project.pbxproj`,
  `SupportingFiles/Info.plist`.
- The existing shared Next `ScreenshotProcessor.swift`, `TextBlocks.swift`,
  `HyMTNative.h`, `HyMTNative.mm`, and `tools/runtime/checks.swift`.

New files: `Config/HyMTCore.xcconfig`, `Core/Phase1Checks.swift`,
`tools/runtime/make_phase1_shortcut.py`, and this report.
No reset, clean, stash, checkout-over-files, stage, commit or push was used.

## Architecture before and after

Before, route A used:

```text
TranslateScreenshotIntent → owned IntentFile bytes → persisted handoff
→ app activation/router → ProcessingViewModel → ProcessingOrchestrator
→ legacy normalizer/OCR/grouping/batch/provider/session/rendering graph
→ OverlayRenderResult → full viewer
```

Route A now uses:

```text
TranslateScreenshotIntent → owned bytes → atomic persisted handoff + notification
→ active AppEnvironment drain → ProcessingViewModel
→ shared ScreenshotProcessor.process(image, target, app-owned engine, requestID)
→ upright pixels → Vision → compact grouping → protected spans
→ Hy-MT2-7B, sequential generation → stable-ID mapping → one rendered UIImage
→ ProcessedScreenshot → existing full viewer / details / share / Photos save
```

The original target references the **same** Next source files, model manifest,
native bridge, Jinja library and runtime. There is no copied second core, new
provider protocol, backend selector, factory, fallback chain or new service locator.
The old container remains for unmigrated routes. Route A does not call its
orchestrator or silently fall back to Apple, dictionary, remote or legacy local MT.

## Model, runtime and installation

| Item | Pinned value |
|---|---|
| Model | Tencent Hy-MT2-7B-Q4_K_M |
| Revision | `ab8472660ac61fac25f1af43fac2599d52a8a775` |
| Size | 4,624,648,896 bytes |
| SHA-256 | `9f96256500f3fc1ab4d64336b58f52a949a95ad7516b0c229476eef782f9f77b` |
| Runtime | llama.cpp v0.6.0 / b11429 |
| Runtime commit | `d81235049384534c167caea52b85a694f6103d14` |
| Runtime source archive SHA-256 | `6b58785f0a82898f4c3442417ff962e2d4b231b1bee5d033902ad90b27901e14` |
| Context / maximum output | 2,048 / 512 tokens |
| Sampling | temperature 0.7, top-p 0.6, top-k 20, repeat penalty 1.05, seed 42 |

The original app has its own `Documents/model.gguf`. No access to the Next
container is hard-coded. Presence, exact size and streamed SHA-256 are checked
before native load. Import copies into a temporary file, verifies it, then
replaces the installed file. A failed verification preserves the existing model.
Settings offers manual verified import and reports readiness. The final production
download system is intentionally deferred.

The existing embedded 7B Jinja template, Chinese translation instruction,
Metal offload, EOG termination and sequential block generation remain unchanged.
The shared runtime/framework/Jinja artifact hashes were checked against the
recorded runtime manifest. Native load confirmed the Apple A19 Pro GPU.

## Handoff, lifecycle and cancellation

`IntentInputDecoder` still makes a deep owned copy of `IntentFile.data`.
`TemporaryImageStore.shared` is the one store/claim actor. It atomically writes
the latest request, enforces freshness and remembers claimed request IDs.
Successful claim removes the pending file; replaying a claimed ID is rejected.

After route A persists, it posts a notification on the main actor. The foreground
app drains on both activation and notification. A drain-again flag covers a
notification arriving while an earlier drain is awaiting the store actor.
No polling loop, daemon or queue framework was added.

On iOS 26 route A declares foreground supported modes. `openAppWhenRun` remains
for the iOS 18 deployment compatibility path. `perform()` validates/copies/stores
and returns; it does not own or run the 7B engine.

`AppEnvironment` owns one `HyMTTranslator` actor and one native instance.
The actor owns the one model/context. While active, retries/subsequent requests
reuse the prepared engine. Background cancels, joins native work and unloads;
inactive cancels without submitting another block. A newer request arriving
during that join prevents a stale unload from freeing its context.

Replacement cancels the old Swift task, sets the native atomic cancellation
flag, awaits the old task, then begins the newer request. Generation no longer
resets cancellation per block. The explicit request boundary resets it once,
with Task checks before/after. Verification/load/warmup have cancellation checks;
native model load has a cancellation progress callback. Unload is actor serialized.
Request/run-ID guards discard stale progress, completion and error callbacks.

The app disables idle sleep while its local job runs, restores it at exit, and
cancels/joins/unloads on a memory warning. Debug exports count memory warnings.
Debug cancellation records measure request-to-processing-exit latency;
`nativeReturnedBy` is an upper bound on native exit, not an instrumented
GPU/kernel timestamp. The physical cancel test measured 24.0 ms to that safe
processing exit bound, followed by a successful retry.

## Result contract and viewer

`ProcessedScreenshot` contains request ID, EN/RU target, original/rendered
UIImage, `[ProcessedBlock]` and `[ProcessingWarning]`. Each block contains its
stable Int OCR ID, source/translated text, source rectangle, actual rendered
rectangle and optional failure. Runtime dictionaries are diagnostic exports;
the viewer does not read them as its data contract.

The old `TextBlock` collision was resolved by renaming the shared compact OCR
type to `OCRBlock`. The existing UIKit zoom component's UUID hotspot IDs are
deterministic projections of those Int IDs. Original mode uses source geometry;
translated mode uses actual rendered geometry, with source geometry for failed
unrendered blocks. Failed blocks remain inspectable.

The existing full viewer retains original/translated switching, zoom/pan,
double-tap, block sheets, text list/copy, sharing and Photos saving. It displays
the processor's finished image directly; route A does not run the old SwiftUI
overlay fallback. Share writes that rendered PNG to a temporary file, and save
uses the rendered UIImage. Partial results expose warnings and retry. The warning
summary distinguishes translation failures from labels that did not fit; a
rendering warning in block details retains the generated translation as well.

One temporary legacy initializer converts the untouched floating route's old
full-viewer result for compilation. The lightweight floating flow and separate
Quick Look intent are not rewired in this phase.

## Checks and builds

- Original app Debug and Release builds succeeded.
- Next Debug build succeeded with the shared source changes.
- Compact host checks passed for geometric grouping and protected-span integrity.
- Physical Debug contract checks passed: claim once, latest pending request wins,
  stable IDs, source/rendered geometry, protected spans, missing model, wrong
  size/hash, cancellation before load, typed partial failure and EN/RU propagation.
- `git diff --check` passed.

Contract checks do not substitute for real cancellation, native replacement,
language or Shortcut UI acceptance. The legacy unit-test target has pre-existing
module/test-host/source-list inconsistencies (`ScreenTranslator` versus the
actual `ChinaTap_Screen_Translator` module/product). It was not revived by adding
old providers; these bounded checks cover the changed contracts instead.

## Physical iPhone evidence

Device: iPhone 17 Pro Max, `iPhone18,2`, iOS 26.5.1 / 23F81.
The original bundle was installed, with its own verified model.
Phone actions are performed by the user at their request. Monitoring/export and
build/install use the command line; Mirroring is not reconnected during capture.

The test Shortcut was generated as a binary plist and signed with Apple's
`shortcuts sign`. Its App Intent identity comes from the built original app's
metadata. `Phase1 Translate Files` opens Files, waits two seconds, takes a
screenshot and passes its output to the original `TranslateScreenshotIntent`.
It preserves the existing installed shortcuts.

### Initial capture failure and diagnosis

With iPhone Mirroring active, four received input PNGs were 1320×2868, fully
opaque and contained **zero non-black pixels**. The latest raw input hash was
`798b4ef3d4bca1cd0ecdad537e01fab17be201fdc85ebb3e765a380ba783cb9f`.
A separate device screenshot capture also produced opaque black pixels.
The app saved the received bytes before redraw/OCR, so the input was already
black before the new processor touched it.

After the user closed Mirroring, unlocked the physical phone and ran the same
Shortcut there, a 5,067,152-byte PNG containing the Chinese PDF arrived and
translation completed. This establishes the capture-context problem for this
device/test setup; it does not claim that all mirroring configurations always
behave this way. The empty-OCR error now gives a readable screenshot/Mirroring
retry instruction instead of exposing internal grouping terminology.

### First real Chinese PDF → Russian result

Request: `5F5275E1-6BA7-4FFF-864A-08ADCAC9CCDE`.
Source: Files PDF `注塑杯盖 (3)`, with product photos, headings, description and
small five-column specifications partially clipped at the bottom of the screen.
This is a real available document capture, not a synthetic commerce/chat fixture.

| Metric | Observed |
|---|---:|
| Model already loaded | No |
| SHA-256 verification | 1,962 ms |
| Native load | 811 ms |
| Warmup | 564 ms, 3 output tokens, EOG |
| OCR | 241 ms |
| OCR observations / translation blocks | 26 / 21 |
| Grouping | 0.135 ms |
| Translation, including model preparation | 49,633 ms |
| Render | 18 ms |
| Processor total | 49,955 ms |
| Output tokens across blocks | 425 |
| Generation/protected-span failures | 0 |
| Render-fit failures | 10 |
| Maximum sampled footprint | 422.13 MiB |
| End resident memory | 4,477.83 MiB |
| End thermal state | nominal (0) |
| Low Power Mode | off |
| Power | charging |

These are processor timings; they do not include manual Shortcut interaction
or intent-to-viewer wall time. Clean mmap residency and physical footprint are
different measurements, not a claim that a 4.62 GB model occupies only 422 MiB.
Charging remained connected; this is not the requested unplugged thermal batch.
That installed build preceded the final memory-warning-count diagnostic fields.

The user confirmed physically that Original/Translated switching, enlargement,
translated-block detail, Share and Save all work. The app displayed a partial
rendered result and retained successful translations. A saved rendered PNG and
per-block/raw OCR report were exported.

### Quality observations, classified before changes

- **OCR:** small clipped labels at the bottom include wrong characters, such as
  `1000日/箱` where the product specification is not a number of days. No dictionary
  or repair fallback was introduced to conceal OCR mistakes.
- **GROUPING / RENDERING:** two centered wrapped description lines remain separate
  blocks, and their expanded translation panels overlap. This is a shared Next
  renderer/grouping limitation exposed by the real screenshot, not a duplicate
  SwiftUI overlay.
- **RENDERING:** ten tiny bottom specification rows cannot fit Russian at the
  current 18 px minimum. They are warnings with retained source/failure markers,
  not silently counted as successfully rendered translations.
- **TRANSLATION:** all generated outputs terminated normally; some Russian product
  terminology is awkward. Generation success does not establish supplier-quality
  translation or correctness of OCR-corrupted text.

### Cancel, retry and warm model reuse

On the installed diagnostic build, the user cancelled during translation,
retried the screenshot, then used the result menu's Re-run Translation. All
three actions worked without a crash. Request
`925ECE17-785A-4C54-9894-4D7785F2CF95`, cancelled run
`76A4270A-873F-4F91-BD6D-03B943125A9C`, recorded **24.035 ms** to processing exit.
The subsequent successful Russian report has `modelReused=true`, 21 blocks,
45,475 ms total, 45,193 ms translation, 231 ms OCR, 12 ms rendering,
zero memory warnings, fair thermal state (1) and charging power state.
Reported physical memory is 12,262,113,280 bytes.

An additional earlier in-app rerun recorded 47,182 ms with `modelReused=true`.
These early Debug reports were stored by request ID and a retry could overwrite
the earlier report for that same screenshot. First-run metrics above were recorded
from the original export before that overwrite. Final Debug exports now include
the unique run ID in their directory, preserving every attempt separately.

### Real Chinese PDF → English

Request: `B75E9D51-F095-4B35-9F26-F650C84804A1`, run
`5E45FDE6-EA2E-40BD-8F8B-C622EF0C54CA`. The user selected English in Settings and
ran the actual test Shortcut; the result appeared without a crash.

| Metric | Observed |
|---|---:|
| Model already loaded | No |
| Verification / native load | 3,045 / 862 ms |
| OCR / translation / render | 250 / 32,823 / 42 ms |
| Total | 33,165 ms |
| Translation blocks / output tokens | 23 / 237 |
| Generation/protected-span errors | 0 |
| Labels that did not fit | 13 |
| End footprint / resident memory | 438.49 / 4,514.36 MiB |
| Memory warnings / end thermal | 0 / nominal (0) |
| Power | charging |

The extra detected blocks include OCR noise in system UI, and small bottom rows
still contain OCR mistakes; e.g. one temperature digit was recognized as 3 rather
than 2. This is a real partial result, not a claim of perfect OCR or rendering.
The user clarified that this English test was invoked once. It is not rapid
replacement evidence. Remaining cold/already-open/replacement tests use the
existing two-action Shortcut assigned to **Action Button**, as required by the
user. Siri is not part of the desired or tested UX.

### Action Button: cold app, replacement and already-open delivery

The user assigned the existing **Open in App Translator** Shortcut to Action
Button and explicitly confirmed all three requested cases without errors:
force-quit/start from a Chinese PDF, another invocation before completion after
returning to the PDF, and invocation from Original inside the foreground app.
The actual command captures the current screen; it does not need Siri or an
Open Files step.

The exports show the combined cold-start/replacement sequence:

1. `5D14F2B6-0EF7-4936-BE71-FD3801FD5DA5`, run
   `DF9DE82A-5370-4858-91B5-45CC60500D61`: screenshot received and processing
   started, then safely cancelled at 01:17:08. Native work had returned by
   processing exit **22.654 ms** after cancellation. It has no completed report
   or output PNG, so no stale successful result was exported.
2. New request `9C19853E-F4B6-4185-819B-C91EAC37D175`, run
   `73802E9B-40CB-4276-9A84-CA9BC03046B1`: completed at 01:17:59,
   `modelReused=false`, 36 blocks, 328 output tokens, **43,394 ms** total.
   Verification/load/warmup: 1,721 / 277 / 545 ms. OCR: 255 ms; translation:
   43,073 ms; rendering: 23 ms. This is the newer screenshot's completed result.
3. Foreground request `E4774647-3B41-425A-97C9-77815CDACDB4`, run
   `97AF8DB9-2794-48AD-AD19-AD1A07A9C73E`: completed at 01:18:51,
   **modelReused=true**, 36 blocks, 328 tokens, **43,426 ms** total.
   It used the same cached load/warmup report and produced the new full viewer.

Both completed Action Button reports have no generation/protected-span errors,
zero memory warnings, fair thermal state, Low Power Mode off and 10 layout-fit
warnings. End footprint/residency: 421.65 / 4,941.34 MiB for replacement and
422.41 / 4,955.34 MiB for the foreground request. Power remained charging.
The final physical screen capture confirms the translated full viewer and its
explicit partial-result banner. Warm reuse avoids reloading but does not remove
the cost of generating 36 translations.

Cold start and replacement were exercised as a combined sequence; the first
request was intentionally superseded. The user confirmed cold app opening and
processing, and the newer request completed in that cold-started app. An
additional uninterrupted force-quit/cold-run trace was not separately collected.
Switching back to the PDF also exercises background cancellation/unload;
same-process foreground delivery is independently corroborated by the third
request's `modelReused=true` report.

### Final acceptance matrix

| Scenario | Current evidence |
|---|---|
| Real Shortcut → original app → new core → result | PASS, Russian PDF run |
| Cold model preparation | PASS, modelReused=false and load/warmup exported |
| Cold app after force quit | PASS, user-confirmed opening/processing in the combined cold/replacement sequence |
| Warm Shortcut launch | PASS, subsequent Action Button requests completed |
| Model reuse while remaining active | PASS, Russian reports modelReused=true |
| Already-foreground handoff | PASS, Action Button from Original, new request and modelReused=true |
| Rapid second invocation / stale-result rejection | PASS, cancelled first request / completed newer request / user confirmation |
| Cancel during native generation | PASS, user confirmation and 24.035 ms exit bound |
| Retry after failure/cancel | PASS, successful cancel/retry and in-app rerun |
| English | PASS, 33.2 s real Shortcut result with layout warnings |
| Russian | PASS, partial rendering / quality limitations above |
| Viewer/detail/share/save | PASS, user physical confirmation |
| No old-translator fallback on A | PASS by call path and native load/generation evidence |
| No crash/native ownership race across lifecycle cases | PASS for this bounded physical batch, not an exhaustive stress guarantee |

## Size, reduction and remaining legacy

Compared with the recorded dirty baseline, tracked Swift files have approximately
240 net added lines. The focused Debug check file is 69 lines; the Shortcut
generator is 45 Python lines and shared build configuration is 6 lines. Existing
untracked Next sources were adapted in place; their changes must not be reported
as all-new code against HEAD. The shared processor is currently 274 Swift lines.
The baseline hash file did not record old untracked source lengths, so no false
exact line count is asserted for those edits.

No legacy bulk deletion was performed. The normal route bypasses the old
orchestrator/router/normalizer/provider/rendering path and viewer fallback.
Unused newly added viewer data helpers were removed. No new translation-service
interface or backend configuration hierarchy was added.

Apple Translation, Quick Look code, CEDICT/dictionaries, server/tooling, old tests
and old native harness sources remain. Original-target build configuration now
links the pinned shared Next runtime; the old native harness enable macro and its
old framework embed phase are detached to avoid incompatible duplicate
`llama.framework` symbols. The old native Debug tools therefore cannot load their
old runtime in this target. Their sources/scripts are preserved, not migrated.
The future ~22.6k legacy-line deletion remains Phase 3 work.

## Artifacts, limitations and exact Phase 2 recommendation

Development evidence is under `../BuildArtifacts/oct2026/migration-phase1/`:
build logs/DerivedData, baseline files, signed Shortcut, `phase1-checks.json`,
`current-prepare.json`, input pixel inspection and exported `current-device-reports/`.
The real run directory contains `input.png`, `result.png` and `report.json`.
Raw product imagery and large runtime/model files were not copied into this report.
Frozen exports are under `captures/ru-cancel-retry-final`, `en-rapid-final`
(the EN run was single invocation despite this development folder name), and
`action-button-final`. The final native screen capture is
`action-button-final-viewer.png`. The first blank device capture originally named
`real-product-source.png` is **not** usable authentic screenshot evidence.

Remaining limitations are shared-core OCR/grouping/rendering quality, long 7B
generation latency, the absence of an unplugged thermal/stress batch, and the
unmigrated floating/Quick Look/legacy stacks. There is no observed Phase 1
integration blocker after the tested normal Action Button flow.

Recommended Phase 2 task, **only after explicit authorization**: connect
`FloatingScreenTranslateIntent`'s persisted `.floatingPreview` request to this
same app-owned `ScreenshotProcessor`/engine; adapt the existing lightweight
floating result view to `ProcessedScreenshot` and its finished image. Inference
stays in the foreground app. Test cold/warm Action Button → floating result,
cancel/replacement and dismissal on this iPhone. Do not route it through the
Quick Look runner or revive an old provider to preserve the presentation.

Before a production-quality rollout, address centered wrapped grouping/overlay
collisions and dense small-row layout using these recorded real inputs. This
quality follow-up is separate from adding another model/backend. No such grouping
or renderer repair, Phase 2 implementation or Phase 3 legacy deletion was started.

No commits or pushes were made. The final installed original app is the tested
Debug build; original Debug/Release, Next Debug, compact host checks and physical
Debug contract checks succeeded. The user-selected English target remains saved.
