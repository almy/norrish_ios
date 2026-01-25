# Analyzing Overlay → Result Transition

---

## Overview

This pattern describes the transition from an analyzing overlay to a result screen within a camera-based license plate recognition flow. It focuses on user experience, lifecycle management, error handling, and integration points within the `EnhancedCameraPreviewView`.

---

## Flow

- User captures or scans a license plate via camera preview.
- Analyzing overlay appears indicating processing is underway.
- Upon successful analysis, the result screen shows recognized plate details.
- User can confirm, cancel, or retry the scan.
- Errors or cancellations revert to camera preview cleanly.

```swift
// Showing analyzing overlay
EnhancedCameraPreviewView.showAnalyzingOverlay()

// On result ready
EnhancedCameraPreviewView.showResultScreen(with: result)
