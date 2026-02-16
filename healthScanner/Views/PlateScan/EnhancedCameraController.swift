import SwiftUI
import UIKit
import AVFoundation
import Vision

struct CameraControllerRepresentable: UIViewControllerRepresentable {
    @ObservedObject var state: LiveClassificationState
    let onCaptured: (UIImage, Float?, Float?, DepthFrameSnapshot?, String?, Float?) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        CameraViewController(state: state, onCaptured: onCaptured, onCancel: onCancel)
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}

    final class CameraViewController: UIViewController {
        private let state: LiveClassificationState
        private let onCaptured: (UIImage, Float?, Float?, DepthFrameSnapshot?, String?, Float?) -> Void
        private let onCancel: () -> Void

        private let session = AVCaptureSession()
        private let videoOutput = AVCaptureVideoDataOutput()
        private let photoOutput = AVCapturePhotoOutput()
        private let depthOutput = AVCaptureDepthDataOutput()
        private let depthQueue = DispatchQueue(label: "enhancedDepthQueue")
        private let depthStateQueue = DispatchQueue(label: "enhancedDepthStateQueue")

        private var previewLayer: AVCaptureVideoPreviewLayer!
        private let focusMaskLayer = CAShapeLayer()
        private let focusBoxLayer = CAShapeLayer()
        private let focusCrosshairLayer = CAShapeLayer()
        private let focusLabel = CATextLayer()
        private let roiRectNormalized = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)

        private var lastDetectionTime: CFTimeInterval = 0
        private var lastClassificationTime: CFTimeInterval = 0
        private var lastIntermediatePublishTime: CFTimeInterval = 0
        private let detectionInterval: CFTimeInterval = 1.0 / 10.0
        private let classificationInterval: CFTimeInterval = 1.0 / 3.0
        private let intermediatePublishInterval: CFTimeInterval = 1.0 / 15.0

        private var classificationRequest: VNClassifyImageRequest!
        private var detectionRequest: VNCoreMLRequest?
        private var isAnalyzing = false
        private var cameraOpenRequestedAt: CFAbsoluteTime?
        private var hasLoggedFirstFrame = false
        private var frozenCaptureLabel: String?
        private var frozenCaptureConfidence: Float?
        private var lastReliableDetectionTime: CFTimeInterval = 0
        private var pendingLabel: String?
        private var pendingCount: Int = 0
        private let minStableHits = 2
        private let minReliableConfidence: Float = 0.35
        private let staleResetInterval: CFTimeInterval = 1.5

        private var latestDepthMap: CVPixelBuffer?
        private var latestIntrinsics: simd_float3x3 = {
            var m = simd_float3x3()
            m.columns = (
                SIMD3<Float>(1, 0, 0),
                SIMD3<Float>(0, 1, 0),
                SIMD3<Float>(0, 0, 1)
            )
            return m
        }()

        init(state: LiveClassificationState, onCaptured: @escaping (UIImage, Float?, Float?, DepthFrameSnapshot?, String?, Float?) -> Void, onCancel: @escaping () -> Void) {
            self.state = state
            self.onCaptured = onCaptured
            self.onCancel = onCancel
            super.init(nibName: nil, bundle: nil)
            configureSession()
            setupVision()
            NotificationCenter.default.addObserver(self, selector: #selector(shutterTapped), name: .enhancedCapturePhoto, object: nil)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            NotificationCenter.default.removeObserver(self, name: .enhancedCapturePhoto, object: nil)
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black

            previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.layer.bounds
            view.layer.addSublayer(previewLayer)
            setupFocusOverlay()

            setupButtons()

            YOLOModelProvider.getModel { [weak self] vn in
                guard let self, let vn else { return }
                let req = VNCoreMLRequest(model: vn)
                req.imageCropAndScaleOption = .scaleFill
                req.regionOfInterest = self.roiRectNormalized
                self.detectionRequest = req
            }
        }

        override func viewWillLayoutSubviews() {
            super.viewWillLayoutSubviews()
            previewLayer.frame = view.bounds
            updateFocusOverlayFrame()
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            cameraOpenRequestedAt = CFAbsoluteTimeGetCurrent()
            hasLoggedFirstFrame = false
            AppLog.debug(AppLog.vision, "⏱️ [EnhancedCamera] Open requested")
            if !session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async {
                    self.session.startRunning()
                    DispatchQueue.main.async {
                        self.state.isRunning = true
                    }
                }
            }
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            if session.isRunning {
                DispatchQueue.global(qos: .userInitiated).async {
                    self.session.stopRunning()
                    DispatchQueue.main.async {
                        self.state.isRunning = false
                    }
                }
            }
        }

        private func configureSession() {
            session.beginConfiguration()
            if session.canSetSessionPreset(.vga640x480) {
                session.sessionPreset = .vga640x480
            } else if session.canSetSessionPreset(.hd1280x720) {
                session.sessionPreset = .hd1280x720
            } else if session.canSetSessionPreset(.high) {
                session.sessionPreset = .high
            }

            let requested: [AVCaptureDevice.DeviceType] = [.builtInDualCamera, .builtInDualWideCamera, .builtInWideAngleCamera]
            let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: requested, mediaType: .video, position: .back)

            guard let device = discovery.devices.first,
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

            if session.canAddOutput(depthOutput) {
                session.addOutput(depthOutput)
                depthOutput.isFilteringEnabled = true
                depthOutput.setDelegate(self, callbackQueue: depthQueue)
                depthOutput.connection(with: .depthData)?.isEnabled = true
            }

            videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            ]
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue", qos: .userInitiated))
            videoOutput.alwaysDiscardsLateVideoFrames = true
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                videoOutput.connection(with: .video)?.videoOrientation = .portrait
            }

            session.commitConfiguration()
        }

        private func setupVision() {
            classificationRequest = VNClassifyImageRequest(completionHandler: { [weak self] request, _ in
                guard let self else { return }
                if let results = request.results as? [VNClassificationObservation], let top = results.first {
                    DispatchQueue.main.async {
                        self.state.label = top.identifier
                        self.state.confidence = top.confidence
                    }
                } else {
                    DispatchQueue.main.async {
                        self.state.label = "Scanning food…"
                        self.state.confidence = 0
                    }
                }
            })
            classificationRequest.regionOfInterest = roiRectNormalized
            classificationRequest.usesCPUOnly = false
        }

        private func setupFocusOverlay() {
            focusMaskLayer.fillRule = .evenOdd
            focusMaskLayer.fillColor = UIColor.black.withAlphaComponent(0.28).cgColor
            previewLayer.addSublayer(focusMaskLayer)

            focusBoxLayer.strokeColor = UIColor.white.withAlphaComponent(0.75).cgColor
            focusBoxLayer.fillColor = UIColor.clear.cgColor
            focusBoxLayer.lineWidth = 2.0
            focusBoxLayer.lineDashPattern = [6, 4]
            previewLayer.addSublayer(focusBoxLayer)

            focusCrosshairLayer.strokeColor = UIColor.white.withAlphaComponent(0.9).cgColor
            focusCrosshairLayer.fillColor = UIColor.clear.cgColor
            focusCrosshairLayer.lineWidth = 2
            focusCrosshairLayer.lineCap = .round
            previewLayer.addSublayer(focusCrosshairLayer)

            focusLabel.string = "Scanning food..."
            focusLabel.fontSize = 11
            focusLabel.alignmentMode = .center
            focusLabel.foregroundColor = UIColor.white.withAlphaComponent(0.85).cgColor
            focusLabel.contentsScale = UIScreen.main.scale
            previewLayer.addSublayer(focusLabel)
        }

        private func updateFocusOverlayFrame() {
            guard previewLayer.bounds.width > 0, previewLayer.bounds.height > 0 else { return }
            let rect = previewLayer.layerRectConverted(fromMetadataOutputRect: roiRectNormalized)
            let cutout = UIBezierPath(roundedRect: rect, cornerRadius: 12)
            let outer = UIBezierPath(rect: previewLayer.bounds)
            outer.append(cutout)
            focusMaskLayer.path = outer.cgPath
            focusBoxLayer.path = UIBezierPath(roundedRect: rect, cornerRadius: 12).cgPath

            let crossPath = UIBezierPath()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let arm: CGFloat = 10
            let gap: CGFloat = 4
            crossPath.move(to: CGPoint(x: center.x - arm, y: center.y))
            crossPath.addLine(to: CGPoint(x: center.x - gap, y: center.y))
            crossPath.move(to: CGPoint(x: center.x + gap, y: center.y))
            crossPath.addLine(to: CGPoint(x: center.x + arm, y: center.y))
            crossPath.move(to: CGPoint(x: center.x, y: center.y - arm))
            crossPath.addLine(to: CGPoint(x: center.x, y: center.y - gap))
            crossPath.move(to: CGPoint(x: center.x, y: center.y + gap))
            crossPath.addLine(to: CGPoint(x: center.x, y: center.y + arm))
            focusCrosshairLayer.path = crossPath.cgPath

            let labelHeight: CGFloat = 16
            focusLabel.frame = CGRect(
                x: rect.minX,
                y: rect.minY + 6,
                width: rect.width,
                height: labelHeight
            )
        }

        private func setupButtons() {
            let closeButton = UIButton(type: .close)
            closeButton.translatesAutoresizingMaskIntoConstraints = false
            closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
            view.addSubview(closeButton)
            NSLayoutConstraint.activate([
                closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
                closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16)
            ])
        }

        @objc private func shutterTapped() {
            frozenCaptureLabel = state.label
            frozenCaptureConfidence = state.confidence
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        @objc private func closeTapped() {
            onCancel()
        }

        private func performClassification(on pixelBuffer: CVPixelBuffer) {
            let currentTime = CACurrentMediaTime()
            let shouldRunDetection = (currentTime - lastDetectionTime) >= detectionInterval
            let shouldRunClassification = (currentTime - lastClassificationTime) >= classificationInterval
            guard shouldRunDetection || shouldRunClassification else {
                publishIntermediateStateIfNeeded(now: currentTime)
                return
            }

            if isAnalyzing { return }
            isAnalyzing = true
            defer { isAnalyzing = false }

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
            if shouldRunDetection, let det = detectionRequest {
                lastDetectionTime = currentTime
                do {
                    try handler.perform([det])
                    if let objs = det.results as? [VNRecognizedObjectObservation],
                       let focused = focusedDetectionLabel(from: objs) {
                        applyCandidateLabel(focused.identifier, confidence: focused.confidence, now: currentTime)
                    } else if shouldRunClassification {
                        lastClassificationTime = currentTime
                        runFallbackClassification(with: handler)
                    } else {
                        applyNoDetection(now: currentTime)
                    }
                } catch {
                    if shouldRunClassification {
                        lastClassificationTime = currentTime
                        runFallbackClassification(with: handler)
                    }
                }
            } else if shouldRunClassification {
                lastClassificationTime = currentTime
                runFallbackClassification(with: handler)
            }
        }

        private func publishIntermediateStateIfNeeded(now: CFTimeInterval) {
            guard (now - lastIntermediatePublishTime) >= intermediatePublishInterval else { return }
            lastIntermediatePublishTime = now
            let label = state.label
            let conf = state.confidence
            guard label != "Scanning food…" || conf > 0 else { return }
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .liveFoodDetectionUpdate,
                    object: nil,
                    userInfo: ["label": label, "confidence": conf, "intermediate": true]
                )
            }
        }

        private func runFallbackClassification(with handler: VNImageRequestHandler) {
            let request = VNClassifyImageRequest { [weak self] req, _ in
                guard let self else { return }
                let top = (req.results as? [VNClassificationObservation])?.first
                let chosen = (req.results as? [VNClassificationObservation])?.first(where: {
                    self.isCandidateUseful($0.identifier, confidence: $0.confidence)
                })
                if let chosen {
                    self.applyCandidateLabel(chosen.identifier, confidence: chosen.confidence, now: CACurrentMediaTime())
                } else if top == nil {
                    self.applyNoDetection(now: CACurrentMediaTime())
                } else {
                    self.applyNoDetection(now: CACurrentMediaTime())
                }
            }
            do {
                try handler.perform([request])
            } catch {
                AppLog.error(AppLog.vision, "[EnhancedCameraPreview] Fallback classification failed: \(error.localizedDescription)")
            }
        }

        private func applyCandidateLabel(_ rawLabel: String, confidence: Float, now: CFTimeInterval) {
            let normalized = formatLabel(rawLabel)
            guard confidence >= minReliableConfidence else {
                applyNoDetection(now: now)
                return
            }

            if pendingLabel == normalized {
                pendingCount += 1
            } else {
                pendingLabel = normalized
                pendingCount = 1
            }

            guard pendingCount >= minStableHits else { return }
            lastReliableDetectionTime = now

            DispatchQueue.main.async {
                self.state.label = normalized
                self.state.confidence = confidence
                self.focusLabel.string = "Focus: \(normalized) \(Int(confidence * 100))%"
                NotificationCenter.default.post(
                    name: .liveFoodDetectionUpdate,
                    object: nil,
                    userInfo: ["label": normalized, "confidence": confidence]
                )
            }
        }

        private func applyNoDetection(now: CFTimeInterval) {
            // Keep last stable label briefly to avoid rapid flicker.
            guard (now - lastReliableDetectionTime) > staleResetInterval else { return }
            pendingLabel = nil
            pendingCount = 0
            DispatchQueue.main.async {
                self.state.label = "Scanning food…"
                self.state.confidence = 0
                self.focusLabel.string = "Scanning food..."
            }
        }

        private func formatLabel(_ label: String) -> String {
            let lower = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard let first = lower.first else { return "Food" }
            return first.uppercased() + lower.dropFirst()
        }

        private func chooseBestLabel(from labels: [VNClassificationObservation]) -> VNClassificationObservation? {
            for label in labels {
                if isCandidateUseful(label.identifier, confidence: label.confidence) {
                    return label
                }
            }
            return nil
        }

        private func focusedDetectionLabel(from observations: [VNRecognizedObjectObservation]) -> (identifier: String, confidence: Float)? {
            let focus = CGPoint(x: roiRectNormalized.midX, y: roiRectNormalized.midY)
            typealias Candidate = (label: VNClassificationObservation, distance: CGFloat, containsFocus: Bool)
            let candidates: [Candidate] = observations.compactMap { obs in
                guard let label = chooseBestLabel(from: obs.labels) else { return nil }
                let center = CGPoint(x: obs.boundingBox.midX, y: obs.boundingBox.midY)
                let dx = center.x - focus.x
                let dy = center.y - focus.y
                let distance = (dx * dx + dy * dy).squareRoot()
                return (label: label, distance: distance, containsFocus: obs.boundingBox.contains(focus))
            }
            guard !candidates.isEmpty else { return nil }
            let prioritized = candidates.filter { $0.containsFocus }
            let source = prioritized.isEmpty ? candidates : prioritized
            let best = source.sorted {
                if $0.distance == $1.distance {
                    return $0.label.confidence > $1.label.confidence
                }
                return $0.distance < $1.distance
            }.first
            guard let best else { return nil }
            return (identifier: best.label.identifier, confidence: best.label.confidence)
        }

        private func isCandidateUseful(_ identifier: String, confidence: Float) -> Bool {
            guard confidence >= minReliableConfidence else { return false }
            let lower = identifier.lowercased()
            let genericBlocked: Set<String> = [
                "structure", "building", "object", "artifact", "furniture", "material",
                "wall", "floor", "ceiling", "indoor", "outdoor", "room"
            ]
            if genericBlocked.contains(lower) { return false }
            if lower.count < 3 { return false }
            return looksLikeFoodLabel(lower)
        }

        private func looksLikeFoodLabel(_ lower: String) -> Bool {
            let foodKeywords: [String] = [
                "food", "meal", "dish", "plate", "bowl", "snack",
                "fruit", "vegetable", "salad", "rice", "pasta", "noodle", "soup",
                "bread", "toast", "cake", "dessert", "cookie", "chocolate",
                "pizza", "burger", "sandwich", "taco", "burrito", "sushi",
                "egg", "cheese", "yogurt", "milk", "chicken", "beef", "pork", "fish", "shrimp",
                "potato", "fries", "bean", "lentil", "avocado", "banana", "apple", "orange",
                "coffee", "tea", "juice", "smoothie"
            ]
            return foodKeywords.contains { lower.contains($0) }
        }

        private func captureDepthSnapshot() -> (depth: CVPixelBuffer, intrinsics: simd_float3x3)? {
            var depthMap: CVPixelBuffer?
            var intrinsics = latestIntrinsics
            depthStateQueue.sync {
                depthMap = latestDepthMap
                intrinsics = latestIntrinsics
            }
            guard let depthMap else { return nil }
            return (depthMap, intrinsics)
        }

        private func computeCaptureMetrics() -> (volumeML: Float?, massG: Float?) {
            guard let snapshot = captureDepthSnapshot() else {
                return (nil, nil)
            }
            return EnhancedCaptureMetricsEstimator.compute(
                depth: snapshot.depth,
                intrinsics: snapshot.intrinsics,
                label: state.label
            )
        }

        private func makeDepthSnapshot(imageSize: CGSize) -> DepthFrameSnapshot? {
            guard let snapshot = captureDepthSnapshot(),
                  let copiedDepth = Self.copyDepthMap(snapshot.depth) else {
                return nil
            }
            return DepthFrameSnapshot(depthMap: copiedDepth, intrinsics: snapshot.intrinsics, imageSize: imageSize)
        }

        private func cropCapturedImageToROI(_ image: UIImage) -> UIImage {
            // Match the visible ROI by converting through preview-layer metadata mapping (aspect-fill aware).
            let upright = image.normalizedUpOrientation()
            guard let cg = upright.cgImage else { return image }
            let pixelSize = CGSize(width: CGFloat(cg.width), height: CGFloat(cg.height))
            guard pixelSize.width > 1, pixelSize.height > 1 else { return image }

            // ROI as shown on-screen.
            let roiInLayer = previewLayer.layerRectConverted(fromMetadataOutputRect: roiRectNormalized)
            // Convert visible layer rect back to normalized metadata space.
            let metadataRect = previewLayer.metadataOutputRectConverted(fromLayerRect: roiInLayer)
            // Map normalized metadata rect to image pixels.
            let pixelRect = CGRect(
                x: metadataRect.origin.x * pixelSize.width,
                y: metadataRect.origin.y * pixelSize.height,
                width: metadataRect.size.width * pixelSize.width,
                height: metadataRect.size.height * pixelSize.height
            ).integral.intersection(CGRect(origin: .zero, size: pixelSize))

            guard pixelRect.width > 1, pixelRect.height > 1,
                  let cropped = cg.cropping(to: pixelRect) else {
                return image
            }
            return UIImage(cgImage: cropped, scale: upright.scale, orientation: .up)
        }

        private static func copyDepthMap(_ source: CVPixelBuffer) -> CVPixelBuffer? {
            let width = CVPixelBufferGetWidth(source)
            let height = CVPixelBufferGetHeight(source)
            let format = CVPixelBufferGetPixelFormatType(source)
            var destination: CVPixelBuffer?
            let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, format, nil, &destination)
            guard status == kCVReturnSuccess, let destination else {
                return nil
            }

            CVPixelBufferLockBaseAddress(source, .readOnly)
            CVPixelBufferLockBaseAddress(destination, [])
            defer {
                CVPixelBufferUnlockBaseAddress(destination, [])
                CVPixelBufferUnlockBaseAddress(source, .readOnly)
            }

            guard let srcBase = CVPixelBufferGetBaseAddress(source),
                  let dstBase = CVPixelBufferGetBaseAddress(destination) else {
                return nil
            }

            let srcBytesPerRow = CVPixelBufferGetBytesPerRow(source)
            let dstBytesPerRow = CVPixelBufferGetBytesPerRow(destination)
            let copyBytesPerRow = min(srcBytesPerRow, dstBytesPerRow)
            for row in 0..<height {
                let src = srcBase.advanced(by: row * srcBytesPerRow)
                let dst = dstBase.advanced(by: row * dstBytesPerRow)
                memcpy(dst, src, copyBytesPerRow)
            }
            return destination
        }
    }
}

