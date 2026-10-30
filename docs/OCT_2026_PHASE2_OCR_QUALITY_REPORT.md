# ScreenTranslator — Phase 2 and OCR / grouping / layout quality

Date: 2026-10-08. Repository: `/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator`.

## Verdict and evidence boundaries

**Phase 2: PASS EXCEPT MANUAL SHORTCUT ACCEPTANCE, for implementation and the autonomous component/route/UI checks described below. Physical acceptance remains open.**

Both foreground routes now call the same processor and app-owned actor. The lightweight preview consumes the completed `ProcessedScreenshot`; Open Full Viewer changes the route and retains that exact image/result. All 16 final EN/RU geometry regressions pass, using fresh translations from the unchanged native core on the Mac. Three focused iOS UI tests pass.

**This is not a PASS for a complete new floating inference run on an iPhone.** The physical iPhone became unavailable. An attempted simulator inference run failed during native warmup with `Generation limit reached without EOG; output rejected`. Completed-result UI checks therefore use a recorded real result DTO, explicitly labelled as presentation checks. A successful foreground iOS inference → floating completion run, actual system Shortcut invocation, and physical timing/readability are deferred to the next user acceptance stage. No manual action was requested in this phase.

| Gate | Result | Evidence scope |
|---|---|---|
| Shared processor / model / engine for A and B | PASS | Source trace; same `environment.engine` and local VM entry point |
| Persistent floating handoff / cancellation / retry / replacement | PASS | Actual `FloatingScreenTranslateIntent.perform()` called in DEBUG foreground app; production store/coordinator/VM |
| Floating progress UI | PASS | XCUITest on iOS 26.5 Simulator |
| Floating completed image / dismissal | PASS for presentation | Recorded completed real result, not a simulated translator |
| Open Full Viewer without another request/load/generation | PASS | Same UIImage identity; counters unchanged; XCUITest |
| OCR/group/layout regressions | PASS for available corpus | iOS production geometry; Mac native translations; 16 structural checks |
| Full new B pipeline completion on iOS | UNVERIFIED | Physical device unavailable; simulator native warmup failed |
| Physical inference this phase | NO | Phase 1 physical success is historical evidence only |
| System Shortcut automatically invoked | NO | Calling `perform()` proves the handoff contract, not OS invocation |

## Baseline and preservation

The complete Phase 1 report, migration audit and fresh reboot report were read before editing. The dirty working tree was preserved. Start and final HEAD: `19d01e24aadd45847b277c2626308927a4cc3638` on `main`. No commit, push, stash, reset, clean, checkout-over-work, or legacy deletion occurred.

The frozen baseline contains Git status, diff, diff stat, HEAD/log, SHA256 for 220 existing files, line counts and 150 source snapshots. Final preservation checks find no missing baseline files. Existing server, OPUS, CEDICT, Quick Look translation and older runtime files are untouched by this phase. The modified-file list below is relative to that already-dirty baseline, not to Git HEAD.

Artifacts root: `/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/`.

- [Frozen baseline](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/baseline/).
- [Preservation proof](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/preservation-proof.json).
- [Pinned hashes](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/pinned-hashes-final.txt).

Pinned model remains Hy-MT2-7B-Q4_K_M, 4,624,648,896 bytes, SHA256 `9f96256500f3fc1ab4d64336b58f52a949a95ad7516b0c229476eef782f9f77b`. Native `.h/.mm`, model manifest and protected-span implementation match the baseline. Runtime remains llama.cpp v0.6.0, build 11429, commit `d81235049384534c167caea52b85a694f6103d14`, Metal. Prompt, embedded template, sampling and limits are unchanged. Actor changes are DEBUG counters only.

## Phase 2: route before and after

Before, `.floatingPreview` used the old orchestrator and Apple Translation session host. Its result was an `OverlayRenderResult`; preview/full routing followed the old result path. It was already an app foreground preview, not an overlay above other applications. `QuickLookTranslateScreenshotIntent` is a separate legacy route.

After:

