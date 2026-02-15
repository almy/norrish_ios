// norrish Architecture Guide

This document explains the overall architecture of the norrish app, what each major component does, and why it exists. It also highlights how the on-device Core ML pipeline, AR pipeline (feature/ar_capacities), and data persistence work together to deliver reliable scanning and compact payloads to the backend.

## High-level Overview

- The app is a SwiftUI application with a tabbed interface for scanning products, analyzing plates, viewing history, and managing profile/settings.
- Data persistence uses SwiftData with lightweight models for scanned products and plate analyses.
- Camera and scanning are implemented with a mix of SwiftUI and UIKit wrappers to leverage AVFoundation and, when available, ARKit.
- On-device intelligence is provided by Core ML models for food classification and segmentation, plus Vision saliency-based preprocessing.
- The architecture favors a “local-first” approach: do light, fast analysis on-device to reduce payload size and improve reliability, then send compact results to the backend.

## App Entry and Shared Services

- `norrishApp.swift` (App entry):
  - Creates and injects shared environment objects: `ThemeManager.shared` and `LocalizationManager.shared`.
  - Initializes a SwiftData `ModelContainer` with explicit models: `Product`, `PlateAnalysisHistory`, and `Item`.
  - Hosts the root `ContentView` and applies theme and localization helpers.

- Why: Centralizing theme/localization and the model container ensures consistent behavior across all tabs and views with minimal boilerplate.

## UI Structure and Navigation

- `ContentView.swift` defines a `TabView` with four tabs:
  - Scan tab: hosts `BarcodeScannerView` (product barcodes)
  - Plate tab: hosts `PlateAnalysisView` (photo-based plate analysis)
  - History tab: unified view of both `Product` and `PlateAnalysisHistory` with filters and sorters
  - Profile tab: profile/settings (via `ProfileView`)

- Why: The tabs correspond to primary user workflows and keep navigation shallow and predictable.

## Data Models and Persistence (SwiftData)

- Models (referenced):
  - `Product`: A scanned product with `barcode`, `name`, `imageURL`, `nutriScoreLetter`, and `scannedDate`.
  - `PlateAnalysisHistory`: A persisted record for plate analyses with `name`, `nutriScoreLetter`, `analyzedDate`, and image storage/caching.
  - `Item`: If present, a generic model (listed in `ModelContainer`) — used elsewhere in the project.

- Persistence:
  - `@Query` is used in views to read `Product` and `PlateAnalysisHistory` collections.
  - Insert/delete happen through `@Environment(\.modelContext)`.

- Why: SwiftData provides a simple, modern persistence layer integrated with SwiftUI. The models are minimal, keeping storage compact.

## Scanning: Product Barcodes

- `BarcodeScannerView` (SwiftUI): Presents a friendly UI that launches the camera barcode scanner.
- `BarcodeScannerViewController` (UIKit): Implements AVFoundation barcode scanning with a focused region of interest and a visual guide.
- Flow:
  1) User taps “Start Scanning”.
  2) The UIKit controller detects EAN/UPC/PDF417/Code128 barcodes and emits a single debounced result.
  3) The app fetches the product (via `BarcodeScannerViewModel`/`ProductService`) and shows `ProductDetailView`.

- Why: UIKit + AVFoundation provide mature, high-performance barcode scanning. A small wrapper keeps the SwiftUI interface clean.

## Plate Analysis: Photo-based (No AR)

- `PlateAnalysisView` (SwiftUI):
  - Lets the user take a photo (`CameraPreviewView`) or pick from library (`PhotosPicker`).
  - Optionally presents a region selection overlay (`FoodRegionSelectionView`) for manual refinement.
  - Runs analysis and presents results in `PlateAnalysisResultView`.

- `CameraPreviewView` (SwiftUI + UIKit):
  - Uses `AVCaptureSession` to show a live camera preview and capture a single high-quality photo.
  - Can throttle frames for optional real-time hints (commented hook present).

- `ImagePreprocessor.swift`:
  - Provides Vision saliency-based cropping to focus on the most relevant food region(s).
  - Offers mosaic utilities for debugging and UI previews.

- Why: A simple capture→preprocess→analyze pipeline reduces noise and bandwidth. Saliency cropping improves model accuracy and reduces what is sent to the backend.

## On-device Intelligence: Core ML Service

