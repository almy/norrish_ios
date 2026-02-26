# Library & API Audit (2026-02-26)

## Scope
- Project: `healthScanner` (iOS)
- Audit focus: dependency choices, framework usage, modernization level, and concrete risks

## Dependency posture
- External package managers found: none
  - No CocoaPods (`Podfile`), Carthage (`Cartfile`), or SwiftPM package references in `healthScanner.xcodeproj/project.pbxproj`
  - No `Package.resolved` entries under workspace `swiftpm`
- Current posture: Apple-first/native stack

## Framework inventory (Swift imports)
- `SwiftUI` (55 files)
- `Foundation` (40)
- `UIKit` (31)
- `SwiftData` (18)
- `Vision` (10)
- `AVFoundation` (8)
- `CoreML` (6)
- `Photos` (2), `PhotosUI` (1)
- `ARKit` (2), `Accelerate` (1), `Combine` (1)

## Platform baseline
- iOS deployment target: `17.5`
- Swift version in project config: `5.0`

## Findings (ordered by priority)

### 1) Deprecated camera APIs still in active code paths
- `healthScanner/Views/PlateScan/EnhancedCameraController.swift:179`
  - Uses `videoOrientation` on `AVCaptureConnection` (deprecated iOS 17; use `videoRotationAngle`)
- `healthScanner/Views/PlateScan/EnhancedCameraController.swift:201`
  - Uses `VNRequest.usesCPUOnly` (deprecated iOS 17)
- Impact: medium-high (future compatibility drift)

### 2) Swift language mode is behind modern concurrency diagnostics
- `healthScanner.xcodeproj/project.pbxproj` shows `SWIFT_VERSION = 5.0`
- Build previously emitted Swift 6-related warnings in this codebase (actor/sendable isolation issues), which are easier to control by proactively migrating warnings now.
- Impact: high (technical debt accumulation around concurrency)

### 3) Logging strategy is inconsistent and overly verbose in production paths
- `print(...)` calls found: 63
- Heaviest concentration in:
  - `healthScanner/Services/CoreMLFoodAnalysisService.swift`
  - `healthScanner/CoreML/SegmentationEnhancer.swift`
  - `healthScanner/Views/Components/CachedAsyncImage.swift`
- Impact: medium (noise, performance overhead, observability quality)

### 4) Permission architecture for Photos is now good, but should be generalized
- Centralized helper introduced in `healthScanner/Views/Common/MediaPickers.swift`
- Guardrail script added (`scripts/ios_api_guardrails.sh`) to prevent regressions in photo-library API usage
- Impact: positive; keep extending this pattern to camera/microphone/location permissions if added later

### 5) Runtime-crash style initializers still exist (acceptable but should be intentional)
- `fatalError(...)` occurrences: 4
  - `healthScanner/Views/PlateScan/EnhancedCameraController.swift:79`
  - `healthScanner/norrishApp.swift:130`
  - `healthScanner/Scanning/AR/DualCameraPlateScannerViewController.swift:1186`
  - `healthScanner/Scanning/AR/ARPlateScannerViewController.swift:577`
- Impact: low-medium (acceptable for unsupported init paths, but app bootstrap fatal should be explicitly documented)

## What is modern and solid already
- Strong Apple-native stack (no stale third-party dependency surface)
- SwiftUI + SwiftData architecture adopted broadly
- CoreML + Vision + AVFoundation integration is modern and fits product goals
- Photos permission flow now supports limited/full access with settings fallback

## Recommended action plan
1. Replace deprecated camera API usage (`videoOrientation`, `usesCPUOnly`) with iOS 17+ alternatives.
2. Move project to a newer Swift language mode and turn concurrency warnings into enforceable cleanup items.
3. Replace debug `print` with unified logging (`OSLog`/`Logger`) and gate verbose logs by build config.
4. Keep and expand guardrails in CI (deprecated API scans + permission key checks).

## Proposed CI additions
- Add a `deprecated_api_guardrails.sh` script to fail on known deprecated symbols.
- Add a logging guardrail to block new raw `print(...)` in non-test targets (allowlist debug-only files).

