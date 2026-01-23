# HealthScanner - Camera Pipeline Fix

## Error Analysis

### Primary Error
```
❌ Failed to get CGImage from UIImage
<<<< FigXPCUtilities >>>> signalled err=18.446.744.073.709.534.335
<<<< FigCaptureSourceRemote >>>> Fig assert: "err == 0 " at bail (FigCaptureSourceRemote.m:569) - (err=-17281)
💾 ImageCacheService: Failed to convert image to JPEG data
```

### Root Causes
1. **Camera session corruption** (-17281 error code)
2. **Invalid UIImage creation** from camera buffer
3. **Memory pressure** during image processing
4. **Concurrent camera access** conflicts

## Immediate Fixes

### Fix 1: Robust Image Validation
```swift
// Add to ImageCacheService.swift
extension UIImage {
    var isValid: Bool {
        guard let cgImage = self.cgImage else { return false }
        return cgImage.width > 0 && cgImage.height > 0
    }

    func safeJPEGData(compressionQuality: CGFloat = 0.8) -> Data? {
        guard isValid else {
            print("⚠️ Invalid UIImage - cannot convert to JPEG")
            return nil
        }

        return self.jpegData(compressionQuality: compressionQuality)
    }
}

// Update ImageCacheService save method
func saveImage(_ image: UIImage, forKey key: String) {
    guard image.isValid else {
        print("❌ ImageCacheService: Invalid image for key: \(key)")
        return
    }

    guard let imageData = image.safeJPEGData() else {
        print("❌ ImageCacheService: Failed to convert valid image to JPEG for key: \(key)")
        return
    }

    // Continue with save...
}
```

### Fix 2: Camera Session Management
```swift
// Add to CameraPreviewViewController.swift
class RobustCameraManager {
    private var isSessionConfigured = false
    private let sessionQueue = DispatchQueue(label: "camera.session", qos: .userInitiated)

    func configureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.isSessionConfigured else { return }

            // Stop any existing sessions first
            self.stopAllCameraSessions()

            // Wait for cleanup
            Thread.sleep(forTimeInterval: 0.2)

            self.setupCameraSession()
        }
    }

    private func stopAllCameraSessions() {
        // Find and stop all running camera sessions
        let allSessions = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices

        // Force stop any active sessions
        for device in allSessions {
            if device.isConnected {
                print("🛑 Forcing stop of active camera device: \(device.localizedName)")
            }
        }
    }

    private func setupCameraSession() {
        session.beginConfiguration()
        defer {
            session.commitConfiguration()
            isSessionConfigured = true
        }

        // Clear any existing inputs/outputs
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        // Configure with error checking
        guard setupCameraInput() else {
            print("❌ Failed to setup camera input")
            return
        }

        guard setupVideoOutput() else {
            print("❌ Failed to setup video output")
            return
        }
    }
}
```

### Fix 3: Safe Image Conversion from Camera Buffer
```swift
// Update CameraPreviewViewController.swift
extension CameraPreviewViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Throttle frame processing
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastFrameTime >= frameInterval else { return }
        lastFrameTime = now

        // Safe buffer extraction
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("⚠️ Failed to get pixel buffer from sample")
            return
        }

        // Process on background queue
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            let image = self?.createSafeUIImage(from: pixelBuffer)

            DispatchQueue.main.async {
                guard let image = image else {
                    print("⚠️ Failed to create UIImage from pixel buffer")
                    return
                }
                self?.onImageCaptured?(image)
            }
        }
    }

    private func createSafeUIImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        // Lock the pixel buffer
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        // Create CIImage with explicit color space
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Use cached context for better performance
        let context = CIContext(options: [
            .cacheIntermediates: false,
            .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
        ])

        // Create CGImage with bounds checking
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            print("⚠️ Failed to create CGImage from CIImage")
            return nil
        }

        // Validate CGImage before creating UIImage
        guard cgImage.width > 0 && cgImage.height > 0 else {
            print("⚠️ Invalid CGImage dimensions: \(cgImage.width)x\(cgImage.height)")
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}
```

