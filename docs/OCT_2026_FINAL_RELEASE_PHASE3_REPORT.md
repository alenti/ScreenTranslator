# Final Release integration and Phase 3

Updated October 18, 2026, Asia/Shanghai.

**Phase 3 source/project cleanup and the final physical smoke round are complete. Debug/Release and all 14 selected unit/UI tests pass. The owner confirms Quick Look cancellation/immediate retry and Floating → Full Viewer without new processing, and confirms both A/B routes work. Release acceptance is PASS WITH KNOWN LIMITATIONS: a model omission can leave an explicitly warned original block, and earlier long background GPU failures remain a reliability risk. This is not a claim of complete translation quality or unconditional OS background execution.**

## Baseline and preservation

Repository: `/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator`.
HEAD remains `19d01e24aadd45847b277c2626308927a4cc3638`. The pre-existing dirty tree was preserved. No reset, clean, stash, destructive checkout, staging, commit or push was used.

Original October 11 snapshots and reports remain under `/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/final-release-phase3/`. October 18 continuation evidence is in its `resume-20261018/` subdirectory, including resumed status/diff/hashes, `pre-cleanup-source/`, the exact `deleted-source/` archive, `deleted-files.json`, build/test logs and physical request exports. Every deleted file was copied and hash-checked outside Git before removal. There are no unexpected missing baseline files.

The on-phone model remains **4,624,648,896 bytes**, with unchanged modification time **2026-10-06T16:46:09Z** before/after installs. No model recopy, container clearing or user-data deletion occurred. Owner downloads, old OPUS model/config/vocabulary files, local caches, external raw screenshots, frozen corpus, model provenance and historical benchmarks remain. In particular, the pre-existing dirty OPUS `model.bin` state was not reverted or changed by cleanup. Remaining files in that former server directory are retained owner artifacts, not an executable backend.

## Final Release Quick Look contract

Primary flow:

```text
Action Button → installed screenshot Shortcut
→ FastTranslateScreenshotIntent (title: Translate Screenshot for Quick Look)
→ ScreenshotProcessor → HyMTTranslator.shared → HyMTNative
→ rendered ProcessedScreenshot → PNG IntentFile
→ Shortcuts system Quick Look → native X → source app
```

The existing `FastTranslateScreenshotIntent` identity, bundle `AlenShamatov.ScreenTranslator`, parameter `screenshot` and image/file result contract are preserved. `QuickLookTranslateScreenshotIntent` remains a hidden thin compatibility alias calling the same implementation. A and B remain foreground handoff intents. Final Release metadata contains exactly these four actions; obsolete diagnostic actions are absent. File-return actions have background mode / `openAppWhenRun=false`; A/B have foreground mode / `openAppWhenRun=true`. No custom Quick Look close button or ordinary-result redirect was introduced.

No old Quick Look runner, dictionary, server, Apple Translation, fallback, cache or second engine is called. Release removes input pixels and raw OCR/group payloads from Quick Look exports; DEBUG additionally supports local failure screenshot/block evidence. Diagnostics are not a translation cache. Hardware Action Button-to-visible timing was not independently measured; receipt-to-PNG timings below are not substituted for it.

## Production core and lifecycle

Unchanged model/runtime/inference configuration:

- Hy-MT2-7B-Q4_K_M, SHA256 `9f96256500f3fc1ab4d64336b58f52a949a95ad7516b0c229476eef782f9f77b`.
- llama.cpp v0.6.0, commit `d81235049384534c167caea52b85a694f6103d14`, Metal.
- One app-owned actor/native model/context; p8, context 6144, reserved prefix sequence 8.
- Exact common **token** prefix KV sharing, packed independent suffix prefill, independent samplers/decode, bounded waves and stable source/result IDs.
- Sampling top-k 20, top-p 0.6, temperature 0.7, repeat penalty 1.05, seed 42; maximum output 512; current Jinja template, EOG and strict protected spans retained.
- No production exact-result cache, skipped-block budget, alternative model, prompt experiment or OCR/layout redesign.

`ScreenshotJobGate` serializes whole screenshot jobs. Replacement cancels task/native work, joins its safe return and rejects stale run/request IDs before starting the next owner. Cancellation is attempt-scoped; old handlers cannot cancel a newer owner. Public `CancellableIntent` handling on iOS 26.4+ forwards OS cancellation; earlier targets retain Swift cancellation. No iOS 27-only GPU entitlement or keep-alive mechanism was added.

