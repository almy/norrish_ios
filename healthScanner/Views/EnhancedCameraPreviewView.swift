import SwiftUI
import AVFoundation
import Vision
import UIKit

private enum YOLOModelProvider {
    private static var cached: VNCoreMLModel?
    static func load() -> VNCoreMLModel? {
        if let c = cached { return c }
        let bundle = Bundle.main
        let candidates: [URL?] = [
            bundle.url(forResource: "yolov8x-oiv7", withExtension: "mlmodelc"),
            bundle.url(forResource: "yolov8x-oiv7", withExtension: "mlpackage"),
            bundle.url(forResource: "yolov8x-oiv7", withExtension: "mlmodelc", subdirectory: "CoreML"),
            bundle.url(forResource: "yolov8x-oiv7", withExtension: "mlpackage", subdirectory: "CoreML")
        ]
        for url in candidates {
            if let url {
                do {
                    let cfg = MLModelConfiguration(); cfg.computeUnits = .all
                    let ml = try MLModel(contentsOf: url, configuration: cfg)
                    let vn = try VNCoreMLModel(for: ml)
                    cached = vn
                    print("✅ [EnhancedCamera] YOLOv8x model loaded: \(url.lastPathComponent)")
                    return vn
                } catch {
                    continue
                }
            }
        }
        print("ℹ️ [EnhancedCamera] YOLOv8x model not found in bundle; using fallback classifier")
        return nil
    }
}

final class LiveClassificationState: ObservableObject {
    @Published var label: String = "Detecting…"
    @Published var confidence: Float = 0
    @Published var isRunning: Bool = false
}

extension Notification.Name {
    static let enhancedCapturePhoto = Notification.Name("enhancedCapturePhoto")
    static let liveFoodDetectionUpdate = Notification.Name("liveFoodDetectionUpdate")
}

struct EnhancedCameraPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var state = LiveClassificationState()
    private let onCaptured: (UIImage) -> Void

    init(onCaptured: @escaping (UIImage) -> Void) {
        self.onCaptured = onCaptured
    }

    var body: some View {
        ZStack {
            CameraControllerRepresentable(state: state, onCaptured: onCaptured, onCancel: dismiss.callAsFunction)
                .ignoresSafeArea()
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("\(state.label) \(Int(state.confidence * 100))%")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.top, 16)
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        NotificationCenter.default.post(name: .enhancedCapturePhoto, object: nil)
                    } label: {
                        Circle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 65, height: 65)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 32)
                    Spacer()
                }
            }
            .allowsHitTesting(true)

        }
    }
}

private struct CameraControllerRepresentable: UIViewControllerRepresentable {
    @ObservedObject var state: LiveClassificationState
    let onCaptured: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let vc = CameraViewController(state: state, onCaptured: onCaptured, onCancel: onCancel)
        return vc
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}

    final class CameraViewController: UIViewController {
        private let state: LiveClassificationState
        private let onCaptured: (UIImage) -> Void
        private let onCancel: () -> Void

        private let session = AVCaptureSession()
        private let videoOutput = AVCaptureVideoDataOutput()
        private let photoOutput = AVCapturePhotoOutput()

        private var previewLayer: AVCaptureVideoPreviewLayer!

        private var lastAnalysisTime: CFTimeInterval = 0
        private let analysisInterval: CFTimeInterval = 1.0 / 3.0 // 3 Hz

        private var classificationRequest: VNClassifyImageRequest!
        private var detectionRequest: VNCoreMLRequest?

        // Added to prevent simultaneous analysis
        private var isAnalyzing = false

        init(state: LiveClassificationState, onCaptured: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
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

            // Back camera input
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)

            // Photo output
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }

            // Video data output
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
            videoOutput.alwaysDiscardsLateVideoFrames = true
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
                videoOutput.connection(with: .video)?.videoOrientation = .portrait
            }

            session.commitConfiguration()
        }

        private func setupVision() {
            classificationRequest = VNClassifyImageRequest(completionHandler: { [weak self] request, error in
                guard let self = self else { return }
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
                    // Fallback to built-in classifier if detection fails
                    self.runFallbackClassification(with: handler)
                }
            } else {
                self.runFallbackClassification(with: handler)
            }
            isAnalyzing = false
        }

        private func runFallbackClassification(with handler: VNImageRequestHandler) {
            let request = VNClassifyImageRequest { [weak self] req, _ in
                guard let self = self else { return }
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
            do { try handler.perform([request]) } catch { }
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
        DispatchQueue.main.async {
            self.onCaptured(image)
        }
    }
}