- `CoreMLFoodAnalysisService.swift`:
  - Loads two Core ML models (classification and segmentation) from the app bundle. Model names are configurable; the service attempts root and `CoreML/` subdirectory.
  - Public async API: `analyzeFood(image:)` returns an `EnhancedFoodAnalysisResult` with:
    - `FoodClassificationResult` (top label, confidence, top-N)
    - `FoodSegmentationResult` (mask, regions, food pixel count)
  - Robust fallbacks: If models are missing or fail to load, the service returns a “graceful” result so the UI can proceed without blocking.
  - Internals:
    - Preprocessing: resizes images to the model’s expected input size.
    - Classification: extracts probabilities from several possible output keys (portable across models).
    - Segmentation: converts `MLMultiArray` outputs to a `CVPixelBuffer` mask and computes simple region stats.

- Why: Centralizing model loading and inference avoids duplication, makes it easy to swap models, and keeps ML complexity out of views and controllers.

## Real-time Feedback (Optional)

- `EnhancedCameraPreviewView` (SwiftUI):
  - Uses an embedded camera controller with Vision-based YOLO detection for live label/confidence hints.
  - Captures a photo and runs async backend analysis for final plate insights.

- Why: Real-time hints guide the user to hold steady, frame the plate, or retake a photo — improving reliability without heavy UI.

## AR Plate Scanning (feature/ar_capacities)

- `ARPlateScannerViewController.swift` (UIKit + ARKit):
  - LiDAR path: Uses `ARWorldTrackingConfiguration` with `.sceneDepth` to estimate volume (ml) by integrating depth over a segmented mask.
  - Fallback path: If no LiDAR, auto-presents `DualCameraPlateScannerViewController` (AVCapture-based depth) to achieve similar results.
  - Readiness gating: Combines plane stability, camera parallax, mapping state, and depth availability into a readiness score. Captures only when conditions are good.
  - Overlay: Renders either segmentation-based or saliency-based overlays to guide the user.

- `ARPlateScanNutrition.swift`:
  - Defines `ARPlateScanNutrition` (label, confidence, volume, mass, calories, macros).
  - Provides `ARPlateScannerView` (SwiftUI wrapper) that presents the real scanner(s) on device and a simulator fallback.

- Why: AR-based volume estimation provides richer data (volume/mass) for nutritional estimation. The readiness gates improve reliability and reduce bad captures.

## History and Insights

- History UI (in `ContentView.swift`):
  - Merges `Product` and `PlateAnalysisHistory` into a single filterable and sortable list.
  - Uses compact, glanceable rows (`HistoryProductRowView`, `HistoryPlateRowView`) with cached thumbnails via `ImageCacheService`.

- Insights (referenced):
  - `InsightDataService` and related views surface recommendations and trends.

- Why: A unified history helps users track both product scans and plate analyses in one place.

## Localization and Theming

- `LocalizationManager.shared`: Enables `.localized()` helpers in views and supports localized strings (e.g., filter titles, prompts).
- `ThemeManager.shared`: Applies a consistent color scheme and allows for easy theme switching.

- Why: Centralized managers keep UI consistent and simplify future design iterations.

## Networking and Backend Integration (Referenced)

- `ProductService`: Fetches product information by barcode.
- `PlateAnalysisService`: Submits plate images or compact results for server-side analysis.
- Payload strategy:
  - Prefer sending compact JSON (labels, confidences, normalized boxes, pixel counts) and small thumbnails over full-resolution images.
  - Use on-device saliency/segmentation to crop and reduce bandwidth.

- Why: Minimizing payload size improves performance and user privacy while keeping backend costs manageable.

## Putting It All Together: Typical Flows

- Product barcode scan:
  1) `BarcodeScannerView` → `BarcodeScannerViewController` (AVFoundation)
  2) Barcode → `ProductService` fetch → `ProductDetailView`
  3) Persist `Product` (SwiftData) → appears in History

- Plate photo analysis (simple mode):
  1) `PlateAnalysisView` → `CameraPreviewView` (capture)
  2) `ImagePreprocessor.preprocessFoodImage` (saliency crop)
  3) `CoreMLFoodAnalysisService.analyzeFood(image:)`
  4) Persist `PlateAnalysisHistory` and send compact payload