Memory-warning observation is installed independently of SwiftUI before inference. It cancels/joins before idle unload; an intervening new owner prevents a stale unload. Ordinary scene backgrounding cancels the scene's running UI task and does not evict a separate headless job. Model import refuses active processing. Warm residency is reused within the process, not guaranteed across OS eviction.

One targeted recovery fix was required by physical evidence: a non-cancellation native batch error now unloads the unusable backend before surfacing failure. Cooperative cancellation keeps the model warm. There is no silent retry/fallback. A host test using the actual actor/native code proves failure → unloaded → next preparation/load → ID/EOG-valid result. This is not an injected physical GPU-failure test.

Native/header/manifest, VisionText, TextBlocks/protected spans and OverlayLayout hashes match the resumed baseline. Actor recovery, DEBUG diagnostics and the explicitly owner-authorized per-block failure handling changed in ScreenshotProcessor. Model prompt/sampling/native generation, OCR/grouping and overlay placement remain unchanged. The failed model output is rejected, not repaired.

## Physical device and pre-cleanup acceptance

Actual connected device: **iPhone 17 Pro Max / iPhone18,2, iOS 26.5.1**, UDID `00008150-001475EC2E98C01C`. No other phone was targeted. iPhone Mirroring was closed. The saved failing input was inspected: a valid nonblack 1320×2868 Chinese product screenshot.

The successful real OS runs below used a process created by Shortcuts itself, without Mac prelaunch or attached debugger/console. Cold means a new app process, not a purged filesystem cache.

| Release request | EN blocks | Preparation | Translation | Processor | Receipt → PNG | Reuse |
|---|---:|---:|---:|---:|---:|---|
| `8342DF77-6052-4CA1-B353-06DF9C4380AE` | 35 | 3.044 s | 19.930 s | 23.686 s | 23.745 s | cold, load 1 |
| `13F65CD0-8FDB-48FB-9CFC-548BB0184B09` | 35 | <0.001 s | 23.919 s | 24.410 s | 24.542 s | warm, still load 1 |
| `B86A3C76-F71D-4C93-A423-1DBB47007ED0` | see raw report | warm | see raw report | see raw report | 27.651 s | successful immediate post-cancel request |

The first two reports show nominal thermal state, Low Power Mode off, no memory warnings, zero panel intersections / unrelated-source overlaps / bounds violations and one honest fit warning. Resident memory was approximately 5.49 / 5.43 GB; footprint 999 / 1005 MB. These are 35-block screens with substantial output, not a rerun of the sprint's smaller product case; no performance search or cache speed claim was made.

User confirmed: “перевод сработал — я закрыл через крестик и запустил сразу еще раз — все сработало без ошибок”; “появился перевод оба раза и крестик вернул в исходное приложение”.

Actual OS cancellation request `E130F83B-9FCF-45AA-AB6E-D7D6F5F61CC3` records `Swift.CancellationError`; the immediately following request above returned PNG. User: “остановил — сработало и сразу запустил — сработало”. A/B and viewer/share/save smoke: “работают оба — можно удалять”. Foreground numerical exports also contain successful A/B reports with one model load retained. No manual physical cancellation-to-safe-exit interval was captured, so none is invented.

### Earlier failures retained as evidence

These failures preceded the successful true OS-created calls; they are not erased by later success:

| Request / process | Build | Outcome |
|---|---|---|
| `89FE748A…` / 14428 | Release | 30.101 s → batched decode failure; initial verify/load/warmup 3.175 / 17.921 / 0.670 s. |
| `AE4C8E99…` / same process | Release | 0.520 s → prefix decode failure from retained broken backend; motivated recovery fix. |
| `8F5905E3…` / 14484 | fresh Release | 34/34 native blocks completed in a 23.957 s call, then strict span check rejected missing P0 (expected P0/P1/P2, received P1/P2). Source/output evidence was not present in Release. No fabricated restoration was applied. |
| `DB4675FF…` / 14610 | temporary diagnostic Debug | 31/35 blocks, then 30.124 s failure. Console explicitly reports `kIOGPUCommandBufferCallbackErrorBackgroundExecutionNotPermitted`, `Insufficient Permission (to submit GPU work from background)`, backend invalid state and llama_decode -3. |

