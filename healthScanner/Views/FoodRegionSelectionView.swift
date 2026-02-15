import SwiftUI
import Vision
import CoreGraphics
import UIKit

struct FoodRegionSelectionView: View {
    let image: UIImage
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var viewModel: PlateAnalysisViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editableRegions: [EditableRegion] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var dragStartRects: [UUID: CGRect] = [:]
    @State private var lastMagnification: CGFloat = 1.0
    @State private var photoLabel: String = "Food"
    @State private var photoConfidence: Float = 0
    @State private var activeRegionID: UUID?
    @State private var baselineSelectedAreaPx: CGFloat = 0
    @State private var baselineVolumeML: Float?
    @State private var baselineMassG: Float?
    @State private var recalcTask: Task<Void, Never>?
    @State private var recalcGeneration: Int = 0
    @State private var regionCategoryByID: [UUID: (label: String, confidence: Float)] = [:]
    @State private var yoloDetections: [RegionDetection] = []

    struct EditableRegion: Identifiable {
        let id = UUID()
        var rect: CGRect // in image pixel coordinates
        var confidence: Float
        var isSelected: Bool
        var color: Color
    }

    struct RegionDetection {
        let rect: CGRect // in image pixel coordinates
        let label: String
        let confidence: Float
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                titleHeader

                imageCard

                if let errorMessage {
                    Text(errorMessage)
                        .font(AppFonts.sans(11, weight: .medium))
                        .foregroundColor(.momentumAmber)
                }

                infoPanel
                regionDetailCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 24)
        }
        .background(Color.nordicBone.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .onAppear {
            baselineVolumeML = viewModel.transientVolumeML
            baselineMassG = viewModel.transientMassG
            detect()
        }
        .onChange(of: regionsFingerprint) { _, _ in
            scheduleMetadataRefresh()
        }
    }
}

