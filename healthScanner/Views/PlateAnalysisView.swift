import SwiftUI
import PhotosUI
import SwiftData
import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

// Inline fallback enhancer to avoid missing type issues
struct InlinePhotoEnhancer {
    enum Style { case clean, vibrant, warm }
    private let context = CIContext()
    func enhance(_ image: UIImage, style: Style = .clean) -> UIImage {
        guard var ci = CIImage(image: image) else { return image }
        let vibrance = CIFilter.vibrance(); vibrance.inputImage = ci
        vibrance.amount = (style == .vibrant) ? 0.35 : 0.22
        ci = vibrance.outputImage ?? ci
        let vignette = CIFilter.vignette(); vignette.inputImage = ci
        vignette.intensity = 0.2; vignette.radius = 1.5
        ci = vignette.outputImage ?? ci
        guard let cg = context.createCGImage(ci, from: ci.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }
}

struct PlateAnalysisView: View {
    // MARK: State
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel = PlateAnalysisViewModel()
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var detectedCategories: [String] = []
    @State private var enhancePhoto = true
    @State private var enhancerStyle: InlinePhotoEnhancer.Style = .clean
    @State private var showingAnalysis = false
    @State private var showingCamera = false
    @State private var showingRegionOverlay = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                header
                ScrollView {
                    VStack(spacing: 28) {
                        cameraPreview
                        actionButtons
                        tips
                        if viewModel.lastAnalysisResult != nil { reopenLastSection }
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear { viewModel.loadLastAnalysisFromDefaults() }
        .onChange(of: selectedItem) { _, newItem in
            Task { await loadPickedImage(newItem) }
        }
        .onChange(of: viewModel.analysisResult) { _, newValue in
            if newValue != nil { showingAnalysis = true }
        }
        .sheet(isPresented: $showingAnalysis) {
            if let analysis = viewModel.analysisResult {
                PlateAnalysisResultView(
                    analysis: analysis,
                    image: viewModel.lastAnalyzedImage,
                    onStartNewScan: { resetAfterAnalysis() },
                    onClose: { showingAnalysis = false }
                )
            }
        }
        .sheet(isPresented: $showingRegionOverlay) {
            if let img = selectedImage {
                FoodRegionSelectionView(image: img, viewModel: viewModel)
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            EnhancedCameraPreviewView { image in
                self.selectedImage = image
                if enhancePhoto {
                    let vibrance: CGFloat
                    switch enhancerStyle {
                    case .clean: vibrance = 0.22
                    case .vibrant: vibrance = 0.35
                    case .warm: vibrance = 0.28
                    }
                    let segEnhanced = SegmentationEnhancer().enhance(image, preferredVibrance: vibrance)
                    let styled = InlinePhotoEnhancer().enhance(segEnhanced, style: enhancerStyle)
                    self.selectedImage = styled
                } else {
                    self.selectedImage = image
                }
                if let img = self.selectedImage { self.viewModel.lastAnalyzedImage = img }
                if let img = self.selectedImage { classifyImage(img) }
                showingCamera = false
                showingRegionOverlay = true
            }
        }
    }
}

// MARK: - Subviews
private extension PlateAnalysisView {
    var header: some View {
        HStack {
            Text("What's on your plate?").font(.title2).fontWeight(.bold)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    var cameraPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.orange.opacity(0.08))
                .frame(height: 300)
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 20)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 56))
                        .foregroundColor(.mint)
                    Text("camera.preview_hint".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.horizontal, 20)
    }

