# Hy-MT2-1.8B real-world trial and authorized cleanup

Installed October 28, user acceptance and cleanup October 29, 2026 (Asia/Shanghai).

**INSTALLED.** The original signed Release uses official Hy-MT2-1.8B-Q4_K_M through the existing shared processor and actual system Quick Look. The owner confirms «все работает». This is the expressly approved speed/quality trial, not a claim that previous commerce-quality weaknesses were repaired. On October29 the owner additionally authorized removing 7B, obsolete phone models and cache; that supersedes the earlier requirement to retain an immediate on-phone 7B rollback.

## Official artifact and actual native identity

- Repository: [Tencent Hy-MT2-1.8B-GGUF](https://huggingface.co/tencent/Hy-MT2-1.8B-GGUF).
- Immutable revision: `a0c709d9fac510f2c807aa3af52872340dc37a4a`.
- File: `Hy-MT2-1.8B-Q4_K_M.gguf`, **1,133,080,448 bytes**.
- SHA256: `dc5f44fcf1fa496ee7ad725982c0c8c553a4de00259b53af84c4b89fb0c06699`.
- Official repository head is the September8 README update. Expanded file metadata identifies the Q4 blob's last weight commit as `b27182d810fa3ceb6ed04e7c324c54e35c0d209c`, May20. Its size/LFS SHA match the previous artifact; no new weight update was substituted.
- The exact artifact was already in the ORIGINAL app's Documents, since August20. A full on-device size/SHA verification passed; it was not recopied or installed only into Next. An unnecessary new Mac download was stopped after finding/verifying the phone artifact; its incomplete `.part` file is not treated as a verified model.
- Actual Release `prepare18-release.json` proves stage `ready`, native path `Documents/Hy-MT2-1.8B-Q4_K_M.gguf`, matching verified manifest/hash and **Apple A19 Pro GPU / Metal**. Runtime log says `general.name = 1.8B`,32layers and vocabulary120818. The actual embedded template is used; no 7B token-ID assumption is made.
- Runtime remains llama.cpp v0.6.0 `d81235049384534c167caea52b85a694f6103d14`. Native bridge SHA is unchanged: `1d9248763d9010e48c50d8882d269ba810638b5780c242385df12d3a867160aa`.

Evidence root: `/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/trial18-20261028/`. Device inventories, native preparation, source baselines, build/test logs and request JSON remain outside Git.

## Active production configuration

`ScreenTranslatorNext/model.json` is the original application's bundled manifest, with `localPath` set to `Hy-MT2-1.8B-Q4_K_M.gguf`. After the owner's cleanup request there is **one model manifest, one app-owned HyMTTranslator, one native model/context**. The temporary 7B resource/selector was removed from both Xcode projects; `active-model.json` was removed from the phone. No model-selector UI or provider graph remains.

All existing routes retain their contracts: FastTranslateScreenshotIntent → PNG → system Quick Look; normal intent → full viewer; floating intent → lightweight result → the same completed full-viewer result. `FastTranslateScreenshotIntent` identity remains in Release AppIntents metadata. The app was updated in place, never uninstalled, and its data/Shortcuts/settings were preserved. Existing language preference was English; RU remains available.

Preserved inference: p8,6144 context, reserved prefix sequence8, exact token-prefix KV sharing, packed prefill, bounded independent waves/samplers/IDs, EOG, strict protected spans, one actor and native cancellation. Reference sampling remains temperature0.7/top-p0.6/top-k20/repeat1.05/seed42/limit512. Native inference, Vision OCR, grouping, layout and Quick Look intent source were not rewritten.

The 256-entry/1MiB exact RAM cache remains. Its keys include actual loaded model manifest/hash, template, prompt/language/config and exact normalized source. Only validated translations enter it. The former 7B process/cache did not survive the app update; no 7B cached result is attributed to 1.8B. Cleanup empties current values without disabling future reuse.

## Physical original-app shared-core smoke

Actual iPhone17ProMax / iPhone18,2 / iOS26.5.1, nominal thermal, LPM off. The following are **physical original-app DEBUG processor tests**, not Release Shortcut timings or Simulator inference:

| Authentic retained input | Target | Blocks generated | Cache hits | Processor total | Boundary |
|---|---|---:|---:|---:|---|
| Seller chat | EN |7/7|0|12.140s|cold, includes10.040s preparation; translation1.894s|
| Same chat | RU |7/7|0|2.986s|warm model, language-specific fresh generations|
| Archived dense35, SHA511153ff…|EN|35/35|0|4.899s|warm model|
| Same dense35|RU|35/35|0|9.037s|warm model|
| Seller chat, lifecycle replacement|EN|7/7|0|1.793s|warm model, actual replacement completed|

All four language/input combinations had zero translation failures. Chat layouts had zero fit warnings; dense35 had one EN /two RU fit warnings, preserved honestly. There was no OCR/layout redesign to conceal them. Dense35 EN is a single smoke result, not a new three-repetition benchmark median. Its matched previous7B reference was22.763s; the trial shows a real uncached gain but does not promise every screenshot is below10s.

## Real Release Action Button / Quick Look

The owner ran the existing Shortcut on live Chinese screens, closed native X, repeated and tested a dense page. Owner verdict: **«все работает»**. Actual Release reports record background initial application state2 and successful PNG return. The model was not prelaunched or console-attached from Mac for these OS runs.

| Request prefix | Requested / translated | Cache hits | Processor seconds | Receipt→PNG seconds | Model state |
|---|---:|---:|---:|---:|---|
| `E90ACB5B` | 23 / 23 | 0 | 5.063 | 5.139 | cold |
| `8840F87F` | 21 / 21 | 0 | 3.779 | 3.870 | warm |
| `5A3ACA3D` | 23 / 23 | 0 | 10.130 | 10.456 | warm |
| `A9224497` | 37 / 37 | 6 | 4.312 | 4.387 | warm |
| `7FF7322B` | 15 / 15 | 0 | 7.548 | 7.699 | warm |
| `ACD97392` | 16 / 16 | 4 | 3.298 | 3.437 | warm |
| `CD2298F8` | 22 / 22 | 18 | 1.114 | 1.199 | warm |
| `5D86DB34` | 24 / 24 | 4 | 2.806 | 2.888 | warm |

Eight exported successful EN reports have zero native-generation and translation/span failures. Model reused=true in seven following calls; these are different live captures, not a controlled median. Zero-hit real Release examples are3.870–10.456s receipt→PNG; the first cold23-block call is5.139s, preparation1.304s. Dense37 is4.387s **with6cache hits /31fresh generations**, so it is not labeled a fully uncached37-block benchmark. A partial repeat has18hits/22blocks and1.199s receipt→PNG. No fully cached identical 1.8B repeat timing was captured; do not relabel the earlier7B0.495s as this trial's number.

Receipt→PNG excludes the preceding Action Button/screenshot handoff and following OS presentation; no stopwatch Action Button→visible measurement is claimed. Actual system presentation/native-X→source is confirmed by the owner, not inferred from a compile.

Russian physical shared-core smoke passed; a new real Release Russian Shortcut capture was not requested after the owner confirmed the EN trial. It remains a normal selectable language for everyday testing.

## Lifecycle, tests and safeguards

- Original Debug and Release builds PASS. Release embeds one llama.framework and the existing AppIntent identities; no automatic DEBUG benchmark launch in Release.
- Unit/integration/UI run:20passed/0failed on Simulator, including cache isolation/eviction, strict values, full-viewer identity and pinned model-path tests. Simulator is not inference evidence.
- Physical original-app DEBUG route harness PASS: intent handoff, floating progress, native cancellation, retry, rapid replacement with different pixels, latest-result wins, dismissal and FullViewer reuse. Before/after FullViewer counters are identical: requests4,OCR4,grouping4,generations112,loads1,memoryWarnings0. There is no second translation/load/render when opening it.
- RouteA shared-core/intent/viewer contracts pass; the owner did not separately rerun the new Release RouteA/B UI. The physical DEBUG route covers actual RouteB processing and FullViewer. OS Shortcut cancellation was not repeated in this trial; native/app cancellation was.
- Hard safety remains strict. Invalid protected values retain original pixels with an explicit partial warning; no guessed restoration, cross-block output routing or fallback7B translation.
- Release endpoint memory varies with mmap accounting; the exported request table retains resident/charged footprints. Initial cold example has charged622.8MiB/resident1774.7MiB. These are endpoints, not an absolute peak. No memory warning was observed in the physical lifecycle test.
- Known semantic weaknesses remain: discounts, negation/action direction, refund/replacement meaning, technical names and labels can be wrong. The owner knowingly authorized this model trial; no dictionary, LoRA, prompt repair or hidden7B fallback was added.

## Authorized October29 cleanup

The owner then requested cutting7B and removing extra phone models/cache. Before removal, the retained7B file was full-SHA verified and a clean rollback worked; that earlier state is preserved in historical evidence. The subsequent deletion is intentional, not an accidental loss of the original installation.

- Removed `Documents/model.gguf`:4,624,648,896bytes (verified7B).
- Removed `Documents/tiny-test.gguf`:522,186,592bytes (old test model, exact expected regular-file identity checked).
- Removed model bytes total: **5,146,835,488** (~5.15GB decimal).
- Removed app Library/Caches contents: **26,327,111bytes** (~26.3MB). Cleared the in-memory translation cache by unloading/restarting; future exact caching remains enabled.
- Removed the obsolete `active-model.json` and7B manifest/selection code. Active1.8B size/SHA was verified before AND after deletion. Only the1.8B GGUF remains in the original application's Documents inventory.
- App data, settings, source screenshots/reports and historical benchmark artifacts were preserved. No Next app is installed on this phone; its sandbox has no extra models to remove. The Mac's archived/reference7B copy was not part of the phone cleanup and was not deleted.
- Git inventory contains only local `main` and `origin/main`, one worktree, so there were no spare branches to delete. No reset/clean/stash, discarded dirty changes, commit or push.
- Maintenance used an exact-path, identity-checked temporary DEBUG original-app mode because devicectl exposes no file-delete command. The deletion ledger is `cleanup/device/status.json`; the temporary source is archived outside production and removed before final Release. Final build/install verification follows below.

Immediate on-phone7B rollback is **no longer available by the owner's explicit request**. A future restoration would require a deliberate model/configuration deployment using the retained Mac artifact; the app will not silently select or download7B.

## Changed source

Shared loader/path and accurate model labels: `ScreenTranslatorNext/ScreenshotProcessor.swift`, `Features/Settings/SettingsView.swift`, `Features/Processing/ProcessingViewModel.swift`. Single pinned manifest: `ScreenTranslatorNext/model.json`, resource references in both projects. Tests: `Tests/Unit/ScreenTranslatorScaffoldTests.swift`. Existing DEBUG route check clears exact RAM memory before its native replacement case so cache hits cannot skip the cancellation exercise. Installer helper targets the manifest's separate filename.

No new model family/runtime/scheduler/platform research was performed. No server/network translation, user screenshot upload, paid training, new app or Phase3 repeat. Historical reports remain historical and do not override this approved1.8B configuration.

## Everyday use

Keep using the existing **Fast7B Quick Look** Shortcut name/action; its identity is intentionally unchanged even though its model is now1.8B. English is selected; choose Russian in existing Settings when needed. Known semantic limitations should be assessed on real screens. The first run after deleting compiled caches may rebuild kernels and take longer; current cache contents are empty.


### Final cleanup verification

Final original Debug and Release builds PASS. Six focused shared-core tests PASS after simplifying to one pinned model; the earlier full20-test run also passed. `git diff --check` passes. The clean Release was installed successfully in place; its bundle contains only `model.json`, one llama.framework, the preserved FastTranslateScreenshotIntent identity and1.8B manifest. Final on-phone GGUF inventory contains only `Hy-MT2-1.8B-Q4_K_M.gguf` at1,133,080,448bytes. Temporary cleanup code is absent from final source and Release; the useful original DEBUG checks remain. Native bridge hash is unchanged.

The owner-accepted eight real Quick Look runs above precede this storage/configuration cleanup. A new post-cleanup OS Shortcut smoke was not repeated; no new inference algorithm/model/prompt/renderer was introduced. The app is ready for continued everyday use; current RAM/disk cache has been cleared.


## October29 cold-start diagnosis

Owner reported a slow first request after cache cleanup. Actual Release request `CEE21A5B-FFEA-4B5F-9883-EBA92AC64F58` returned PNG in24.355s (35EN blocks, zero result-cache hits): model preparation15.737s, OCR1.159s, translation7.114s, render0.215s. The following request `AEDC3314…` had nine different EN blocks,3.604s receipt→PNG, and preparation0.000004s with the SAME PID37335/load count1. These different screenshots are not a matched inference speedup pair; they prove preparation is paid once in that process. Actual model remains1.8B, p8+packed+prefix remain enabled, no memory warning/model reload occurred between the two.

`prepare.json` records verification1.200s, native reported load0.339s, warmup0.653s. Approximately13.545s of preparation is outside those existing sub-timers. Source inspection explains the measurement gap: HyMTNative.load calls ggml_backend_load_all/llama_backend_init inside call_once BEFORE starting its load timer, then clears the initialization log. Backend registration constructs the Metal device and calls ggml_metal_library_init. This deployed framework contains embedded-source compilation and no bundled precompiled .metallib; the pinned source compiles the Metal libraries on device. Cold Metal/backend initialization, worsened by the recent shader-cache removal, is therefore the evidence-backed leading explanation for the missing interval; it is not a separately measured13.545s pure shader-compilation counter. JSON/scheduling overhead is not individually timed.

Diagnosis evidence: `../BuildArtifacts/oct2026/cold-start-20261029/`. No model, sampling, inference code or installed application was changed for this investigation. A targeted remedy is the supported precompiled Metal-library build path (default.metallib plus applicable tensor library), independently validated for the pinned runtime/A19Pro. Do not remove SHA integrity checks or hide the cost by calling cached output raw inference. A direct backend-init wall timer/log capture should accompany any such build change.
