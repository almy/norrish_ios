import SwiftUI
import SwiftData
import UIKit

extension Notification.Name {
    static let closePlateScanFlow = Notification.Name("closePlateScanFlow")
    static let retakePlateScanFlow = Notification.Name("retakePlateScanFlow")
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
            } else {
                PhotoLibraryPickerView(image: $capturedImage)
                    .ignoresSafeArea()
            }

            if analysisVM.isAnalyzing && mode == .photo {
                AppLoadingOverlay(title: NSLocalizedString("scan.status.fetching", tableName: "Scan", comment: ""))
            }
        }
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
            NavigationView {
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
                NavigationView {
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
