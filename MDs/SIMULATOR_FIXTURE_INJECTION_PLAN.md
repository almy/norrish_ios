# Simulator Fixture Injection Plan

## Goal

Make simulator and persona testing behave as if camera capture already succeeded, without changing the production user experience.

Desired simulator behavior:

- `Scan Product` returns a real EAN and continues through the normal lookup flow
- `Analyze Plate` returns a real image and continues through the normal analysis flow

Desired production behavior:

- unchanged UI
- unchanged navigation
- no visible fixture/debug path for normal users
- no fixture assets bundled into the app target

## Simulator Filesystem Reality

Fixture files live outside the app bundle under `norrish-agents/fixtures/`.

That means app-side fixture loading in simulator/debug mode must explicitly resolve those files from the host filesystem.

Access strategy:

- `ProcessInfo.processInfo.environment["FIXTURE_PATH"]` points to the absolute fixture root
- no relative-path fallback is implemented; absolute path is more explicit and less fragile
- if `FIXTURE_PATH` is not set, or points to an incomplete/invalid fixture directory, the app falls back to legacy hardcoded samples

Production builds should not depend on any of this path resolution.

If `FIXTURE_PATH` is not set in simulator/debug mode:

- barcode should fall back to the current hardcoded sample behavior
- plate should fall back to the current simulator `Simulate Scan` behavior until that path is removed

That keeps the app usable for developers who have not configured external fixtures yet.

## Important Correction

The barcode path is **not** a greenfield problem.

It is already mostly implemented:

- `CameraBarcodeScannerView.swift` already has `#if DEBUG && targetEnvironment(simulator)`
- simulator builds already show a barcode debug surface instead of the live camera
- the debug surface already injects a barcode into the real downstream flow

So the barcode plan should be **incremental**, not architectural.

The plate path is the one that still needs a cleaner simulator-first seam.

## Recommended Split

Treat the two flows differently.

### Barcode

Keep the current simulator debug path and extend it.

Do not introduce a generic cross-flow `ScanInputProvider` abstraction.

Barcode and plate have different input shapes and different simulator problems.

Best next step:

1. augment `DebugBarcodeFixtures.samples` with file-backed loading, retaining hardcoded fallback
2. load barcodes from the external fixture manifest / barcode JSON
3. support launch-arg or env-driven selection
4. preserve the existing downstream lookup/result flow

That is enough for barcode.

### Plate Analysis

Plate analysis is harder.

Unlike barcode, the current plate flow is not just "camera returns image, then backend runs".

There are multiple capture backends and they produce meaningful capture context before the backend call:

- ARKit-derived depth context
- Dual-camera depth/volume context
- Enhanced camera context
- YOLO detection outputs
- segmentation-derived coverage / region information

So the plate problem is not just image acquisition. It is **capture payload parity**.

That is why plate still needs a more careful seam later.

## Abstraction Scope

For v1, do not introduce protocol abstractions unless implementation pressure actually requires them.

Why:

- barcode can be implemented by extending the existing `DebugBarcodeFixtures` path
- plate can be implemented by injecting fixture-backed data at the `analyzePreparedImage(...)` seam
- adding `BarcodeInputSource` / `PlateInputSource` protocols now increases surface area without being necessary for the stated goal

Those abstractions may become useful later if you want:

- cleaner runtime switching
- isolated provider tests
- broader reuse across multiple capture flows

But they are not required for the first implementation.

## Barcode Plan

### Current State

Already present:

- simulator-only barcode UI
- manual sample selection in simulator
- injection of a scanned barcode into the real app flow

### What Should Change

Instead of 3 hardcoded samples in code:

- replace the hardcoded `samples` array with file-backed loading
- load EANs from `norrish-agents/fixtures/barcodes/BarcodeFixtures.json`
- use `norrish-agents/fixtures/fixtures.manifest.json` to choose persona-relevant EANs
- support deterministic selection through launch args or environment variables
- resolve fixture files via `FIXTURE_PATH` in simulator/debug mode

Important detail:

- the fixture JSON contains only EAN strings
- no mock product metadata is needed
- the existing downstream `fetchProduct()` / backend barcode lookup continues to provide the real product data

So barcode fixture mode changes only the source of the scanned EAN, not the lookup logic.

Examples:

- `PERSONA_NAME=karin`
- `FIXTURE_INDEX=0`

### Why This Is The Right Barcode Approach

Because the main simulator barcode seam already exists.

You only need to improve:

- data source
- persona relevance
- determinism
- fixture path resolution

You do **not** need a broad new architecture here.

## Plate Plan

### Current State

Plate testing can use the photo library path, but that does not make it equivalent to a real capture flow.

The current capture stack includes multiple paths that contribute context before analysis:

- depth-derived volume / mass hints
- YOLO region detection
- segmentation summary
- other transient scan metadata passed into the analysis path

The concrete downstream seam is `PlateAnalysisViewModel.analyzePreparedImage(...)`.

That is the most useful implementation anchor because it is where prepared image data and capture context converge before the backend call.

A simulator fixture path that only supplies a `UIImage` will therefore produce a different API request than a real capture path.

That is the exact divergence risk this plan needs to account for.

There is also existing simulator fallback UI in `ARPlateScanNutrition.swift` with a hardcoded `Simulate Scan` button and hardcoded `ARPlateScanNutrition` result.