    var actionButtons: some View {
        VStack(spacing: 14) {
            Button {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    showingCamera = true
                }
            } label: {
                HStack { Image(systemName: "camera.viewfinder"); Text("camera.take_photo".localized) }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(UIImagePickerController.isSourceTypeAvailable(.camera) ? Color.indigo : Color.gray)
                    .cornerRadius(24)
            }
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            .padding(.horizontal, 20)

            PhotosPicker(selection: $selectedItem, matching: .images) {
                HStack { Image(systemName: "photo.on.rectangle"); Text("camera.choose_photo".localized) }
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(24)
            }
            .padding(.horizontal, 20)

            if viewModel.isAnalyzing { ProgressView("camera.analyzing".localized).padding(.top, 4) }

            if !detectedCategories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(detectedCategories, id: \.self) { cat in
                            Text(cat)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            Toggle("Enhance photo", isOn: $enhancePhoto)
                .padding(.horizontal, 20)

            HStack {
                Text("Style").font(.footnote).foregroundColor(.secondary)
                Picker("Style", selection: $enhancerStyle) {
                    Text("Clean").tag(InlinePhotoEnhancer.Style.clean)
                    Text("Vibrant").tag(InlinePhotoEnhancer.Style.vibrant)
                    Text("Warm").tag(InlinePhotoEnhancer.Style.warm)
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, 20)
        }
    }

    var tips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pro tip").font(.footnote).fontWeight(.semibold)
            Text("camera.tip_lighting".localized)
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    var reopenLastSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Previous Analysis")
                .font(.footnote).fontWeight(.semibold)
                .foregroundColor(.secondary)
            Button {
                if let last = viewModel.lastAnalysisResult {
                    viewModel.analysisResult = last
                    selectedImage = viewModel.lastAnalyzedImage
                    showingAnalysis = true
                }
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Reopen Results")
                }
                .font(.subheadline).fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.mint)
                .cornerRadius(20)
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Helpers & Processing
private extension PlateAnalysisView {
    func loadPickedImage(_ item: PhotosPickerItem?) async {
        guard
            let item,
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data)
        else { return }

        selectedImage = image
        if enhancePhoto {
            let vibrance: CGFloat
            switch enhancerStyle {
            case .clean: vibrance = 0.22
            case .vibrant: vibrance = 0.35
            case .warm: vibrance = 0.28
            }
            let segEnhanced = SegmentationEnhancer().enhance(image, preferredVibrance: vibrance)
            selectedImage = InlinePhotoEnhancer().enhance(segEnhanced, style: enhancerStyle)
        }
        if let img = selectedImage { self.viewModel.lastAnalyzedImage = img }
        if let img = selectedImage { classifyImage(img) }

        // Present region selection overlay for manual adjustment
        showingRegionOverlay = true
    }

    func resetAfterAnalysis() {
        selectedImage = nil
        selectedItem = nil
        viewModel.isAnalyzing = false
        viewModel.analysisResult = nil
        showingAnalysis = false
    }

    func classifyImage(_ image: UIImage) {
        detectedCategories = []
        guard let ciImage = CIImage(image: image) else { return }

        // Attempt to load a bundled Core ML classifier first
        let modelURLs: [URL?] = [
            Bundle.main.url(forResource: "FoodClassifier", withExtension: "mlmodelc"),
            Bundle.main.url(forResource: "FoodClassifier", withExtension: "mlpackage"),
            Bundle.main.url(forResource: "CoreML/FoodClassifier", withExtension: "mlmodelc"),
            Bundle.main.url(forResource: "CoreML/FoodClassifier", withExtension: "mlpackage")
        ]
        var coreMLRequest: VNCoreMLRequest?
        for urlOpt in modelURLs {
            if let url = urlOpt {
                do {
                    let cfg = MLModelConfiguration(); cfg.computeUnits = .all
                    let ml = try MLModel(contentsOf: url, configuration: cfg)
                    let vnModel = try VNCoreMLModel(for: ml)
                    let req = VNCoreMLRequest(model: vnModel)
                    req.imageCropAndScaleOption = .centerCrop
                    coreMLRequest = req
                    break
                } catch {
                    continue
                }
            }
        }

        // Fallback to Vision's built-in classifier only if our model isn't found
        let request: VNRequest
        if let coreReq = coreMLRequest {
            request = coreReq
        } else {
            request = VNClassifyImageRequest()
        }

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
                var labels: [String] = []
                if let obs = (request as? VNCoreMLRequest)?.results as? [VNClassificationObservation] {
                    labels = Array(obs.prefix(3).filter { $0.confidence >= 0.15 }.map { $0.identifier })
                } else if let obs = (request as? VNClassifyImageRequest)?.results as? [VNClassificationObservation] {
                    labels = Array(obs.prefix(3).filter { $0.confidence >= 0.15 }.map { $0.identifier })
                } else if let obs = (request.results as? [VNClassificationObservation]) {
                    labels = Array(obs.prefix(3).filter { $0.confidence >= 0.15 }.map { $0.identifier })
                }
                DispatchQueue.main.async {
                    self.detectedCategories = labels
                    // Forward to the view model if supported
                    if let vm = self.viewModel as? PlateAnalysisViewModel {
                        vm.setTransientCategories(labels)
                    }
                }
            } catch {
                // ignore errors for this lightweight preview classification
            }
        }
    }
}

