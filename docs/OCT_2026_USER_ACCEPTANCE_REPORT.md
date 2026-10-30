# ScreenTranslator — physical user acceptance

Date: 2026-10-08. **Physical acceptance complete. Recommendation: FAIL — Phase 2 is not accepted for the required floating UX and complete rendering of readable chat text.**

The shared physical engine, A route, B processing/presentation plumbing, viewer reuse and tested lifecycle actions work. These technical passes do not override the user's rejected floating UX or the reproducible omitted message. No processing fix was made during the acceptance runs.

Repository: `/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator`.
HEAD: `19d01e24aadd45847b277c2626308927a4cc3638`. Existing dirty work preserved. No Phase 3, deletion, commit or push.

Evidence root: `/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/user-acceptance-20261008/`.

## Device

- Physical iPhone 17 Pro Max, `iPhone18,2`, UDID `00008150-001475EC2E98C01C`.
- iOS 26.5.1, build 23F81, Developer Mode enabled; paired and connected over local network.
- iPhone Mirroring was running during setup and was closed before screenshot tests.
- On-device verification reports battery state 1 (unplugged), Low Power Mode off.
- Original bundle: `AlenShamatov.ScreenTranslator`; product `ChinaTap Screen Translator`.
- Original Debug build succeeds. One `llama.framework` and Metal are linked; shared current Phase 2 sources and pinned model manifest are included.
- Existing container model verified on the phone using the production streaming size/SHA256 check. Size 4,624,648,896 bytes; SHA256 `9f96256500f3fc1ab4d64336b58f52a949a95ad7516b0c229476eef782f9f77b`. No model recopy. Verification counters show zero model loads/generations.
- Runtime/prompt/model and Release processing behavior unchanged. Additional DEBUG-only diagnostics record route/run/events, pipeline stage counters, viewer identity/counters and annotated geometry exports before testing. Source edits were limited to `App/AppEnvironment.swift`, `Features/Processing/ProcessingView.swift`, `ProcessingViewModel.swift`, `Core/Phase2Checks.swift` and DEBUG counters/stage marks in the shared `ScreenshotProcessor.swift`. Algorithms, native bridge and model artifacts were not changed. Six completed physical runs and two cancelled runs are retained.
- After the last completed run, the console transport reported an XPC disconnect. A subsequent device process listing still showed the original app running (PID 91469). No product crash is inferred from that logging-channel disconnect; no crash was observed by the user in the tests. This is bounded acceptance evidence, not exhaustive race/stress validation.

## Route A

**Route A RU: PASS for the physical flow and viewer actions.** Actual Action Button/Shortcut → progress → completed local result is physically confirmed. Request `C197D5EC-57FF-4DFD-B2EC-8841193A3AE4`, run `165082D9-C52B-47CF-8CBB-D7A297C5CB8A`, route A, target Russian. Raw input is a real Taobao home page, 1320×2868, 3,287,083 bytes, not black. The user answered «все работает» after testing Original/Translated, zoom, block details, Share and Save.

| Metric | Physical RU result |
|---|---:|
| Raw / accepted / ignored observations | 75 / 70 / 5 |
| Chinese translation groups | 65, all single-observation |
| Model reused | false (cold run) |
| Verification / native load / warmup | 3,072.2 / 6,671.9 / 558.3 ms |
| OCR / grouping | 576.3 / 2.5 ms |
| Translation / layout-render | 123,369.6 / 454.1 ms |
| Processor total | 124,445.4 ms |
| Generation errors / memory warnings | 0 / 0 |
| Generated translation tokens | 966 (warmup counted separately) |
| Fit failures | 17 |
| Panel intersections / unrelated-text coverage / bounds violations | 0 / 0 / 0 |
| Thermal state / battery | fair / unplugged |
| Maximum sampled footprint / end resident memory | 558.52 / 2,197.83 MiB |

User: «Открыл главную страницу таобао - прогресс перевода есть … Сейчас группировка работает очень хорошо и есть проблемы только с некоторыми блоками. Главная проблема - очень очень долго». The user specifically directed attention to the top of the image.

**Route A EN: PASS for actual progress and translated result.** Request `B145769C-CDE4-460C-99D6-2C1C037EC2C7`, run `5959FEB1-39BC-476B-898B-0E99B5F6E7A9`. Although a product-detail page was requested, the received authentic input is another Taobao home-feed state, not a product-detail acceptance case.

