# On-Device llama.cpp Phase 7 Prompt, Stop, And Benchmark Tuning

## Goal

Phase 7 improves the existing DEBUG-only On-Device MT Smoke Test after real-device persistent-session validation showed that runtime performance is viable but output quality is unstable for short Chinese UI, shop, food, and chat phrases.

The goal is to make the debug screen better at answering:

- Which prompt profile works best for a phrase.
- Whether native stop sequences prevented extra notes, labels, or repeated instructions.
- Whether cleanup removed prompt residue without damaging good translations.
- Whether CJK fragments leaked into cleaned English.
- Whether built-in cases pass deterministic sanity checks.
- How generation time, output tokens, and memory compare across profiles and session modes.

## What Changed

Phase 7 adds a small prompt-profile matrix to the smoke-test service:

- `minimal`: shortest possible translation prompt.
- `strict`: compact Chinese-to-English instruction with labels.
- `uiShort`: concise app/UI label translation.
- `foodOrder`: food/order/product option phrase translation.
- `logisticsChat`: longer seller/chat/logistics sentence translation.

Each built-in test case has a default profile based on category. The DEBUG UI also allows manual profile override and a `Run Selected Across Profiles` benchmark that runs the selected phrase through every profile.

Native stop sequence support was added to the Objective-C++ llama.cpp bridge. After each decoded token, the bridge checks the accumulated generated text for common unwanted sections such as `Note:`, `Explanation:`, `Chinese:`, `English:`, `No notes`, and `No explanation`. When a stop sequence is found, generation stops early, the bridge reports the stop sequence, and the Swift cleanup pass receives the truncated output.

The cleanup and validation passes were tuned for the observed failures:

- Repeated `English:`, `Translation:`, and prompt-instruction fragments are removed more deliberately.
- Duplicate sentence blocks are collapsed.
- Missing spaces around patched terms are fixed, such as `restaurant'sdelivery`.
- A tiny smoke-test-only CJK patch list handles known residues like `外卖`, `云吞`, `神券价`, and `份量` when the output is otherwise English-like.
- Validation distinguishes hard failures, acceptable cleanup warnings, and quality warnings using deterministic checks.

## What Phase 7 Does Not Change

Phase 7 still does not connect on-device MT to Quick Look.

It does not change:

- AppIntent signatures.
- OCR.
- Grouping.
- Overlay rendering.
- `QuickLookLocalMTClient`.
- The remote Mac Hy-MT backend.
- Dictionary runtime behavior.
- Production translation defaults.

The work remains reachable only from the DEBUG On-Device MT Smoke Test screen.

## How To Test On Real iPhone

1. Build and run a DEBUG build on a physical iPhone.
2. Open Settings.
3. Open On-Device MT Smoke Test.
4. Import a local `.gguf` if needed. It is copied to app Documents as `tiny-test.gguf`.
5. Tap `Load Session`.
6. Confirm:
   - `Runtime Linked` is `yes`.
   - `Session Loaded` is `yes`.
   - Model size is shown.
   - Resident memory is shown.
7. Pick a known difficult case such as `Favorite reward`, `Portion size`, `Friendly reminder`, or `Add random wontons`.
8. Review the default profile and optionally select another profile.
9. Tap `Run Selected with Session`.
10. Tap `Run Selected Across Profiles`.
11. Tap `Run All Default Profiles` or `Run All with Session`.
12. Record pass/warning/fail counts, generation times, stop triggers, CJK leaks, prompt-fragment leaks, and memory.
13. Tap `Unload Session` when done.

## Good Result

A strong Phase 7 real-device result looks like:

- Session load remains reliable.
- The selected-across-profiles list identifies at least one clean profile for difficult short phrases.
- Most default-profile test cases are `pass` or explainable `warning`.
- Prompt fragments may appear in raw output, but cleaned output should not retain them.
- CJK fragments should be absent after cleanup, or patched and clearly reported as warnings.
- Native stop triggers should reduce trailing notes or repeated labels without cutting valid translations.
- Persistent generation remains materially faster than cold one-shot total time.

## Metrics To Capture

For each real-device benchmark, capture:

- iPhone model and iOS version.
- GGUF model name and file size.
- Prompt profile used.
- Run mode: `coldOneShot` or `persistentSession`.
- Prompt token count.
- Output token count.
- Generation duration.
- Total duration.
- Resident memory before and after.
- Stop triggered: yes/no.
- Stop sequence, if any.
- Raw output preview.
- Cleaned output.
- Cleanup actions.
- Validation status.
- Validation warnings.
- CJK fragments.
- Prompt fragments.

## Known Limitations

- Stop detection is string-level after token decode, not tokenizer-level stop-token enforcement.
- The cleanup patch map is intentionally tiny and smoke-test-only.
- Keyword validation is deterministic and approximate; it is not semantic model evaluation.
- Generic GGUF models may still mistranslate short Chinese commerce phrases.
- Profile benchmarks are manual DEBUG experiments and can be expensive when run across all cases.
- The model is still imported locally; no automatic model download exists.

## If Prompt Fragments Remain

Check whether the fragment appears only in raw output or also in cleaned output.

If the cleaned output is good, keep the result as a warning. If prompt residue survives cleanup, add a narrow fragment rule only when it cannot remove valid translation text.

## If CJK Leaks Remain

If the output is mostly English with one known short residue, add a small smoke-test-only patch entry and record the cleanup action.

If the output is mostly Chinese, copied input, or unrelated text, keep it as a failure. Do not turn the patch map into a translation provider.

## Next Recommended Phase

Phase 8 should still avoid production Quick Look integration until the prompt/profile matrix is stable on real hardware.

Recommended next work:

1. Run Phase 7 repeatedly on real iPhone with the current 498 MB model.
2. Choose default profiles that consistently produce pass/warning results.
3. Decide whether a single profile is good enough or whether future block categories need profile routing.
4. Add a manual retry-profile experiment only inside the DEBUG screen if CJK leaks remain common.
5. After clean repeated runs, design a feature-flagged on-device backend interface that can coexist with remote Mac Hy-MT while remaining disabled by default.
