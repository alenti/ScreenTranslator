# On-Device llama.cpp Phase 4 Real-Device Validation

## What Phase 4 Proves

Phase 4 verifies the isolated DEBUG-only on-device MT smoke test can run a local GGUF through the linked llama.cpp bridge on Simulator and, manually, on a real iPhone.

The validation target is still intentionally small:

- Import a local GGUF into app Documents as `tiny-test.gguf`.
- Run one selected built-in Chinese test phrase or all built-in phrases.
- Use a stricter translation-only prompt.
- Clean common extra model text such as `Note:`, `Explanation:`, repeated prompt labels, and repeated Chinese input.
- Show raw output, cleaned output, approximate validation status, timings, token counts, runtime-linked state, model size, environment, and resident memory when available.

## What Phase 4 Does Not Prove

Phase 4 does not integrate on-device MT into Quick Look, OCR, overlay rendering, AppIntents, `QuickLookLocalMTClient`, the remote Hy-MT backend, dictionary runtime, or production translation defaults.

It also does not prove Hy-MT quality, AngelSlim 1.25-bit support, STQ1_0 support, long screenshot throughput, background execution behavior, thermal behavior under repeated use, or App Store packaging readiness.

## How To Run On Simulator

1. Build and run the DEBUG app on an iOS Simulator.
2. Open Settings.
3. Open the On-Device MT Smoke Test screen.
4. Tap `Import GGUF Model`.
5. Pick a local `.gguf` file.
6. Confirm the import status shows `Imported`, with a path ending in `Documents/tiny-test.gguf` and a non-zero file size.
7. Pick a test case.
8. Tap `Run Selected Test`, or tap `Run All Test Cases`.
9. Record the diagnostics shown in `Latest Result`.

## How To Run On Real iPhone

1. Open `ScreenTranslator.xcodeproj` in Xcode.
2. Select the `ScreenTranslator` scheme and a physical iPhone destination.
3. Use a DEBUG configuration.
4. Build and run on the iPhone.
5. Open Settings in the app.
6. Open the On-Device MT Smoke Test screen.
7. Tap `Import GGUF Model`.
8. Choose a `.gguf` from Files, iCloud Drive, AirDrop-saved files, or another local document provider.
9. Confirm the import status shows `Imported`.
10. Run one selected test first.
11. If that succeeds, run all built-in test cases.

The screen should show `Environment: Real iPhone` when the test ran on device.

## How To Import GGUF On Real iPhone

The app does not download models. Move the GGUF onto the device yourself, then use the debug import button:

- AirDrop the `.gguf` to the iPhone and save it to Files.
- Or copy it into iCloud Drive and wait for it to become locally available.
- Or use Finder device file sharing only if that is configured later.

The importer copies the selected file into the app Documents directory as:

```text
tiny-test.gguf
```

If that file already exists, the importer replaces it. GGUF files remain local-only and must not be committed to git.

## Metrics To Record

For each Simulator and iPhone run, record:

- Device model and iOS version.
- `Environment` value.
- `Runtime Linked` value.
- Model filename and approximate model size.
- `Load` time.
- `Generation` time.
- `Total` time.
- `Prompt Tokens`.
- `Output Tokens`.
- `Resident Memory`.
- Raw output.
- Cleaned output.
- Validation status and warnings.
- Whether the app remained responsive after returning from the smoke-test screen.

## Expected Result

A good Phase 4 result looks like:

- Runtime linked: `yes`.
- Model exists: `yes`.
- Model size is non-zero and close to the imported GGUF size.
- The selected test returns a non-empty English cleaned output.
- The cleaned output has no CJK characters.
- The raw output may contain extra text, but the cleaned output should remove obvious notes or prompt labels.
- Validation is `pass` or `warning`.
- The app does not crash if the model is missing, invalid, slow, or produces poor text.

For the default phrase:

```text
网络错误，请重试
```

An acceptable cleaned output is approximately:

```text
Network error, please try again.
```

Exact wording is not required in Phase 4.

## Known Limitations

- Each test may load the model fresh; this is useful for safety but inflates total runtime.
- The cleaner is intentionally conservative and heuristic.
- Validation is not BLEU, COMET, or a real translation metric.
- Small generic GGUF models may produce mediocre translation quality.
- The current bridge uses simple deterministic generation and a small token budget.
- Simulator performance does not predict real iPhone thermal or memory behavior.
- Resident memory sampling is best-effort.

## Next Phase Recommendation

Phase 5 should keep the Quick Look pipeline untouched and focus on repeatable real-device measurements:

1. Run the Phase 4 matrix on at least one recent iPhone.
2. Test a tiny GGUF, the current 522 MB GGUF, and one stronger small translation-capable GGUF if available.
3. Decide whether model reuse is needed to avoid repeated load costs.
4. Only after stable real-device smoke tests, design an optional on-device backend mode behind a feature flag.
5. Keep the remote Mac Hy-MT backend as the default working translation path until on-device latency, memory, and quality are acceptable.
