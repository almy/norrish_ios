import SwiftUI
import SwiftData
import UIKit

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
    @State private var capturedFocusLabel: String?
    @State private var capturedFocusConfidence: Float?
    let mode: Mode
    let onCameraCaptured: ((QuickPlateCapturePayload) -> Void)?

    init(mode: Mode, onCameraCaptured: ((QuickPlateCapturePayload) -> Void)? = nil) {
        self.mode = mode
        self.onCameraCaptured = onCameraCaptured
    }

    var body: some View {
        ZStack {
            if mode == .camera {
                #if DEBUG && targetEnvironment(simulator)
                simulatorCameraReplacement
                #else
                EnhancedCameraPreviewView { image, volumeML, massG, depthSnapshot, focusLabel, focusConfidence in
                    DispatchQueue.main.async {
                        if let onCameraCaptured {
                            onCameraCaptured(
                                QuickPlateCapturePayload(
                                    image: image,
                                    volumeML: volumeML,
                                    massG: massG,
                                    depthSnapshot: depthSnapshot,
                                    focusLabel: focusLabel,
                                    focusConfidence: focusConfidence
                                )
                            )
                            dismiss()
                        } else {
                            self.capturedVolumeML = volumeML
                            self.capturedMassG = massG
                            self.capturedDepthSnapshot = depthSnapshot
                            self.capturedFocusLabel = focusLabel
                            self.capturedFocusConfidence = focusConfidence
                            self.capturedImage = image
                        }
                    }
                }
                .ignoresSafeArea()
                #endif
            } else {
                PhotoLibraryPickerView(image: $capturedImage)
                    .ignoresSafeArea()
            }

            if analysisVM.isAnalyzing && mode == .photo {
                AppLoadingOverlay(title: NSLocalizedString("scan.status.fetching", tableName: "Scan", comment: ""))
            }
        }
        .accessibilityIdentifier(mode == .camera ? "screen.plateQuickScan.camera" : "screen.plateQuickScan.photo")
        .onChange(of: capturedImage) { _, newValue in
            guard let image = newValue else { return }
            analysisVM.analysisResult = nil
            analysisVM.setTransientScanMetrics(volumeML: capturedVolumeML, massG: capturedMassG)
            analysisVM.setTransientDepthSnapshot(capturedDepthSnapshot)
            resultAnalysis = nil
            pendingImage = PendingImage(image: image)
            awaitingAnalysisResult = true
        }
        .fullScreenCover(isPresented: $showResult) {
            NavigationStack {
                if let analysis = resultAnalysis {
                    if analysis.isGuardrailBlocked {
                        BlockedPlateAnalysisView(
                            analysis: analysis,
                            image: capturedImage,
                            onRetake: {
                                showResult = false
                                resultAnalysis = nil
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
                            }
                        )
                    } else {
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
                            onLogMeal: { intent in
                                analysisVM.logCurrentMeal(intent: intent, modelContext: modelContext)
                            }
                        )
                    }
                } else {
                    Color.clear.onAppear { showResult = false }
                }
            }
        }
        .fullScreenCover(item: $pendingImage) { pending in
            FoodRegionSelectionView(
                image: pending.image,
                viewModel: analysisVM,
                preferredFocusLabel: capturedFocusLabel,
                preferredFocusConfidence: capturedFocusConfidence
            )
        }
        .onChange(of: analysisVM.analysisResult) { _, newValue in
            guard awaitingAnalysisResult else { return }
            if let result = newValue {
                resultAnalysis = result
                pendingImage = nil
                showResult = true
                awaitingAnalysisResult = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .closePlateScanFlow)) { _ in
            dismiss()
        }
    }

    #if DEBUG && targetEnvironment(simulator)
    /// Simulator camera replacement: shows fixture picker when FIXTURE_PATH
    /// is configured, falls back to photo library picker otherwise so the
    /// flow remains usable without fixture configuration.
    @ViewBuilder
    private var simulatorCameraReplacement: some View {
        if ExternalPlateFixtureLoader.isAvailable {
            SimulatorPlateFixturePickerView(
                onImageSelected: { image in
                    // Non-LiDAR baseline: no depth, no volume/mass
                    self.capturedVolumeML = nil
                    self.capturedMassG = nil
                    self.capturedDepthSnapshot = nil
                    self.capturedFocusLabel = nil
                    self.capturedFocusConfidence = nil
                    self.capturedImage = image
                },
                onClose: { dismiss() }
            )
        } else {
            PhotoLibraryPickerView(image: $capturedImage)
                .ignoresSafeArea()
        }
    }
    #endif
}

struct QuickPlateCapturePayload: Identifiable {
    let id = UUID()
    let image: UIImage
    let volumeML: Float?
    let massG: Float?
    let depthSnapshot: DepthFrameSnapshot?
    let focusLabel: String?
    let focusConfidence: Float?
}

struct PlateQuickPostCaptureFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var analysisVM = PlateAnalysisViewModel()
    @State private var resultAnalysis: PlateAnalysis?
    @State private var awaitingAnalysisResult = false

    let capture: QuickPlateCapturePayload

    var body: some View {
        ZStack {
            if let analysis = resultAnalysis {
                NavigationStack {
                    if analysis.isGuardrailBlocked {
                        BlockedPlateAnalysisView(
                            analysis: analysis,
                            image: capture.image,
                            onRetake: {
                                NotificationCenter.default.post(name: .retakePlateScanFlow, object: nil)
                                dismiss()
                            },
                            onClose: { dismiss() }
                        )
                    } else {
                        PlateAnalysisResultView(
                            analysis: analysis,
                            image: capture.image,
                            onStartNewScan: { dismiss() },
                            onClose: { dismiss() },
                            onLogMeal: { intent in
                                analysisVM.logCurrentMeal(intent: intent, modelContext: modelContext)
                            }
                        )
                    }
                }
            } else {
                FoodRegionSelectionView(
                    image: capture.image,
                    viewModel: analysisVM,
                    preferredFocusLabel: capture.focusLabel,
                    preferredFocusConfidence: capture.focusConfidence,
                    dismissOnConfirm: false,
                    onCloseRequested: { dismiss() },
                    onRetakeRequested: { dismiss() }
                )
            }

            if analysisVM.isAnalyzing {
                AppLoadingOverlay(title: NSLocalizedString("scan.status.fetching", tableName: "Scan", comment: ""))
            }
        }
        .onAppear {
            analysisVM.analysisResult = nil
            analysisVM.setTransientScanMetrics(volumeML: capture.volumeML, massG: capture.massG)
            analysisVM.setTransientDepthSnapshot(capture.depthSnapshot)
            awaitingAnalysisResult = true
        }
        .onChange(of: analysisVM.analysisResult) { _, newValue in
            guard awaitingAnalysisResult else { return }
            if let result = newValue {
                resultAnalysis = result
            }
        }
        .onChange(of: analysisVM.isAnalyzing) { _, isAnalyzing in
            guard awaitingAnalysisResult, !isAnalyzing else { return }
            if let result = analysisVM.analysisResult {
                resultAnalysis = result
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

// MARK: - Simulator Plate Fixture Picker

#if DEBUG && targetEnvironment(simulator)
struct SimulatorPlateFixturePickerView: View {
    let onImageSelected: (UIImage) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.nordicBone.opacity(0.6)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.04))

            VStack {
                Spacer(minLength: 24)
                pickerSurface
                Spacer(minLength: 32)
            }
        }
        .onAppear {
            // Auto-inject if PERSONA_NAME + FIXTURE_INDEX are set (automated persona runs).
            if let image = ExternalPlateFixtureLoader.autoInjectPlateImage() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onImageSelected(image)
                }
            }
        }
    }

    private var pickerSurface: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.midnightSpruce)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("debug.plate.title", comment: "Simulator plate debug panel title"))
                            .font(AppFonts.serif(22, weight: .semibold))
                            .foregroundColor(.midnightSpruce)
                        Text(fixtureSourceLabel)
                            .font(AppFonts.sans(13, weight: .regular))
                            .foregroundColor(.nordicSlate)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.midnightSpruce)
                        .frame(width: 32, height: 32)
                        .background(Color.cardSurface)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(NSLocalizedString("debug.plate.close", comment: "Close simulator plate debug panel"))
            }

            // Plate list
            ScrollView {
                externalFixtureList
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.5)

            Text(fixtureFooterLabel)
                .font(AppFonts.sans(11, weight: .regular))
                .foregroundColor(.nordicSlate.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.nordicBone)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 18, x: 0, y: 8)
        .padding(.horizontal, 20)
    }

    private var externalFixtureList: some View {
        let items = ExternalPlateFixtureLoader.loadDisplayItems()
        return VStack(spacing: 10) {
            ForEach(items) { item in
                Button(action: {
                    if let image = ExternalPlateFixtureLoader.loadImage(filename: item.filename) {
                        onImageSelected(image)
                    }
                }) {
                    HStack(alignment: .center, spacing: 12) {
                        // Thumbnail
                        if let thumb = ExternalPlateFixtureLoader.loadImage(filename: item.filename) {
                            Image(uiImage: thumb)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.label)
                                .font(AppFonts.sans(14, weight: .semibold))
                                .foregroundColor(.midnightSpruce)
                            Text(item.subtitle)
                                .font(AppFonts.sans(12, weight: .regular))
                                .foregroundColor(.nordicSlate)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(NSLocalizedString("debug.plate.cta", comment: "Simulator plate debug action"))
                            .font(AppFonts.sans(12, weight: .semibold))
                            .foregroundColor(.midnightSpruce)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var fixtureSourceLabel: String {
        if let persona = ExternalPlateFixtureLoader.personaName {
            return "External fixtures · \(persona.capitalized)"
        }
        return "External fixtures loaded"
    }

    private var fixtureFooterLabel: String {
        "Plate images loaded from FIXTURE_PATH. Real backend analysis runs after selection."
    }
}
#endif