private extension FoodRegionSelectionView {
    var titleHeader: some View {
        Text("Select food areas")
            .font(AppFonts.serif(22, weight: .semibold))
            .foregroundColor(.midnightSpruce)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    var imageCard: some View {
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
                            RegionOverlay(rect: viewRect, color: .momentumAmber, selected: region.isSelected)
                                .gesture(dragGesture(for: $region, fittedSize: fitted, origin: origin))
                                .simultaneousGesture(magnifyGesture(for: $region))
                                .onTapGesture {
                                    activeRegionID = region.id
                                    region.isSelected.toggle()
                                }
                        }
                    }
            }
        }
        .aspectRatio(0.8, contentMode: .fit)
        .background(Color.black.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }

    var infoPanel: some View {
        infoCard(title: "Captured Photo Segmentation", lines: photoSegmentationLines)
    }

    func infoCard(title: String, lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFonts.sans(12, weight: .semibold))
            .foregroundColor(.midnightSpruce)
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(AppFonts.sans(11, weight: .regular))
                    .foregroundColor(.nordicSlate)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.45), lineWidth: 1)
                )
        )
    }

    var photoSegmentationLines: [String] {
        let imagePxW = Int(image.size.width * image.scale)
        let imagePxH = Int(image.size.height * image.scale)
        let imageArea = max(1, imagePxW * imagePxH)
        let selectedRegions = editableRegions.filter { $0.isSelected }
        let selectedArea = selectedRegions.reduce(0) { $0 + Int($1.rect.width * $1.rect.height) }
        let selectedPct = Int(Double(selectedArea) / Double(imageArea) * 100)
        let confAvg = selectedRegions.isEmpty ? 0 : selectedRegions.map { $0.confidence }.reduce(0, +) / Float(selectedRegions.count)
        let confMin = selectedRegions.map { $0.confidence }.min() ?? 0
        let confMax = selectedRegions.map { $0.confidence }.max() ?? 0
        let largestRegionArea = selectedRegions.map { Int($0.rect.width * $0.rect.height) }.max() ?? 0
        let largestRegionPct = Int(Double(largestRegionArea) / Double(imageArea) * 100)
        let selectedBBox = combinedBoundingBox(of: selectedRegions.map { $0.rect })
        let bboxPctW = Int(selectedBBox.size.width / max(1, image.size.width) * 100)
        let bboxPctH = Int(selectedBBox.size.height / max(1, image.size.height) * 100)
        let edgeMarginPx = minEdgeMargin(for: selectedBBox, imageSize: image.size)
        let edgeMarginPct = Int((edgeMarginPx / max(1, min(image.size.width, image.size.height))) * 100)
        let suggestion = selectionSuggestion(selectedPct: selectedPct, regionsSelected: selectedRegions.count, edgeMarginPct: edgeMarginPct)
        var lines: [String] = [
            "image_px: \(imagePxW)x\(imagePxH)",
            "label: \(photoLabel)",
            String(format: "confidence: %.2f", photoConfidence),
            "volume_ml: \(formatMetric(viewModel.transientVolumeML))",
            "mass_g_est: \(formatMetric(viewModel.transientMassG))",
            "plate_coverage: \(selectedPct)%",
            "regions_selected: \(selectedRegions.count) of \(editableRegions.count)",
            String(format: "confidence_avg: %.2f (min %.2f / max %.2f)", confAvg, confMin, confMax),
            "largest_region_pct: \(largestRegionPct)%",
            "selected_bbox: \(bboxPctW)% x \(bboxPctH)%",
            "edge_margin: \(Int(edgeMarginPx))px (\(edgeMarginPct)%)",
            "suggestion: \(suggestion)",
            "regions_total: \(editableRegions.count)",
            "regions_selected: \(selectedRegions.count)",
            "selected_area_px: \(selectedArea) (\(selectedPct)%)"
        ]
        for (idx, region) in editableRegions.enumerated() {
            let area = Int(region.rect.width * region.rect.height)
            let pct = Int(Double(area) / Double(imageArea) * 100)
            let sel = region.isSelected ? "yes" : "no"
            let category = categoryForRegion(region)
            lines.append(String(format: "r%02d sel:%@ conf:%.2f area:%d (%d%%)",
                                idx + 1,
                                sel,
                                region.confidence,
                                area,
                                pct))
            lines.append("r\(String(format: "%02d", idx + 1)) category: \(category)")
        }
        if let active = activeRegion {
            let activeArea = Int(active.rect.width * active.rect.height)
            let activePct = Int(Double(activeArea) / Double(imageArea) * 100)
            lines.append(String(format: "active_region_conf: %.2f", active.confidence))
            lines.append("active_region_selected: \(active.isSelected ? "yes" : "no")")
            lines.append("active_region_area_px: \(activeArea) (\(activePct)%)")
            lines.append("active_region_size_px: \(Int(active.rect.width))x\(Int(active.rect.height))")
        }
        return lines
    }

    var regionsFingerprint: String {
        editableRegions.map { region in
            let x = Int(region.rect.origin.x.rounded())
            let y = Int(region.rect.origin.y.rounded())
            let w = Int(region.rect.size.width.rounded())
            let h = Int(region.rect.size.height.rounded())
            return "\(region.id.uuidString.prefix(6)):\(x),\(y),\(w),\(h),\(region.isSelected ? 1 : 0)"
        }
        .joined(separator: "|")
    }

    func formatMetric(_ value: Float?) -> String {
        guard let value else { return "n/a" }
        return String(Int(round(value)))
    }

    func combinedBoundingBox(of rects: [CGRect]) -> CGRect {
        guard let first = rects.first else { return .zero }
        var box = first
        for rect in rects.dropFirst() {
            box = box.union(rect)
        }
        return box
    }

    func minEdgeMargin(for rect: CGRect, imageSize: CGSize) -> CGFloat {
        guard rect != .zero else { return min(imageSize.width, imageSize.height) }
        let left = rect.minX
        let top = rect.minY
        let right = max(0, imageSize.width - rect.maxX)
        let bottom = max(0, imageSize.height - rect.maxY)
        return min(left, top, right, bottom)
    }

    func selectionSuggestion(selectedPct: Int, regionsSelected: Int, edgeMarginPct: Int) -> String {
        if regionsSelected == 0 {
            return "Select at least one region."
        }
        if selectedPct < 25 {
            return "Low coverage — consider zooming in."
        }
        if regionsSelected > 3 {
            return "Many regions — consider focusing on the plate."
        }
        if edgeMarginPct < 3 {
            return "Selection near edge — ensure full plate is visible."
        }
        return "Selection looks good."
    }

    var regionDetailCard: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.momentumAmber)
                        .frame(width: 10, height: 10)
                    Text("Include")
                        .font(AppFonts.sans(13, weight: .medium))
                        .foregroundColor(.midnightSpruce)
                }
                Spacer()
                toggle
            }

            Divider().opacity(0.15)

            HStack {
                Text(String(format: "conf: %.2f", currentConfidence))
                    .font(AppFonts.sans(11, weight: .regular))
                    .foregroundColor(.nordicSlate)
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
                HStack(spacing: 16) {
                    iconButton(system: "minus") { adjustFirstRegion(scale: 0.95) }
                    iconButton(system: "plus") { adjustFirstRegion(scale: 1.05) }
                }
                .foregroundColor(.momentumAmber)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.5), lineWidth: 1)
                )
        )
    }

    var bottomBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.nordicBone.opacity(0.0), Color.nordicBone],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 30)
            HStack(spacing: 12) {
                Button("Retake") { dismiss() }
                    .buttonStyle(FRNeutralOutlineButtonStyle())
                    .frame(maxWidth: .infinity)

                Button("Close") {
                    NotificationCenter.default.post(name: .closePlateScanFlow, object: nil)
                    dismiss()
                }
                .buttonStyle(FRNeutralOutlineButtonStyle())
                .frame(maxWidth: .infinity)

                Button(action: confirm) {
                    if viewModel.isAnalyzing { ProgressView() } else { Text("Analyze") }
                }
                .buttonStyle(FRPrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(viewModel.isAnalyzing || editableRegions.allSatisfy { !$0.isSelected })
                .opacity(editableRegions.allSatisfy { !$0.isSelected } ? 0.6 : 1.0)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .padding(.top, 12)
            .background(Color.nordicBone)
        }
    }

    var currentConfidence: Float {
        activeRegion?.confidence ?? editableRegions.first?.confidence ?? 0
    }

    var toggle: some View {
        Toggle("", isOn: bindingForActiveRegion)
            .labelsHidden()
            .toggleStyle(FRPillToggleStyle(onColor: .mossInsight))
    }

    var bindingForActiveRegion: Binding<Bool> {
        Binding(
            get: { activeRegion?.isSelected ?? editableRegions.first?.isSelected ?? false },
            set: { newValue in
                if let idx = activeRegionIndex {
                    editableRegions[idx].isSelected = newValue
                } else if !editableRegions.isEmpty {
                    editableRegions[0].isSelected = newValue
                }
            }
        )
    }

    func iconButton(system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    func adjustFirstRegion(scale: CGFloat) {
        if let idx = activeRegionIndex {
            resize(&editableRegions[idx], scale: scale)
        } else if !editableRegions.isEmpty {
            resize(&editableRegions[0], scale: scale)
        }
    }

    func detect() {
        isLoading = true
        Task { @MainActor in
            let results = viewModel.detectFoodRegions(in: image, maxRegions: 5)
            let colors: [Color] = [.momentumAmber, .mossInsight, .midnightSpruce, .nordicSlate, .momentumAmber.opacity(0.7), .mossInsight.opacity(0.7)]
            self.editableRegions = results.enumerated().map { idx, r in
                EditableRegion(rect: r.boundingBox, confidence: r.confidence, isSelected: true, color: colors[idx % colors.count])
            }
            self.activeRegionID = self.editableRegions.first?.id
            self.baselineSelectedAreaPx = max(1, self.editableRegions.reduce(0) { $0 + ($1.rect.width * $1.rect.height) })
            await runYOLORegionCategorization()
            self.scheduleMetadataRefresh()
            isLoading = false
        }
    }

    func confirm() {
        let selected = editableRegions.filter { $0.isSelected }
        guard !selected.isEmpty else { return }
        let categories = selected.enumerated().map { idx, region in
            regionCategoryByID[region.id]?.label ?? "Food"
        }
        viewModel.setTransientCategories(categories)
        Task { @MainActor in
            let results: [ImagePreprocessor.Result] = selected.compactMap { er in
                guard let cropped = crop(image: image, to: er.rect) else { return nil }
                let px = Int(cropped.size.width * cropped.size.height)
                return ImagePreprocessor.Result(image: cropped, boundingBox: er.rect.integral, pixelCount: px, confidence: er.confidence)
            }
            await viewModel.analyzeSelectedRegions(results, originalImage: image, modelContext: modelContext)
            dismiss()
        }
    }

    func dragGesture(for region: Binding<EditableRegion>, fittedSize: CGSize, origin: CGPoint) -> some Gesture {
        let regionID = region.wrappedValue.id
        return DragGesture()
            .onChanged { value in
                activeRegionID = regionID
                if dragStartRects[regionID] == nil {
                    dragStartRects[regionID] = region.wrappedValue.rect
                }
                guard let startRect = dragStartRects[regionID] else { return }
                let delta = viewDeltaToImageDelta(value.translation, imageSize: image.size, fittedSize: fittedSize)
                var newOrigin = CGPoint(x: startRect.origin.x + delta.width,
                                        y: startRect.origin.y + delta.height)
                newOrigin.x = max(0, min(image.size.width - startRect.size.width, newOrigin.x))
                newOrigin.y = max(0, min(image.size.height - startRect.size.height, newOrigin.y))
                region.wrappedValue.rect = CGRect(origin: newOrigin, size: startRect.size)
            }
            .onEnded { _ in
                dragStartRects[regionID] = nil
            }
    }

    func magnifyGesture(for region: Binding<EditableRegion>) -> some Gesture {
        let regionID = region.wrappedValue.id
        return MagnificationGesture()
            .onChanged { value in
                activeRegionID = regionID
                let delta = value / max(0.001, lastMagnification)
                lastMagnification = value
                var updated = region.wrappedValue
                resize(&updated, scale: delta)
                region.wrappedValue = updated
            }
            .onEnded { _ in
                lastMagnification = 1.0
            }
    }

    func resize(_ region: inout EditableRegion, scale: CGFloat) {
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

    func fittedImageSize(in container: CGSize, imageSize: CGSize) -> CGSize {
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        return CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
    }

    func imageRectToViewRect(_ rect: CGRect, imageSize: CGSize, fittedSize: CGSize, origin: CGPoint) -> CGRect {
        let sx = fittedSize.width / imageSize.width
        let sy = fittedSize.height / imageSize.height
        let x = origin.x + rect.origin.x * sx
        let y = origin.y + rect.origin.y * sy
        let w = rect.width * sx
        let h = rect.height * sy
        return CGRect(x: x, y: y, width: w, height: h)
    }

    func viewDeltaToImageDelta(_ delta: CGSize, imageSize: CGSize, fittedSize: CGSize) -> CGSize {
        let sx = imageSize.width / fittedSize.width
        let sy = imageSize.height / fittedSize.height
        return CGSize(width: delta.width * sx, height: delta.height * sy)
    }

    func scheduleMetadataRefresh() {
        recalcGeneration += 1
        let generation = recalcGeneration
        let selectedRects = editableRegions.filter { $0.isSelected }.map { $0.rect }
        let depthSnapshot = viewModel.transientDepthSnapshot
        let fallbackBaseVolume = baselineVolumeML ?? viewModel.transientVolumeML
        let fallbackBaseMass = baselineMassG ?? viewModel.transientMassG
        let fallbackReferenceArea = max(1, baselineSelectedAreaPx)
        let currentSelectedArea = editableRegions
            .filter { $0.isSelected }
            .reduce(CGFloat(0)) { $0 + ($1.rect.width * $1.rect.height) }

        recalcTask?.cancel()
        recalcTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            refreshLabelForCurrentSelection()

            if let depthSnapshot, !selectedRects.isEmpty {
                let metrics = await computeDepthMetricsAsync(
                    snapshot: depthSnapshot,
                    selectedRects: selectedRects,
                    label: photoLabel
                )
                if recalcGeneration == generation {
                    viewModel.setTransientScanMetrics(volumeML: metrics.volumeML, massG: metrics.massG)
                }
            } else if let baseVolume = fallbackBaseVolume, let baseMass = fallbackBaseMass {
                let ratio = max(0, min(3, currentSelectedArea / fallbackReferenceArea))
                let scaledVolume = baseVolume * Float(ratio)
                let scaledMass = baseMass * Float(ratio)
                if recalcGeneration == generation {
                    viewModel.setTransientScanMetrics(volumeML: scaledVolume, massG: scaledMass)
                }
            }
        }
    }

    func computeDepthMetricsAsync(snapshot: DepthFrameSnapshot,
                                  selectedRects: [CGRect],
                                  label: String) async -> (volumeML: Float?, massG: Float?) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let metrics = EnhancedCaptureMetricsEstimator.compute(
                    snapshot: snapshot,
                    selectedRects: selectedRects,
                    label: label
                )
                continuation.resume(returning: metrics)
            }
        }
    }

    func refreshLabelForCurrentSelection() {
        remapDetectionsToEditableRegions()
        guard let active = activeRegion else {
            photoLabel = "Food"
            photoConfidence = 0
            return
        }
        if let category = regionCategoryByID[active.id] {
            photoLabel = category.label
            photoConfidence = category.confidence
        } else {
            photoLabel = "Food"
            photoConfidence = 0
        }
    }

    func runYOLORegionCategorization() async {
        let detections = await detectYOLORegions(in: image)
        yoloDetections = detections
        remapDetectionsToEditableRegions()
        refreshLabelForCurrentSelection()
    }

    func detectYOLORegions(in image: UIImage) async -> [RegionDetection] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let cg = image.cgImage,
                      let model = YOLOModelProvider.load() else {
                    continuation.resume(returning: [])
                    return
                }
                let request = VNCoreMLRequest(model: model)
                request.imageCropAndScaleOption = .scaleFill
                let handler = VNImageRequestHandler(
                    cgImage: cg,
                    orientation: cgImagePropertyOrientation(from: image.imageOrientation),
                    options: [:]
                )
                do {
                    try handler.perform([request])
                    let observations = (request.results as? [VNRecognizedObjectObservation]) ?? []
                    let imageSize = image.size
                    let mapped = observations.compactMap { obs -> RegionDetection? in
                        guard let top = obs.labels.first else { return nil }
                        let rect = denormalizeVisionRect(obs.boundingBox, imageSize: imageSize)
                        return RegionDetection(
                            rect: rect.integral,
                            label: formattedModelLabel(top.identifier),
                            confidence: top.confidence
                        )
                    }
                    continuation.resume(returning: mapped)
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }

    func remapDetectionsToEditableRegions() {
        var mapped: [UUID: (label: String, confidence: Float)] = [:]
        for region in editableRegions {
            let best = yoloDetections
                .map { detection in
                    (detection, overlapRatio(region.rect, detection.rect))
                }
                .max { lhs, rhs in
                    if lhs.1 == rhs.1 {
                        return lhs.0.confidence < rhs.0.confidence
                    }
                    return lhs.1 < rhs.1
                }

            if let best, best.1 > 0.005 {
                mapped[region.id] = (best.0.label, best.0.confidence)
                continue
            }

            if let nearest = nearestDetection(to: region.rect) {
                mapped[region.id] = (nearest.label, nearest.confidence)
                continue
            }

            mapped[region.id] = ("Food", 0)
        }
        regionCategoryByID = mapped
    }

    func nearestDetection(to rect: CGRect) -> RegionDetection? {
        guard !yoloDetections.isEmpty else { return nil }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return yoloDetections.min { lhs, rhs in
            let ld = squaredDistance(center, CGPoint(x: lhs.rect.midX, y: lhs.rect.midY))
            let rd = squaredDistance(center, CGPoint(x: rhs.rect.midX, y: rhs.rect.midY))
            if ld == rd {
                return lhs.confidence < rhs.confidence
            }
            return ld < rd
        }
    }

    func squaredDistance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return dx * dx + dy * dy
    }

    func categoryForRegion(_ region: EditableRegion) -> String {
        regionCategoryByID[region.id]?.label ?? "Food"
    }

    func overlapRatio(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let intersection = a.intersection(b)
        guard !intersection.isNull else { return 0 }
        let interArea = intersection.width * intersection.height
        let denom = max(1, min(a.width * a.height, b.width * b.height))
        return interArea / denom
    }

    func formattedModelLabel(_ raw: String) -> String {
        let trimmed = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: " ")
        guard let first = trimmed.first else { return "Food" }
        return first.uppercased() + trimmed.dropFirst()
    }

    func denormalizeVisionRect(_ rect: CGRect, imageSize: CGSize) -> CGRect {
        let w = rect.width * imageSize.width
        let h = rect.height * imageSize.height
        let x = rect.origin.x * imageSize.width
        let yFromBottom = rect.origin.y * imageSize.height
        let y = imageSize.height - yFromBottom - h
        return CGRect(x: max(0, x), y: max(0, y), width: max(1, w), height: max(1, h))
    }

    var activeRegionIndex: Int? {
        guard let activeRegionID else { return nil }
        return editableRegions.firstIndex(where: { $0.id == activeRegionID })
    }

    var activeRegion: EditableRegion? {
        guard let idx = activeRegionIndex else { return nil }
        return editableRegions[idx]
    }
}

