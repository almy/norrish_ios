// ARPlateScannerViewController.swift
// Core ARKit scanner (LiDAR/sceneDepth) with automatic fallback to DualCameraPlateScannerViewController
//
// Expects:
//  - ARPlateScanNutrition struct (in ARPlateScanNutrition.swift)
//  - Optional CoreML models: FoodSegmentation.mlmodel, FoodClassifier.mlmodel
//  - DualCameraPlateScannerViewController.swift present in target (non‑LiDAR fallback)
//  - Info.plist: NSCameraUsageDescription
//
// Usage: Presented via ARPlateScannerView (SwiftUI wrapper)

import UIKit
import ARKit
import Vision
import CoreML
import Foundation

public final class ARPlateScannerViewController: UIViewController, ARSessionDelegate {
    // Public callbacks bridged by ARPlateScannerView
    public var onResult: ((ARPlateScanNutrition, UIImage) -> Void)?
    public var onCancel: (() -> Void)?
    
    // Tuning (top of ARPlateScannerViewController)
    private var minScanFrames = 25
    private var requiredStableFrames = 18
    private var movementThreshold: Float = 0.004  // meters

    public var autoSendToOpenAI = false                  // default off to avoid double-send
    public var onAIText: ((String) -> Void)?             // bubble AI text up if you want

    // UI
    private let sceneView = ARSCNView(frame: .zero)
    private let hud = HUD()
    private let closeBtn = UIButton(type: .close)
    
    // Segmentation/saliency overlay
    private let segmentationOverlayView = UIImageView()
    private let overlayQueue = DispatchQueue(label: "ar.segmentation.overlay")
    private var lastOverlayTime: CFTimeInterval = 0
    private var overlayBusy = false

    // Vision
    private var segmentationRequest: VNCoreMLRequest?
    private var classificationRequest: VNCoreMLRequest?
    private let visionQueue = DispatchQueue(label: "food.vision.queue")

    // Plane/history
    private var currentPlatePlane: simd_float4? // ax+by+cz+d=0 in world
    private var planeHistory: [simd_float4] = []
    private var camHistory: [simd_float4x4] = []

    // Control
    private var didEmit = false

    // Normalized center-square crop (tweak as needed). (x,y,w,h) in 0..1 coordinates of displayed preview
    private let cropNormalized = CGRect(x: 0.15, y: 0.15, width: 0.70, height: 0.70)
    // Overlay view draws the guidance circle/square
    private let cropOverlay = PlateCropOverlay()

