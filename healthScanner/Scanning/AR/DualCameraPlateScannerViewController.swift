// DualCameraPlateScannerViewController.swift — Non-LiDAR Fallback (AVCapture Video + Depth)
// Works on iPhones without LiDAR (11/12/13 non-Pro, 12/13 mini, etc.)

import UIKit
import AVFoundation
import Vision
import CoreML
import CoreImage
import CoreVideo
import simd
import SwiftUI

// MARK: - Detection Model Provider (prewarm support)
fileprivate final class DetectionModelProvider {
    static let shared = DetectionModelProvider()
    private let queue = DispatchQueue(label: "detection.model.loader")
    private var detectionRequest: VNCoreMLRequest?
    private var loading = false
    private var completions: [(VNCoreMLRequest?) -> Void] = []

    func preload() {
        AppLog.debug(AppLog.scanner, "🔸 [Vision] Prewarm requested")
        getDetectionRequest { _ in }
    }

    func getDetectionRequest(completion: @escaping (VNCoreMLRequest?) -> Void) {
        queue.async {
            if let req = self.detectionRequest {
                AppLog.debug(AppLog.scanner, "⚡️ [Vision] Using cached detection request")
                DispatchQueue.main.async { completion(req) }
                return
            }
            self.completions.append(completion)
            if self.loading { return }
            self.loading = true
            let start = CACurrentMediaTime()
            let req = self.loadDetectionRequest()
            self.detectionRequest = req
            let ms = Int((CACurrentMediaTime() - start) * 1000)
            AppLog.debug(AppLog.scanner, "✅ [Vision] Prewarm complete in \(ms) ms (success: \(req != nil))")
            let callbacks = self.completions
            self.completions.removeAll()
            self.loading = false
            for cb in callbacks {
                DispatchQueue.main.async { cb(req) }
            }
        }
    }

    private func loadDetectionRequest() -> VNCoreMLRequest? {
        guard let url = findModelURL(named: "yolov8x-oiv7") else {
            AppLog.debug(AppLog.scanner, "ℹ️ [Vision] YOLOv8 model not available")
            logBundleModels()
            return nil
        }
        do {
            let cfg = MLModelConfiguration(); cfg.computeUnits = .all
            let ml = try MLModel(contentsOf: url, configuration: cfg)
            if let vn = try? VNCoreMLModel(for: ml) {
                let req = VNCoreMLRequest(model: vn)
                req.imageCropAndScaleOption = .scaleFill
                AppLog.debug(AppLog.scanner, "✅ [Vision] YOLOv8 detection model enabled (\(url.pathExtension)) [prewarmed]")
                return req
            } else {
                AppLog.debug(AppLog.scanner, "⚠️ [Vision] Could not wrap model in VNCoreMLModel")
            }
        } catch {
            AppLog.debug(AppLog.scanner, "⚠️ [Vision] Failed to load YOLOv8 model: \(error)")
        }
        logBundleModels()
        return nil
    }

    private func findModelURL(named baseName: String, bundle: Bundle = .main) -> URL? {
        if let url = bundle.url(forResource: baseName, withExtension: "mlmodelc") { return url }
        if let url = bundle.url(forResource: baseName, withExtension: "mlmodelc", subdirectory: "CoreML") { return url }
        if let url = bundle.url(forResource: baseName, withExtension: "mlpackage") { return url }
        if let url = bundle.url(forResource: baseName, withExtension: "mlpackage", subdirectory: "CoreML") { return url }
        return nil
    }

    private func logBundleModels() {
        let compiled = Bundle.main.paths(forResourcesOfType: "mlmodelc", inDirectory: nil)
        if !compiled.isEmpty {
            AppLog.debug(AppLog.scanner, "📦 .mlmodelc in bundle:")
            compiled.forEach { AppLog.debug(AppLog.scanner, "  - \($0)") }
        }
        let packages = Bundle.main.paths(forResourcesOfType: "mlpackage", inDirectory: nil)
        if !packages.isEmpty {
            AppLog.debug(AppLog.scanner, "📦 .mlpackage in bundle:")
            packages.forEach { AppLog.debug(AppLog.scanner, "  - \($0)") }
        }
    }
}

public final class DualCameraPlateScannerViewController: UIViewController,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    AVCaptureDepthDataOutputDelegate
{
    // MARK: Public callbacks
    public var onResult: ((ARPlateScanNutrition, UIImage) -> Void)?
    public var onCancel: (() -> Void)?

    // MARK: Prewarming
    public static func prewarmModels() {
        DetectionModelProvider.shared.preload()
    }
    public static func prewarmModels(completion: @escaping (Bool) -> Void) {
        DetectionModelProvider.shared.getDetectionRequest { req in
            completion(req != nil)
        }
    }

    // MARK: UI
    private let preview = PreviewView()
    private var previewSize: CGSize = .zero
    // Segmentation/saliency overlay
    private let segmentationOverlayView = UIImageView()
    private let overlayQueue = DispatchQueue(label: "segmentation.overlay")
    private var lastOverlayTime: CFTimeInterval = 0
    private var overlayBusy = false
    private let showDetectionBoxes = true
    private var didLogDetectionResultType = false
    private let hud = HUD()
    private let closeBtn = UIButton(type: .close)
    private let captureBtn = UIButton(type: .custom)
    // Classification badge UI
    private let classificationBadge = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    private let classificationIcon = UIImageView()
    private let classificationText = UILabel()
    private var isReadyToCapture = false
    private var pendingUserCapture = false
    private var didShowFirstFrame = false
    private var lastVideoPixelBuffer: CVPixelBuffer?
    private var lastEffectiveDepthBuffer: CVPixelBuffer?
    private var lastPlaneFit: simd_float4?

    // MARK: Capture
    private let session = AVCaptureSession()
    private var videoDevice: AVCaptureDevice?
    private let videoOutput = AVCaptureVideoDataOutput()
    private let depthOutput = AVCaptureDepthDataOutput()
    private let videoQueue = DispatchQueue(label: "video.queue")
    private let depthQueue = DispatchQueue(label: "depth.queue")

    // Latest buffers
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
    // Fused depth tracking (monocular path)
    private var lastDepthData: AVDepthData?
    private var lastDepthTimestamp: CMTime = .invalid
    private var fusedDepthMap: CVPixelBuffer?
    private var previousFusedDepthMap: CVPixelBuffer?

