# UI redesign, product polish and release readiness

October 30, 2026. Repository `/Users/notnik_kg/Desktop/Programming/ScreenTranslator/ScreenTranslator`, HEAD `19d01e24aadd45847b277c2626308927a4cc3638` (unchanged; nothing staged, committed or pushed). The pre-existing dirty tree from Phase 3 and the 1.8B trial was preserved; no reset, clean, stash or destructive checkout was used.

**Status: PARTIAL.** The redesign, mode selection, onboarding, localization, cleanup and release preparation are implemented. Debug and Release build, unit tests and UI tests pass on the Simulator. Physical iPhone verification of the new build is pending the owner's confirmation (see §18). The app is a release candidate, not App Store-ready: model distribution and the items in §20 remain.

Out-of-Git evidence (UI test screenshots): `/Users/notnik_kg/Desktop/Programming/ScreenTranslator/BuildArtifacts/oct2026/ui-redesign-20261030/`.

## 1. Original UI audit

| Screen | Findings |
|---|---|
| Launch / "home" | No real home. The root showed a processing placeholder ("Waiting for Screenshot") with a fake percentage bar (hard-coded 10 %, 22 %, 45 %…), a developer card "Latest Screenshot Handoff" (source name, filename, pixel size) and a text "Settings" button. There was no way to translate an image from inside the app. |
| Progress | Fake percentages; internal terms ("Grouping Text Blocks", "Rendering Overlay", "Preparing local model"); detail line exposed the GGUF name ("Hy-MT2-1.8B-Q4_K_M · on this iPhone"). |
| Floating preview (B) | Custom gradients, card-in-card layout, percentage badge, handoff debug card, hand-rolled colors for light/dark. |
| Full viewer | Functional (zoom, hotspots, share/save, transcript) but custom glass imitations with hard-coded colors; block detail showed raw frame coordinates (`x:… y:… w:… h:…`); transcript showed pixel size; partial banner exposed raw validation text ("Translation failed: Protected spans corrupted…"). |
| Errors | Separate dark gradient screen; raw `localizedDescription` from the native engine reached users (e.g. "Model SHA256 does not match pinned model", "Batched decode failed"). Quick Look errors surfaced raw text in the Shortcuts alert. |
| Settings | One form: segmented language picker, "present and SHA-256 verified" status, "Import Hy-MT2-1.8B-Q4_K_M" button, Shortcut instructions for three flows (Quick Look, full viewer, lightweight preview). |
| Release hygiene | Release wrote `prepare.json`, `ProcessingMetrics/` and an unbounded `ReleaseQuickLook/<id>/` folder per request into Documents, which is visible in the Files app (`UIFileSharingEnabled`). `openFullViewerRecordingReuse` wrote acceptance JSON in Release. App targeted iPhone + iPad but had no iPad icons (build warnings, and App Store would require iPad screenshots). No privacy manifest. English only. |

## 2. Visual design principles

Apple system-app style (owner request: "в стиле Apple-приложений"). Material 3 was suggested mid-task; it was not applied because it is Google's design language and would conflict with the iOS look.

- Native components first: `List`/`Form` inset-grouped, `NavigationStack`, sheets with detents, `Picker`, `LabeledContent`, `ShareLink`, `PhotosPicker`.
- iOS 26 Liquid Glass for floating controls only (`.glassProminent`, `.glass`, `.glassEffect`), placed on the full viewer and primary actions.
- System typography (Dynamic Type text styles only), SF Symbols, semantic colors (`.secondary`, `systemGroupedBackground`, `.separator`). No hard-coded light/dark colors, gradients or decorative animation.
- One accent color taken from the app icon's orange: `#C2410C` light / `#EF6B24` dark (light variant has ≥ 4.5:1 contrast against white).
- One prominent action per screen. Motion is limited to state changes and respects Reduce Motion.
- Small shared component set in `Features/Shared/SharedViews.swift`: `ModelStatusLabel`, `ShortcutSetupSteps`, `FeatureHeader`, `PrimaryButton`. No framework or abstraction layer.

## 3. Screens redesigned