    // MARK: Lifecycle
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        setupVision()
        startSession()
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sceneView.frame = view.bounds
        segmentationOverlayView.frame = view.bounds
        hud.frame = view.bounds
        cropOverlay.frame = view.bounds
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    // MARK: Setup
    private func setupUI() {
        sceneView.automaticallyUpdatesLighting = true
        sceneView.session.delegate = self
        sceneView.scene = SCNScene()
        view.addSubview(sceneView)
        
        // Add segmentation overlay above scene view
        segmentationOverlayView.backgroundColor = .clear
        segmentationOverlayView.contentMode = .scaleAspectFill
        segmentationOverlayView.isUserInteractionEnabled = false
        segmentationOverlayView.alpha = 0.0
        view.addSubview(segmentationOverlayView)
        
        view.addSubview(hud)
        // Insert overlay above scene, below buttons
        cropOverlay.isUserInteractionEnabled = false
        cropOverlay.backgroundColor = .clear
        view.addSubview(cropOverlay)

        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeBtn)
        NSLayoutConstraint.activate([
            closeBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12)
        ])

        hud.setStatus("Initializing…")
    }

    @objc private func closeTapped() {
        if !didEmit { onCancel?() }
        dismiss(animated: true)
    }

    private func setupVision() {
        // TODO: Uncomment when FoodSegmentation and FoodClassifier models are added
        /*
        if let segModel = try? VNCoreMLModel(for: FoodSegmentation().model) {
            let req = VNCoreMLRequest(model: segModel)
            req.imageCropAndScaleOption = .scaleFill
            segmentationRequest = req
        }
        if let clsModel = try? VNCoreMLModel(for: FoodClassifier().model) {
            let req = VNCoreMLRequest(model: clsModel)
            req.imageCropAndScaleOption = .centerCrop
            classificationRequest = req
        }
        */
    }

    // MARK: Session
    private func startSession() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic

        // Check if AR World Tracking is supported at all
        guard ARWorldTrackingConfiguration.isSupported else {
            print("ARWorldTracking not supported - presenting fallback")
            presentFallbackScanner()
            return
        }

        // If sceneDepth is available, run LiDAR path; otherwise present dual‑camera fallback
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            print("LiDAR device detected - using scene depth")
            config.frameSemantics.insert(.sceneDepth)
            sceneView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
            hud.setStatus("Move slowly around the plate…")
        } else {
            print("No sceneDepth — presenting DualCameraPlateScannerViewController")
            DispatchQueue.main.async { [weak self] in
                self?.presentFallbackScanner()
            }
            return
        }
    }
    
    private func presentFallbackScanner() {
        let fallback = DualCameraPlateScannerViewController()
        fallback.onResult = { [weak self] result, image in
            guard let self else { return }
            self.didEmit = true
            self.onResult?(result, image)
            self.dismiss(animated: true)
        }
        fallback.onCancel = { [weak self] in
            self?.onCancel?()
            self?.dismiss(animated: true)
        }
        fallback.modalPresentationStyle = .fullScreen
        present(fallback, animated: true)
    }
    
    private func addTapGestureForNonLiDAR() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(screenTapped))
        sceneView.addGestureRecognizer(tapGesture)
    }
    
    @objc private func screenTapped() {
        guard !didEmit else { return }
        guard let frame = sceneView.session.currentFrame else { return }
        didEmit = true
        sceneView.session.delegate = nil
        hud.setStatus("Processing...")
        let fullImage = UIImage(pixelBuffer: frame.capturedImage, orientation: .right)
        let cropped = cropToOverlay(fullImage)
        let result = ARPlateScanNutrition(
            label: "food",
            confidence: 0.7,
            volumeML: 150.0,
            massG: 150.0,
            calories: 200,
            protein: 15,
            carbs: 25,
            fat: 8
        )
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onResult?(result, cropped)
            self.dismiss(animated: true)
        }
    }

    // MARK: ARSessionDelegate
    public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard !didEmit else { return }

        // Throttled pre-detection overlay (~5 FPS)
        let nowOverlay = CACurrentMediaTime()
        if !overlayBusy && (nowOverlay - lastOverlayTime) > 0.20 {
            overlayBusy = true
            lastOverlayTime = nowOverlay
            let pb = frame.capturedImage
            overlayQueue.async { [weak self] in
                guard let self else { return }
                if let overlayImage = self.generateOverlayImage(from: pb) {
                    DispatchQueue.main.async {
                        self.segmentationOverlayView.image = overlayImage
                        self.segmentationOverlayView.alpha = 0.55
                    }
                }
                self.overlayBusy = false
            }
        }

        // Gather anchors/camera history
        camHistory.append(frame.camera.transform)
        if camHistory.count > 30 { camHistory.removeFirst(camHistory.count - 30) }

        if let plane = bestHorizontalPlane(from: frame) {
            currentPlatePlane = plane
            planeHistory.append(plane)
            if planeHistory.count > 30 { planeHistory.removeFirst(planeHistory.count - 30) }
        }

        // Only require depth for LiDAR devices
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            guard let depth = frame.sceneDepth else {
                hud.setStatus("Move closer / add light for depth…")
                return
            }
            
            // Readiness gates for LiDAR devices
            let ready = readinessScore(frame: frame)
            hud.setProgress(ready.score, hint: ready.hint)
            if ready.ready { captureAndFinish(from: frame, depth: depth) }
        }
    }
    
    public func session(_ session: ARSession, didFailWithError error: Error) {
        print("AR Session failed with error: \(error)")
        hud.setStatus("AR Error: \(error.localizedDescription)")
        
        // Try to recover or fall back
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.presentFallbackScanner()
        }
    }
    
    public func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let state = camera.trackingState
        print("AR Tracking state changed: \(state)")
        
        switch state {
        case .normal:
            // Camera is working properly
            break
        case .limited(let reason):
            switch reason {
            case .excessiveMotion:
                hud.setStatus("Move device more slowly")
            case .insufficientFeatures:
                hud.setStatus("Point camera at a textured surface")
            case .initializing:
                hud.setStatus("Initializing AR...")
            case .relocalizing:
                hud.setStatus("Tracking lost, relocalizing...")
            @unknown default:
                hud.setStatus("Limited tracking: \(reason)")
            }
        case .notAvailable:
            print("AR tracking not available")
            hud.setStatus("AR not available")
            presentFallbackScanner()
        }
    }
    
    public func sessionWasInterrupted(_ session: ARSession) {
        print("AR Session was interrupted")
        hud.setStatus("Session interrupted")
    }
    
    public func sessionInterruptionEnded(_ session: ARSession) {
        print("AR Session interruption ended")
        hud.setStatus("Resuming AR...")
        // Restart the session
        session.run(session.configuration!, options: [.resetTracking, .removeExistingAnchors])
    }
    
    private func bestHorizontalPlane(from frame: ARFrame) -> simd_float4? {
        let planes = frame.anchors.compactMap { $0 as? ARPlaneAnchor }.filter { $0.alignment == .horizontal }
        guard let camPos = simd_float3?(simd_make_float3(frame.camera.transform.columns.3.x, frame.camera.transform.columns.3.y, frame.camera.transform.columns.3.z)) else { return nil }
        var best: (p: simd_float4, d: Float)?
        for a in planes {
            let n = simd_normalize(simd_float3(a.transform.columns.1.x, a.transform.columns.1.y, a.transform.columns.1.z))
            let pt = simd_float3(a.transform.columns.3.x, a.transform.columns.3.y, a.transform.columns.3.z)
            let d = -simd_dot(n, pt)
            let plane = simd_float4(n.x, n.y, n.z, d)
            let dist = abs(simd_dot(n, camPos) + d) / simd_length(n)
            if best == nil || dist < best!.d { best = (plane, dist) }
        }
        return best?.p
    }

    private func readinessScore(frame: ARFrame) -> (ready: Bool, score: Float, hint: String) {
        let mappingOK = (frame.worldMappingStatus == .extending || frame.worldMappingStatus == .mapped)
        var planeStableOK = false
        if planeHistory.count > 10 {
            let normals = planeHistory.map { simd_float3($0.x, $0.y, $0.z) }
            let avgN = normals.reduce(simd_float3(0,0,0), +) / Float(normals.count)
            let nVar = normals.map { simd_length($0 - avgN) }.reduce(0,+) / Float(normals.count)
            let dVals = planeHistory.map { $0.w }
            let dAvg = dVals.reduce(0,+) / Float(dVals.count)
            let dVar = dVals.map { abs($0 - dAvg) }.reduce(0,+) / Float(dVals.count)
            planeStableOK = (nVar < 0.02 && dVar < 0.003)
        }
        var parallaxOK = false
        if let first = camHistory.first, let last = camHistory.last {
            let t0 = simd_float3(first.columns.3.x, first.columns.3.y, first.columns.3.z)
            let t1 = simd_float3(last.columns.3.x, last.columns.3.y, last.columns.3.z)
            let baseline = simd_length(t1 - t0)
            
            // Extract 3x3 rotation matrices from 4x4 transforms
            let R0 = simd_float3x3(
                simd_float3(first.columns.0.x, first.columns.0.y, first.columns.0.z),
                simd_float3(first.columns.1.x, first.columns.1.y, first.columns.1.z),
                simd_float3(first.columns.2.x, first.columns.2.y, first.columns.2.z)
            )
            let R1 = simd_float3x3(
                simd_float3(last.columns.0.x, last.columns.0.y, last.columns.0.z),
                simd_float3(last.columns.1.x, last.columns.1.y, last.columns.1.z),
                simd_float3(last.columns.2.x, last.columns.2.y, last.columns.2.z)
            )
            let dR = R1 * R0.transpose
            
            // Calculate rotation angle (simplified)
            let trace = dR.columns.0.x + dR.columns.1.y + dR.columns.2.z
            let angle = acos(max(-1, min(1, (trace - 1) / 2))) * 180 / Float.pi
            parallaxOK = (baseline > 0.07 || angle > 8)
        }
        let depthOK = (frame.sceneDepth != nil)
        let parts = [mappingOK, planeStableOK, parallaxOK, depthOK]
        let score = Float(parts.map{ $0 ? 1:0 }.reduce(0,+)) / 4.0
        let ready = (score > 0.95)
        let hint = ready ? "Hold still… capturing" : guidanceHint(mapping: mappingOK, plane: planeStableOK, parallax: parallaxOK, depth: depthOK)
        return (ready, score, hint)
    }

    private func guidanceHint(mapping: Bool, plane: Bool, parallax: Bool, depth: Bool) -> String {
        if !mapping { return "Keep moving slowly…" }
        if !plane { return "Center the plate and move slightly…" }
        if !parallax { return "Step left/right a little…" }
        if !depth { return "Move closer or add light…" }
        return "Almost there…"
    }

    // MARK: - Overlay generation (segmentation or saliency)
    private func generateOverlayImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        // Prefer segmentationRequest if available; else fall back to saliency
        if let seg = segmentationRequest {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
            do {
                try handler.perform([seg])
                if let mask = (seg.results?.first as? VNPixelBufferObservation)?.pixelBuffer {
                    return makeColoredOverlay(fromMask: mask)
                }
            } catch { /* ignore and fall through */ }
        }
        let saliency = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        do {
            try handler.perform([saliency])
            if let obs = saliency.results?.first as? VNSaliencyImageObservation,
               let boxes = obs.salientObjects, !boxes.isEmpty {
                return makeOverlayFromBoxes(boxes: boxes, sourceSize: pixelBufferSize(pixelBuffer))
            }
        } catch { /* ignore */ }
        return nil
    }

    private func pixelBufferSize(_ pb: CVPixelBuffer) -> CGSize {
        return CGSize(width: CVPixelBufferGetWidth(pb), height: CVPixelBufferGetHeight(pb))
    }

    private func makeColoredOverlay(fromMask mask: CVPixelBuffer) -> UIImage? {
        let ciMask = CIImage(cvPixelBuffer: mask)
        let green = CIColor(red: 0, green: 1, blue: 0, alpha: 1)
        let transparent = CIColor(red: 0, green: 0, blue: 0, alpha: 0)
        let colored = ciMask.applyingFilter("CIFalseColor", parameters: [
            "inputColor0": transparent,
            "inputColor1": green
        ])
        let blurred = colored.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.0])
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cg = context.createCGImage(blurred, from: blurred.extent) else { return nil }
        return UIImage(cgImage: cg, scale: 1.0, orientation: .right)
    }

    private func makeOverlayFromBoxes(boxes: [VNRectangleObservation], sourceSize: CGSize) -> UIImage? {
        let size = sourceSize
        UIGraphicsBeginImageContextWithOptions(size, false, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return nil }
        ctx.setFillColor(UIColor.clear.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        ctx.setFillColor(UIColor.green.withAlphaComponent(0.9).cgColor)
        for box in boxes {
            let w = CGFloat(box.boundingBox.width) * size.width
            let h = CGFloat(box.boundingBox.height) * size.height
            let x = CGFloat(box.boundingBox.origin.x) * size.width
            let yFromBottom = CGFloat(box.boundingBox.origin.y) * size.height
            let y = size.height - yFromBottom - h
            ctx.fill(CGRect(x: x, y: y, width: w, height: h))
        }
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let out = img, let cg = out.cgImage else { return nil }
        return UIImage(cgImage: cg, scale: 1.0, orientation: .right)
    }


    private func captureAndFinish(from frame: ARFrame, depth: ARDepthData) {
        guard !didEmit else { return }
        didEmit = true
        sceneView.session.delegate = nil
        let fullImage = UIImage(pixelBuffer: frame.capturedImage, orientation: .right)
        let (mask, label, conf) = runVision(frame: frame)
        guard let plane = currentPlatePlane else { finishWithFallback(image: cropToOverlay(fullImage)); return }
        let volumeML = integrateVolume(depth: depth, mask: mask, intrinsics: frame.camera.intrinsics, resolution: frame.camera.imageResolution, planeWorld: plane, cameraTransform: frame.camera.transform)
        print("🟢 [LiDAR] volumeML=\(String(format: "%.1f", volumeML))")
        let density = DensityDB.density(for: label)
        let mass = max(0, volumeML * density)
        let nut = NutritionDB.estimate(for: label, grams: mass)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let result = ARPlateScanNutrition(
            label: label,
            confidence: conf,
            volumeML: volumeML,
            massG: mass,
            calories: Int(round(nut.caloriesKCal)),
            protein: Int(round(nut.proteinG)),
            carbs: Int(round(nut.carbsG)),
            fat: Int(round(nut.fatG))
        )
        let cropped = cropToOverlay(fullImage)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onResult?(result, cropped)
            // Post a notification so the prompt system can react globally
            NotificationCenter.default.post(name: .plateScanCompleted, object: nil, userInfo: [
                "result": result,
                "image": cropped
            ])
            self.dismiss(animated: true)
        }
    }

    private func finishWithFallback(image: UIImage) {
        let cropped = cropToOverlay(image)
        let result = ARPlateScanNutrition(label: "food", confidence: 0.5, volumeML: 0, massG: 0, calories: 0, protein: 0, carbs: 0, fat: 0)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onResult?(result, cropped)
            NotificationCenter.default.post(name: .plateScanCompleted, object: nil, userInfo: [
                "result": result,
                "image": cropped
            ])
            self.dismiss(animated: true)
        }
    }

    private func runVision(frame: ARFrame) -> (mask: CVPixelBuffer?, label: String, conf: Float) {
        guard segmentationRequest != nil || classificationRequest != nil else {
            return (nil, "food", 0.5)
        }
        let handler = VNImageRequestHandler(cvPixelBuffer: frame.capturedImage, orientation: .right, options: [:])
        var mask: CVPixelBuffer? = nil
        var label = "food"
        var conf: Float = 0.5
        do {
            if let seg = segmentationRequest { try handler.perform([seg]); mask = (seg.results?.first as? VNPixelBufferObservation)?.pixelBuffer }
            if let cls = classificationRequest { try handler.perform([cls]); if let top = cls.results?.first as? VNClassificationObservation { label = top.identifier; conf = top.confidence } }
        } catch { }
        return (mask, label, conf)
    }

    // MARK: Volume integration (sceneDepth path)
    private func integrateVolume(depth: ARDepthData, mask: CVPixelBuffer?, intrinsics: simd_float3x3, resolution: CGSize, planeWorld: simd_float4, cameraTransform: simd_float4x4) -> Float {
        let depthMap = depth.depthMap
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        if let m = mask { CVPixelBufferLockBaseAddress(m, .readOnly) }
        defer {
            CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
            if let m = mask { CVPixelBufferUnlockBaseAddress(m, .readOnly) }
        }
        let w = CVPixelBufferGetWidth(depthMap)
        let h = CVPixelBufferGetHeight(depthMap)
        guard let dptr = CVPixelBufferGetBaseAddress(depthMap)?.assumingMemoryBound(to: Float32.self) else { return 0 }

        var mw = 0, mh = 0
        var mptr: UnsafeMutablePointer<UInt8>? = nil
        if let m = mask {
            mw = CVPixelBufferGetWidth(m)
            mh = CVPixelBufferGetHeight(m)
            if let baseAddress = CVPixelBufferGetBaseAddress(m) {
                mptr = baseAddress.assumingMemoryBound(to: UInt8.self)
            }
        }

        let fx = intrinsics.columns.0.x
        let fy = intrinsics.columns.1.y
        let cx = intrinsics.columns.2.x
        let cy = intrinsics.columns.2.y

        let sx = mw > 0 ? Float(mw) / Float(w) : 1
        let sy = mh > 0 ? Float(mh) / Float(h) : 1

        let n = simd_float3(planeWorld.x, planeWorld.y, planeWorld.z)
        let d = planeWorld.w
        let camToWorld = cameraTransform

        var volM3: Double = 0
        for y in 0..<h {
            for x in 0..<w {
                let z = dptr[y*w+x]
                if !z.isFinite || z <= 0 { continue }
                if let mp = mptr { let mx = min(max(Int(Float(x)*sx),0), mw-1); let my = min(max(Int(Float(y)*sy),0), mh-1); if mp[my*mw+mx] <= 127 { continue } }
                let Xc = (Float(x) - cx) * z / fx
                let Yc = (Float(y) - cy) * z / fy
                let camP = simd_float4(Xc, Yc, z, 1)
                let wP4 = camToWorld * camP
                let wP = simd_float3(wP4.x, wP4.y, wP4.z)
                let signed = simd_dot(n, wP) + d
                if signed <= 0 { continue }
                let height = Double(signed / simd_length(n))
                let dA = Double((z * z) / (fx * fy))
                volM3 += height * dA
            }
        }
        return Float(volM3 * 1_000_000.0) // m^3 -> ml
    }
}