    // MARK: Vision (optional)
    // Load ML models off the main thread to avoid blocking UI
    private func setupVisionAsync() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.setupVision()
        }
    }
    
    private var detectionRequest: VNCoreMLRequest?

    // Plane stability
    private var planeHistory: [simd_float4] = []

    // Control
    private var didEmit = false
    
    //Overaly
    private let hudModel = ScanHUDModel()
    private lazy var ringOverlayHost = UIHostingController(rootView: PlateProgressRingView(model: hudModel))
    private let ringGeometryQueue = DispatchQueue(label: "dualcam.ring.geometry")
    private var ringCenterSnapshot: CGPoint = .zero
    private var ringSizeSnapshot: CGFloat = 0

    // Normalized fallback crop if ring size isn't ready (x,y,w,h) in 0..1
    private let fallbackCropNormalized = CGRect(x: 0.15, y: 0.15, width: 0.70, height: 0.70)

    // Readiness fallback (when depth is unavailable): time-based progress
    private var fallbackProgress: Float = 0
    private var lastProgressTick: CFTimeInterval = CACurrentMediaTime()
    private var stableFrameCount: Int = 0
    private var hapticLevel: Int = 0 // 0: none, 1: mid, 2: near-ready

    // Progress smoothing & capture window
    private var lastDisplayedProgress: CGFloat = 0
    private var nearReadyFrameCount: Int = 0
    private let requiredNearReadyFrames: Int = 10 // ~0.6s at ~16fps
    private var nearReadyStartTime: CFTimeInterval = 0
    private let nearReadyTimeout: CFTimeInterval = 4.0 // seconds

    // Content gating
    private var contentStableCount: Int = 0
    private let requiredContentStableFrames: Int = 8 // ~0.5s at ~15fps
    private var lastTextureCheckTime: CFTimeInterval = 0
    private var cachedTextureOK = false
    private let textureCheckInterval: CFTimeInterval = 0.2

    // No local nutrition DB here; AI handles nutrition downstream

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        addRingOverlay()
        setupVisionAsync()
        configureSession()
        // Removed session.startRunning() here as requested
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.previewSize = self.view.bounds.size
        setRingGeometrySnapshot(center: hudModel.ringCenter, size: hudModel.ringSize)
    }

    // MARK: UI
    private func setupUI() {
        preview.videoGravity = .resizeAspectFill
        view.addSubview(preview)
        preview.alpha = 0
        
        // Add segmentation overlay above preview
        segmentationOverlayView.translatesAutoresizingMaskIntoConstraints = false
        segmentationOverlayView.backgroundColor = .clear
        segmentationOverlayView.contentMode = .scaleAspectFill
        segmentationOverlayView.isUserInteractionEnabled = false
        view.addSubview(segmentationOverlayView)
        
        view.addSubview(hud)
        preview.translatesAutoresizingMaskIntoConstraints = false
        hud.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: view.topAnchor),
            preview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            preview.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            segmentationOverlayView.topAnchor.constraint(equalTo: view.topAnchor),
            segmentationOverlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            segmentationOverlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            segmentationOverlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            hud.topAnchor.constraint(equalTo: view.topAnchor),
            hud.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hud.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hud.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        // Cache preview size for background-thread computations
        self.previewSize = self.view.bounds.size

        // Classification badge setup
        classificationBadge.translatesAutoresizingMaskIntoConstraints = false
        classificationBadge.layer.cornerRadius = 14
        classificationBadge.clipsToBounds = true
        let badgeContent = classificationBadge.contentView
        classificationIcon.translatesAutoresizingMaskIntoConstraints = false
        classificationIcon.tintColor = .white
        classificationIcon.contentMode = .scaleAspectFit
        classificationText.translatesAutoresizingMaskIntoConstraints = false
        classificationText.textColor = .white
        classificationText.font = .systemFont(ofSize: 16, weight: .semibold)
        classificationText.text = "Detecting food…"
        badgeContent.addSubview(classificationIcon)
        badgeContent.addSubview(classificationText)
        view.addSubview(classificationBadge)
        NSLayoutConstraint.activate([
            classificationBadge.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            classificationBadge.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            classificationIcon.leadingAnchor.constraint(equalTo: badgeContent.leadingAnchor, constant: 12),
            classificationIcon.centerYAnchor.constraint(equalTo: badgeContent.centerYAnchor),
            classificationIcon.widthAnchor.constraint(equalToConstant: 20),
            classificationIcon.heightAnchor.constraint(equalToConstant: 20),
            classificationText.leadingAnchor.constraint(equalTo: classificationIcon.trailingAnchor, constant: 8),
            classificationText.trailingAnchor.constraint(equalTo: badgeContent.trailingAnchor, constant: -12),
            classificationText.topAnchor.constraint(equalTo: badgeContent.topAnchor, constant: 8),
            classificationText.bottomAnchor.constraint(equalTo: badgeContent.bottomAnchor, constant: -8)
        ])

        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeBtn)
        NSLayoutConstraint.activate([
            closeBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12)
        ])
        
        // Capture button (user-initiated)
        captureBtn.translatesAutoresizingMaskIntoConstraints = false
        captureBtn.isEnabled = false
        captureBtn.alpha = 0.5
        captureBtn.backgroundColor = .white
        captureBtn.layer.cornerRadius = 40
        captureBtn.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        view.addSubview(captureBtn)
        NSLayoutConstraint.activate([
            captureBtn.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureBtn.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            captureBtn.widthAnchor.constraint(equalToConstant: 80),
            captureBtn.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        hud.setStatus("Move slowly around the plate…")
        
        view.bringSubviewToFront(closeBtn)
        view.bringSubviewToFront(captureBtn)
        view.bringSubviewToFront(hud)
        view.bringSubviewToFront(classificationBadge)
    }
    
    //adding overlay
    private func addRingOverlay() {
        let host = ringOverlayHost
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        host.view.translatesAutoresizingMaskIntoConstraints = false
        addChild(host)
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        view.bringSubviewToFront(segmentationOverlayView)
        // Ensure buttons are above the overlay to receive touches
        view.bringSubviewToFront(closeBtn)
        view.bringSubviewToFront(captureBtn)
        view.bringSubviewToFront(hud)
        // default ring position: center
        hudModel.ringCenter = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        hudModel.ringSize = min(view.bounds.width, view.bounds.height) * 0.48
        setRingGeometrySnapshot(center: hudModel.ringCenter, size: hudModel.ringSize)
    }

    private func setRingGeometrySnapshot(center: CGPoint, size: CGFloat) {
        ringGeometryQueue.sync {
            ringCenterSnapshot = center
            ringSizeSnapshot = size
        }
    }

    private func currentRingGeometry() -> (center: CGPoint, size: CGFloat) {
        ringGeometryQueue.sync {
            (ringCenterSnapshot, ringSizeSnapshot)
        }
    }


    @objc private func closeTapped() { onCancel?(); dismiss(animated: true) }
    @objc private func captureTapped() {
        pendingUserCapture = true
    }

    // MARK: Vision
    private func setupVision() {
        DetectionModelProvider.shared.getDetectionRequest { [weak self] req in
            guard let self else { return }
            self.detectionRequest = req
            let detAvailable = (req != nil) ? "YES" : "NO"
            AppLog.debug(AppLog.scanner, "🔎 [Vision] Detection model available: \(detAvailable)")
            if req != nil {
                AppLog.debug(AppLog.scanner, "🔧 [Vision] Detection request configured; verifying observation type on first inference…")
            }
        }
    }

    private func logDetectionResultTypesIfNeeded(_ results: [Any]?) {
        guard !didLogDetectionResultType else { return }
        let types = (results ?? []).map { String(describing: type(of: $0)) }
        if let first = results?.first {
            if first is VNRecognizedObjectObservation {
                AppLog.debug(AppLog.scanner, "✅ [YOLO] Vision is returning VNRecognizedObjectObservation – object detector mode ENABLED")
            } else if first is VNCoreMLFeatureValueObservation {
                AppLog.debug(AppLog.scanner, "⚠️ [YOLO] Vision returned VNCoreMLFeatureValueObservation – manual decoding required (object detector mode NOT enabled)")
            } else {
                AppLog.debug(AppLog.scanner, "ℹ️ [YOLO] Vision results types: \(types)")
            }
        } else {
            AppLog.debug(AppLog.scanner, "ℹ️ [YOLO] Vision results types: \(types)")
        }
        AppLog.debug(AppLog.scanner, "[YOLO] VNCoreMLRequest results types: \(types)")
        didLogDetectionResultType = true
    }

    // Removed iconForLabel(_:) method as per instructions

    // MARK: Capture config
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .vga640x480

        // Prefer dual/dual-wide; fall back to wide
        let requested: [AVCaptureDevice.DeviceType] = [.builtInDualCamera, .builtInDualWideCamera, .builtInWideAngleCamera]
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: requested, mediaType: .video, position: .back)
        guard let device = discovery.devices.first else {
            hud.setStatus("No back camera available")
            session.commitConfiguration()
            return
        }
        videoDevice = device

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
        } catch {
            hud.setStatus("Camera error: \(error.localizedDescription)")
            session.commitConfiguration()
            return
        }

        // Video output
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        ]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        preview.session = session

        // Depth output (separate delegate – no deliverySupported flags on DepthDataOutput)
        if session.canAddOutput(depthOutput) {
            session.addOutput(depthOutput)
            depthOutput.isFilteringEnabled = true
            depthOutput.setDelegate(self, callbackQueue: depthQueue)
            depthOutput.connection(with: .depthData)?.isEnabled = true
        }

        // Best-effort focus/exposure
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
            if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.unlockForConfiguration()
        } catch {
            AppLog.error(AppLog.scanner, "[DualCam] Focus/exposure configuration failed: \(error.localizedDescription)")
        }

        session.commitConfiguration()
    }

    // MARK: Delegates
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !didEmit, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        if !didShowFirstFrame {
            didShowFirstFrame = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                UIView.animate(withDuration: 0.25) { self.preview.alpha = 1 }
            }
        }
        self.lastVideoPixelBuffer = pixelBuffer

        // Determine freshness of the last fused depth relative to this video frame
        let videoTS = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let depthForFrame: CVPixelBuffer? = isDepthFresh(for: videoTS) ? fusedDepthMap : nil
        let effectiveDepth: CVPixelBuffer? = depthForFrame

        // Camera intrinsics (if present)
        if let att = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) as? NSData {
            latestIntrinsics = att.bytes.bindMemory(to: simd_float3x3.self, capacity: 1).pointee
        }

        // Vision (optional)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        var label = "food"
        var conf: Float = 0.5
        var detections: [VNRecognizedObjectObservation] = []
        do {
            if let det = detectionRequest {
                try handler.perform([det])
                logDetectionResultTypesIfNeeded(det.results)
                let objs = det.results as? [VNRecognizedObjectObservation] ?? []
                detections = objs
                if let best = objs.max(by: { $0.confidence < $1.confidence }),
                   let top = best.labels.first {
                    label = top.identifier
                    conf = top.confidence
                }
            }
        } catch {
            AppLog.error(AppLog.scanner, "[DualCam] Vision detection request failed: \(error.localizedDescription)")
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.classificationIcon.image = IconMapper.shared.icon(for: label)?.withRenderingMode(.alwaysTemplate)
            let niceLabel = label.prefix(1).uppercased() + label.dropFirst()
            let percent = Int(max(0, min(100, conf * 100)))
            self.classificationText.text = percent > 0 ? "\(niceLabel) • \(percent)%" : niceLabel
        }

        if showDetectionBoxes {
            let nowOverlay = CACurrentMediaTime()
            if !overlayBusy && (nowOverlay - lastOverlayTime) > 0.20 {
                overlayBusy = true
                lastOverlayTime = nowOverlay
                overlayQueue.async { [weak self] in
                    guard let self else { return }
                    let overlayImage = self.generateOverlayImage(from: pixelBuffer)
                    DispatchQueue.main.async { [weak self] in
                        guard let self else { return }
                        self.segmentationOverlayView.image = overlayImage
                        self.segmentationOverlayView.alpha = (overlayImage != nil) ? 0.35 : 0.0
                        self.segmentationOverlayView.isHidden = (overlayImage == nil)
                    }
                    self.overlayBusy = false
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.segmentationOverlayView.image = nil
                self?.segmentationOverlayView.alpha = 0.0
                self?.segmentationOverlayView.isHidden = true
            }
        }

        func detectionCoverage(_ obs: [VNRecognizedObjectObservation]) -> Float {
            guard !obs.isEmpty else { return 0 }
            let size = self.pixelBufferSize(pixelBuffer)
            var totalArea: CGFloat = 0
            for o in obs {
                let bb = o.boundingBox
                totalArea += (CGFloat(bb.width) * size.width) * (CGFloat(bb.height) * size.height)
            }
            let frameArea = max(1, size.width * size.height)
            let cov = totalArea / frameArea
            return Float(min(1.0, max(0.0, cov)))
        }
        let coverage: Float = detectionCoverage(detections)

        var ringCoverage: CGFloat = 0
        let viewSize = self.previewSize
        let pbSize = self.pixelBufferSize(pixelBuffer)
        let scale = max(viewSize.width / pbSize.width, viewSize.height / pbSize.height)
        let displayedW = pbSize.width * scale
        let displayedH = pbSize.height * scale
        let offsetX = (viewSize.width - displayedW) * 0.5
        let offsetY = (viewSize.height - displayedH) * 0.5
        let (ringCenter, ringSize) = currentRingGeometry()
        let padFactor: CGFloat = 1.0
        let ringRectView = CGRect(x: ringCenter.x - (ringSize*padFactor)/2,
                                  y: ringCenter.y - (ringSize*padFactor)/2,
                                  width: ringSize*padFactor,
                                  height: ringSize*padFactor)
        if !detections.isEmpty {
            for o in detections {
                let bb = o.boundingBox
                let w = CGFloat(bb.width) * pbSize.width
                let h = CGFloat(bb.height) * pbSize.height
                let x = CGFloat(bb.origin.x) * pbSize.width
                let yFromBottom = CGFloat(bb.origin.y) * pbSize.height
                let y = pbSize.height - yFromBottom - h
                let mapped = CGRect(
                    x: offsetX + (x * scale),
                    y: offsetY + (y * scale),
                    width: w * scale,
                    height: h * scale
                )
                let inter = mapped.intersection(ringRectView)
                if inter.width > 0 && inter.height > 0 {
                    let cov = inter.width * inter.height / max(1, ringRectView.width * ringRectView.height)
                    ringCoverage = max(ringCoverage, cov)
                }
            }
        }

        // Combine gating: require coverage, ring overlap, and texture
        let coverageOK = coverage > 0.20
        let ringOK = ringCoverage > 0.50
        let now = CACurrentMediaTime()
        let shouldRefreshTexture = (now - lastTextureCheckTime) >= textureCheckInterval
        let textureOK: Bool
        if coverageOK && ringOK {
            if shouldRefreshTexture {
                lastTextureCheckTime = now
                if let full = UIImage(pixelBuffer: pixelBuffer, orientation: .right) {
                    let ringCropped = self.cropToRing(full)
                    let density = edgeDensity(in: ringCropped)
                    cachedTextureOK = density > 0.10 // tune threshold as needed
                } else {
                    cachedTextureOK = false
                }
            }
            textureOK = cachedTextureOK
        } else {
            cachedTextureOK = false
            textureOK = false
        }
        let contentOK = coverageOK && ringOK && textureOK
        if contentOK { contentStableCount += 1 } else { contentStableCount = 0 }

        // Plane fit from latest depth (if any)
        var plane: simd_float4? = nil
        if let d = effectiveDepth { plane = Self.estimatePlane(depth: d, intrinsics: latestIntrinsics) }
        self.lastEffectiveDepthBuffer = effectiveDepth
        self.lastPlaneFit = plane
        if let p = plane {
            planeHistory.append(p)
            if planeHistory.count > 20 { planeHistory.removeFirst() }
        }

        // Readiness
        let r = readiness(depth: effectiveDepth, planeHistory: planeHistory)

        // Update ring progress; if no depth, advance a time-based fallback
        let nowProgress = CACurrentMediaTime()
        let dt = nowProgress - lastProgressTick
        lastProgressTick = nowProgress
        var ready = r.ready
        var progress = r.score
        // Advance a time-based fallback so progress completes even without perfect depth
        let ramp = Float(dt / 2.0) // ~2s to full
        fallbackProgress = min(1.0, fallbackProgress + ramp)
        if effectiveDepth != nil {
            // With depth, still allow fallback to drive to green if score is low
            progress = max(progress, min(1.0, fallbackProgress * 0.95))
        } else {
            progress = max(progress, fallbackProgress)
        }
        if progress >= 0.99 { stableFrameCount += 1 } else { stableFrameCount = 0 }
        ready = ready || (stableFrameCount >= 4)

        // Smooth progress to avoid oscillation and cap at 0.99 until finalize
        let smoothedProgress = max(lastDisplayedProgress, CGFloat(progress))
        let cappedProgress = min(smoothedProgress, 0.99)
        lastDisplayedProgress = cappedProgress

        // Near-ready window with dwell and timeout
        let nearReadyThreshold: Float = 0.95
        let isNearReady = progress >= nearReadyThreshold && (contentStableCount >= requiredContentStableFrames)
        if isNearReady {
            nearReadyFrameCount += 1
            if nearReadyStartTime == 0 { nearReadyStartTime = CACurrentMediaTime() }
        } else {
            // gentle decay instead of hard reset
            nearReadyFrameCount = max(0, nearReadyFrameCount - 1)
            if nearReadyFrameCount == 0 { nearReadyStartTime = 0 }
        }
        let captureWindowActive = nearReadyFrameCount >= requiredNearReadyFrames
        let timedOut: Bool = (nearReadyStartTime > 0) && ((CACurrentMediaTime() - nearReadyStartTime) > nearReadyTimeout)

        // Combine: accept ready or capture window or timeout (best-effort)
        ready = ready || captureWindowActive || timedOut

        // Combine with content gating: require content to be valid for several frames
        // ready = ready && contentReady // moved into hint logic

        DispatchQueue.main.async {
            self.hudModel.progress = cappedProgress
            // Specific, actionable hinting
            let contentReady = (self.contentStableCount >= self.requiredContentStableFrames)
            var hintText: String
            if !contentReady {
                // Determine which sub-condition is failing if possible
                var parts: [String] = []
                if !(coverage > 0.20) { parts.append("Fill the ring with the plate") }
                if !(ringCoverage > 0.50) { parts.append("Center the plate in the ring") }
                if !textureOK { parts.append("Point at food (not flat texture)") }
                hintText = parts.first ?? "Center the plate and fill the ring"
            } else if !r.planeStableOK {
                hintText = "Hold the phone steady"
            } else if !r.depthOK {
                hintText = "Move closer or add light"
            } else {
                hintText = ready ? "Ready — tap shutter" : r.hint
            }
            self.hudModel.hint = "\(Int(progress*100))% – \(hintText)"
        }
        // Haptics when crossing thresholds
        if hapticLevel == 0 && progress >= 0.6 {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            hapticLevel = 1
        } else if hapticLevel == 1 && progress >= 0.9 {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            hapticLevel = 2
        }
        // Debug progress
        if Int(progress*100) % 10 == 0 { AppLog.debug(AppLog.scanner, "🔵 [DualCam] progress=\(String(format: "%.2f", progress)) ready=\(ready) depth=\(effectiveDepth != nil)") }

        // Update capture button state based on readiness and content gating
        let enableCapture = ready
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isReadyToCapture = enableCapture
            self.captureBtn.isEnabled = enableCapture
            self.captureBtn.alpha = enableCapture ? 1.0 : 0.5
        }

        // Only capture when user taps the button and we are ready
        guard enableCapture && pendingUserCapture else { return }
        pendingUserCapture = false

        // Finalize - build full image first
        guard let fullImage = UIImage(pixelBuffer: pixelBuffer, orientation: .right) else {
            return
        }
        let croppedImage = cropToRing(fullImage)
        let volML = Self.integrateVolume(depth: effectiveDepth, mask: nil, intrinsics: latestIntrinsics, plane: planeHistory.last)
        AppLog.debug(AppLog.scanner, "🟢 [DualCam] depth=\(effectiveDepth != nil ? "yes" : "no"), volumeML=\(String(format: "%.1f", volML))")
        let mass: Float = 0

        DispatchQueue.main.async { [weak self] in
            self?.hudModel.progress = 1.0
            self?.hudModel.hint = "100% – Capturing…"
        }

        let result = ARPlateScanNutrition(
            label: label,
            confidence: conf,
            volumeML: Float(volML),
            massG: Float(mass),
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0
        )
        didEmit = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onResult?(result, croppedImage)
            self.dismiss(animated: true)
        }
    }

    public func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        // 1) Normalize to DepthFloat32 and portrait EXIF orientation to match our video/UI path
        var data = depthData
        let targetFormat = kCVPixelFormatType_DepthFloat32
        if data.depthDataType != targetFormat {
            data = data.converting(toDepthDataType: targetFormat)
        }
        // NOTE: Orientation alignment skipped to avoid SDK throwing variants; metrics use calibration instead

        // 2) Fuse with previous (simple temporal smoothing) and replace depth map
        let currentMap = data.depthDataMap
        guard let fusedPB = Self.fuseDepth(current: currentMap, previous: previousFusedDepthMap) else {
            // Fallback: no fusion possible, keep current
            lastDepthData = data
            fusedDepthMap = currentMap
            previousFusedDepthMap = currentMap
            lastDepthTimestamp = timestamp
            // Prefer calibration intrinsics from depth data when available
            if let calib = data.cameraCalibrationData {
                latestIntrinsics = calib.intrinsicMatrix
            }
            let w = CVPixelBufferGetWidth(currentMap)
            let h = CVPixelBufferGetHeight(currentMap)
            AppLog.debug(AppLog.scanner, "🟢 [DualCam] depth map received (no fusion): \(w)x\(h)")
            return
        }

        // Preserve original depth data for calibration; use fused pixel buffer for metrics
        lastDepthData = data
        fusedDepthMap = fusedPB
        previousFusedDepthMap = fusedPB
        lastDepthTimestamp = timestamp
        latestDepthMap = fusedPB // keep legacy property updated for debugging/UI
        if let calib = data.cameraCalibrationData {
            latestIntrinsics = calib.intrinsicMatrix
        }
        let w = CVPixelBufferGetWidth(fusedPB)
        let h = CVPixelBufferGetHeight(fusedPB)
        AppLog.debug(AppLog.scanner, "🟢 [DualCam] fused depth map: \(w)x\(h)")
    }

    // MARK: Readiness
    /// Returns overall readiness plus component flags for UI/hints.
    private func readiness(
        depth: CVPixelBuffer?,
        planeHistory: [simd_float4]
    ) -> (ready: Bool, score: Float, hint: String, depthOK: Bool, planeStableOK: Bool) {

        let depthOK = (depth != nil)

        var planeStableOK = false
        if planeHistory.count > 6 {
            let normals: [SIMD3<Float>] = planeHistory.map { SIMD3($0.x, $0.y, $0.z) }
            let avg: SIMD3<Float> = normals.map { $0 }.reduce(SIMD3<Float>(0,0,0), +) / Float(normals.count)
            let varN: Float = normals.map { simd_length($0 - avg) }.reduce(0 as Float, +) / Float(normals.count)

            let dVals: [Float] = planeHistory.map { $0.w }
            let dAvg: Float = dVals.reduce(0 as Float, +) / Float(dVals.count)
            let varD: Float = dVals.map { abs($0 - dAvg) }.reduce(0 as Float, +) / Float(dVals.count)

            // non-LiDAR: looser thresholds for stability
            planeStableOK = (varN < 0.06 && varD < 0.02)
        }

        let parts = [depthOK, planeStableOK].map { $0 ? 1 : 0 }
        let score = Float(parts.reduce(0, +)) / 2.0
        let ready = score > 0.85

        let hint: String
        if ready {
            hint = "Hold still… capturing"
        } else if !depthOK {
            hint = "Move closer / add light"
        } else if !planeStableOK {
            hint = "Move slightly left/right"
        } else {
            hint = "Almost there…"
        }

        return (ready, score, hint, depthOK, planeStableOK)
    }

    // MARK: - Overlay generation (segmentation or saliency)
    private func generateOverlayImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        if let det = detectionRequest {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
            do {
                try handler.perform([det])
                logDetectionResultTypesIfNeeded(det.results)
                if let objs = det.results as? [VNRecognizedObjectObservation], !objs.isEmpty {
                    return makeOverlayFromDetections(objs: objs, sourceSize: pixelBufferSize(pixelBuffer))
                }
            } catch {
                AppLog.error(AppLog.scanner, "[DualCam] Overlay detection failed, falling back to saliency: \(error.localizedDescription)")
            }
        }
        // Saliency fallback (attention-based first, then objectness-based)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        do {
            // 1) Attention-based saliency
            let attention = VNGenerateAttentionBasedSaliencyImageRequest()
            try handler.perform([attention])
            if let obs = attention.results?.first as? VNSaliencyImageObservation,
               let boxes = obs.salientObjects, !boxes.isEmpty {
                return makeOverlayFromBoxes(boxes: boxes, sourceSize: pixelBufferSize(pixelBuffer))
            }
            // 2) Objectness-based saliency fallback
            let objectness = VNGenerateObjectnessBasedSaliencyImageRequest()
            try handler.perform([objectness])
            if let obs2 = objectness.results?.first as? VNSaliencyImageObservation,
               let boxes2 = obs2.salientObjects, !boxes2.isEmpty {
                return makeOverlayFromBoxes(boxes: boxes2, sourceSize: pixelBufferSize(pixelBuffer))
            }
        } catch {
            AppLog.error(AppLog.scanner, "[DualCam] Saliency overlay generation failed: \(error.localizedDescription)")
        }
        return nil
    }

    private func pixelBufferSize(_ pb: CVPixelBuffer) -> CGSize {
        return CGSize(width: CVPixelBufferGetWidth(pb), height: CVPixelBufferGetHeight(pb))
    }

    private func makeColoredOverlay(fromMask mask: CVPixelBuffer) -> UIImage? {
        // Convert grayscale mask (0..1) to green RGBA with alpha scaled by intensity
        let ciMask = CIImage(cvPixelBuffer: mask)
        // Normalize and tint to green with alpha
        let green = CIColor(red: 0, green: 1, blue: 0, alpha: 1)
        let transparent = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        let colored = ciMask.applyingFilter("CIFalseColor", parameters: [
            "inputColor0": transparent, // low
            "inputColor1": green        // high
        ])
        // Slight blur to soften edges
        let blurred = colored.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.0])
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cg = context.createCGImage(blurred, from: blurred.extent) else { return nil }
        // Orient upright portrait
        return UIImage(cgImage: cg, scale: 1.0, orientation: .right)
    }
    
    private func makeOverlayFromBoxes(boxes: [VNRectangleObservation], sourceSize: CGSize) -> UIImage? {
        let size = sourceSize
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        ctx.setFillColor(UIColor.clear.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        ctx.setStrokeColor(UIColor(red: 0.310, green: 0.475, blue: 0.259, alpha: 0.9).cgColor)
        ctx.setLineWidth(2.0)
        for box in boxes {
            // VN boxes are normalized with origin at bottom-left; convert
            let w = CGFloat(box.boundingBox.width) * size.width
            let h = CGFloat(box.boundingBox.height) * size.height
            let x = CGFloat(box.boundingBox.origin.x) * size.width
            let yFromBottom = CGFloat(box.boundingBox.origin.y) * size.height
            let y = size.height - yFromBottom - h
            let rect = CGRect(x: x, y: y, width: w, height: h)
            ctx.stroke(rect)
        }
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img.map { UIImage(cgImage: $0.cgImage!, scale: 1.0, orientation: .up) }
    }

    private func makeOverlayFromDetections(objs: [VNRecognizedObjectObservation], sourceSize: CGSize) -> UIImage? {
        let size = sourceSize
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        // Clear background
        ctx.setFillColor(UIColor.clear.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))

        // Badge style
        let font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        let textColor = UIColor.white
        let padH: CGFloat = 10
        let padV: CGFloat = 6
        let corner: CGFloat = 10
        let iconSize: CGFloat = 18

        for o in objs {
            guard let top = o.labels.first else { continue }
            let labelText = "\(top.identifier) \(Int(top.confidence * 100))%"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]
            let textSize = (labelText as NSString).size(withAttributes: attrs)

            // Compute detection rect (normalized -> pixel coordinates)
            let w = CGFloat(o.boundingBox.width) * size.width
            let h = CGFloat(o.boundingBox.height) * size.height
            let x = CGFloat(o.boundingBox.origin.x) * size.width
            let yFromBottom = CGFloat(o.boundingBox.origin.y) * size.height
            let y = size.height - yFromBottom - h
            let rect = CGRect(x: x, y: y, width: w, height: h)

            // Badge rect anchored to top-left of detection rect
            let badgeW = iconSize + 8 + textSize.width + 2*padH
            let badgeH = max(iconSize, textSize.height) + 2*padV
            var badgeX = rect.minX
            var badgeY = rect.minY - badgeH - 4
            if badgeY < 0 { badgeY = rect.minY + 4 } // if not enough space above, place inside
            if badgeX + badgeW > size.width { badgeX = max(0, size.width - badgeW - 4) }
            let badgeRect = CGRect(x: badgeX, y: badgeY, width: badgeW, height: badgeH)

            // Draw badge background
            let bgPath = UIBezierPath(roundedRect: badgeRect, cornerRadius: corner)
            ctx.setFillColor(UIColor.black.withAlphaComponent(0.6).cgColor)
            ctx.addPath(bgPath.cgPath)
            ctx.fillPath()

            // Draw icon
            let iconX = badgeRect.minX + padH
            let iconY = badgeRect.minY + (badgeH - iconSize)/2
            if let icon = IconMapper.shared.icon(for: top.identifier)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                icon.draw(in: CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize))
            }

            // Draw text
            let textX = iconX + iconSize + 8
            let textY = badgeRect.minY + (badgeH - textSize.height)/2
            (labelText as NSString).draw(at: CGPoint(x: textX, y: textY), withAttributes: attrs)
        }

        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img.map { UIImage(cgImage: $0.cgImage!, scale: 1.0, orientation: .up) }
    }

    // MARK: Plane fit
    private static func estimatePlane(depth: CVPixelBuffer, intrinsics: simd_float3x3) -> simd_float4? {
        CVPixelBufferLockBaseAddress(depth, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depth, .readOnly) }
        let w = CVPixelBufferGetWidth(depth)
        let h = CVPixelBufferGetHeight(depth)
        guard let ptr = CVPixelBufferGetBaseAddress(depth)?.assumingMemoryBound(to: Float32.self) else { return nil }
        let fx = intrinsics.columns.0.x
        let fy = intrinsics.columns.1.y
        let cx = intrinsics.columns.2.x
        let cy = intrinsics.columns.2.y

        var pts: [SIMD3<Float>] = []
        let step = max(2, min(w, h) / 160)
        var yy = 0
        while yy < h {
            var xx = 0
            while xx < w {
                let z = ptr[yy*w+xx]
                if z.isFinite && z > 0 {
                    let Xc = (Float(xx) - cx) * z / fx
                    let Yc = (Float(yy) - cy) * z / fy
                    pts.append(SIMD3<Float>(Xc, Yc, z))
                }
                xx += step
            }
            yy += step
        }
        guard pts.count > 50 else { return nil }

        // Least squares plane fit to ax+by+cz+d=0
        var A: simd_float3x3 = .init(rows: [
            SIMD3<Float>(0,0,0),
            SIMD3<Float>(0,0,0),
            SIMD3<Float>(0,0,0)
        ])
        var b = SIMD3<Float>(0,0,0)

        for p in pts {
            A += simd_float3x3(rows: [
                SIMD3<Float>(p.x*p.x, p.x*p.y, p.x*p.z),
                SIMD3<Float>(p.y*p.x, p.y*p.y, p.y*p.z),
                SIMD3<Float>(p.z*p.x, p.z*p.y, p.z*p.z)
            ])
            b += SIMD3<Float>(-p.x, -p.y, -p.z)
        }
        let n = A.inverse * b
        let normal = simd_normalize(SIMD3<Float>(n.x, n.y, n.z))
        let sum3: SIMD3<Float> = pts.reduce(SIMD3<Float>(0,0,0), +)
        let mean = sum3 / Float(pts.count)
        let d = -simd_dot(normal, mean)
        return simd_float4(normal.x, normal.y, normal.z, d)
    }

    // MARK: Volume integration
    private static func integrateVolume(depth: CVPixelBuffer?, mask: CVPixelBuffer?, intrinsics: simd_float3x3, plane: simd_float4?) -> Float {
        guard let depth = depth, let plane = plane else { return 0 }
        CVPixelBufferLockBaseAddress(depth, .readOnly)
        if let m = mask { CVPixelBufferLockBaseAddress(m, .readOnly) }
        defer {
            CVPixelBufferUnlockBaseAddress(depth, .readOnly)
            if let m = mask { CVPixelBufferUnlockBaseAddress(m, .readOnly) }
        }

        let w = CVPixelBufferGetWidth(depth)
        let h = CVPixelBufferGetHeight(depth)
        guard let dptr = CVPixelBufferGetBaseAddress(depth)?.assumingMemoryBound(to: Float32.self) else { return 0 }

        var mw = 0, mh = 0
        var mptr: UnsafeMutablePointer<UInt8>? = nil
        if let mask = mask {
            mw = CVPixelBufferGetWidth(mask); mh = CVPixelBufferGetHeight(mask)
            mptr = CVPixelBufferGetBaseAddress(mask)?.assumingMemoryBound(to: UInt8.self)
        }

        let fx = intrinsics.columns.0.x
        let fy = intrinsics.columns.1.y
        let cx = intrinsics.columns.2.x
        let cy = intrinsics.columns.2.y
        let n = SIMD3<Float>(plane.x, plane.y, plane.z)
        let d = plane.w
        let sx = mw > 0 ? Float(mw) / Float(w) : 1
        let sy = mh > 0 ? Float(mh) / Float(h) : 1

        var volM3: Double = 0
        var yy = 0
        while yy < h {
            var xx = 0
            while xx < w {
                let z = dptr[yy*w+xx]
                if z.isFinite && z > 0 {
                    if let mp = mptr {
                        let mx = min(max(Int(Float(xx)*sx),0), mw-1)
                        let my = min(max(Int(Float(yy)*sy),0), mh-1)
                        if mp[my*mw+mx] <= 127 { xx += 1; continue }
                    }
                    let Xc = (Float(xx) - cx) * z / fx
                    let Yc = (Float(yy) - cy) * z / fy
                    let pw = SIMD3<Float>(Xc, Yc, z)
                    let signed = simd_dot(n, pw) + d
                    if signed > 0 {
                        let height = Double(signed / simd_length(n))
                        let dA = Double((z * z) / (fx * fy))
                        volM3 += height * dA
                    }
                }
                xx += 1
            }
            yy += 1
        }
        return Float(volM3 * 1_000_000.0) // m^3 -> ml
    }

    // MARK: - Monocular depth fusion helpers
    private static func fuseDepth(current: CVPixelBuffer, previous: CVPixelBuffer?) -> CVPixelBuffer? {
        let w = CVPixelBufferGetWidth(current)
        let h = CVPixelBufferGetHeight(current)
        var outPB: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_DepthFloat32, nil, &outPB)
        guard status == kCVReturnSuccess, let dst = outPB else { return nil }

        CVPixelBufferLockBaseAddress(current, .readOnly)
        CVPixelBufferLockBaseAddress(dst, [])
        defer {
            CVPixelBufferUnlockBaseAddress(dst, [])
            CVPixelBufferUnlockBaseAddress(current, .readOnly)
        }
        guard let cptr = CVPixelBufferGetBaseAddress(current)?.assumingMemoryBound(to: Float32.self),
              let dptr = CVPixelBufferGetBaseAddress(dst)?.assumingMemoryBound(to: Float32.self) else { return nil }

        if let prev = previous,
           CVPixelBufferGetWidth(prev) == w,
           CVPixelBufferGetHeight(prev) == h {
            CVPixelBufferLockBaseAddress(prev, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(prev, .readOnly) }
            if let pptr = CVPixelBufferGetBaseAddress(prev)?.assumingMemoryBound(to: Float32.self) {
                let alpha: Float = 0.6 // current weight
                let beta: Float = 1.0 - alpha
                let count = w * h
                var i = 0
                while i < count {
                    let c = cptr[i]
                    let p = pptr[i]
                    if c.isFinite && c > 0 {
                        if p.isFinite && p > 0 {
                            dptr[i] = alpha * c + beta * p
                        } else {
                            dptr[i] = c
                        }
                    } else {
                        dptr[i] = p.isFinite && p > 0 ? p : 0
                    }
                    i += 1
                }
                return dst
            }
        }
        // No previous or mismatched size — just copy current
        let count = w * h
        var i = 0
        while i < count { dptr[i] = cptr[i]; i += 1 }
        return dst
    }

    private func isDepthFresh(for videoTimestamp: CMTime, toleranceSec: Double = 0.15) -> Bool {
        guard lastDepthTimestamp.isValid, videoTimestamp.isValid else { return false }
        let dt = CMTimeSubtract(videoTimestamp, lastDepthTimestamp)
        return abs(CMTimeGetSeconds(dt)) <= toleranceSec
    }
}

