import SwiftUI
import Vision
import CoreGraphics

struct FoodRegionSelectionView: View {
    let image: UIImage
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: PlateAnalysisViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editableRegions: [EditableRegion] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var dragStartRects: [UUID: CGRect] = [:]

    struct EditableRegion: Identifiable {
        let id = UUID()
        var rect: CGRect // in image pixel coordinates
        var confidence: Float
        var isSelected: Bool
        var color: Color
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Select food areas")
                .font(.headline)

            ZStack {
                GeometryReader { geo in
                    let fitted = fittedImageSize(in: geo.size, imageSize: image.size)
                    let origin = CGPoint(x: (geo.size.width - fitted.width) / 2, y: (geo.size.height - fitted.height) / 2)
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: fitted.width, height: fitted.height)
                        .position(x: origin.x + fitted.width / 2, y: origin.y + fitted.height / 2)
                        .overlay {
                            ForEach($editableRegions) { $region in
                                let viewRect = imageRectToViewRect(region.rect, imageSize: image.size, fittedSize: fitted, origin: origin)
                                RegionOverlay(rect: viewRect, color: region.color, selected: region.isSelected)
                                    .gesture(dragGesture(for: $region, fittedSize: fitted, origin: origin))
                                    .onTapGesture { region.isSelected.toggle() }
                            }
                        }
                }
            }
            .background(Color.black.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if let errorMessage { Text(errorMessage).foregroundColor(.red) }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach($editableRegions) { $region in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Circle().fill(region.color).frame(width: 10, height: 10)
                                Toggle("Include", isOn: $region.isSelected)
                            }
                            Text(String(format: "conf: %.2f", region.confidence))
                                .font(.caption)
                            HStack {
                                Button("−") { resize(&region, scale: 0.95) }
                                Button("+") { resize(&region, scale: 1.05) }
                            }
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
                    }
                }
                .padding(.horizontal)
            }

            HStack {
                Button("Retake") { dismiss() }
                Spacer()
                Button("Close") {
                    NotificationCenter.default.post(name: .closePlateScanFlow, object: nil)
                    dismiss()
                }
                Spacer()
                Button(action: confirm) {
                    if viewModel.isAnalyzing { ProgressView() } else { Text("Analyze") }
                }
                .disabled(viewModel.isAnalyzing || editableRegions.allSatisfy { !$0.isSelected })
            }
        }
        .padding()
        .onAppear(perform: detect)
    }

    private func detect() {
        isLoading = true
        Task { @MainActor in
            let results = viewModel.detectFoodRegions(in: image, maxRegions: 5)
            let colors: [Color] = [.yellow, .green, .blue, .orange, .pink, .purple]
            self.editableRegions = results.enumerated().map { idx, r in
                EditableRegion(rect: r.boundingBox, confidence: r.confidence, isSelected: true, color: colors[idx % colors.count])
            }
            isLoading = false
        }
    }

    private func confirm() {
        let selected = editableRegions.filter { $0.isSelected }
        guard !selected.isEmpty else { return }
        // Build results from the edited rects
        let results: [ImagePreprocessor.Result] = selected.compactMap { er in
            guard let cropped = crop(image: image, to: er.rect) else { return nil }
            let px = Int(cropped.size.width * cropped.size.height)
            return ImagePreprocessor.Result(image: cropped, boundingBox: er.rect.integral, pixelCount: px, confidence: er.confidence)
        }
        Task { @MainActor in
            await viewModel.analyzeSelectedRegions(results, originalImage: image, modelContext: modelContext)
            dismiss()
        }
    }

    private func dragGesture(for region: Binding<EditableRegion>, fittedSize: CGSize, origin: CGPoint) -> some Gesture {
        let regionID = region.wrappedValue.id
        return DragGesture()
            .onChanged { value in
                // Record the starting rect on first change for this drag
                if dragStartRects[regionID] == nil {
                    dragStartRects[regionID] = region.wrappedValue.rect
                }
                guard let startRect = dragStartRects[regionID] else { return }
                // Convert view-space translation to image-space delta
                let delta = viewDeltaToImageDelta(value.translation, imageSize: image.size, fittedSize: fittedSize)
                var newOrigin = CGPoint(x: startRect.origin.x + delta.width,
                                        y: startRect.origin.y + delta.height)
                // Clamp within image bounds
                newOrigin.x = max(0, min(image.size.width - startRect.size.width, newOrigin.x))
                newOrigin.y = max(0, min(image.size.height - startRect.size.height, newOrigin.y))
                region.wrappedValue.rect = CGRect(origin: newOrigin, size: startRect.size)
            }
            .onEnded { _ in
                // Clear the stored start rect at end
                dragStartRects[regionID] = nil
            }
    }

    private func resize(_ region: inout EditableRegion, scale: CGFloat) {
        var rect = region.rect
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var newSize = CGSize(width: rect.width * scale, height: rect.height * scale)
        newSize.width = max(12, min(image.size.width, newSize.width))
        newSize.height = max(12, min(image.size.height, newSize.height))
        var newOrigin = CGPoint(x: center.x - newSize.width / 2, y: center.y - newSize.height / 2)
        newOrigin.x = max(0, min(image.size.width - newSize.width, newOrigin.x))
        newOrigin.y = max(0, min(image.size.height - newSize.height, newOrigin.y))
        region.rect = CGRect(origin: newOrigin, size: newSize)
    }

    // MARK: - Geometry helpers

    private func fittedImageSize(in container: CGSize, imageSize: CGSize) -> CGSize {
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    private func imageRectToViewRect(_ rect: CGRect, imageSize: CGSize, fittedSize: CGSize, origin: CGPoint) -> CGRect {
        let sx = fittedSize.width / imageSize.width
        let sy = fittedSize.height / imageSize.height
        let x = origin.x + rect.origin.x * sx
        let y = origin.y + rect.origin.y * sy
        let w = rect.width * sx
        let h = rect.height * sy
        return CGRect(x: x, y: y, width: w, height: h)
    }

    private func viewDeltaToImageDelta(_ delta: CGSize, imageSize: CGSize, fittedSize: CGSize) -> CGSize {
        let sx = imageSize.width / fittedSize.width
        let sy = imageSize.height / fittedSize.height
        return CGSize(width: delta.width * sx, height: delta.height * sy)
    }
}

private struct RegionOverlay: View {
    let rect: CGRect
    let color: Color
    let selected: Bool

    var body: some View {
        Rectangle()
            .path(in: rect)
            .stroke(selected ? color : color.opacity(0.4), lineWidth: selected ? 3 : 1.5)
            .overlay(
                Rectangle()
                    .path(in: rect)
                    .fill(color.opacity(selected ? 0.12 : 0.06))
            )
    }
}

// Local crop helper (image pixel coordinates)
private func crop(image: UIImage, to rect: CGRect) -> UIImage? {
    guard let cg = image.cgImage else { return nil }
    let scale = image.scale
    let pixelRect = CGRect(x: rect.origin.x * scale,
                           y: rect.origin.y * scale,
                           width: rect.size.width * scale,
                           height: rect.size.height * scale)
    guard let croppedCG = cg.cropping(to: pixelRect) else { return nil }
    return UIImage(cgImage: croppedCG, scale: scale, orientation: image.imageOrientation)
}