- **Home** (new, `Features/Home/HomeView.swift`): large title, one-line description, primary **Translate Image** (Photos picker, no library permission required), model setup prompt when the model is missing, **Translate To** picker, **Last Translation** row (reopens the completed result with no new inference), **Translate from Any App** (Action Button setup, shows current mode), **AI Model** status row, Settings button.
- **Translation progress** (`Features/Processing/ProcessingView.swift`): screenshot thumbnail, "Chinese → English", three real stages (Reading screenshot → Translating → Preparing preview). The translating stage shows "Getting the AI model ready…" during an actual model load, then "12 of 23 text blocks" with a determinate bar driven by the native per-sequence completion callback. Cancel; then in place: cancelled state (Try Again / Close) or a readable error (Try Again, or Set Up AI Model for model errors). VoiceOver announces stage changes.
- **Full viewer** (`Features/ResultOverlay/ResultOverlayView.swift`): edge-to-edge zoomable image (unchanged `ZoomablePreviewImage` geometry), glass close button, Share (`ShareLink`), "More" menu (Save to Photos, Copy Translation/Original, Show All Text, Reset Zoom, Translate Again). A **Translated / Original** segmented control sits at the bottom. A one-time "Tap any text for details" hint. A subtle partial notice that opens All Text. Tap hides chrome.
- **Block detail / All Text** sheets: native lists with selectable text, a Copy menu and a readable note for untranslated or shortened blocks. Coordinates and pixel sizes removed.
- **Floating preview (legacy B)**: same progress panel; when complete, the translated image plus **Open Full Viewer** (reuses the same `ProcessedScreenshot`).
- **Settings** (sheet): Translation (Translate To, Show Results), Action Button Setup, AI Model (status → details), About (version/build, Privacy, Acknowledgements, Show Welcome Guide).
- **AI Model details**: status, model name (`Hy-MT2-1.8B`), size, free storage, Import Model File… (only when not ready), privacy note.
- **Action Button setup**: mode cards with Recommended badge, exact numbered steps for the selected mode, Open Shortcuts.
- **Onboarding** (new): see §7.
- `ErrorView`/`ErrorViewModel` removed; errors are shown in the progress screen.

## 4. Screenshots

Captured by UI tests (Simulator, iPhone 17 Pro Max, iOS 26.5): onboarding pages, Home, floating progress and completed preview. Archived outside Git in `BuildArtifacts/oct2026/ui-redesign-20261030/screenshots/`. The first full run executed in the simulator's Russian locale, so those images also document the RU UI. No "before" screenshots were captured in this session; the before state is described in §1.

## 5. Shortcut mode-selection implementation

Setting **Show Results** (`resultPresentation`, UserDefaults) with two options:

- **Quick Preview** (default, recommended): *Take Screenshot → Translate Screenshot for Quick Look → Quick Look*. Uses the existing `FastTranslateScreenshotIntent` (background, returns PNG) and the real system Quick Look with its native X.
- **Open in App**: *Take Screenshot → Translate Screenshot in App*. Uses the existing `TranslateScreenshotIntent` (foreground), which opens progress and then the full viewer.

The selector chooses which configuration the app explains and recommends: Settings, the Action Button screen, onboarding and the Home row all follow it, with exact steps and an **Open Shortcuts** button (`shortcuts://create-shortcut`, with a fallback to `shortcuts://`). Optional ready-made iCloud links appear only if `QuickPreviewShortcutURL` / `MainScreenshotTranslatorShortcutURL` are configured in Info.plist. They are not configured today, so no link is shown.

## 6. Actual mode behaviour and limitations

- **iOS does not let an app rewrite a user's Shortcut.** A Shortcut that ends in a Quick Look action always shows Quick Look, and an app-opening intent always opens the app. A single Shortcut cannot honour both modes, because the returned PNG would still be passed to Quick Look. Two configurations is the technically correct design. The UI says so: "After changing it, update the shortcut once".
- Existing installed Shortcuts are untouched. All four intent identities remain in Release metadata (verified in `Metadata.appintents`): `FastTranslateScreenshotIntent` (visible, "Translate Screenshot for Quick Look"), `TranslateScreenshotIntent` (visible, title now "Translate Screenshot in App"), `QuickLookTranslateScreenshotIntent` (hidden alias) and `FloatingScreenTranslateIntent` (now hidden from discovery and from App Shortcuts but still runnable by installed shortcuts). Only display titles changed; identities and parameters did not.
- App Shortcuts list now shows two entries, "Quick Preview" and "Open in App". Siri phrases are unchanged and English only.
- Quick Look errors now reach the Shortcuts alert as readable messages (`AppError`). Cancellation is still rethrown as-is.

