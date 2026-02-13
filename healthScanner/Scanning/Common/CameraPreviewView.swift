//
//  CameraPreviewView.swift
//  HealthScanner
//
//  Simplified SwiftUI camera preview with CoreML integration.
//

import SwiftUI
import AVFoundation
import UIKit
import CoreImage

extension Notification.Name {
    static let capturePhoto = Notification.Name("capturePhoto")
}

struct CameraPreviewView: View {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
#if targetEnvironment(simulator)
            simulatorPlaceholder
#else
            CameraPreviewControllerRepresentable(onImageCaptured: onImageCaptured)
                .ignoresSafeArea()
#endif
            overlayFades
            overlayControls
        }
    }

    @ViewBuilder
    private var overlayControls: some View {
        VStack {
            topBar

            Spacer()

#if !targetEnvironment(simulator)
            bottomBar
#endif
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.16))
                    )
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

#if !targetEnvironment(simulator)
    private var bottomBar: some View {
        VStack(spacing: 18) {
            Button {
                NotificationCenter.default.post(name: .capturePhoto, object: nil)
            } label: {
                captureButton
            }
            .buttonStyle(.plain)

            Text("camera.preview_hint".localized)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .padding(.bottom, 12)
    }

    private var captureButton: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 92, height: 92)

            Circle()
                .stroke(Color.white.opacity(0.35), lineWidth: 2)
                .frame(width: 82, height: 82)

            Circle()
                .fill(Color.white)
                .frame(width: 64, height: 64)
        }
        .shadow(color: Color.black.opacity(0.6), radius: 18, y: 6)
    }
#endif

    private var overlayFades: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.08), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)

            Spacer()

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.28), Color.black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 220)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

#if targetEnvironment(simulator)
    @ViewBuilder
    private var simulatorPlaceholder: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 64))
                .foregroundColor(.white)

            Text("placeholder.camera.title".localized)
                .font(AppFonts.serif(20, weight: .semibold))
                .foregroundColor(.white)

            Text("placeholder.camera.simulator_message".localized)
                .font(AppFonts.sans(12, weight: .regular))
                .foregroundColor(.nordicSlate)
                .multilineTextAlignment(.center)

            Button("button.camera.simulator_capture".localized) {
                let testImage = createPlaceholderImage()
                onImageCaptured(testImage)
                dismiss()
            }
            .font(AppFonts.sans(13, weight: .semibold))
            .foregroundColor(.nordicBone)
            .padding(.horizontal, 40)
            .padding(.vertical, 15)
            .background(Color.midnightSpruce)
            .cornerRadius(25)
        }
        .padding()
    }

    private func createPlaceholderImage() -> UIImage {
        let size = CGSize(width: 300, height: 400)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)

        let context = UIGraphicsGetCurrentContext()!
        let colors = [UIColor(Color.momentumAmber).cgColor, UIColor(Color.midnightSpruce).cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])

        let text = "placeholder.camera.sample_text".localized
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraphStyle
        ]

        let textRect = CGRect(x: 20, y: size.height / 2 - 60, width: size.width - 40, height: 120)
        text.draw(in: textRect, withAttributes: attributes)

        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()

        return image
    }
#endif
}

private struct CameraPreviewControllerRepresentable: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void

    func makeUIViewController(context: Context) -> CameraPreviewViewController {
        let controller = CameraPreviewViewController()
        controller.onImageCaptured = onImageCaptured
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraPreviewViewController, context: Context) {}
}

