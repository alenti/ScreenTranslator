# On-Device llama.cpp Phase 5 Quality Cleanup

## What Changed

Phase 5 improves the existing DEBUG-only On-Device MT Smoke Test so it is more useful for short Chinese UI, ecommerce, food, chat, and logistics phrases.

The smoke test now reports:

- Raw model output.
- Cleaned output.
- Cleanup actions applied.
- Cleanup warnings.
- CJK fragments that remain after cleanup.
- Prompt fragments found in raw or cleaned output.
- Expected keyword matches and misses.
- Validation status: `pass`, `warning`, or `fail`.
- Runtime, model, timing, token, and resident-memory diagnostics.

## Why This Happens Before Quick Look Integration

The real-device llama.cpp runtime is working, but screenshot translation needs cleaner and more predictable short-phrase behavior before it can safely sit near the Quick Look pipeline. Phase 5 keeps the work isolated so OCR, grouping, overlays, AppIntents, `QuickLookLocalMTClient`, the remote Hy-MT backend, and production translation defaults stay untouched.

## Prompt Strategy

The prompt is intentionally compact:

```text
Translate Chinese to English.
Return only the English translation.
No notes. No explanation. No labels.

Chinese:
<input>

English:
```

This keeps the instruction short and easy to tune later. If the model repeats labels or instructions anyway, the cleanup pipeline records and removes those fragments where it can.

## Cleanup Pipeline

The cleanup pass is deterministic and smoke-test-only. It does not call a network service, does not use the app dictionary runtime, and does not act as a standalone translation provider.

Cleanup currently:

- Keeps text after the last useful `English:` label when present.
- Cuts obvious trailing sections such as `Note:`, `Notes:`, `Explanation:`, `Chinese:`, `Input:`, `Prompt:`, `Do not`, `Return only`, and `Translate`.
- Removes repeated prompt fragments.
- Removes repeated original Chinese input.
- Normalizes spaces and newlines.
- Removes obvious leading bullets or numbering.
- Removes wrapping quotes.
- Prefers the first English-looking translation line when the model emits multiple lines.
- Applies a tiny DEBUG-only CJK patch map only when output is already mostly English.

The patch map is intentionally small. It exists to repair leaked fragments inside otherwise English output, such as `外卖` inside an English sentence. It is not a dictionary translation backend.

## Validation Meaning

`pass` means the cleaned output is non-empty, English-like, free of unpatched CJK residue, and matches enough expected keyword hints.

`warning` means the output may be usable but had cleanup issues, patched CJK fragments, prompt residue in raw output, partial keyword matches, or minor remaining residue.

`fail` means generation failed, the model was missing, the runtime was unavailable, output was empty, output remained mostly Chinese, prompt fragments survived cleanup, or expected meaning hints were completely missed.

This is not BLEU, COMET, or semantic AI evaluation. It is a deterministic sanity check for repeated local smoke tests.

## How To Run On Real iPhone

1. Build and run a DEBUG build on a physical iPhone.
2. Open Settings.
3. Open On-Device MT Smoke Test.
4. Tap `Import GGUF Model`.
5. Choose a local `.gguf` from Files.
6. Confirm the model path ends in `Documents/tiny-test.gguf`.
7. Run `Network error` first.
8. Confirm `Environment` is `Real iPhone`, `Runtime Linked` is `yes`, and the cleaned output is English.
9. Run all test cases.
10. Record pass/warning/fail counts, raw output, cleaned output, cleanup actions, CJK fragments, timings, token counts, and resident memory.

## Good Result

A strong Phase 5 run looks like:

- Most cases are `pass`.
- Any `warning` has a clear reason, such as raw prompt fragments that were successfully cleaned.
- `CJK Fragments` is `none` for cleaned outputs, or only appears when a small fragment was patched and reported.
- `Prompt Fragments` may appear for raw output, but cleaned output should not retain prompt labels or instructions.
- Load and generation times remain stable across repeated runs.
- The app remains responsive after run-all completes.

## If CJK Leaks Remain

First inspect whether the output is otherwise English-like. If it is mostly English with one small known fragment, add a tiny smoke-test-only patch entry and record the action.

If the output is mostly Chinese or repeatedly copies the input, do not patch it into a translation. Treat it as a model or prompt failure and keep the result as `fail`.

## If Prompt Fragments Remain

Check whether the raw output repeated the prompt or whether cleanup left a label behind. Add a conservative cleanup marker only if it does not destroy valid translations. Avoid adding broader rules that could remove real English text.

## Known Limitations

- The model is loaded fresh per smoke test.
- Stop sequences are implemented as cleanup truncation, not native llama.cpp stopping.
- Keyword validation is approximate and deterministic.
- Generic small GGUF models may still produce awkward translations.
- The tiny CJK patch map is not a general dictionary.
- This screen is DEBUG-only and must not become a production dependency.

## Recommended Phase 6

Phase 6 should still avoid Quick Look integration at first. Recommended next work:

1. Run Phase 5 on real iPhone with the current 498 MB model.
2. Save pass/warning/fail results and timings for all built-in cases.
3. Decide whether model reuse is needed to reduce repeated load overhead.
4. Add an optional retry prompt only for the isolated smoke-test screen if CJK leakage remains common.
5. Only after repeated clean real-device results, design an on-device translation backend interface behind a feature flag while keeping remote Hy-MT as the default path.