private extension UIImage {
    func normalizedUpOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

extension CameraControllerRepresentable.CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        if !hasLoggedFirstFrame {
            hasLoggedFirstFrame = true
            if let start = cameraOpenRequestedAt {
                let elapsedMS = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
                AppLog.debug(AppLog.vision, "⏱️ [EnhancedCamera] First frame visible in \(elapsedMS) ms")
            } else {
                AppLog.debug(AppLog.vision, "⏱️ [EnhancedCamera] First frame visible")
            }
        }
        performClassification(on: pixelBuffer)
    }
}

extension CameraControllerRepresentable.CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        let croppedImage = cropCapturedImageToROI(image)
        let metrics = computeCaptureMetrics()
        // Depth snapshot maps to full sensor image coordinates; skip passing it with cropped imagery.
        let depthSnapshot: DepthFrameSnapshot? = nil
        let capturedLabel = frozenCaptureLabel ?? self.state.label
        let capturedConfidence = frozenCaptureConfidence ?? self.state.confidence
        frozenCaptureLabel = nil
        frozenCaptureConfidence = nil
        DispatchQueue.main.async {
            self.onCaptured(croppedImage, metrics.volumeML, metrics.massG, depthSnapshot, capturedLabel, capturedConfidence)
        }
    }
}

extension CameraControllerRepresentable.CameraViewController: AVCaptureDepthDataOutputDelegate {
    func depthDataOutput(_ output: AVCaptureDepthDataOutput,
                         didOutput depthData: AVDepthData,
                         timestamp: CMTime,
                         connection: AVCaptureConnection) {
        var converted = depthData
        if converted.depthDataType != kCVPixelFormatType_DepthFloat32 {
            converted = converted.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        }
        let depthMap = converted.depthDataMap
        let intrinsics = converted.cameraCalibrationData?.intrinsicMatrix

        depthStateQueue.async { [weak self] in
            guard let self else { return }
            self.latestDepthMap = depthMap
            if let intrinsics {
                self.latestIntrinsics = intrinsics
            }
        }
    }
}