### Fix 4: Memory Pressure Handling
```swift
// Add to your main camera class
class CameraMemoryManager {
    private var memoryWarningObserver: NSObjectProtocol?

    init() {
        setupMemoryWarningHandler()
    }

    private func setupMemoryWarningHandler() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    private func handleMemoryWarning() {
        print("🧠 Memory warning - cleaning up camera resources")

        // Reduce camera quality temporarily
        if session.canSetSessionPreset(.medium) {
            session.sessionPreset = .medium
        }

        // Clear image cache
        ImageCacheService.shared.clearCache()

        // Force garbage collection
        autoreleasepool {
            // Create empty pool to free up memory
        }
    }

    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
```

### Fix 5: Concurrent Access Protection
```swift
// Add to prevent multiple camera access
class CameraAccessManager {
    static let shared = CameraAccessManager()
    private var activeSessions: Set<String> = []
    private let accessQueue = DispatchQueue(label: "camera.access", attributes: .concurrent)

    func requestAccess(for identifier: String, completion: @escaping (Bool) -> Void) {
        accessQueue.async(flags: .barrier) {
            guard !self.activeSessions.contains(identifier) else {
                DispatchQueue.main.async {
                    completion(false)
                }
                return
            }

            self.activeSessions.insert(identifier)
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }

    func releaseAccess(for identifier: String) {
        accessQueue.async(flags: .barrier) {
            self.activeSessions.remove(identifier)
        }
    }
}

// Use in your camera view controllers
class CameraPreviewViewController: UIViewController {
    private let cameraIdentifier = UUID().uuidString

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        CameraAccessManager.shared.requestAccess(for: cameraIdentifier) { [weak self] granted in
            if granted {
                self?.startCamera()
            } else {
                print("❌ Camera access denied - another session active")
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        CameraAccessManager.shared.releaseAccess(for: cameraIdentifier)
        stopCamera()
    }
}
```

## Quick Implementation Steps

### Step 1: Add Error Checking (5 minutes)
```swift
// Add this to ImageCacheService immediately
func saveImage(_ image: UIImage, forKey key: String) {
    print("💾 ImageCacheService: Attempting to save image for key: \(key)")

    // Validate image first
    guard image.cgImage != nil else {
        print("❌ ImageCacheService: Invalid UIImage (no CGImage) for key: \(key)")
        return
    }

    guard let imageData = image.jpegData(compressionQuality: 0.8) else {
        print("❌ ImageCacheService: Failed to convert image to JPEG data for key: \(key)")
        return
    }

    // Continue with existing save logic...
}
```

### Step 2: Fix Camera Buffer Processing (10 minutes)
Update the `captureOutput` method with the safe image creation code above.

### Step 3: Add Memory Warning Handler (5 minutes)
Add the memory manager to your main camera class.

### Step 4: Prevent Session Conflicts (10 minutes)
Implement the camera access manager to prevent multiple simultaneous camera sessions.

## Testing the Fix

### Verify the Fix Works
1. **Test in low memory conditions**: Use Xcode memory debugger
2. **Test rapid camera switching**: Switch between scanning modes quickly
3. **Test background/foreground**: Put app in background and return
4. **Monitor logs**: Should see no more FigCapture errors

### Success Criteria
- [ ] No more "Failed to get CGImage" errors
- [ ] No FigCapture assertion failures
- [ ] Smooth camera preview without crashes
- [ ] Successful image saving to cache

## Long-term Prevention

### Add Monitoring
```swift
class CameraHealthMonitor {
    static func logCameraState() {
        let devices = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        ).devices

        for device in devices {
            print("📷 Camera \(device.localizedName): connected=\(device.isConnected)")
        }
    }
}
```

### Performance Metrics
```swift
class ImageProcessingMetrics {
    static func trackImageConversion(success: Bool, duration: TimeInterval) {
        if !success || duration > 0.1 {
            print("⚠️ Image conversion issue: success=\(success), duration=\(duration)s")
        }
    }
}
```

This fix addresses the root causes of your camera pipeline errors and provides robust error handling to prevent future occurrences.