Those processes had been started/monitored from Mac before invocation. The real OS-created cold/warm calls subsequently passed. The exact execution-assertion difference is not established; this does **not** prove a universal 15- or 30-second AppIntent budget or universal background failure. The isolated span failure was not silently repaired or declared fixed.

## Phase 3 removal

Removed obsolete application/tooling code:

- Apple Translation service/session broker/language manager/batch builder and hidden TranslationSession host/preparation UI.
- All old Quick Look providers, runner, dictionary/English paths, remote configuration/client, fallback/timeout architecture, OCR mapping/grouping/renderer and diagnostics; old debug echo/tiny actions and registrations.
- CEDICT database and dictionary generators/fixtures; Mac FastAPI, OPUS and old Hy-MT server source/requirements/scripts.
- Old llama/Stage1 bridges, local native debug UI/harness/prompt profiles and old embedding/configuration wiring.
- Old orchestrator, OCR/grouping/rendering/normalizer services, provider protocols, AppContainer/AppServices, legacy adapter/result DTOs and unused old history/settings stores.
- Old renderer views and tests which only tested deleted implementations. Useful input/store tests were retained; obsolete scaffold assertions now test current DTO identity and strict spans.

Settings retain EN/RU, model import/readiness and Shortcut setup. Nonfunctional legacy renderer sliders, Apple language packs, LAN/preflight and old debug options are gone. Full viewer, lightweight preview, original/translated, zoom/pan, block details, transcript, Share/Photos Save and retry remain. The Quick Look setup guide now shows its actual three actions and native-X behavior; A/B setup and existing optional import links remain.

### Measured reduction

Physical source scope: owned `.swift/.mm/.h/.m/.cpp/.py/.sh`; excludes runtime/vendor, model weights, vocab/resource databases, docs/config, caches and generated artifacts. Compare the **current October 18 pre-cleanup snapshot**, not a clean Git HEAD that predates dirty work.

| Scope | Before files / lines | After files / lines | Net lines removed |
|---|---:|---:|---:|
| App and shared core, including DEBUG checks and standalone Next development entry | 107 / 32,560 | 37 / 5,695 | 26,865 |
| Tests | 14 / 2,303 | 5 / 519 | 1,784 |
| Owned tooling | 39 / 6,005 | 15 / 846 | 5,159 |
| Total | 160 / 40,868 | 57 / 7,060 | 33,808 |

**114 files deleted**, including **103 source files / 32,023 source lines** in deleted files. Net reduction is larger because retained files were also simplified. The 3,514,368-byte CEDICT database is a resource, not thousands of “source lines”. The original application Compile Sources phase now has **33 files / 5,296 physical lines**, including DEBUG-only checks; its native header and separate Next launch/benchmark entry are outside that compile-phase count.

Xcode cleanup removes **335 project objects**: retired file/build references, empty groups, obsolete embedding shell phase and unused resource build entries. Bridging header imports only current HyMTNative; legacy linker/search flags/configuration, network/ATS plist permissions and old Shortcuts registrations are removed. Photos permission, file sharing/import, bundle identity and current Metal/Jinja/runtime dependencies remain. Historical ScaffoldSnapshot.md stays in the repository but is no longer copied into the app/test bundles. Unit tests import the real app module rather than compiling a second copy of the application; test-host path matches the actual product name.

The final Release links and embeds **one** llama.framework. Apple Translation is absent from linked frameworks. No old backend is compiled/selectable. Release has no automatic PERF_MODE, PHASE1_CHECKS, PHASE2_MODE or Stage1 autorun strings.

## Final architecture

```text
ScreenTranslatorApp → AppEnvironment / AppCoordinator
  A/B intents → TemporaryImageStore → ProcessingViewModel
  Quick Look file-return intents ───────────────────────┐
                                                       ↓
  ScreenshotProcessor → VisionText → TextBlocks
    → one HyMTTranslator actor → HyMTNative / pinned Metal runtime
    → OverlayLayout / renderer → ProcessedScreenshot
      → full viewer / lightweight preview / PNG IntentFile
```

These small shared processing files remain physically under `ScreenTranslatorNext/`; the standalone development app references the same files, not a duplicate translator. No provider graph, model pool, second context, backend selector or production result cache was introduced.

## Validation after cleanup