// MARK: - Density & Nutrition (local copies so this file compiles standalone)
// Density/Nutrition lookups centralized in Models/NutritionConstants.swift

// MARK: - Support Views
final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    var session: AVCaptureSession? {
        get { videoPreviewLayer.session }
        set { videoPreviewLayer.session = newValue }
    }
    var videoGravity: AVLayerVideoGravity {
        get { videoPreviewLayer.videoGravity }
        set { videoPreviewLayer.videoGravity = newValue }
    }
}

private final class HUD: UIView {
    private let status = UILabel()
    private let bar = UIProgressView(progressViewStyle: .bar)
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        status.textColor = .white
        status.numberOfLines = 2
        status.font = .systemFont(ofSize: 15, weight: .semibold)
        addSubview(status)
        addSubview(bar)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() {
        super.layoutSubviews()
        status.frame = CGRect(x: 16, y: safeAreaInsets.top+8, width: bounds.width-32, height: 44)
        bar.frame = CGRect(x: 16, y: status.frame.maxY+6, width: bounds.width-32, height: 6)
    }
    func setStatus(_ t: String) { DispatchQueue.main.async { self.status.text = t } }
    func setProgress(_ p: Float, hint: String) {
        DispatchQueue.main.async {
            self.bar.setProgress(min(max(p,0),1), animated: true)
            self.status.text = p > 0.98 ? hint : "\(Int(p*100))% – \(hint)"
        }
    }
}