```text
Shortcut → FloatingScreenTranslateIntent.perform()
  → IntentFile decode → persistent IntentHandoffRequest(.floatingPreview)
  → foreground app / pending-request drain
  → coordinator.showFloatingPreview(job)
  → ProcessingViewModel.handleIncomingScreenshot(job, localTarget)
  → ScreenshotProcessor.process(..., engine: environment.engine)
  → VisionText → groupText → HyMTTranslator / HyMTNative
  → layoutScreenshotOverlays → renderScreenshotOverlays
  → ProcessedScreenshot → floating renderedImage
  → Open Full Viewer → same ProcessedScreenshot / same UIImage
```

`AppEnvironment.init` owns one `HyMTTranslator`. A and B both call the same VM local entry point. `onLocalCompleted` chooses the presentation route from the active handoff; it does not choose a backend. `openFullViewer()` only changes `activeLaunchBehavior` and `route`. No OCR, rendering, model preparation or translation is called there. Original/translated geometry, warnings and stable block IDs travel in the same typed DTO.

The B intent has the same iOS 26 `.foreground` supported mode as A, with `openAppWhenRun` retained for the deployment compatibility path. It only decodes/stores/notifies and returns. The new core never executes in a background intent. Apple documents the current [AppIntent supported modes](https://developer.apple.com/documentation/appintents/appintent/supportedmodes) and [foreground mode](https://developer.apple.com/documentation/appintents/intentmodes/foreground).

The Apple Translation host was removed from floating presentation. It remains available in legacy settings until Phase 3; the independent Quick Look C route remains unchanged. Neither participates in A/B processing. Existing cancellation, native-request barrier, latest-wins handoff, inactivity/background handling and memory-warning behavior are retained. The same model remains actor-owned while active; background unloading follows Phase 1 policy.

The preview preserves lightweight progress/result, Cancel, Try Again, Done and Open Full Viewer. Completed preview shows the rendered image, not the original. A basic contrast defect found in screenshots was fixed by replacing hard-coded white preview headings with system primary/secondary colors.

### Autonomous route and UI tests

`Phase2Checks` is entirely `#if DEBUG`; `PHASE2_MODE` is an explicit launch environment opt-in. Release has neither its entry point nor automatic fixture processing. Its quality mode calls the full production processor. Export/layout modes call the exact production OCR/grouper/layout/renderer functions, not alternate implementations. Layout requires a native MT record with matching group ID **and exact source text**; mismatches fail.

The `contract` mode calls the actual B intent, consumes the production persisted handoff, cancels, retries, rapidly replaces, then cancels the outstanding request. It injects a recorded completed real DTO only to test the completion/presentation half. Before and after Open Full Viewer counters are both `{requests: 2, generations: 0, loads: 0}`; image identity is unchanged. Those zero generation/load values are disclosed evidence that this check does **not** validate inference.

Three final XCUITests pass on an iPhone 17 Pro Max iOS 26.5 Simulator clone:

1. Actual handoff/progress → cancel → retry → cancel → dismissal.
2. Recorded completed result → Open Full Viewer → Original control.
3. Recorded completed result → Done → idle, no preview control remains.

- [Contract report](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/contract-tests/report.json).
- [Final UI result bundle](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/ui-tests-completion.xcresult).
- [UI summary](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/ui-summary-completion.json).
- [Exported UI screenshots](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/ui-attachments-completion/).
- [Repeated Phase 1 contract checks](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/phase1-checks-preserved.json): claim-once, latest-wins, stable IDs, geometry, exact protected spans, missing/incorrect model, cancellation before loading, partial warnings, EN/RU — PASS.

## Regression corpus and provenance

The suite was frozen before production geometry changes. It contains four authentic Phase 1 captures of the **same Chinese cup-lid PDF in different capture states**, and four existing synthetic development cards. It does not represent four independent real applications. Black Mirroring captures were excluded from positive OCR cases.

| Fixture | Provenance | Purpose |
|---|---|---|
| `real-pdf-ru` | Physical Phase 1 RU cancel/retry export, request `5F5275E1…` | Centered paragraph; clipped lower table; 10 old fit warnings |
| `real-pdf-en` | Physical Phase 1 EN export, request `5E45…` inside `B75…` capture | Same paragraph; small rows; 13 old fit warnings |
| `real-action-pdf` | Physical Action Button PDF capture, request `738…` inside `9C…` | Full screenshot/status chrome; five-column specs |
| `real-action-app` | Physical already-open Action Button capture, request `97AF…` inside `E477…` | Handoff capture state; full dense table |
| `synthetic-A_product_ui` | Existing fresh reboot card | Independent UI labels and mixed identifiers |
| `synthetic-B_dense_commerce` | Existing card | Dense independent labels/options |
| `synthetic-C_seller_chat` | Existing card | Wrapped seller/customer messages |
| `synthetic-D_packaging_spec` | Existing card | Paragraphs, specs and protected spans |

`tools/runtime/phase2_suite.json` records input SHA256, provenance and expected **structural** properties: readable Chinese headings, centered paragraph members, separate table cell locations, clipped exclusions, bounds, area and intersection gates. There are no expected translations. Fresh model output is not replaced with hard-coded translations.

Every final case exports exact-source `original.png`, `vision-observations.png`, `grouping-debug.png`, `translated-result-en.png`, `translated-result-ru.png` and `report.json`. JSON includes top candidate/available alternatives/confidence, raw rectangles, ignored reasons, grouping links/source members, rendered rectangles/font/fit, overlap/area metrics and stage timings. Ignored raw observations remain inspectable. Annotated images distinguish observations from groups and show member links with automatically generated colors.

[Final 16-run structural proof](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/final-regressions/structural-checks.json) and [final artifacts](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/final-regressions/).

### Native translation provenance

Fresh EN/RU translations were generated on Apple M5 with the actual unchanged `HyMTNative.mm` and a verbatim copy of the production Swift actor, compiled against the already-built pinned v0.6.0 host runtime. The driver calls the same protected-span code and actor, loads the pinned model and uses the unchanged prompt/sampling. This is a DEBUG-only component artifact generator, not an application backend. Across 16 runs there are **270 successful group generations and 0 errors**. Their output is then consumed by the production iOS geometry functions.

[Native source proof](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/mac-native/source-proof.json), [generation summary](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/mac-native-summary.json). This validates native output for the current groups on the Mac; it does not validate foreground iOS model lifecycle or iPhone latency.

## Failure classification

| Observed failure | Layer | Change / remaining behavior |
|---|---|---|
| Tiny temperature digit −20 recognized as −30 | `OCR_RECOGNITION` | Still present in one real crop; raw text retained, no fabricated correction |
| Clipped `1000日/箱`-like fragment | `OCR_RECOGNITION` | Geometry/confidence marks incomplete; skipped, original pixels retained |
| Clock/battery/chrome fragments | `OCR_NOISE` | Conservative clock-confirmed status-band and ambiguous-short filtering |
| Centered wrapped description split into two blocks | `GROUPING_UNDERMERGE` | Center alignment/line height/overlap/gap now joins its two observations |
| Nearby independent options or cells | `GROUPING_OVERMERGE` | Tighter same-row joins and row-peer veto; grids remain separate |
| Correct output too large for source cell | `LAYOUT_FIT` | Scale/line-height font floor and small safe expansions; honest warning if impossible |
| Panels intersect | `LAYOUT_COLLISION` | Stable reading-order placement with source/placed-panel obstacles |
| Expansion obscures unrelated text | `LAYOUT_COVERAGE` | Raw text geometry protected, capped area, reject unsafe candidate |

## OCR experiments and chosen configuration

The previous processor already used Vision `.accurate`, `zh-Hans / zh-Hant / en-US`, correction OFF, current default revision and default minimum text height. The winning request configuration remains that configuration. The change is diagnostics plus conservative admission filtering, not an assertion that a new language setting fixes recognition.

The production [Vision text request](https://developer.apple.com/documentation/vision/vnrecognizetextrequest) is centralized in `VisionText.swift`. On the tested systems the default revision is 3 and minimum height is 0. Three candidates are requested; these fixtures actually returned one per observation. Confidence values include 1.0, 0.5 and 0.3; a 0.5 observation is not discarded just because it is not 1.0.

Experiments: 32 simulator OCR runs (eight inputs × language sets × correction ON/OFF), and 88 Mac OCR runs (eight inputs × eleven configurations), plus orientation comparisons. Machine-readable data is in `ocr-experiments-ios/` and `ocr-experiments-final/`.

| Experiment | Finding | Decision |
|---|---|---|
| Simplified + Traditional + English vs Simplified + English | No consistent benefit on the troublesome small rows | Keep broader explicit language set |
| Language correction ON/OFF | Did not consistently restore the mistaken characters | OFF, preserve observations |
| Explicit revision 3 / minimum height 0 | Same default behavior on this system | Avoid unnecessary production override |
| Half-resolution image | Loses detail | Reject |
| Whole-image 2× upscale | Inconsistent small-text changes, extra OCR work | Reject |
| Local bottom-band crop | Can recover `只` in one fragment, but introduces other errors such as `克重` → `克車` | Reject; no production second pass |
| Wrong orientation on unchanged pixels | Stress case changes OCR as expected | Not treated as a correct-orientation test |
| Pixels rotated 90° + matching `.right` orientation | Same recognized text on all eight cases | PASS; coordinates use upright dimensions |
| Candidate alternatives | Only one candidate available in these runs | No guess/substitution |

The app continues to redraw incoming UIImage pixels upright once, including EXIF/mirrored input handling, so OCR and rendering use the same coordinates. The native OCR helper also understands oriented CGImages; the roundtrip experiment exercises it directly.

### Noise and clipped text

Admission uses generic geometry and confidence only. Empty/symbol-only observations and ambiguous short candidates below 0.35 are ignored. A status bar is identified only with a small upper-left clock observation; aligned small far-right status content is then ignored. The regex identifies clock structure, not application/product vocabulary. There is no Taobao/PDD rule table.

Near the screenshot edge, an observation is marked incomplete when confidence is low or its height is reduced against nearby lines. The band is `max(4 px, 0.35 × observation height)`. The two cropped real PDF inputs have seven and six edge exclusions; full Action Button captures have none. The clipped text remains in JSON and its geometry remains an obstacle. This deliberately avoids translating unreliable fragments and does not claim recovery of missing pixels.

No dictionary, CEDICT, semantic regex repair, translation-as-OCR, model change or hard-coded Chinese replacement was added. Large clearly readable headings pass the structural suite. **Small-text recognition itself has no demonstrated general improvement**: the reliable improvements are noise admission, exclusion of incomplete rows and correct downstream geometry.

## Grouping changes and results

The old grouper merged same-row candidates at a broad 1.2-line-height gap, then joined only left-aligned wrapped lines. It had no centered paragraph case, height/row-peer checks or negative-gap tolerance. The centered PDF description consequently remained two translation requests and expanded into overlapping panels.

The new function remains geometric and deterministic. It groups same-row fragments only with strong vertical overlap, similar height, limited horizontal gap and no meaningful rectangle overlap. A small wider gap is permitted for a Chinese label and adjacent Latin value. Wrapped joins require matching left edge or center, similar line height, strong horizontal overlap, close vertical gap and a sufficiently wide preceding line. Sentence-ending punctuation stops a join; a same-row peer veto preserves grids/tables. Small OCR y jitter is ordered by row cohort before x position, preserving predictable dense-table allocation.

Focused checks cover the **actual Phase 1 centered rectangles**, the existing actual-device `灯不 / 亮` chat geometry, a two-column option grid and adjacent buttons. Real fixture assertions require the centered pair to share one block and the five weight cells to remain separate. These are structural checks, not text replacement rules.

| Input | Raw / accepted / ignored | Groups | Mean members | Largest | Singles | Edge exclusions |
|---|---:|---:|---:|---:|---:|---:|
| real-pdf-ru | 27 / 16 / 11 | 15 | 1.07 | 2 | 14 | 7 |
| real-pdf-en | 28 / 17 / 11 | 15 | 1.07 | 2 | 14 | 6 |
| real-action-pdf | 37 / 35 / 2 | 34 | 1.03 | 2 | 33 | 0 |
| real-action-app | 37 / 35 / 2 | 34 | 1.03 | 2 | 33 | 0 |
| synthetic A | 14 / 13 / 1 | 8 | 1.00 | 1 | 8 | 0 |
| synthetic B | 23 / 22 / 1 | 18 | 1.00 | 1 | 18 | 0 |
| synthetic C | 14 / 13 / 1 | 4 | 2.00 | 2 | 0 | 0 |
| synthetic D | 16 / 15 / 1 | 7 | 1.57 | 4 | 5 | 0 |

Accepted Latin-only observations are retained as obstacles/diagnostics but are not Chinese translation groups; therefore accepted count need not equal grouped member count. Synthetic D's four-member group is one visually contiguous four-line paragraph, checked in the annotated image, not a giant spec-table merge.

Known centered undermerge cases: **4/4 before split → 4/4 after joined**. Known grid/weight-cell overmerge checks: **0 after**. This is a bounded fixture result, not a corpus-wide linguistic undermerge/overmerge accuracy score. No complete human grouping ground truth exists for every raw observation.

## Overlay layout and measurable quality

The previous renderer tried a fixed 18 px minimum and generous padding/expansion independently per block. It could grow a panel over another paragraph/cell and had no shared obstacle/collision pass.

The new small deterministic pass starts at the source rectangle in stable reading order. It tries exact source, modest height growth, modest width growth, then combined candidates; trims candidates against neighbors; reduces font before choosing a larger candidate. Other accepted observations, uncertain Chinese/clipped observations and already placed panels are obstacles. Unsafe candidates are discarded. Expansions are centered on the source and capped at 2.5× source area with limited extra line height. A placed panel is tightened to measured text while preserving the source association. Bounds violations and text/panel intersections are forbidden.

Font sizing uses `scale = imageWidth / 1170` and the original **line** height, not the entire grouped paragraph height. The minimum is `max(11 × scale, min(18 × scale, 0.48 × lineHeight))`; preferred size also tracks line height. Dense source rows get zero padding rather than losing most of their box to padding. The observed final font range is 12.41–46.64 image pixels. Very small PDF cells still require zoom when viewing the entire page; zero geometric fit failures is not a physical readability acceptance claim.

If no safe readable placement exists, `rect` remains nil and a typed `LAYOUT_FIT` warning is emitted. The original pixels remain visible. There is no large destructive fallback rectangle. Compact white panels remain the baseline: deterministic, fast and no inpainting. Neighboring non-text photo content is limited through source association, tight dimensions and the area cap; image-object segmentation is not implemented, so zero text coverage must not be misrepresented as measured zero photo coverage.

Each placement records source/rendered area, ratio, area outside source, screen percentage, overlap with unrelated raw text, overlap with other panels, font and fit. Bounds and exact positive intersection area are checked. The final unrelated-text check is stricter than the historical comparison because it protects raw accepted/uncertain observations, not only other translation groups.

### Matched real captures: before → after

| Capture / target | Fit failures | Panel-pair intersections | Panels covering unrelated text | Largest area ratio |
|---|---:|---:|---:|---:|
| real-pdf-ru / RU | 10 → **0** | 1 → **0** | 7 → **0** | 4.72 → 1.50 |
| real-pdf-en / EN | 13 → **0** | 2 → **0** | 4 → **0** | 4.72 → 1.99 |
| real-action-pdf / EN | 10 → **0** | 8 → **0** | 14 → **0** | 7.28 → 2.21 |
| real-action-app / EN | 10 → **0** | 8 → **0** | 14 → **0** | 7.28 → 2.21 |
| Matched totals | **43 → 0** | **19 → 0** | **39 → 0** | max **7.28 → 2.21** |

Across **all eight inputs × EN/RU**, the final run has **0 fit failures, 0 translated-panel intersections, 0 unrelated-text-overlap panels, and 0 bounds violations**. Maximum area ratio is 2.21253. Cropped/ignored rows are not counted as successfully translated; the full Action Button inputs still translate 34 blocks with no fit warnings. The reduction is therefore not solely the result of skipping cropped content. After translations are fresh outputs for the improved groups; they are not guaranteed text-identical to Phase 1 outputs.

[Before metrics](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/before-metrics.json), [after metrics](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/after-metrics.json).

Visual examples:

- [RU before](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/corpus/real-pdf-ru/before-result.png) → [RU after](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/final-regressions/real-pdf-ru/translated-result-ru.png).
- [Full capture before](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/corpus/real-action-pdf/before-result.png) → [EN after](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/final-regressions/real-action-pdf/translated-result-en.png) / [RU after](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/final-regressions/real-action-pdf/translated-result-ru.png).
- [Real grouping diagnostic](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/final-regressions/real-action-pdf/grouping-debug.png).

## Performance and device limitations

Physical device discovery used `xcrun devicectl list devices`; simulator discovery used `xcrun simctl list devices`. The previous test phone `00008150-001475EC2E98C01C` (iPhone 17 Pro Max) was initially listed connected, but launch failed with CoreDevice usage-assertion error 4016 and subsequent discovery listed it unavailable. Other physical phones were unavailable too. No user unlock, Action Button press or Mirroring action was requested. Automatic UI access on the locked Mac also failed. XCUITest could still operate the simulator.

Production OCR/layout ran on iPhone 17 Pro iOS 26.5 Simulator (`02CBCF1F-5605-4F64-A7F3-1FF189BAB779`); UI tests used the iPhone 17 Pro Max iOS 26.5 Simulator (`13D9A408-FDEC-4F84-8EA1-D99D6EF73737`) clone. Native translations ran on Apple M5 macOS with the exact pinned runtime. These are three explicitly different evidence environments.

The full simulator processor attempt spent over 15 minutes in Metal-simulator warmup, hit the unchanged generation limit without EOG, and correctly failed. No limit increase, fallback, alternate model or success fabrication was used. [Failure status](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/native-simulator-attempt/status.json), `quality-simulator.log`, `simulator-inference-sample.txt` and prepare diagnostics retain that evidence. Phase 1 proves the model worked on the physical iPhone; this phase does not repeat that proof.

### Historical iPhone timing vs current component timing

All values below are milliseconds. They are recorded separately and **must not be interpreted as a same-device speedup/regression comparison**.

| Capture / target | Before physical OCR / group / render / MT / total | After simulator OCR / group / render | After Mac MT |
|---|---|---|---:|
| real-pdf-ru / RU | 234 / 0.131 / 21.5 / 46,887 / 47,182 | 745 / 0.129 / 38.3 | 54,308 |
| real-pdf-en / EN | 250 / 0.248 / 41.5 / 32,823 / 33,165 | 756 / 0.130 / 58.4 | 26,209 |
| real-action-pdf / EN | 255 / 0.204 / 22.6 / 43,073 / 43,394 | 811 / 0.374 / 84.7 | 49,852 |
| real-action-app / EN | 254 / 0.194 / 16.1 / 43,109 / 43,426 | 893 / 0.393 / 123.2 | 30,917 |

Current simulator corpus ranges: OCR 680–893 ms, grouping 0.096–0.393 ms, layout+render 7.5–123.2 ms. Mac MT per image ranges 9,761–75,875 ms. The Mac baseline OCR experiment ranges 117–388 ms. A sum of Mac inference and simulator geometry would be a composite number, not a measured application total, so it is not reported as total. **After physical total/model latency is unmeasured.** Model configuration is unchanged; latency cannot be claimed unchanged from these different devices.

A controlled same-Mac Debug timing check used frozen production baseline `groupText` and current production functions on the same recorded observations, 1,000 repetitions each. On the largest 37-observation real input: old grouping 0.175 ms; new grouping 0.340 ms; new classification 0.280 ms. Added classification+grouping cost is **0.446 ms** per screenshot. Across the suite this added cost is below 0.5 ms. [Controlled geometry timing](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/geometry-timing-comparison.json).

Production retains one Vision pass, no upscaling and no second crop pass. The new geometry cost is milliseconds/submilliseconds rather than additional seconds. Actual post-change iPhone rendering and OCR timings remain a physical acceptance measurement.

## Code and cleanup

Modified relative to the Phase 2 baseline (14 files):

- `App/AppCoordinator.swift`, `App/AppEnvironment.swift`: shared completion and presentation-only full transition.
- `Intents/TranslateScreenshotIntent.swift`: thin foreground B handoff notification/mode.
- `ScreenTranslatorApp.swift`: stop hosting Apple Translation for B; DEBUG opt-in.
- `Features/Processing/ProcessingView.swift`, `ProcessingViewModel.swift`: shared rendered preview/control wiring; DEBUG recorded DTO presentation.
- `Features/ResultOverlay/OverlayPreviewSurface.swift`: system text contrast.
- `Features/Settings/SettingsView.swift`: accurate shared-local-core copy.
- `ScreenTranslatorNext/ScreenshotProcessor.swift`, `TextBlocks.swift`: shared geometry, mapping/diagnostics, DEBUG actor counters.
- Both `.pbxproj` files: same geometry sources; original app adds DEBUG checks.
- `ScreenTranslatorUITests/ScreenTranslatorUITests.swift`, `tools/runtime/checks.swift`: focused UI and grouping/span checks.

Added:

- `ScreenTranslatorNext/VisionText.swift` — 52 lines, one OCR/filter implementation.
- `ScreenTranslatorNext/OverlayLayout.swift` — 115 lines, one layout/renderer/metric implementation.
- `Core/Phase2Checks.swift` — 251 DEBUG-only lines, autonomous production-function checks and explicitly labelled DTO presentation fixture.
- `tools/runtime/phase2_suite.json` — 314 lines of DEBUG corpus/structural expectations.
- `tools/runtime/phase2_regression_checks.swift` — 50 lines.
- `tools/runtime/ocr_quality.swift` — 56 DEBUG-only experiment lines.
- `tools/runtime/mac_quality.py` — 82 lines, component fixture generator using the actual native/actor sources.
- This report.

Code/config diff before this prose report: **1,158 lines added, 97 removed, net +1,061**. Production Swift portion: **333 added, 95 removed, net +238** (includes DEBUG counter/fixture hooks). Most remaining additions are the requested DEBUG harness, regression manifest and checks. `ScreenshotProcessor.swift` shrank from 274 to 248 lines. [Per-file counts](/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/phase2-ocr-quality/phase2-code-size.json).

The obsolete inline renderer/OCR were replaced, not kept alongside a new production pipeline. No OCR provider hierarchy, grouping protocols, renderer factory, heuristic plugins, backend enums or fallback chain was added. OCR alternatives stay in DEBUG tools; none is selectable as a Release backend. An unused historical-translation geometry replay branch was removed during cleanup; final layout fixtures use fresh source-matched native outputs. Temporary baseline timing copies and failed experiment artifacts are outside the repository and not built into the app. Phase 3 bulk deletion did not start.

Validation: final original Debug simulator/UI build and three UI tests PASS; original generic-device Debug and Release builds PASS; ScreenTranslatorNext generic-device Debug build PASS; grouping/span host checks PASS; 16 structural regressions PASS; Phase 1 checks PASS; `git diff --check` PASS. Release binary inspection finds no Phase2 launch mode/recorded-result diagnostics. Build success is not device acceptance.

### Reproducible checks

From the repository root:

```sh
swiftc ScreenTranslatorNext/TextBlocks.swift tools/runtime/checks.swift -o /tmp/screentranslator-group-checks
/tmp/screentranslator-group-checks
swiftc -parse-as-library tools/runtime/phase2_regression_checks.swift -o /tmp/screentranslator-regression-checks
/tmp/screentranslator-regression-checks ../BuildArtifacts/oct2026/phase2-ocr-quality/final-regressions tools/runtime/phase2_suite.json
```

For iOS regression generation, copy the stored corpus into app Documents `Phase2Corpus/`, then explicitly launch DEBUG with `PHASE2_MODE=quality` on an accessible physical device. `export`, `ocr`, `layout`, `contract`, `ui` and `presentation` are separate evidence modes; layout requires exact source-matched native output records. `quality` is the full processor path; `contract`/`presentation` recorded completion must never be treated as its replacement acceptance proof. No mode is automatically enabled in Release.

## Remaining issues and next stage

1. A successful new floating route with actual inference on the physical iPhone is still unverified; the simulator's warmup failure is real. Actual OS Shortcut/Action Button launch, rapid replacement during native inference, warm model reuse and foreground/background behavior need the next physical acceptance round. Route contracts and recorded presentation tests do not close that gate.
2. Vision still misreads a small temperature digit in `real-pdf-en`. Local crop/upscale/configuration experiments were insufficiently reliable, so no speculative repair was shipped. Clipped rows remain explicitly excluded and untranslated.
3. Dense full-page PDF cells use small source-relative text and need viewer zoom. Physical readability has not been accepted. Zero collisions/fit warnings does not alone establish comfortable reading at fit-to-screen size.
4. Authentic corpus diversity is limited: four captures of one real PDF plus four secondary synthetic cards. Image-object coverage is constrained geometrically but not semantically measured; broader authentic commerce/chat inputs remain future coverage, not invented tests.

**Recommended next stage: USER ACCEPTANCE TEST of A + B on the iPhone 17 Pro Max.** Its exact scope is normal and Floating Screen Translator Action Button routes, completed floating result, Open Full Viewer without retranslation, cancel/retry/replacement, EN/RU dense-label readability, share/save, and physical stage timings/lifecycle. That stage was not started here. Phase 3 deletion remains unauthorized until that acceptance.