EN: 50 raw / 45 accepted / 5 ignored observations, 41 groups; 261 output tokens; OCR 380.7 ms, grouping 1.14 ms, translation 38,938.6 ms, layout/render 272.7 ms, total **39,640.7 ms**. Two fit warnings; zero collisions, unrelated-text overlaps and bounds violations; zero generation errors/memory warnings; thermal nominal, unplugged. `modelReused=false` after leaving the app; verification 1,811.6 ms and load 351.3 ms. Actor counters: requests/OCR/group/render 2, translation generations 106, model loads 2. Generation counters exclude the separately reported preparation warmup.

User: «перевод начался и работал заметно быстрее чем русский вариант. Так же возникла проблема только с верхней частью экрана - блоки в нем не перевелись». This is a different input and token count; 39.6 vs 124.4 seconds is not a controlled EN/RU language comparison.

## Route B

**Route B physical handoff/progress/completion: PASS; layout quality has a reproducible failure.** The user ran the signed two-action Floating Shortcut from a real seller chat. Request `248EDF07-2DDB-4071-8E2A-40102BBF5984`, run `93D28A7C-9534-4978-A3D9-8B0B9E8F6BCB`, actual target **English** (Russian was requested but is not asserted for this run).

The unchanged native core completed on Apple A19 Pro GPU: 28 raw / 24 accepted / 4 ignored observations; seven Chinese groups, largest six observations; 199 output tokens; OCR 277.0 ms, grouping 1.12 ms, translation 28,274.6 ms, render 34.3 ms, total **28,614.8 ms**. Cold (`modelReused=false`); zero generation errors, memory warnings, collisions, unrelated-text overlaps or bounds violations. Two large message parts have fit warnings and are not painted.

User: «Я открыл чат - но Floating Screen Translator.shortcut открыл приложение в каком-то отдельной вкладке. Не перевелся целый большой блок текста».

**Route B overall user acceptance: FAIL for UX.** The user answered «Ожидал другой floating UX» and specified the actual requirement verbatim:

> «После нажатия action button мы не переходим в приложение ,а открывается Floating Screen поверх приложения на который можно нажать и откроется перевод на весь экран,а снизу кнопка готово .Такой раньше был реализован в приложении».

The current foreground app lightweight route is different from that requirement. It was not accepted simply because progress, preview, Done and Open Full Viewer work. The described experience resembles a system preview/Quick Look style result; that is an inference, not proof of the user's exact old installed Shortcut mechanism. A separate follow-up must recover that precise presentation contract while keeping the shared core and a reliable 7B execution lifecycle. This report does not promise reliable background inference or implement another translator.

## Full Viewer reuse

**PASS on physical iPhone.** The user pressed Open Full Viewer and confirmed «открылся - прогресса никакого не было».

| Counter | Before | After |
|---|---:|---:|
| Requests | 3 | 3 |
| OCR | 3 | 3 |
| Grouping | 3 | 3 |
| Rendering | 3 | 3 |
| Translation generation calls | 113 | 113 |
| Model loads | 3 | 3 |

`sameRenderedImage=true`, `sameRequestID=true`, `noAdditionalProcessing=true`; route becomes `result`. Request identity remains `248EDF07-2DDB-4071-8E2A-40102BBF5984`. This proof is from the real completed physical run, not a recorded DTO presentation fixture. The generation counter excludes separately reported preparation warmup. Evidence: `b-viewer-reuse.json`.

## Real screenshots

Case A-RU-1: authentic Taobao home feed with product cards, dense promotional labels and navigation. User considers grouping generally very good, with some top-block problems; latency is the main complaint.

Case A-EN-1: another authentic Taobao home feed. User confirms English result and notices untranslated top labels. `OCR_RECOGNITION`: top sources include `人购` and `小外卖` rather than the clearly visible intended labels. `LAYOUT_FIT`: both associated translations cannot be safely placed and remain warnings. Top independent labels also arrive together in some Vision observations; this is distinguished from grouper merges. All raw/annotated/result/report artifacts are retained.

Case B-EN-1: authentic seller chat, including a long numbered message and seller replies. Large text is recognized, grouped and translated successfully; the user's large green message stays Chinese because both corresponding placements are rejected. **LAYOUT_FIT root cause:** source block 10 ends at y=1321.841914; adjacent block 16 starts at y=1321.000000. Their bounding boxes overlap by about **0.842 px**. The strict obstacle test rejects even the source candidate, and existing candidate trimming cannot resolve an obstacle that already crosses that source boundary. Thus both otherwise readable, successfully translated parts are not drawn. Zero rendered collisions does not make this omission acceptable. Raw observations, grouping image, output translations and result are retained. No layout edit was made during acceptance.