// MARK: - HUD
private final class HUD: UIView {
    private let status = UILabel()
    private let bar = UIProgressView(progressViewStyle: .bar)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        status.textColor = .white
        status.font = .systemFont(ofSize: 15, weight: .semibold)
        status.numberOfLines = 2
        addSubview(status)
        addSubview(bar)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        status.frame = CGRect(x: 16, y: safeAreaInsets.top + 8, width: bounds.width - 32, height: 44)
        bar.frame = CGRect(x: 16, y: status.frame.maxY + 6, width: bounds.width - 32, height: 6)
    }

    func setStatus(_ t: String) { DispatchQueue.main.async { self.status.text = t } }
    func setProgress(_ p: Float, hint: String) { DispatchQueue.main.async { self.bar.setProgress(min(max(p,0),1), animated: true); self.status.text = p > 0.98 ? hint : "\(Int(p*100))% – \(hint)" } }
}

private extension UIImage {
    convenience init(pixelBuffer: CVPixelBuffer, orientation: UIImage.Orientation) {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)!
        self.init(cgImage: cgImage, scale: 1.0, orientation: orientation)
    }
}

// MARK: - Cropping Helper & Supporting Views / Utilities (added)
private extension ARPlateScannerViewController {
    func cropToOverlay(_ image: UIImage) -> UIImage {
        // Use cropNormalized (already defined in controller) to crop center square.
        guard let cg = image.cgImage else { return image }
        let src = image.fixedOrientation()
        guard let orientedCG = src.cgImage else { return image }
        let width = CGFloat(orientedCG.width)
        let height = CGFloat(orientedCG.height)
        let rect = CGRect(x: cropNormalized.origin.x * width,
                          y: cropNormalized.origin.y * height,
                          width: cropNormalized.size.width * width,
                          height: cropNormalized.size.height * height).integral
        guard let croppedCG = orientedCG.cropping(to: rect.intersection(CGRect(x: 0, y: 0, width: width, height: height))) else { return src }
        return UIImage(cgImage: croppedCG, scale: src.scale, orientation: .up)
    }
}

