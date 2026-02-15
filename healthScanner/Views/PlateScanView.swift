import SwiftUI
import SwiftData
import UIKit
import AVFoundation
import Vision
import CoreML

extension Notification.Name {
    static let closePlateScanFlow = Notification.Name("closePlateScanFlow")
}

struct PlateScanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var analysisVM = PlateAnalysisViewModel()
    @State private var showResult = false
    @State private var resultAnalysis: PlateAnalysis?
    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var capturedImage: UIImage?
    @State private var pendingImage: PendingImage?
    @State private var awaitingAnalysisResult = false
    @State private var didOpenInitialPicker = false

    /// Called when a photo is captured or picked.
    let onImagePicked: (UIImage) -> Void
    /// Optional cancel handler
    let onCancel: (() -> Void)?
    let startInPhotoPicker: Bool

    init(onImagePicked: @escaping (UIImage) -> Void, onCancel: (() -> Void)? = nil, startInPhotoPicker: Bool = false) {
        self.onImagePicked = onImagePicked
        self.onCancel = onCancel
        self.startInPhotoPicker = startInPhotoPicker
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroArea
                    guidanceTips
                    actionButtons
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .overlay(
                Group {
                    if analysisVM.isAnalyzing {
                        Color.black.opacity(0.35).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                            Text(NSLocalizedString("scan.status.fetching", tableName: "Scan", comment: ""))
                                .foregroundColor(.white)
                                .font(AppFonts.sans(13, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            )
        }
        .background(Color.nordicBone)
        .fullScreenCover(isPresented: $showResult) {
            NavigationView {
                PlateAnalysisResultView(
                    analysis: resultAnalysis ?? PlateAnalysis.mockAnalysis(),
                    image: capturedImage,
                    onStartNewScan: {
                        showResult = false
                        showCamera = true
                    },
                    onClose: {
                        showResult = false
                    },
                    onLogMeal: {
                        // Dismiss Plate Analysis and return to parent view
                        showResult = false
                    }
                )
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraCaptureView(image: $capturedImage)
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoLibraryPickerView(image: $capturedImage)
        }
        .sheet(item: $pendingImage, onDismiss: {
            if !analysisVM.isAnalyzing {
                awaitingAnalysisResult = false
            }
        }) { pending in
            FoodRegionSelectionView(
                image: pending.image,
                viewModel: analysisVM
            )
        }
        .onAppear {
            if startInPhotoPicker && !didOpenInitialPicker {
                didOpenInitialPicker = true
                showPhotoPicker = true
            }
        }
        .onChange(of: capturedImage) { _, newValue in
            guard let image = newValue else { return }
            // Ensure any capture UI is dismissed before showing results
            showCamera = false
            showPhotoPicker = false
            onImagePicked(image)
            pendingImage = PendingImage(image: image)
            awaitingAnalysisResult = true
        }
        .onChange(of: analysisVM.analysisResult) { _, newValue in
            guard awaitingAnalysisResult, let img = pendingImage?.image else { return }
            if let result = newValue ?? analysisVM.lastAnalysisResult {
                resultAnalysis = result
                capturedImage = img
                showResult = true
            } else {
                dismiss()
            }
            awaitingAnalysisResult = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .closePlateScanFlow)) { _ in
            dismiss()
        }
    }

    // MARK: - Sections
    private var header: some View {
        HStack {
            Button(action: handleCancel) {
                Image(systemName: "chevron.backward").font(.headline)
            }
            Spacer()
            Text("Scan Your Plate")
                .font(AppFonts.serif(22, weight: .semibold))
                .foregroundColor(.midnightSpruce)
            Spacer()
            // balance spacer
            Image(systemName: "chevron.backward").opacity(0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private var heroArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.cardSurface)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardBorder, lineWidth: 1))
                .frame(height: 200)
            VStack(spacing: 10) {
                Image(systemName: "camera.viewfinder").font(.system(size: 44)).foregroundColor(.momentumAmber)
                Text("Center the plate inside the frame")
                    .font(AppFonts.sans(13, weight: .regular)).foregroundColor(.nordicSlate)
            }
        }
    }

    private var guidanceTips: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tips for a great scan").font(AppFonts.serif(16, weight: .semibold)).foregroundColor(.midnightSpruce)
            tipRow(icon: "sun.max.fill", title: "Good lighting", message: "Avoid strong shadows; use natural light when possible.")
            tipRow(icon: "crop", title: "Fill the frame", message: "Get close enough so the plate is prominent in view.")
            tipRow(icon: "square.and.arrow.down", title: "Top-down angle", message: "Hold your phone above the plate for best results.")
            tipRow(icon: "fork.knife", title: "Single plate", message: "One plate at a time works best.")
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { showCamera = true }) {
                HStack { Image(systemName: "camera.fill"); Text("Take Photo") }
                    .font(AppFonts.sans(14, weight: .semibold))
                    .foregroundColor(.nordicBone)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.midnightSpruce)
                    .cornerRadius(14)
            }

            Button(action: { showPhotoPicker = true }) {
                HStack { Image(systemName: "photo.fill.on.rectangle.fill"); Text("Import from Photos") }
                    .font(AppFonts.sans(13, weight: .medium))
                    .foregroundColor(.momentumAmber)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.cardSurface)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cardBorder, lineWidth: 1))
            }
        }
    }

    // MARK: - Helpers
    private func tipRow(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundColor(.mossInsight).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppFonts.sans(13, weight: .semibold)).foregroundColor(.midnightSpruce)
                Text(message).font(AppFonts.sans(12, weight: .regular)).foregroundColor(.nordicSlate)
            }
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cardSurface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cardBorder, lineWidth: 1))
        )
    }

    private func handleCancel() {
        onCancel?()
        dismiss()
    }
}