| Check | Result / boundary |
|---|---|
| Original Debug physical-device build | PASS |
| Original signed Release, fresh DerivedData | PASS |
| Next Debug build, same shared core | PASS |
| Unit/UI | PASS, final 11 unit + 3 UI, zero failures; `final-tests.xcresult`. Includes captured real span omission and Quick Look partial-notice tests. |
| Phase 1 contracts | PASS, input latest/claim-once, spans, IDs, viewer geometry, model rejection, pre-load cancellation, memory-warning delivery, import rejection during active job |
| Native production p8 | PASS, IDs/prefix/packed/EOG/spans/wave split/capacity + cancellation/retry at five stages; host correctness, not iPhone timing |
| Whole-job ownership | PASS, 100 replacements, one active owner, late-old rejection, scoped cancellation/retry; host correctness |
| Geometry | PASS, current Vision/grouping/layout executed on Simulator; 16 EN/RU real/synthetic cases, matching recorded native translations, zero collision/coverage/bounds/fit failures |
| Model/native/OCR/group/layout hashes | PASS, unchanged selected implementation |
| Release signature / manifest / action metadata / one runtime | PASS locally |
| git diff --check / preservation audit | PASS |
| Final cleaned Release physical smoke | PASS by final owner confirmation, with known partial-translation/background limitations; evidence boundaries below |

Simulator UI completion uses explicitly labeled recorded-result fixtures; cancellation pauses the actual preparation boundary because the simulator has no 7B GGUF. Neither is claimed as physical inference. No new synthetic-only quality pass or full performance sprint was run.

## Post-cleanup launch authorization incident

The first installed cleaned Release could not launch at all. There was **no new Quick Look receipt**, no OCR/model work and no new application crash report. CoreDevice/SpringBoard reported EBADEXEC 85; macOS Console on the intended phone identified the real reason:

```text
amfid: validation failed because of missing trust and/or authorization (0xe8008026)
The provisioning profile requires online authorization.
AppleMobileFileIntegrityError Code=-400
```

Local signature/profile checks alone did not establish launch permission. The profile includes this phone and expires October 5, 2027; both previously working and cleaned apps use the identical Apple Development leaf certificate, valid June 2026–June 2027. Icon launch and an alternate phone network did not initially resolve it. A Mac HEAD request could reach PPQ; that does not prove phone authorization succeeded.