private final class PlateCropOverlay: UIView {
    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setFillColor(UIColor.black.withAlphaComponent(0.35).cgColor)
        ctx.fill(rect)
        let insetX = rect.width * 0.15
        let insetY = rect.height * 0.15
        let side = min(rect.width - insetX*2, rect.height - insetY*2)
        let square = CGRect(x: (rect.width - side)/2, y: (rect.height - side)/2, width: side, height: side)
        let circlePath = UIBezierPath(ovalIn: square)
        ctx.setBlendMode(.clear)
        ctx.addPath(circlePath.cgPath)
        ctx.fillPath()
        ctx.setBlendMode(.normal)
        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.9).cgColor)
        ctx.setLineWidth(3)
        ctx.addPath(circlePath.cgPath)
        ctx.strokePath()
    }
}

private extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? self
    }
}

// Lightweight local density & nutrition lookups (only if global versions absent)
private enum DensityDB {
    static let defaults: [String: Float] = ["rice":0.85,"pasta":0.60,"chicken":1.05,"beef":1.10,"broccoli":0.40,"apple":0.80,"banana":0.94,"food":0.80]
    static func density(for label: String) -> Float { defaults[label.lowercased()] ?? defaults["food"]! }
}
private enum NutritionDB {
    private struct Entry { let kcal: Float; let protein: Float; let carbs: Float; let fat: Float }
    private static let table: [String: Entry] = [
        "rice": .init(kcal:130, protein:2.4, carbs:28, fat:0.3),
        "pasta": .init(kcal:131, protein:5, carbs:25, fat:1.1),
        "chicken": .init(kcal:165, protein:31, carbs:0, fat:3.6),
        "beef": .init(kcal:250, protein:26, carbs:0, fat:15),
        "broccoli": .init(kcal:34, protein:2.8, carbs:7, fat:0.4),
        "apple": .init(kcal:52, protein:0.3, carbs:14, fat:0.2),
        "banana": .init(kcal:89, protein:1.1, carbs:23, fat:0.3),
        "food": .init(kcal:150, protein:6, carbs:18, fat:5)
    ]
    static func estimate(for label: String, grams: Float) -> (caloriesKCal: Float, proteinG: Float, carbsG: Float, fatG: Float) {
        let e = table[label.lowercased()] ?? table["food"]!
        let f = grams / 100.0
        return (e.kcal * f, e.protein * f, e.carbs * f, e.fat * f)
    }
}