// MARK: - Cropping Helpers
private extension DualCameraPlateScannerViewController {
    func cropToRing(_ image: UIImage) -> UIImage {
        let src = image.fixedOrientation()
        guard let cg = src.cgImage else { return image }
        let imgW = CGFloat(cg.width)
        let imgH = CGFloat(cg.height)
        // Obtain ring geometry (on main thread)
        let (ringCenter, ringSize) = currentRingGeometry()
        if ringSize <= 2 { // fallback normalized square
            return cropFallback(src, imgW: imgW, imgH: imgH)
        }
        let viewSize = previewSize
        guard viewSize.width > 0, viewSize.height > 0 else { return src }
        // Aspect-fill scaling from camera image (imgW x imgH) into preview bounds
        let scale = max(viewSize.width / imgW, viewSize.height / imgH)
        let displayedW = imgW * scale
        let displayedH = imgH * scale
        let offsetX = (viewSize.width - displayedW) * 0.5
        let offsetY = (viewSize.height - displayedH) * 0.5
        // Expand crop to be larger than the visible ring to include full plate
        let padFactor: CGFloat = 1.35
        let w = ringSize * padFactor
        let ringRectView = CGRect(x: ringCenter.x - w/2,
                                  y: ringCenter.y - w/2,
                                  width: w,
                                  height: w)
        let ringRectImage = CGRect(
            x: (ringRectView.origin.x - offsetX) / scale,
            y: (ringRectView.origin.y - offsetY) / scale,
            width: ringRectView.size.width / scale,
            height: ringRectView.size.height / scale
        ).integral
        let imageBounds = CGRect(x: 0, y: 0, width: imgW, height: imgH)
        guard let cropped = cg.cropping(to: ringRectImage.intersection(imageBounds)) else { return src }
        return UIImage(cgImage: cropped, scale: src.scale, orientation: .up)
    }