// MARK: - Quick Scan Flows (no intermediate UI)
struct PlateQuickScanView: View {
    enum Mode { case camera, photo }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var analysisVM = PlateAnalysisViewModel()
    @State private var resultAnalysis: PlateAnalysis?
    @State private var capturedImage: UIImage?
    @State private var showResult = false
    @State private var pendingImage: PendingImage?
    @State private var awaitingAnalysisResult = false
    let mode: Mode

    var body: some View {
        ZStack {
            if mode == .camera {
                EnhancedCameraPreviewView { image in
                    DispatchQueue.main.async {
                        self.capturedImage = image
                    }
                }
                .ignoresSafeArea()
            } else {
                PhotoLibraryPickerView(image: $capturedImage)
                    .ignoresSafeArea()
            }

            if analysisVM.isAnalyzing && mode == .photo {
                Color.black.opacity(0.35).ignoresSafeArea()
                VStack(spacing: 16) {
                    ProgressView()
                    Text(NSLocalizedString("scan.status.fetching", tableName: "Scan", comment: ""))
                        .foregroundColor(.white)
                        .font(AppFonts.sans(13, weight: .semibold))
                }
            }
        }
        .onChange(of: capturedImage) { _, newValue in
            guard let image = newValue else { return }
            analysisVM.setTransientScanMetrics(volumeML: nil, massG: nil)
            pendingImage = PendingImage(image: image)
            awaitingAnalysisResult = true
        }
        .fullScreenCover(isPresented: $showResult) {
            NavigationView {
                PlateAnalysisResultView(
                    analysis: resultAnalysis ?? PlateAnalysis.mockAnalysis(),
                    image: capturedImage,
                    onStartNewScan: {
                        showResult = false
                        capturedImage = nil
                        analysisVM.setTransientScanMetrics(volumeML: nil, massG: nil)
                    },
                    onClose: {
                        showResult = false
                        dismiss()
                    },
                    onLogMeal: {
                        // Dismiss Plate Analysis and return to previous screen for quick scan
                        showResult = false
                        dismiss()
                    }
                )
            }
        }
        .sheet(item: $pendingImage, onDismiss: {
            if !analysisVM.isAnalyzing {
                awaitingAnalysisResult = false
            }
        }) { pending in
            FoodRegionSelectionView(
                image: pending.image,
                viewModel: analysisVM
            )
        }
        .onChange(of: analysisVM.analysisResult) { _, newValue in
            guard awaitingAnalysisResult else { return }
            if let result = newValue ?? analysisVM.lastAnalysisResult {
                resultAnalysis = result
                showResult = true
            } else {
                dismiss()
            }
            awaitingAnalysisResult = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .closePlateScanFlow)) { _ in
            dismiss()
        }
    }
}

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
                    AppLog.debug(AppLog.vision, "✅ [EnhancedCamera] YOLOv8x model loaded: \(url.lastPathComponent)")
                    return vn
                } catch {
                    continue
                }
            }
        }
        AppLog.debug(AppLog.vision, "ℹ️ [EnhancedCamera] YOLOv8x model not found in bundle; using fallback classifier")
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
                        .font(AppFonts.sans(11, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .foregroundColor(.nordicBone)
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

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                       for: .video,
                                                       position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }
            session.addInput(input)

            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
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
            do {
                try handler.perform([request])
            } catch {
                AppLog.error(AppLog.vision, "[EnhancedCameraPreview] Fallback classification failed: \(error.localizedDescription)")
            }
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

private struct PendingImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - CameraCaptureView
/// Minimal UIKit-backed camera capture for SwiftUI. You can swap this with PHPicker or AVCaptureSession-based view.
struct CameraCaptureView: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator

        let hosting = UIHostingController(rootView: ReticleOverlayView().allowsHitTesting(false))
        hosting.view.backgroundColor = .clear
        hosting.view.frame = picker.view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        picker.cameraOverlayView = hosting.view

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraCaptureView
        init(_ parent: CameraCaptureView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage { parent.image = image }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - PhotoLibraryPickerView
struct PhotoLibraryPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoLibraryPickerView
        init(_ parent: PhotoLibraryPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage { parent.image = image }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - ReticleOverlayView
struct ReticleOverlayView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cornerLength: CGFloat = 28
            let cornerLineWidth: CGFloat = 2
            let circleRadius: CGFloat = 70
            let center = CGPoint(x: w / 2, y: h / 2)
            let cornerColor = Color.white.opacity(0.3)
            let circleColor = Color.white.opacity(0.15)

            ZStack {
                // Corner brackets - top left
                Path { path in
                    path.move(to: CGPoint(x: 0, y: cornerLength))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: cornerLength, y: 0))
                }
                .stroke(cornerColor, lineWidth: cornerLineWidth)

                // top right
                Path { path in
                    path.move(to: CGPoint(x: w - cornerLength, y: 0))
                    path.addLine(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w, y: cornerLength))
                }
                .stroke(cornerColor, lineWidth: cornerLineWidth)

                // bottom left
                Path { path in
                    path.move(to: CGPoint(x: 0, y: h - cornerLength))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: cornerLength, y: h))
                }
                .stroke(cornerColor, lineWidth: cornerLineWidth)

                // bottom right
                Path { path in
                    path.move(to: CGPoint(x: w - cornerLength, y: h))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: w, y: h - cornerLength))
                }
                .stroke(cornerColor, lineWidth: cornerLineWidth)

                // center dot
                Circle()
                    .fill(cornerColor)
                    .frame(width: 6, height: 6)
                    .position(center)

                // thin circular guide
                Circle()
                    .stroke(circleColor, lineWidth: 1)
                    .frame(width: circleRadius * 2, height: circleRadius * 2)
                    .position(center)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    NavigationView { PlateScanView(onImagePicked: { _ in }) }
}
