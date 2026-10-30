# On-Device llama.cpp Phase 6 Persistent Session Benchmark

## What Phase 6 Changes

Phase 6 adds a DEBUG-only persistent llama.cpp session benchmark to the existing On-Device MT Smoke Test screen.

The screen now supports two isolated modes:

- Single Run / Cold Run: the existing path that may load the GGUF model, generate, and free the model for each test.
- Persistent Session: an explicit debug-only session that loads `Documents/tiny-test.gguf` once, reuses the loaded model/context for selected or run-all tests, and unloads only when the user taps `Unload Session`.

Persistent generation still uses the Phase 5 prompt, cleanup, CJK leak detection, keyword validation, warnings, raw/cleaned output, timings, token counts, resident-memory diagnostics, and validation status.

## What Phase 6 Does Not Change

Phase 6 does not connect on-device MT to Quick Look.

It does not change:

- AppIntent signatures.
- OCR.
- Grouping.
- Overlay rendering.
- `QuickLookLocalMTClient`.
- The remote Mac Hy-MT backend.
- Dictionary runtime behavior.
- Production translation defaults.

The persistent session is only reachable from the DEBUG smoke-test screen.

## How To Run On Real iPhone

1. Build and run a DEBUG build on a physical iPhone.
2. Open Settings.
3. Open On-Device MT Smoke Test.
4. Import a local `.gguf` if needed; it should be copied to app Documents as `tiny-test.gguf`.
5. Run one cold selected test first and record total/load/generation time.
6. Tap `Load Session`.
7. Confirm `Session Loaded` is `yes`, `Runtime Linked` is `yes`, and resident memory is shown.
8. Tap `Run Selected with Session`.
9. Tap `Run All with Session`.
10. Review the benchmark comparison and validation summary.
11. Tap `Unload Session`.
12. Confirm `Session Loaded` returns to `no`.

## How To Interpret Results

Useful fields:

- `Load`: one-time session load cost.
- `Generation`: per-test generation cost after reuse.
- `Total`: Swift/native wall time for the action.
- `Average Generation`: average generation time across persistent run-all.
- `Memory Before` / `Memory After`: resident-memory samples around session load or run-all.
- `Memory Delta`: approximate resident-memory change.
- `Session Remained Loaded`: confirms the session survived run-all.
- `Model Reloaded`: should be `no` for persistent generation and `yes` for cold generation.

The benchmark comparison is intentionally simple. It is meant to answer whether reusing the model has an obvious speed benefit before any Quick Look integration is designed.

## Expected Good Result

A good Phase 6 result looks like:

- Session load succeeds reliably on real iPhone.
- Run-all with session completes without crash.
- Most built-in cases are `pass` or explainable `warning`.
- Persistent selected generation is much faster than cold selected total time.
- Persistent run-all is clearly faster than cold run-all.
- Resident memory remains stable enough across repeated persistent runs.
- `Unload Session` succeeds and the status returns to unloaded.

## Failure Modes

Common failure modes:

- Missing model: import a GGUF so `Documents/tiny-test.gguf` exists.
- Runtime not linked: rebuild the local llama.cpp static libraries and generated xcconfig.
- Session not loaded: tap `Load Session` before persistent generation.
- Context too small: the prompt plus requested output exceeded the persistent context window.
- Generation failure: inspect raw error, prompt tokens, output tokens, and resident memory.
- Memory pressure: unload the session, restart the app, or test with a smaller GGUF.

## How To Unload Or Reset

Tap `Unload Session`.

If memory still looks suspicious after repeated runs, terminate and relaunch the app, then load the session again. The session is intentionally not loaded automatically.

## Data To Collect Before Phase 7

For each real-device benchmark, record:

- iPhone model and iOS version.
- GGUF model name and file size.
- Session load time.
- Resident memory before and after load.
- Cold selected total/load/generation time.
- Persistent selected generation time.
- Cold run-all total time.
- Persistent run-all total time.
- Persistent average/min/max generation time.
- Pass/warning/fail counts.
- Whether CJK or prompt fragments remain.
- Whether unload succeeds.

## Decision Gate For Phase 7

Proceed to Phase 7 only if:

- Session loads reliably on real iPhone.
- Run-all works without crash.
- Cleaned outputs are mostly pass/warning, not fail.
- Memory remains stable enough after repeated runs.
- Persistent session gives a clear speed benefit over cold per-run.
- Unload frees the session safely.

If these do not hold, continue improving the isolated smoke-test runtime before designing any Quick Look backend integration.