Case B-RU-1 (replacement): real cup/specification image with capacity labels and many Latin/numeric values. 32 raw / 30 accepted / 2 ignored observations, one edge-clipped exclusion, seven single-observation Chinese groups, 23 accepted non-Chinese observations retained unchanged. 119 output tokens; OCR 139.9 ms, grouping 0.65 ms, translation 13,745.6 ms, render 53.3 ms, total **13,963.6 ms**. One fit warning; zero panel/text intersections and bounds violations; no generation errors. `modelReused=false`; actor counts requests/OCR/group 7, render 5, generation 128, load 5. User confirms the correct newer screenshot and no errors.

Case B-RU-2 (foreground warm repeat): same specification image displayed in the full viewer's Original mode and recaptured by the actual Action Button. Request `48DEE025-182B-4538-8BF7-B81C98F30CD3`, run `23014D6A-D797-4222-A3F9-3DB11F287F27`. Eight groups, 131 output tokens, OCR 267.6 ms, grouping 0.82 ms, translation 12,787.7 ms, render 58.2 ms, total **13,139.4 ms**, `modelReused=true`. One fit warning remains, with no intersections/bounds violations or generation errors; zero memory warnings, nominal thermal state. User: «сработало - но перевелось не все».

Coverage achieved: real commerce feed/product cards, real seller chat, real specification image and long multiline chat paragraphs. A standalone product-detail/description page was requested but was not received as a distinct category; it is not claimed as tested. All raw inputs inspected are non-black. No synthetic screenshot is used for this acceptance.

Evidence-backed classifications for the Taobao RU case:

- `OCR_RECOGNITION`: the independent top labels `飞猪` and `超级88` arrive as one Vision observation/source. This is not a new grouper overmerge: all 65 final groups have one observation.
- `LAYOUT_FIT` / readability: «Рекомендации» wraps inside the word. It geometrically fits but has poor typography. Seventeen other labels have explicit fit warnings and retain original content. Some angled promotional lines have overlapping Vision boxes, preventing safe placement.
- `OCR_RECOGNITION` with downstream translation impact: the visible `1200G瞬时流速` is recognized as `1200G暖时流速`; its output uses a temperature interpretation («…1200 Градусов»). This must not be attributed solely to the model when its input already contains the wrong character.
- `TRANSLATION`: bottom `消息` becomes «Новости» rather than messages in this UI context. No semantic correction or model change was made.
- `PERFORMANCE`: 124.4 s for 65 groups; user describes the wait as «очень очень долго».

Raw `input.png`, annotated observations/groups, `result.png` and `report.json` are retained in the request/run capture directory. These are current physical artifacts, not Phase 2 composite results.

## Lifecycle

- **Cancellation/retry: PASS on B.** Request `D262ACDD-9E15-471C-8A42-D2BE5AEE389A`, cancelled run `C49BAD44-B4E1-4138-8225-7DE903F27EB4`. Cancellation-to-safe-processing-exit upper bound: **32.705 ms**. Cancellation file and console identify the native cancellation/Swift exit; there is no successful old-run report or result. This is a processing exit bound, not a GPU kernel timestamp.
- Retry run `C74F2F56-DB65-4ECC-BF64-B1AE71785BC8` completes the same screenshot with `modelReused=true`, seven groups, English, **18,174.3 ms** total (OCR 207.6 ms, translation 17,911.1 ms, render 26.2 ms). Same two layout failures remain. Model load count is 4 before/after retry; no reload. The user confirms cancel/retry worked and «Done сработал».
- User: «Сработало - результат показал тот же самый перевод что и в прошлый раз - не перевелся один большой блок текста. Done сработал». A new completed run ID and events prove actual reprocessing; similar deterministic text is not evidence of a stale result.
- **Rapid replacement: PASS for the physical sequence on B.** Older request `75E92944-747D-43FF-8B5A-6A7065761163`, run `04597BEA-A1F8-45CC-A944-11C7C29A1B34`, was cancelled while leaving the app/preparing the model; safe processing exit upper bound **20.019 ms**. No completed old-run report/result exists. New request `8B71A018-102D-45E7-ADD8-2CD7FE5C989F`, run `9D251129-E316-405A-B26A-84411CF4830F`, completes the different real specification image in Russian. Input files and IDs are distinct. User: «да - появился. Все сработало». This sequence does not prove simultaneous native generation overlap: the old run was cancelled during preparation, while the earlier explicit Cancel test covered active translation.
- **Warm model reuse: PASS for active retry and a post-success foreground invocation.** In the final run `48DEE025…`, request/OCR/group counts move 7→8, render 5→6 and translation-generation 128→136, while model loads stay **5→5**; `modelReused=true`. No new 4.62 GB model verification/load/warmup was needed. Cold A/B runs after leaving the app are consistent with the existing background-unload policy, not evidence of a second engine.