private final class CameraPreviewViewController: UIViewController {
    var onImageCaptured: ((UIImage) -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "camera.preview.session")
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let frameProcessingQueue = DispatchQueue(label: "camera.preview.frames", qos: .userInitiated)
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var lastFrameTime: CFTimeInterval = 0
    private let frameInterval: CFTimeInterval = 0.75
    private var latestFrame: UIImage?
    private var isSessionConfigured = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCaptureNotification()
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.isSessionConfigured && !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupCaptureNotification() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(capturePhoto),
            name: .capturePhoto,
            object: nil
        )
    }

    @objc private func capturePhoto() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.isSessionConfigured else {
                print("⚠️ Capture requested before session configured")
                return
            }

            let settings = AVCapturePhotoSettings()

            if #available(iOS 13.0, *) {
                settings.photoQualityPrioritization = .balanced
            }

            if self.photoOutput.supportedFlashModes.contains(.off) {
                settings.flashMode = .off
            }

            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func configureSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                DispatchQueue.main.async {
                    if granted {
                        self.setupSession()
                    } else {
                        print("❌ Camera access denied by user")
                    }
                }
            }
        default:
            print("❌ Camera access not authorized")
        }
    }

    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard !self.isSessionConfigured else { return }

            self.session.beginConfiguration()
            var configurationSucceeded = false

            defer {
                self.session.commitConfiguration()
                if configurationSucceeded {
                    self.isSessionConfigured = true
                    if !self.session.isRunning {
                        self.session.startRunning()
                    }
                    DispatchQueue.main.async {
                        self.setupPreviewLayer()
                    }
                }
            }

            self.session.sessionPreset = .photo
            self.session.inputs.forEach { self.session.removeInput($0) }
            self.session.outputs.forEach { self.session.removeOutput($0) }

            guard let device = self.selectCaptureDevice() else {
                print("❌ No available capture device")
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                guard self.session.canAddInput(input) else {
                    print("❌ Cannot add camera input to session")
                    return
                }
                self.session.addInput(input)

                try device.lockForConfiguration()
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposureModeSupported(.continuousAutoExposure) {
                    device.exposureMode = .continuousAutoExposure
                }
                if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                    device.whiteBalanceMode = .continuousAutoWhiteBalance
                }
                device.unlockForConfiguration()
            } catch {
                print("❌ Failed to configure camera input: \(error)")
                return
            }

            self.videoOutput.alwaysDiscardsLateVideoFrames = true
            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]

            guard self.session.canAddOutput(self.videoOutput) else {
                print("❌ Cannot add video output to session")
                return
            }
            self.session.addOutput(self.videoOutput)
            self.videoOutput.setSampleBufferDelegate(self, queue: self.frameProcessingQueue)

            if let connection = self.videoOutput.connection(with: .video) {
                if connection.isVideoStabilizationSupported {
                    connection.preferredVideoStabilizationMode = .auto
                }
                // Use videoRotationAngle instead of deprecated videoOrientation
                if #available(iOS 17.0, *) {
                    if connection.isVideoRotationAngleSupported(0) {
                        connection.videoRotationAngle = 0
                    }
                } else {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait
                    }
                }
            }

            guard self.session.canAddOutput(self.photoOutput) else {
                print("❌ Cannot add photo output to session")
                return
            }
            self.session.addOutput(self.photoOutput)

            self.photoOutput.isLivePhotoCaptureEnabled = false
            if self.photoOutput.isDepthDataDeliverySupported {
                self.photoOutput.isDepthDataDeliveryEnabled = false
            }
            if #available(iOS 12.0, *), self.photoOutput.isPortraitEffectsMatteDeliverySupported {
                self.photoOutput.isPortraitEffectsMatteDeliveryEnabled = false
            }
            if #available(iOS 13.0, *), self.photoOutput.isDualCameraDualPhotoDeliverySupported {
                self.photoOutput.isDualCameraDualPhotoDeliveryEnabled = false
            }
            if #available(iOS 13.0, *), self.photoOutput.isVirtualDeviceConstituentPhotoDeliverySupported {
                self.photoOutput.isVirtualDeviceConstituentPhotoDeliveryEnabled = false
            }
            if #available(iOS 17.0, *), self.photoOutput.isResponsiveCaptureSupported {
                self.photoOutput.isResponsiveCaptureEnabled = false
            }

            configurationSucceeded = true
        }
    }

    private func selectCaptureDevice() -> AVCaptureDevice? {
        if let wide = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            return wide
        }

        if #available(iOS 13.0, *) {
            let fallbackTypes: [AVCaptureDevice.DeviceType] = [
                .builtInDualCamera,
                .builtInDualWideCamera,
                .builtInTripleCamera
            ]

            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: fallbackTypes,
                mediaType: .video,
                position: .back
            )

            if let backup = discovery.devices.first {
                return backup
            }
        }

        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
    }

    private func setupPreviewLayer() {
        if let existingLayer = previewLayer {
            existingLayer.session = session
            existingLayer.frame = view.bounds
            return
        }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }

    private func deliverLatestFrameFallback() {
        sessionQueue.async { [weak self] in
            guard let self, let fallback = self.latestFrame else {
                print("⚠️ No fallback frame available for capture")
                return
            }

            DispatchQueue.main.async {
                self.onImageCaptured?(fallback)
            }
        }
    }

    private func makeUIImage(from pixelBuffer: CVPixelBuffer) -> UIImage? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext(options: [
            .cacheIntermediates: false,
            .outputColorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        ])

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

extension CameraPreviewViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastFrameTime >= frameInterval else { return }
        lastFrameTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("⚠️ Failed to obtain pixel buffer from sample")
            return
        }

        if let image = makeUIImage(from: pixelBuffer) {
            sessionQueue.async { [weak self] in
                self?.latestFrame = image
            }
        }

        // CoreMLFoodAnalysisService.shared.performRealtimeInference(on: pixelBuffer)
    }
}

extension CameraPreviewViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            print("❌ Failed to capture photo: \(error)")
            deliverLatestFrameFallback()
            return
        }

        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            print("⚠️ No photo data representation available")
            deliverLatestFrameFallback()
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.onImageCaptured?(image)
        }
    }
}
