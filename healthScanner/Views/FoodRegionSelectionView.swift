import SwiftUI
import SwiftData
import UIKit

extension Notification.Name {
    static let closePlateScanFlow = Notification.Name("closePlateScanFlow")
}

struct FoodRegionSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: PlateAnalysisViewModel
    let image: UIImage
    let onAnalyzed: (() -> Void)?

    @State private var regions: [ImagePreprocessor.Result] = []
    @State private var selected: Set<Int> = []
    @State private var isWorking = false

    init(image: UIImage, viewModel: PlateAnalysisViewModel, onAnalyzed: (() -> Void)? = nil) {
        self.image = image
        self.viewModel = viewModel
        self.onAnalyzed = onAnalyzed
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                header
                imageWithRegions
                if !regions.isEmpty {
                    regionChips
                }
                actionButtons
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .navigationBarHidden(true)
            .onAppear { loadRegions() }
            .overlay {
                if isWorking || viewModel.isAnalyzing {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView("Preparing scan…")
                        .foregroundColor(.white)
                        .padding(16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

private extension FoodRegionSelectionView {
    var header: some View {
        HStack {
            Button("Retake") {
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
            Spacer()
            Text("Crop Your Plate")
                .font(.headline)
            Spacer()
            Button("Close") {
                NotificationCenter.default.post(name: .closePlateScanFlow, object: nil)
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
        }
    }

    var imageWithRegions: some View {
        GeometryReader { geo in
            let displaySize = geo.size
            let imgSize = image.size
            let scale = min(displaySize.width / max(1, imgSize.width),
                            displaySize.height / max(1, imgSize.height))
            let renderSize = CGSize(width: imgSize.width * scale, height: imgSize.height * scale)
            let xOffset = (displaySize.width - renderSize.width) / 2
            let yOffset = (displaySize.height - renderSize.height) / 2

            ZStack(alignment: .topLeading) {
                Color.black.opacity(0.05)
                    .cornerRadius(12)

                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: renderSize.width, height: renderSize.height)
                    .position(x: displaySize.width / 2, y: displaySize.height / 2)

                ForEach(Array(regions.enumerated()), id: \.offset) { idx, region in
                    let rect = region.boundingBox
                    let frame = CGRect(
                        x: xOffset + rect.origin.x * scale,
                        y: yOffset + rect.origin.y * scale,
                        width: rect.size.width * scale,
                        height: rect.size.height * scale
                    )
                    Rectangle()
                        .stroke(selected.contains(idx) ? Color.green : Color.white.opacity(0.65), lineWidth: selected.contains(idx) ? 3 : 2)
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                        .contentShape(Rectangle())
                        .onTapGesture { toggleSelection(idx) }
                }
            }
        }
        .frame(height: 360)
        .cornerRadius(12)
    }

    var regionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(regions.enumerated()), id: \.offset) { idx, region in
                    Button {
                        toggleSelection(idx)
                    } label: {
                        VStack(spacing: 6) {
                            Image(uiImage: region.image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipped()
                                .cornerRadius(8)
                            Text("Region \(idx + 1)")
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                        .padding(8)
                        .background(selected.contains(idx) ? Color.green.opacity(0.15) : Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected.contains(idx) ? Color.green : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: { Task { await analyzeSelected() } }) {
                Text(selected.isEmpty ? "Select a region" : "Analyze Selected")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(selected.isEmpty ? Color.gray : Color.green)
                    .cornerRadius(14)
            }
            .disabled(selected.isEmpty)

            Button(action: { Task { await analyzeFullImage() } }) {
                Text("Analyze Full Photo")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
            }
        }
    }

    func loadRegions() {
        let detected = viewModel.detectFoodRegions(in: image, maxRegions: 3)
        if detected.isEmpty {
            let pre = ImagePreprocessor.preprocessFoodImage(image)
            regions = [pre]
            selected = [0]
        } else {
            regions = detected
            selected = [0]
        }
    }

    func toggleSelection(_ idx: Int) {
        if selected.contains(idx) {
            selected.remove(idx)
        } else {
            selected.insert(idx)
        }
    }

    func analyzeSelected() async {
        guard !isWorking else { return }
        isWorking = true
        let picked = regions.enumerated().compactMap { selected.contains($0.offset) ? $0.element : nil }
        await viewModel.analyzeSelectedRegions(picked, originalImage: image, modelContext: modelContext)
        isWorking = false
        onAnalyzed?()
        dismiss()
    }

    func analyzeFullImage() async {
        guard !isWorking else { return }
        isWorking = true
        await viewModel.analyzeSelectedRegions([], originalImage: image, modelContext: modelContext)
        isWorking = false
        onAnalyzed?()
        dismiss()
    }
}