- AR plate analysis (advanced mode):
  1) `ARPlateScannerView` → `ARPlateScannerViewController` (ARKit)
  2) Readiness gates, segmentation/saliency overlay
  3) Capture → depth integration → `ARPlateScanNutrition`
  4) Persist history and send compact payload

## Design Principles and Rationale

- Local-first intelligence: Do fast, light work on-device (saliency/segmentation/classification) before contacting the backend.
- Modularity: Keep ML, AR, camera, and UI concerns separate for easier maintenance.
- Progressive enhancement: Basic photo flow works everywhere; AR volume and real-time hints are opt-in enhancements.
- Reliability over features: Readiness gates and saliency cropping reduce bad captures and noisy data.

## Extensibility and Customization

- Swapping models:
  - Update `CoreMLFoodAnalysisService` model names and output keys to match your new `.mlmodel`/`.mlpackage` files.
  - The service is resilient to minor output name differences (e.g., `classLabelProbs`, `predictions`, `scores`).

- Adding AR:
  - Present `ARPlateScannerView` conditionally when ARKit + sceneDepth are available.
  - Keep the non-AR path as the default for compatibility.

- Segmentation integration (unification):
  - If desired, abstract segmentation via a small `SegmentationProvider` interface to share the same mask logic between AR and non-AR flows.

## Permissions and Capabilities

- Ensure `NSCameraUsageDescription` is present in Info.plist.
- AR features require compatible devices (LiDAR for sceneDepth path). The code falls back automatically when not available.

## Known Integration Points (to verify in your project)

- `DualCameraPlateScannerViewController.swift`: Referenced as a fallback in AR; ensure it’s included if you plan to use AR on non-LiDAR devices.
- `PlateAnalysisService`, `PlateAnalysisViewModel`, `PlateAnalysisResultView`, `FoodRegionSelectionView`: Referenced in the codebase; confirm they are present in your target or adjust references.
- Core ML model names: Confirm your actual model filenames and adjust `CoreMLFoodAnalysisService` accordingly.


## TODO: Extend segmentation to multiple items (if you provide the YOLO‑seg model file) and add per‑item crops to the payload sender.

## Quick Start: Minimal Plate Flow

- Use `CameraPreviewView` to capture a photo.
- Call `ImagePreprocessor.preprocessFoodImage` to crop the salient region.
- Call `PlateAnalysisService.analyze(image:)`.
- Save a `PlateAnalysisHistory` record and send a compact payload to the backend.

This “simple mode” avoids AR and real-time overlays, keeping the path to shipping short and maintainable.

## Glossary

- Saliency: Vision-based attention map used to select the most relevant region in an image.
- Segmentation: Pixel-wise classification of the image (food vs background), used for overlays and volume integration.
- AR Readiness: A heuristic combining mapping, plane stability, parallax, and depth availability to decide when to capture.
- Compact Payload: Small JSON + small thumbnail instead of full-size images.
## Visual Architecture: How Everything Connects

Below are visual diagrams that map the major modules and the end-to-end flows. These diagrams are intended to make the relationships and data flow between components explicit.

### High-level Component Diagram

```mermaid
flowchart TD
    A[User] --> B[ContentView (TabView)]
    B --> C1[Scan Tab - BarcodeScannerView]
    B --> C2[Plate Tab - PlateAnalysisView]
    B --> C3[History Tab]
    B --> C4[Profile Tab]

    C1 --> D1[BarcodeScannerViewController (AVFoundation)]
    D1 --> E1[Barcode result]
    E1 --> F1[ProductService]
    F1 --> G1[ProductDetailView]
    G1 --> H[SwiftData (Product)]
    H --> C3

    C2 --> D2[CameraPreviewView (AVCaptureSession)]
    D2 --> E2[Captured Photo]
    E2 --> F2[ImagePreprocessor (Saliency Crop)]
    F2 --> G2[CoreMLFoodAnalysisService]
    G2 --> H2[PlateAnalysisResultView]
    H2 --> H3[SwiftData (PlateAnalysisHistory)]
    H3 --> C3

    C2 --> D2b[Optional: EnhancedCameraPreviewView]
    D2b --> G2

    C2 --> D2c[Optional: ARPlateScannerView]
    D2c --> I[ARPlateScannerViewController (ARKit)]
    I --> J[Depth + Segmentation Integration]
    J --> K[ARPlateScanNutrition]
    K --> H3

    G2 --> L[Backend (Compact Payload)]
    K --> L