Apple documents the first-launch PPQ requirement and a seven-day offline-profile alternative in [Provisioning profile updates](https://developer.apple.com/help/account/provisioning-profiles/provisioning-profile-updates). No unsigned profile alteration, private entitlement, new certificate or security bypass was attempted.

The owner then accepted a new Apple Agreement. Afterwards the **final cleaned Release installed and launched successfully on the intended phone with the original normal profile** (`launch-after-agreement.json`, PID 15282). This is observed recovery after acceptance, not a claim about undocumented PPQ server internals. No offline profile was created or substituted. The empty diagnostic process was terminated before the requested true OS-created final Shortcut smoke, avoiding a prelaunched inference process.

## Post-cleanup translation failures — investigation history

After the signature launch check, the empty process was stopped. The actual Shortcut then created PID 15303 itself, without Mac prelaunch or attached debugger:

- `64200C7C-C4D5-4B67-92CB-D5189E2D84EA`: receipt 1792333682.305, failure 1792333712.414, **30.109 s**, `Batched decode failed/cancelled`. Release did not preserve a backend log, so the earlier diagnostic background-GPU denial is a hypothesis for this run, not newly proven here.
- `8B649B16-993D-4593-B361-23759B845E81`: receipt 1792333787.599, failure 1792333810.879, **23.280 s**, `Block 8: Protected spans corrupted: expected P0/P1/P2, received P1/P2`.

The second call progressed past a fresh preparation after the failed backend, rather than inheriting the earlier prefix-decode failure. Strict span validation still correctly refuses corrupted output. This recurs after cleanup and is not accepted as a cosmetic issue. The model/prompt/OCR/native algorithms remain unchanged; no value was fabricated and no dictionary/fallback was enabled.

A simulator export plus actual Mac actor/native run on the previously saved diagnostic input did not reproduce the span failure. It did not identify the new physical source and was not counted as physical acceptance. The subsequent physical capture/reproduction and authorized error-handling change below resolved the whole-screenshot abort for this class of invalid block. The earlier 30-second native failure is retained as a reliability issue, not declared fixed by the span change.

## Exact protected-span reproduction (October 18)

An autonomous foreground run on the physical iPhone, using the existing DEBUG quality entry point and the newly captured actual screenshot, reproduced the missing P0 without background-GPU interference. No user test buttons were required. Request `63B9EFA3-CFC0-4EAF-A42D-D28D4D446A16`, block ID 5 / generation index 2, ID matches, EOG true, 53 output tokens. The same screen's Vision observation IDs differ by capture/platform, so block 5 here is not assumed to equal every previous block 8.

The exact source has an Apple 18 **promax** product heading followed by a **Magsafe** / 17**pro** case description. Protected spans are `[promax, Magsafe, pro]`. The native output preserved P1/P2 but omitted P0. The complete source, masked text and raw model output are retained only in the external `physical-span-block/.../span-failure.json`; screenshot pixels remain in external diagnostic artifacts. This establishes model omission rather than cross-sequence ID leakage. Strict restoration correctly refuses it.

The owner subsequently authorized a narrowly scoped **partial-result error-handling** change: retain original pixels for the invalid block, expose a warning and keep other valid outputs. It is implemented and verified below; model/prompt/sampling and strict validation were not changed.

## Owner-authorized partial-result handling and physical verification

The owner explicitly approved: “Да, частичный результат с предупреждением”. The change is restricted to block output validation/publication:

- A bad protected-span or empty block output retains its source pixels, has no rendered overlay, and receives an explicit translation warning.
- Other valid ID/EOG-validated model outputs are kept. The ordinary viewer's existing partial banner/block details/retry display those warnings.
- System Quick Look appends a compact EN/RU notice **below** the screenshot, outside its original content; no custom close button or new screen is added. Valid complete images retain their exact UIImage. The shared overlay renderer/geometry are unchanged.
- ID/index mismatches, missing EOG, native decode/capacity/cancellation errors remain whole-request failures. An all-invalid batch also fails explicitly; an unchanged screenshot is not passed off as a successful translation.
- No semantic placeholder fabrication, dictionary, automatic retranslation, cache, model/prompt/sampling/native change was introduced.

The focused test uses the exact physical masked-source/output omission, confirms rejection of the invalid block, preservation of a valid neighbor, unchanged complete image identity and the appended partial-notice canvas. The initial test fixture used a 3× UIKit renderer despite the pipeline's 1× pixel canvas; its crop-height assertion failed. Correcting the fixture to production scale 1 passes. The final **14-test full selection passes**, rather than hiding the earlier test failure.

An autonomous **physical iPhone foreground** run of the same stored screenshot completed EN and RU using the production pipeline:

| Target | Requested / valid blocks | Translation | Total processor | Model |
|---|---:|---:|---:|---|
| EN | 30 / 29; one strict span rejection | 17.304 s | 21.824 s | first load |
| RU | 30 / 30 | see raw report | 40.544 s | reused, still one load |

Both runs had zero panel intersections, unrelated-source overlaps and bounds violations, and no memory warnings. EN retained two independent fit warnings. These are foreground debug-instrumented correctness runs, **not** system Quick Look timing or a new performance sprint. Artifacts: `physical-partial-final/` and `partial-foreground-console.log`. Release was restored after diagnostic validation.

Real post-fix Release OS-created PID 15778 then returned PNG twice:

| Request | EN blocks / valid | Preparation | Receipt → PNG | Reuse |
|---|---:|---:|---:|---|
| `C51C88B3-ADF8-4CC0-884D-192B5C173234` | 31 / 30, one translation warning | 4.173 s | 25.865 s | new process, load 1 |
| `592D47DB-4954-4B3D-A766-30E2953A6370` | 28 / 28 | warm | 15.272 s | same process, still load 1 |

The screenshots have different block counts and are **not claimed as a controlled cold/warm speedup pair**. The first call has zero intersections/coverage/bounds violations and two fit warnings; its thermal state is fair (1), Low Power Mode off, no memory warnings. Action Button-to-visible timing is still not independently measured. The final owner confirmation and instrumentation boundary are recorded below.

## Final owner smoke confirmation and evidence boundary

The final installed artifact is the cleaned, signed **Release** at `resume-20261018/DerivedData-final-release/Build/Products/Release-iphoneos/ChinaTap Screen Translator.app`. It was not replaced after the final smoke questions. The device remains connected as physical iPhone 17 Pro Max (`00008150-001475EC2E98C01C`). The restored Release has no automatic benchmark launch behavior.

After the partial-result fix, the owner reported:

> Это очень странно, что один из блоков просто остается на китайском, без причины — совсем обычный текст. Старый floating работает и старый open in app тоже работает.

This confirms A/B behavior, **not** approval of the missing block. The reason is established by the physical source/raw-output capture: the model omitted protected `promax`. Leaving original pixels avoids silently removing the product characteristic. The partial warning is recovery from a bad output, not a correction of that output. Both retained routes call the current shared 7B core; “старый” here describes the familiar UX, not a restored legacy translator.

The final question explicitly requested (1) Floating → Open Full Viewer without new progress and (2) stopping actual Fast7B Quick Look during processing, then immediately requesting it again. The owner answered:

> все работает

| Final physical smoke item | Verdict | Evidence |
|---|---|---|
| Actual installed Shortcut → system Quick Look | PASS, partial-result limitation | Two current Release PNG exports plus owner preview feedback |
| Native X → original app | PASS in this acceptance session | Owner explicitly confirmed both earlier real Release calls; subsequent final smoke confirmed working behavior; no independent UI video |
| A full viewer / B lightweight route | PASS | Final owner report that both routes work; retained physical route exports |
| B → Open Full Viewer without new progress | PASS by final owner confirmation | Final explicit question/answer; current identity-preserving implementation and automated DTO/UI checks |
| Quick Look stop → immediate retry | PASS by final owner confirmation | Final explicit question/answer; earlier actual OS cancellation/error receipt and successful immediate next PNG retained |
| Warm model reuse | PASS instrumented | Current real OS-created Release PID 15778, two completed PNG reports, loads stays 1 |
| Final cancellation safe-exit duration / new full-viewer counters | NOT INDEPENDENTLY MEASURED | No fresh matching exports in final copied container snapshot; old counter files are not presented as new proof |

Final read-only snapshots are under `resume-20261018/final-owner-confirmation/{quicklook,acceptance,processing}/`. The latest copied Release Quick Look request is still `592D47DB…`; the copied viewer-reuse files predate this final build. Therefore the final manual observations are reported as owner confirmation, not fabricated new request IDs or counter evidence. No additional test round was demanded merely to obtain duplicated telemetry.

The selected full unit/UI run has 14 passes / zero failures. Native ownership/recovery and 16-case geometry artifacts remain passing. Final `git diff --check` passes. HEAD remains `19d01e24aadd45847b277c2626308927a4cc3638`; there was no staging, commit or push. The retained OPUS owner weight is still 79,567,635 bytes; it was not deleted as part of the removed server source. The on-phone 7B model/container were preserved.

## Final disposition

- **Release integration: PASS WITH KNOWN LIMITATIONS.** Real system Quick Look works, as do the retained A/B result routes and owner-tested cancellation/retry. This is a signed development Release installed on the phone, not an App Store distribution/archive acceptance claim.
- **Phase 3: COMPLETED.** 114 files deleted and archived; 33,808 net owned source lines removed. 57 owned source/test/tool files / 7,060 lines remain in the measured scope. Apple Translation, old Quick Look providers/dictionaries, CEDICT, executable Mac/OPUS server code, obsolete llama bridges and duplicate OCR/grouping/rendering are removed from the application/project.
- **No currently observed P0 smoke blocker.** This does not erase the earlier failed requests.
- **P1 translation completeness:** an ordinary product description can lose a protected value in model output; one such block stays original with a partial warning. The owner expressly considers this undesirable. Not fixed by this task, and not relabeled an OCR or mapping problem.
- **P1 background reliability:** earlier long/cold calls failed near 30 seconds, including one explicitly captured background Metal permission denial. Later real OS-created calls and final owner smoke pass, but no evidence establishes unconditional reliability across all cold workloads or eviction conditions.
- **P2 layout fit:** two tiny source regions remained honest fit warnings in the current EN exports; zero panel intersections, unrelated-source overlaps or bounds violations in those reports.
- **Timing boundary:** current receipt-to-PNG is 25.865 s for 31 requested blocks / 30 valid, and 15.272 s for a different 28-block capture / 28 valid. They are not a controlled speedup pair. Action Button-to-visible time and final cancel-to-safe-exit milliseconds were not measured. No performance search was restarted.

This Release/Phase 3 task stops here. The next implementation scope, if requested, is a narrowly specified remedy for model protected-value omissions and long cold background reliability, using the retained evidence; no such model/prompt/translation change has been made or authorized by the cleanup task.
