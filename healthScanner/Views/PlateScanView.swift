import SwiftUI
import SwiftData
import UIKit

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

    let onImagePicked: (UIImage) -> Void
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
                if let analysis = resultAnalysis {
                    PlateAnalysisResultView(
                        analysis: analysis,
                        image: capturedImage,
                        onStartNewScan: {
                            showResult = false
                            showCamera = true
                        },
                        onClose: {
                            showResult = false
                        },
                        onLogMeal: {
                            showResult = false
                        }
                    )
                } else {
                    ProgressView()
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraCaptureView(image: $capturedImage)
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoLibraryPickerView(image: $capturedImage)
        }
        .sheet(item: $pendingImage) { pending in
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
            guard !awaitingAnalysisResult else { return }
            showCamera = false
            showPhotoPicker = false
            onImagePicked(image)
            analysisVM.analysisResult = nil
            resultAnalysis = nil
            pendingImage = PendingImage(image: image)
            awaitingAnalysisResult = true
        }
        .onChange(of: analysisVM.analysisResult) { _, newValue in
            guard awaitingAnalysisResult, let img = pendingImage?.image else { return }
            if let result = newValue {
                resultAnalysis = result
                capturedImage = img
                pendingImage = nil
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
    @State private var capturedVolumeML: Float?
    @State private var capturedMassG: Float?
    @State private var capturedDepthSnapshot: DepthFrameSnapshot?
    let mode: Mode

    var body: some View {
        ZStack {
            if mode == .camera {
                EnhancedCameraPreviewView { image, volumeML, massG, depthSnapshot in
                    DispatchQueue.main.async {
                        self.capturedVolumeML = volumeML
                        self.capturedMassG = massG
                        self.capturedDepthSnapshot = depthSnapshot
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
            analysisVM.setTransientScanMetrics(volumeML: capturedVolumeML, massG: capturedMassG)
            analysisVM.setTransientDepthSnapshot(capturedDepthSnapshot)
            analysisVM.analysisResult = nil
            resultAnalysis = nil
            pendingImage = PendingImage(image: image)
            awaitingAnalysisResult = true
        }
        .fullScreenCover(isPresented: $showResult) {
            NavigationView {
                if let analysis = resultAnalysis {
                    PlateAnalysisResultView(
                        analysis: analysis,
                        image: capturedImage,
                        onStartNewScan: {
                            showResult = false
                            capturedImage = nil
                            capturedVolumeML = nil
                            capturedMassG = nil
                            capturedDepthSnapshot = nil
                            analysisVM.setTransientScanMetrics(volumeML: nil, massG: nil)
                            analysisVM.setTransientDepthSnapshot(nil)
                        },
                        onClose: {
                            showResult = false
                            dismiss()
                        },
                        onLogMeal: {
                            showResult = false
                            dismiss()
                        }
                    )
                } else {
                    ProgressView()
                }
            }
        }
        .sheet(item: $pendingImage) { pending in
            FoodRegionSelectionView(
                image: pending.image,
                viewModel: analysisVM
            )
        }
        .onChange(of: analysisVM.analysisResult) { _, newValue in
            guard awaitingAnalysisResult else { return }
            if let result = newValue {
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
