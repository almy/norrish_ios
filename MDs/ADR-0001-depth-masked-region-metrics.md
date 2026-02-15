# ADR-0001: Edit-Driven Depth-Masked Region Metrics

- Status: Accepted
- Date: 2026-02-15

## Context

`FoodRegionSelectionView` allows users to edit/toggle selected food regions after capture.  
Previously:

- `volume_ml` / `mass_g_est` were computed once at capture time.
- Region edits did not recompute depth-based metrics.
- Metadata updates on edits were limited and could diverge from user-selected regions.

This created a mismatch between what the user selected and what was sent to backend context.

## Decision

Implement an edit-driven metrics pipeline based on captured depth data:

1. Capture and freeze depth context at photo time.
   - Add `DepthFrameSnapshot` containing:
     - `depthMap: CVPixelBuffer`
     - `intrinsics: simd_float3x3`
     - `imageSize: CGSize`
   - Pass snapshot through camera callback into `PlateAnalysisViewModel` as transient state.

2. Recompute metrics from selected regions on every edit.
   - In `FoodRegionSelectionView`, debounce edit reactions.
   - Build a binary mask from selected regions mapped into depth-map coordinates.
   - Recompute volume with depth integration constrained by mask.
   - Recompute mass from recalculated volume and detected label density.

3. Keep a safe fallback path.
   - If no depth snapshot is available, use existing area-ratio scaling fallback.

4. Keep computations off the main thread.
   - Depth-mask metric recomputation runs on a background queue.

## Consequences

### Positive

- Backend context (`volume_ml`, `mass_g_est`) tracks user-edited selection.
- Better alignment between UI selection and numeric estimates.
- Preserves behavior on devices/capture paths without usable depth.

### Tradeoffs

- More transient state passed through UI/view model boundaries.
- Additional compute after edits (mitigated by debounce and background execution).
- Mask uses bounding-box rasterization (fast, but not pixel-perfect segmentation).

## Implementation Notes

Key files:

- `healthScanner/Services/Scanning/EnhancedCaptureMetricsEstimator.swift`
  - Added `DepthFrameSnapshot`
  - Added masked `compute(snapshot:selectedRects:label:)`
- `healthScanner/Views/PlateScan/EnhancedCameraController.swift`
  - Captures and copies depth map for snapshot transport
- `healthScanner/Views/PlateScan/EnhancedCameraPreviewView.swift`
  - Extended capture callback to include snapshot
- `healthScanner/ViewModels/PlateAnalysisViewModel.swift`
  - Added `transientDepthSnapshot` storage
- `healthScanner/Views/FoodRegionSelectionView.swift`
  - Debounced edit reaction
  - Depth-mask recompute on edit
  - Area-ratio fallback when depth unavailable

## Alternatives Considered

1. Keep capture-time-only metrics
   - Rejected: does not reflect post-capture user edits.

2. Area-ratio scaling only
   - Rejected as primary path: fast but less accurate than depth-mask recomputation.

3. Full pixel segmentation mask from model output for integration
   - Deferred: higher complexity and runtime cost; bounding-box mask is acceptable for current product stage.