    func cropFallback(_ src: UIImage, imgW: CGFloat, imgH: CGFloat) -> UIImage {
        guard let cg = src.cgImage else { return src }
        let r = fallbackCropNormalized
        let rect = CGRect(x: r.origin.x * imgW,
                          y: r.origin.y * imgH,
                          width: r.size.width * imgW,
                          height: r.size.height * imgH).integral
        guard let cropped = cg.cropping(to: rect.intersection(CGRect(x:0,y:0,width:imgW,height:imgH))) else { return src }
        return UIImage(cgImage: cropped, scale: src.scale, orientation: .up)
    }
    
    func edgeDensity(in image: UIImage) -> Float {
        guard let cg = image.cgImage else { return 0 }
        let ci = CIImage(cgImage: cg)
            .applyingFilter("CILanczosScaleTransform", parameters: ["inputScale": 0.5])
            .applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 1.0])
        let ctx = CIContext(options: [.useSoftwareRenderer: false])
        guard let out = ctx.createCGImage(ci, from: ci.extent), let provider = out.dataProvider, let raw = provider.data else { return 0 }
        let bytesPerPixel = 4
        let width = out.width
        let height = out.height
        let bytesPerRow = out.bytesPerRow
        guard let basePtr = CFDataGetBytePtr(raw) else { return 0 }
        var countNonBlack = 0
        var total = 0
        let stepY = max(1, height / 80)
        let stepX = max(1, width / 80)
        var y = 0
        while y < height {
            var x = 0
            while x < width {
                let idx = y * bytesPerRow + x * bytesPerPixel
                let r = basePtr[idx]
                let g = basePtr[idx+1]
                let b = basePtr[idx+2]
                if r > 8 || g > 8 || b > 8 { countNonBlack += 1 }
                total += 1
                x += stepX
            }
            y += stepY
        }
        return total > 0 ? Float(countNonBlack) / Float(total) : 0
    }
}

// MARK: - UIImage Extensions
private extension UIImage {
    convenience init?(pixelBuffer: CVPixelBuffer, orientation: UIImage.Orientation = .up) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        self.init(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
    
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }
}
