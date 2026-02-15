import SwiftUI
import UIKit
import AVFoundation
import Vision

struct CameraControllerRepresentable: UIViewControllerRepresentable {
    @ObservedObject var state: LiveClassificationState
    let onCaptured: (UIImage, Float?, Float?, DepthFrameSnapshot?) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        CameraViewController(state: state, onCaptured: onCaptured, onCancel: onCancel)
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}

    final class CameraViewController: UIViewController {
        private let state: LiveClassificationState
        private let onCaptured: (UIImage, Float?, Float?, DepthFrameSnapshot?) -> Void
        private let onCancel: () -> Void

        private let session = AVCaptureSession()
        private let videoOutput = AVCaptureVideoDataOutput()
        private let photoOutput = AVCapturePhotoOutput()
        private let depthOutput = AVCaptureDepthDataOutput()
        private let depthQueue = DispatchQueue(label: "enhancedDepthQueue")
        private let depthStateQueue = DispatchQueue(label: "enhancedDepthStateQueue")

        private var previewLayer: AVCaptureVideoPreviewLayer!

        private var lastAnalysisTime: CFTimeInterval = 0
        private let analysisInterval: CFTimeInterval = 1.0 / 3.0

        private var classificationRequest: VNClassifyImageRequest!
        private var detectionRequest: VNCoreMLRequest?
        private var isAnalyzing = false

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

        init(state: LiveClassificationState, onCaptured: @escaping (UIImage, Float?, Float?, DepthFrameSnapshot?) -> Void, onCancel: @escaping () -> Void) {
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

            setupButtons()

            if let vn = YOLOModelProvider.load() {
                let req = VNCoreMLRequest(model: vn)
                req.imageCropAndScaleOption = .scaleFill
                detectionRequest = req
            }
        }

        override func viewWillLayoutSubviews() {
            super.viewWillLayoutSubviews()
            previewLayer.frame = view.bounds
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
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
            session.sessionPreset = .photo

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

            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
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
                        self.state.label = "Detecting…"
                        self.state.confidence = 0
                    }
                }
            })
            classificationRequest.usesCPUOnly = false
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
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            photoOutput.capturePhoto(with: settings, delegate: self)
        }

        @objc private func closeTapped() {
            onCancel()
        }

        private func performClassification(on pixelBuffer: CVPixelBuffer) {
            let currentTime = CACurrentMediaTime()
            guard currentTime - lastAnalysisTime >= analysisInterval else { return }
            lastAnalysisTime = currentTime

            if isAnalyzing { return }
            isAnalyzing = true

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
            if let det = detectionRequest {
                do {
                    try handler.perform([det])
                    if let objs = det.results as? [VNRecognizedObjectObservation],
                       let best = objs.max(by: { $0.confidence < $1.confidence }),
                       let top = best.labels.first {
                        let label = top.identifier
                        let conf = top.confidence
                        DispatchQueue.main.async {
                            self.state.label = label.prefix(1).uppercased() + label.dropFirst()
                            self.state.confidence = conf
                            NotificationCenter.default.post(
                                name: .liveFoodDetectionUpdate,
                                object: nil,
                                userInfo: ["label": self.state.label, "confidence": conf]
                            )
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.state.label = "Detecting…"
                            self.state.confidence = 0
                            NotificationCenter.default.post(
                                name: .liveFoodDetectionUpdate,
                                object: nil,
                                userInfo: ["label": self.state.label, "confidence": Float(0)]
                            )
                        }
                    }
                } catch {
                    runFallbackClassification(with: handler)
                }
            } else {
                runFallbackClassification(with: handler)
            }
            isAnalyzing = false
        }

        private func runFallbackClassification(with handler: VNImageRequestHandler) {
            let request = VNClassifyImageRequest { [weak self] req, _ in
                guard let self else { return }
                let top = (req.results as? [VNClassificationObservation])?.first
                let label = top?.identifier ?? "Detecting…"
                let conf = top?.confidence ?? 0.0
                DispatchQueue.main.async {
                    self.state.label = label.prefix(1).uppercased() + label.dropFirst()
                    self.state.confidence = conf
                    NotificationCenter.default.post(
                        name: .liveFoodDetectionUpdate,
                        object: nil,
                        userInfo: ["label": self.state.label, "confidence": conf]
                    )
                }
            }
            do {
                try handler.perform([request])
            } catch {
                AppLog.error(AppLog.vision, "[EnhancedCameraPreview] Fallback classification failed: \(error.localizedDescription)")
            }
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

extension CameraControllerRepresentable.CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
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
        let metrics = computeCaptureMetrics()
        let depthSnapshot = makeDepthSnapshot(imageSize: image.size)
        DispatchQueue.main.async {
            self.onCaptured(image, metrics.volumeML, metrics.massG, depthSnapshot)
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