## 7. Onboarding

Six short steps, shown once: Welcome → Language → AI Model → How should results open → Action Button setup → Ready. The step is persisted (`onboardingStep`), so an interruption resumes in place. If an Open-in-App Shortcut arrives during onboarding, the handoff takes priority and onboarding reappears afterwards. An installed model is recognised ("AI Model Ready"). A missing model offers the real Import Model File… action or **Set Up Later**. Existing language and Shortcut settings are prefilled and never reset. No permissions are requested. Settings › Show Welcome Guide replays it. The owner will see it once after updating.

## 8. Model readiness UX

`ModelState`: checking, notInstalled, damaged (wrong size), installing (import copy and SHA-256), insufficientStorage (checked before import), ready, failed(AppError). The status uses a fast presence/size check. The full SHA-256 verification still runs inside `prepare()` before every load, as before. **Not implemented:** download/verify-download states. No Download button exists because there is no backend; `ModelState` is where those cases go when model delivery is built. The model name is shown only in AI Model details.

Active model preserved: `model.json` still pins `Hy-MT2-1.8B-Q4_K_M.gguf`, 1,133,080,448 bytes, SHA-256 `dc5f44fc…6699`. Prompts, sampling, p8, prefix KV sharing, packed prefill, exact cache, cancellation, spans, OCR, grouping, layout and native code are unchanged. The only edits in `ScreenshotProcessor.swift` are diagnostics file locations (see §10). No 7B artifacts were touched; per the 1.8B trial report, the on-phone 7B was already removed earlier at the owner's request, and the Mac archive copy was not touched.

## 9. Developer-only functions removed from the product

- Fake percentage progress (`ProcessingState.progressValue`, `displayTitle`) and internal stage names.
- "Latest Screenshot Handoff" card (`latestInputSummary`), model filename in progress text.
- Block frame coordinates, transcript pixel-size badge, raw warning strings in the viewer.
- Raw engine/native error text in the app and in Shortcuts alerts.
- Release Acceptance JSON written when opening the full viewer (now DEBUG-only).
- Release diagnostics in user-visible Documents: `prepare.json`, `ProcessingMetrics/` and `ReleaseQuickLook/` now go to `Library/Caches/Diagnostics` in Release. `ReleaseQuickLook` is pruned to the 32 most recent reports; previously it was unbounded. DEBUG keeps Documents so existing device-export tooling still works. Existing files already on the phone were not deleted.
- Release binary check: no `PHASE2_MODE`, `PHASE1_CHECKS`, `Phase2Reports`, `ACCEPTANCE`, `viewer-reuse`, `benchmarkLoad` or UI-test strings.

Kept and DEBUG-isolated: `Phase1Checks`, `Phase2Checks` (route/UI/quality harnesses, updated to the new API), per-request DEBUG reports, span-failure evidence.

## 10. Production code cleanup

- Deleted: `ErrorView.swift` (174 lines), `ErrorViewModel.swift` (63), `OverlayPreviewSurface.swift` (77) and `IntentResultRouter.swift` (32; a router used only by a test; `IntentHandoffRequest` moved to `ScreenshotInput.swift`). Also unused `ScreenshotInput.placeholder` / `ProcessingJob.placeholder`, the `ResultMode.text` case, about 25 unused view-model properties, the empty `Resources/Dictionaries/` folder and the empty `Features/Debug` and `Features/OnDeviceMT` folders.
- `AppRoute` reduced to idle / processing / floatingPreview / result. The settings and error routes are replaced by a sheet and an in-place state.
- Fixed while testing: Retry on the legacy floating screen jumped to the full-screen route; it now stays on the floating route.
- UI layer (all touched app files): **3,282 → 2,955 lines**, while adding Home, onboarding, model details, Action Button setup, Privacy and Acknowledgements. That is 4 files / 346 lines deleted. Tests were not deleted to inflate this number.
- Project: deployment target 18.0/18.5 → **26.0** (all targets), `TARGETED_DEVICE_FAMILY` → iPhone only (removes both iPad-icon warnings and iPad screenshot requirements), `ru` added to known regions, stale file references removed. Swift compile warnings in app code: 0 (the two earlier warnings are fixed). Remaining warnings come from vendored llama.cpp/jinja headers.

