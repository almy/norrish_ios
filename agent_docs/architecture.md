# Architecture — Norrish

## Scanning Flows

1. **Barcode scanning** — UIKit `AVCaptureSession` wrapped for SwiftUI via `Scanning/Barcode/CameraBarcodeScannerView`. Backend lookup returns product nutrition data.
2. **Plate analysis** — photo-based meal analysis using on-device YOLO models (`CoreML/`) + backend AI. Multiple camera backends in `Scanning/AR/` (ARKit, dual-camera, enhanced).

## Boundaries (enforce strictly)

- `BackendAPIClient` is the **single** network client — all API calls go through it. Config in `Resources/AppConfig.plist`.
- `NutritionRecommendationEngine` runs on-device ML — privacy-preserving by design, **never** send raw nutrition data to backend for recommendations.
- `ImageCacheService` handles all image persistence — use it, don't create new caching.
- Photos permission must only be requested in `Views/Common/MediaPickers.swift` (enforced by `scripts/ios_api_guardrails.sh`). Use `PHPickerViewController`, never `UIImagePickerController.sourceType = .photoLibrary`.

## Data Layer

SwiftData models in `Models/`: `Product`, `PlateAnalysisHistory`, `DailyNutritionAggregateEntity`, etc.

## MVVM Pattern

`Views/` → `ViewModels/` → `Services/` + `Models/`

Use `ObservableObject` + `@Published`. Do **not** use `@Observable` — the project uses the older pattern consistently throughout.