That path should be treated as temporary tech debt, not as the long-term fixture solution.

### Recommended Future Direction

For plate analysis, the seam must sit at the **post-capture payload** boundary, not at raw image selection.

Normal:

- capture backend produces image plus capture context
- app hands that post-capture payload into the downstream analysis flow

Simulator/debug:

- fixture path resolves persona-matched plate input
- fixture path also resolves matching capture context
- app hands the same shape of post-capture payload into the downstream analysis flow

This means a plate fixture system likely needs to represent more than an image file.

For persona UX testing, the plan should explicitly choose **reduced fidelity with a real production baseline**, not "synthesize or acknowledge reduced fidelity" as an open question.

Recommended baseline:

- use the existing non-LiDAR production path as the fixture-context baseline

Why:

- missing depth data is already a real production condition today
- personas are primarily evaluating UX and result interpretation, not depth-pipeline accuracy
- this keeps the fixture path realistic without needing to fake high-fidelity AR/depth signals

At minimum the fixture-side representation may need support for:

- image
- optional volume / mass hints aligned with non-LiDAR behavior
- focus label / confidence
- region or segmentation summary
- other transient context expected by the current analysis path

The current hardcoded `Simulate Scan` fallback should be replaced by this fixture-backed path, not left alongside it indefinitely.

## Core Principle

Do not fake the final result screen.
Do not shortcut the backend.
Do not create a separate simulator-only results experience.

The fixture path should replace only the **capture source**, not the rest of the flow.

That preserves:

- loading UI
- backend/API calls
- error handling
- result rendering
- state transitions
- history/logging

## Fixture Source

Use the external fixture files that already exist:

- `norrish-agents/fixtures/fixtures.manifest.json`
- `norrish-agents/fixtures/barcodes/BarcodeFixtures.json`
- `norrish-agents/fixtures/plates/`

These should remain outside the app bundle.

In simulator/debug mode, the app should read them through a configured filesystem path, ideally:

- `FIXTURE_PATH=/absolute/path/to/norrish-agents/fixtures`

## Deterministic Selection

Fixture choice should be deterministic, not random.

Suggested controls:

- `FIXTURE_PATH` — absolute path to the fixture root directory
- `PERSONA_NAME` — selects persona-specific barcodes from the manifest
- `FIXTURE_INDEX` — selects a specific barcode within the persona's list

This allows:

- repeatable persona runs
- stable regression testing
- automation from the persona runner

## What To Avoid

Avoid:

- fake result screens
- hardcoded mock result views
- production-visible fixture pickers
- simulator-only navigation that does not exist in the real app
- skipping real loading/backend behavior just for convenience

These create test drift.

## Main Risk

The main risk is not end-user glitching. The main risk is **test-path divergence**.

That happens when the simulator path does not hand off the same kind of payload the real capture flow would normally hand off.

Examples:

- different object shape
- missing metadata
- skipped preprocessing
- different timing/loading behavior
- missing depth / volume context
- missing detection / segmentation context

## End-User Impact

If this is scoped correctly to simulator/debug conditions, real users should notice nothing.

Why:

- same visible buttons
- same visible screens
- same production navigation
- same production camera behavior

The only changed behavior is internal and simulator-specific.

## Practical Implementation Order

### Barcode

1. extend `DebugBarcodeFixtures`
2. resolve fixture root via `FIXTURE_PATH`
3. load barcodes from fixture files instead of hardcoded samples
4. add `PERSONA_NAME` and `FIXTURE_INDEX` support
5. if `FIXTURE_PATH` is missing, fall back to current hardcoded samples
6. keep existing simulator debug UI and real downstream flow

### Plate

1. inventory the exact post-capture payload the current capture backends produce
2. identify which parts are required vs optional for backend fidelity
3. resolve fixture root via `FIXTURE_PATH`
4. use `PlateAnalysisViewModel.analyzePreparedImage(...)` as the concrete injection seam
5. define a reduced-fidelity simulator payload based on the existing non-LiDAR production path
6. add fixture support for plate image plus capture context, not image alone
7. drive fixture choice from the manifest
8. if `FIXTURE_PATH` is missing, temporarily fall back to the current `Simulate Scan` behavior
9. replace the hardcoded `Simulate Scan` fallback with the fixture-backed path once stable
10. verify backend request parity against a real non-LiDAR capture path

### Plate Parity Verification Method

Use a concrete payload comparison during development.

Recommended approach:

1. enable request/context logging for the real non-LiDAR capture path
2. capture the context JSON sent from a real photo-based path
3. run the simulator fixture path for the same general scenario
4. capture the context JSON again
5. diff the two payloads

Verification target:

- structural equivalence, not byte-for-byte equality

Specifically compare:

- top-level keys
- nested keys
- value types
- presence/absence of expected optional fields

Acceptable differences:

- exact numeric values
- image-derived estimates that naturally vary

Unacceptable differences:

- missing required sections
- different key structure
- wrong value types
- omitted fields that the real non-LiDAR path normally sends

This can start as a one-time manual diff and later become an automated regression test if needed.

## Summary

The right plan is not one abstraction for everything.

It is:

- **barcode:** extend the simulator debug path that already exists, backed by external fixture files
- **plate:** add a simulator-only post-capture payload seam with capture-context parity
- **both:** use external persona fixtures and deterministic selection

That gets you reliable simulator testing without changing the production UX.
