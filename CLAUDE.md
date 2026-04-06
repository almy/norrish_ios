# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build for simulator
xcodebuild -project healthScanner.xcodeproj -scheme healthScanner -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run all tests
xcodebuild test -project healthScanner.xcodeproj -scheme healthScanner -testPlan healthScanner -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16'

# Run a single test class
xcodebuild test -project healthScanner.xcodeproj -scheme healthScanner -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:healthScannerTests/BackendIntegrationTests

# Run API guardrails check
bash scripts/ios_api_guardrails.sh

# Bump build number (pre-archive)
bash scripts/prearchive_bump_build.sh
```

- Prefer running single test classes over the full suite for speed
- Bundle ID: `com.myftiu.ios.norrish` | Swift 5.10 | Deployment target: iOS 17.5

## Architecture

**Pure native iOS — no external dependencies (no SPM, CocoaPods, or Carthage). Do not add any.**

The app ("Norrish") is a health/nutrition scanner with two main scanning flows:

1. **Barcode scanning** — UIKit `AVCaptureSession` wrapped for SwiftUI via `Scanning/Barcode/CameraBarcodeScannerView`. Backend lookup returns product nutrition data.
2. **Plate analysis** — photo-based meal analysis using on-device YOLO models (`CoreML/`) + backend AI. Multiple camera backends in `Scanning/AR/` (ARKit, dual-camera, enhanced).

Key architectural boundaries:
- `BackendAPIClient` is the **single** network client — all API calls go through it. Config in `Resources/AppConfig.plist`.
- `NutritionRecommendationEngine` runs on-device ML — privacy-preserving by design, never send raw nutrition data to backend for recommendations.
- `ImageCacheService` handles all image persistence — use it, don't create new caching.
- Photos permission must only be requested in `Views/Common/MediaPickers.swift` (enforced by `scripts/ios_api_guardrails.sh`). Use `PHPickerViewController`, never `UIImagePickerController.sourceType = .photoLibrary`.

**Data layer**: SwiftData models in `Models/` (Product, PlateAnalysisHistory, DailyNutritionAggregateEntity, etc.).

**MVVM pattern**: `Views/` → `ViewModels/` → `Services/` + `Models/`. Use `ObservableObject` + `@Published` (not `@Observable` — project uses the older pattern consistently).

## Simulator Development

- YOLO26X-seg produces garbage results on simulator — it is skipped; only `yolov8x-oiv7` runs on sim
- Camera/AR features use fixture injection on simulator: `Scanning/Barcode/DebugBarcodeFixtures.swift` and `Scanning/Plate/DebugPlateFixtures.swift`
- Test fixtures in `norrish-agents/fixtures/` — these are NOT bundled in the app target

Environment variables for simulator/testing:
- `BACKEND_DEBUG=1` — log backend requests
- `FIXTURE_PATH` / `FIXTURE_INDEX` — external fixture injection
- `NORRISH_SCREENSHOT_MODE=1` / `NORRISH_SCREENSHOT_ROUTE` — screenshot testing
- `PERSONA_NAME` — persona for test scenarios

## Code Style

- SwiftUI for all new views — UIKit only for hardware wrappers (camera, AR)
- Localize all user-facing strings in `Resources/Localization/Localizable.strings` (en + sv)
- Custom fonts: Playfair Display (display text), Inter (body text)
- Commit messages: imperative mood, descriptive (e.g., "Fix close button on barcode camera", "Add simulator fixture injection")