## Physical performance summary

All timings are processor milliseconds, not full Action Button-to-visible-result wall time. Translation includes preparation on cold runs. Warm load diagnostics are cached preparation information and are not charged again. Input/token counts differ across runs, so these are representative observations, not a controlled speed benchmark.

| Run | Target / groups / output tokens | Reused model | OCR | Group | Translation | Layout/render | Total | Fit warnings |
|---|---|---|---:|---:|---:|---:|---:|---:|
| A Taobao dense feed | RU / 65 / 966 | no | 576.3 | 2.50 | 123,369.6 | 454.1 | 124,445.4 | 17 |
| A other Taobao feed | EN / 41 / 261 | no | 380.7 | 1.14 | 38,938.6 | 272.7 | 39,640.7 | 2 |
| B seller chat | EN / 7 / 199 | no | 277.0 | 1.12 | 28,274.6 | 34.3 | 28,614.8 | 2 |
| B chat retry | EN / 7 / 199 | yes | 207.6 | 1.03 | 17,911.1 | 26.2 | 18,174.3 | 2 |
| B new spec after replacement | RU / 7 / 119 | no | 139.9 | 0.65 | 13,745.6 | 53.3 | 13,963.6 | 1 |
| B spec in foreground repeat | RU / 8 / 131 | yes | 267.6 | 0.82 | 12,787.7 | 58.2 | 13,139.4 | 1 |

All six completed runs report zero generation errors, rendered-panel intersections, unrelated-source-text overlaps, screenshot-bound violations and memory warnings. Their **25 fit warnings** include two repeated omissions of the large chat message; zero overlap does not imply complete translation. User judges the dense RU wait unacceptable in practice. The main delay is model translation/preparation, not the millisecond grouping stage; no optimization/model/prompt experiment was undertaken here.

## Remaining problems

- P0: no observed crash, native race, corrupt result or broken basic route in this bounded physical session.
- P1 UX: B opens a foreground app screen, while the user requires a floating result above the source app, tap-to-fullscreen and a bottom Done control. Product acceptance of B fails.
- P1 PERFORMANCE: real dense-page wait is over two minutes and is the user's main complaint.
- P1 LAYOUT_FIT/readability: 17 unrendered labels and awkward top navigation wrapping on this authentic input.
- P1 LAYOUT_FIT: complete large seller-chat message omitted because adjacent OCR/group rectangles overlap by less than one pixel; narrow shared-layout fix needed before quality acceptance.
- P2 TRANSLATION: messages/news UI context mistake. The flow/temperature example is classified as OCR recognition with downstream translation impact, not solely a model fault.
- P2 OCR_RECOGNITION: occasional top-label segmentation and small promotional-text mistakes; user reports grouping generally very good.

No processing fix was made while the user was testing. The repeated large-message omission is captured as a clear, narrow shared-layout bug for a follow-up, not concealed through dictionary/model/fallback changes. The exact old floating presentation still needs identification; its presumed implementation is not treated as a verified fact.

## Recommendation

**FAIL. Phase 3 ready: NO.**

Physical A, B processing, result reuse, EN/RU execution and the tested lifecycle paths are proven. User acceptance of the intended product is not achieved: the expected floating UX was not preserved, and readable large chat text is omitted by layout. The user also flags dense RU latency as the main everyday problem. These are not resolved by deleting legacy files.

Recommended next authorized work: a narrow shared-layout correction for subpixel source-box overlap, with this real chat added to regression gates; separately identify/recover the user's former system floating/fullscreen/Done presentation and decide a reliable execution path for the unchanged shared 7B core. Recheck those outcomes on this iPhone. Performance work should use the captured timings without attributing OCR-corrupted units solely to the model. No such implementation, Phase 3 cleanup, commit or push was started.

## Evidence and final preservation

- `build-debug.log`, `build-link-proof.json`, `install.json`, `model-verification.json`: current original signed build, unique runtime/Metal linkage, on-device pinned verification.
- `device-console.log`, `captures/Acceptance/events.jsonl`, cancellation files: chronological physical processing and cancellation evidence.
- `b-viewer-reuse.json`: exact physical counters and image/request identity.
- `captures/Phase1Reports/<request>/<run>/`: original input, input pixel inspection, Vision annotation, grouping annotation, rendered PNG and full JSON for completed runs; raw input/cancellation for cancelled runs.
- `source-preservation.json`, baseline Git/source hashes: preserve existing dirty work and the pinned native/model artifacts. HEAD remains unchanged.

Final language selection is Russian; the installed app is the tested Debug build. All acceptance artifacts are stored outside Git except this summary report. No simulator result was substituted for a physical result.