## 11. Files

New: `Features/Home/HomeView.swift`, `Features/Onboarding/OnboardingView.swift`, `Features/Shared/SharedViews.swift`, `Resources/Localizable.xcstrings`, `Resources/InfoPlist.xcstrings`, `Resources/PrivacyInfo.xcprivacy`, this report.
Rewritten: `ScreenTranslatorApp.swift`, `App/AppCoordinator.swift`, `App/AppEnvironment.swift`, `App/AppRoute.swift`, `Core/Models/AppError.swift`, `Core/Models/ProcessingState.swift`, `Features/Processing/*`, `Features/ResultOverlay/ResultOverlayView.swift`, `ResultOverlayViewModel.swift`, `ResultMode.swift`, `Features/Settings/*`, `Intents/AppShortcutsProvider.swift`, `ScreenTranslatorUITests/ScreenTranslatorUITests.swift`.
Edited: `Intents/TranslateScreenshotIntent.swift` (titles, hidden floating, readable errors, diagnostics location/pruning, nicer partial notice), `ScreenTranslatorNext/ScreenshotProcessor.swift` (diagnostics directory only), `Core/Models/ScreenshotInput.swift`, `ProcessingJob.swift`, `Core/Phase1Checks.swift`, `Core/Phase2Checks.swift`, `SupportingFiles/Info.plist`, `Resources/Assets.xcassets/AccentColor.colorset`, `ScreenTranslator.xcodeproj/project.pbxproj`, `Tests/Unit/ScreenTranslatorScaffoldTests.swift`, `Tests/Integration/IntentInputFlowTests.swift`.
Deleted: the four files listed in §10.

## 12. Localization

String Catalog with **English and Russian**: 162 entries, all fully translated. Build-time extraction shows 0 missing and 0 unused keys. The partial-result count uses real plural variants (RU one/few/many/other). `InfoPlist.xcstrings` localizes the Photos usage text. Chinese UI did not exist before and was not added; source content stays Chinese.

- Target language and UI language are separate. The target is stored in `localTarget`, which the Quick Look intent reads; UI language follows iOS.
- The Quick Look partial notice is written in the *target* language, because that is what the reader of the image reads.
- App Intent action titles stay English in both languages so the in-app setup steps match what Shortcuts shows.
- Siri phrases are not localized.

## 13. Accessibility

Dynamic Type everywhere (text styles only). Touch targets are ≥ 44 pt. VoiceOver:

- labels on icon buttons (Close, Share, More);
- combined elements for rows and steps;
- `.isSelected` traits on choices;
- stage and toast announcements;
- block hotspots keep their translated-text labels.

Reduce Motion is honoured for viewer chrome and mode switching. Semantic colors give correct light/dark rendering. Not done: an audit with Accessibility Inspector at the largest accessibility sizes, and landscape screenshots.

## 14. User-facing errors

`AppError` maps every processor/native message to: Can't Read This Image, Screenshot Not Received, No Chinese Text Found, AI Model Not Installed, AI Model Needs Reinstalling, AI Model Couldn't Start, Not Enough Storage, Translation Failed. Raw causes stay in `detail` (DEBUG/harness) and in diagnostics. The partial-translation safety behaviour is unchanged: invalid blocks keep their original pixels. This is disclosed subtly and never hidden:

- in-app: the "N text blocks shown in the original" pill and a per-block note;
- Quick Look: a pale strip below the image ("⚠︎ … couldn't be translated reliably and is shown in the original").

## 15–17. Build and test results