private struct RegionOverlay: View {
    let rect: CGRect
    let color: Color
    let selected: Bool

    var body: some View {
        Rectangle()
            .path(in: rect)
            .stroke(selected ? color : color.opacity(0.4), lineWidth: selected ? 2.5 : 1.5)
            .overlay(
                Rectangle()
                    .path(in: rect)
                    .fill(color.opacity(selected ? 0.10 : 0.05))
            )
    }
}

private struct FRNeutralOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFonts.sans(13, weight: .medium))
            .foregroundColor(.momentumAmber)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(Color.clear)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

private struct FRPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFonts.sans(13, weight: .semibold))
            .foregroundColor(.nordicBone)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                Capsule().fill(Color.midnightSpruce)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}

private struct FRPillToggleStyle: ToggleStyle {
    let onColor: Color

    func makeBody(configuration: Configuration) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(configuration.isOn ? onColor : Color.nordicSlate.opacity(0.3))
            .frame(width: 44, height: 24)
            .overlay(
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .offset(x: configuration.isOn ? 10 : -10)
                    .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
            )
            .onTapGesture { configuration.isOn.toggle() }
    }
}

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

private func cgImagePropertyOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch uiOrientation {
    case .up: return .up
    case .down: return .down
    case .left: return .left
    case .right: return .right
    case .upMirrored: return .upMirrored
    case .downMirrored: return .downMirrored
    case .leftMirrored: return .leftMirrored
    case .rightMirrored: return .rightMirrored
    @unknown default: return .up
    }
}
