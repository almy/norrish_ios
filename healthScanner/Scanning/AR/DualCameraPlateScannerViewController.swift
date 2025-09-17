// DualCameraPlateScannerViewController.swift — Non-LiDAR Fallback (AVCapture Video + Depth)
// Works on iPhones without LiDAR (11/12/13 non-Pro, 12/13 mini, etc.)

import UIKit
import AVFoundation
import Vision
import CoreML
import CoreImage
import simd
import SwiftUI

public final class DualCameraPlateScannerViewController: UIViewController,
    AVCaptureVideoDataOutputSampleBufferDelegate,
    AVCaptureDepthDataOutputDelegate
{
    // MARK: Public callbacks
    public var onResult: ((ARPlateScanNutrition, UIImage) -> Void)?
    public var onCancel: (() -> Void)?

    // MARK: UI
    private let preview = PreviewView()
    private let hud = HUD()
    private let closeBtn = UIButton(type: .close)

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

    // MARK: Vision (optional)
    private var segmentationRequest: VNCoreMLRequest?
    private var classificationRequest: VNCoreMLRequest?

    // Plane stability
    private var planeHistory: [simd_float4] = []

    // Control
    private var didEmit = false
    
    //Overaly
    private let hudModel = ScanHUDModel()
    private lazy var ringOverlayHost = UIHostingController(rootView: PlateProgressRingView(model: hudModel))

    // Normalized fallback crop if ring size isn't ready (x,y,w,h) in 0..1
    private let fallbackCropNormalized = CGRect(x: 0.15, y: 0.15, width: 0.70, height: 0.70)

    // Readiness fallback (when depth is unavailable): time-based progress
    private var fallbackProgress: Float = 0
    private var lastProgressTick: CFTimeInterval = CACurrentMediaTime()
    private var stableFrameCount: Int = 0
    private var hapticLevel: Int = 0 // 0: none, 1: mid, 2: near-ready

    // No local nutrition DB here; AI handles nutrition downstream

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupUI()
        addRingOverlay()
        setupVision()
        configureSession()
        session.startRunning()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    // MARK: UI
    private func setupUI() {
        preview.videoGravity = .resizeAspectFill
        view.addSubview(preview)
        view.addSubview(hud)
        preview.translatesAutoresizingMaskIntoConstraints = false
        hud.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            preview.topAnchor.constraint(equalTo: view.topAnchor),
            preview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            preview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            preview.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hud.topAnchor.constraint(equalTo: view.topAnchor),
            hud.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hud.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hud.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeBtn)
        NSLayoutConstraint.activate([
            closeBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            closeBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12)
        ])
        hud.setStatus("Move slowly around the plate… (non-LiDAR mode)")
    }
    
    //adding overlay
    private func addRingOverlay() {
        let host = ringOverlayHost
        host.view.backgroundColor = .clear
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
        // default ring position: center
        hudModel.ringCenter = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        hudModel.ringSize = min(view.bounds.width, view.bounds.height) * 0.48
    }


    @objc private func closeTapped() { onCancel?(); dismiss(animated: true) }

    // MARK: Vision
    private func setupVision() {
        // TODO: Uncomment when FoodSegmentation and FoodClassifier models are added
        /*
        if let segModel = try? VNCoreMLModel(for: FoodSegmentation().model) {
            let r = VNCoreMLRequest(model: segModel)
            r.imageCropAndScaleOption = .scaleFill
            segmentationRequest = r
        }
        if let clsModel = try? VNCoreMLModel(for: FoodClassifier().model) {
            let r = VNCoreMLRequest(model: clsModel)
            r.imageCropAndScaleOption = .centerCrop
            classificationRequest = r
        }
        */
    }

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
        } catch { /* ignore */ }

        session.commitConfiguration()
    }

    // MARK: Delegates
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !didEmit, let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Camera intrinsics (if present)
        if let att = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) as? NSData {
            latestIntrinsics = att.bytes.bindMemory(to: simd_float3x3.self, capacity: 1).pointee
        }

        // Vision (optional)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        var mask: CVPixelBuffer? = nil
        var label = "food"
        var conf: Float = 0.5
        do {
            if let seg = segmentationRequest {
                try handler.perform([seg])
                mask = (seg.results?.first as? VNPixelBufferObservation)?.pixelBuffer
            }
            if let cls = classificationRequest {
                try handler.perform([cls])
                if let top = cls.results?.first as? VNClassificationObservation {
                    label = top.identifier; conf = top.confidence
                }
            }
        } catch { /* ignore */ }

        // Plane fit from latest depth (if any)
        var plane: simd_float4? = nil
        if let d = latestDepthMap { plane = Self.estimatePlane(depth: d, intrinsics: latestIntrinsics) }
        if let p = plane {
            planeHistory.append(p)
            if planeHistory.count > 20 { planeHistory.removeFirst() }
        }

        // Readiness
        let r = readiness(depth: latestDepthMap, planeHistory: planeHistory)

        // Update ring progress; if no depth, advance a time-based fallback
        let now = CACurrentMediaTime()
        let dt = now - lastProgressTick
        lastProgressTick = now
        var ready = r.ready
        var progress = r.score
        // Advance a time-based fallback so progress completes even without perfect depth
        let ramp = Float(dt / 2.0) // ~2s to full
        fallbackProgress = min(1.0, fallbackProgress + ramp)
        if latestDepthMap != nil {
            // With depth, still allow fallback to drive to green if score is low
            progress = max(progress, min(1.0, fallbackProgress * 0.95))
        } else {
            progress = max(progress, fallbackProgress)
        }
        if progress >= 0.99 { stableFrameCount += 1 } else { stableFrameCount = 0 }
        ready = ready || (stableFrameCount >= 4)

        DispatchQueue.main.async {
            self.hudModel.progress = CGFloat(progress)
            self.hudModel.hint = "\(Int(progress*100))% – " + (ready ? "Hold still… capturing" : r.hint)
            self.hudModel.hasDepth = (self.latestDepthMap != nil)
            self.hudModel.planeStable = r.planeStableOK
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
        if Int(progress*100) % 10 == 0 { print("🔵 [DualCam] progress=\(String(format: "%.2f", progress)) ready=\(ready) depth=\(latestDepthMap != nil)") }

        guard ready else { return }

        // Finalize - build full image first
        guard let fullImage = UIImage(pixelBuffer: pixelBuffer, orientation: .right) else {
            return
        }
        let croppedImage = cropToRing(fullImage)
        let volML = Self.integrateVolume(depth: latestDepthMap, mask: mask, intrinsics: latestIntrinsics, plane: planeHistory.last)
        print("🟢 [DualCam] depth=\(latestDepthMap != nil ? "yes" : "no"), volumeML=\(String(format: "%.1f", volML))")
        // Do not estimate nutrition locally; let OpenAI handle macros downstream
        let mass: Float = 0
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
        let converted = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        latestDepthMap = converted.depthDataMap
        let w = CVPixelBufferGetWidth(latestDepthMap!)
        let h = CVPixelBufferGetHeight(latestDepthMap!)
        print("🟢 [DualCam] depth map received: \(w)x\(h)")
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
            let avg: SIMD3<Float> = normals.reduce(SIMD3<Float>(0,0,0), +) / Float(normals.count)
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
        var ringCenter = CGPoint.zero
        var ringSize: CGFloat = 0
        DispatchQueue.main.sync { // safe since captureOutput not on main
            ringCenter = hudModel.ringCenter
            ringSize = hudModel.ringSize
        }
        if ringSize <= 2 { // fallback normalized square
            return cropFallback(src, imgW: imgW, imgH: imgH)
        }
        let viewSize = preview.bounds.size
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