| Check | Result |
|---|---|
| Debug, Simulator (iPhone 17 Pro Max, iOS 26.5) | PASS, 0 Swift warnings in app code |
| Release, signed for the physical iPhone (`00008150-001475EC2E98C01C`) | PASS, 0 Swift warnings; bundle has one `llama.framework`, `model.json`, `PrivacyInfo.xcprivacy`, `en/ru.lproj`; MinimumOS 26.0; iPhone only |
| Unit tests (15) | PASS 15/15, including new: error mapping never exposes native text; mode/target/onboarding settings persist; last result reopen and release without reprocessing |
| UI tests | PASS 5/5: onboarding walkthrough → Home; Settings → Action Button setup; floating cancel → retry → cancel → dismiss (real `intent.perform` handoff, preparation boundary held, no simulator model); recorded-result floating → full viewer (same image, no new processing) → close → Home with Last Translation; floating dismissal. Launch-performance tests skipped. |
| Native/OCR/layout contract | Unchanged code paths (native, Vision, grouping, layout, renderer not edited). `Phase1Checks` updated and compiled in DEBUG. Physical native p8/geometry harnesses were not rerun because inference code did not change. |

Final run after all edits: **20/20 PASS** (`final.xcresult`, iPhone 17 Pro Max Simulator, iOS 26.5). The first full run found 3 UI failures. Two were tests querying English text while the simulator ran in Russian; the tests now pin `-AppleLanguages (en)`. One was a **real bug** (Retry on the legacy floating screen switched to the full-screen route), which is fixed. Final Release, generic iOS device, development-signed (team XWSTFX7FZU, bundle `AlenShamatov.ScreenTranslator`): **PASS**, with no DEBUG harness strings in the binary. `git diff --check`: clean.

## 18. Physical iPhone validation

**NOT TESTED for this build.** The owner's iPhone 17 Pro Max (`00008150-001475EC2E98C01C`, iOS 26.5.1) was connected at the start, and the first Release build was signed against it. It became unavailable (disconnected or locked) before the final Release could be installed. Nothing was installed on the phone during this task; its app data, model and Shortcuts are untouched. Simulator results are not claimed as physical passes, and inference was not run on the Simulator.

To finish: connect and unlock the phone. Then install the Release build in place (an update, not a reinstall) and check the 12 items from the task brief:

1. Launch.
2. Home screen.
3. Model shown as Ready.
4. Chinese → English.
5. Chinese → Russian.
6. Quick Preview opens Quick Look.
7. ✕ returns to the source app.
8. Open in App opens the viewer.
9. Last Translation reopens without new progress.
10. Cancel and Try Again.
11. Settings persist.
12. No developer controls.

## 19. Known remaining issues

- Model quality limits from the 1.8B trial remain (occasional protected-value omission leads to a disclosed original block; semantic errors on discounts and negation).
- Earlier background GPU/30-second failure history is unchanged by this UI task.
- "ChinaTap Screen Translator" is truncated on the Home Screen. A short `CFBundleDisplayName` is the owner's branding decision and was not changed.
- Landscape and the largest Dynamic Type sizes were not screenshot-audited.
- Siri phrases are English only.

## 20. App Store submission blockers

1. **Model distribution**: the 1.13 GB model must currently be imported manually from Files. There is no download, Background Assets or On-Demand Resources pipeline. Reviewers and new users cannot translate until this exists.
2. **Hy-MT2 model licence**: its terms must be confirmed for commercial App Store distribution, and the full licence/attribution text added to Acknowledgements. Today the screen names the model and links to its page only.
3. **llama.framework privacy manifest**: confirm the embedded framework needs no own `PrivacyInfo.xcprivacy`, and check the app manifest reasons against Apple's current list.
4. App Store Connect metadata: privacy nutrition label ("Data Not Collected" matches the code), support and privacy-policy URLs (no support contact is configured in the app), screenshots, age rating, description.
5. Version/build numbers are still 1.0 (1). Distribution signing/archive has not been exercised (only development signing).
6. Display-name decision (§19).
7. Physical verification of this build (§18) and broader device coverage beyond iPhone 17 Pro Max.
