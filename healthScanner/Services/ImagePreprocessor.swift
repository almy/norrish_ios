import Foundation
import UIKit
import Vision
import CoreML

public struct ImagePreprocessor {
    public struct Result {
        public let image: UIImage
        public let boundingBox: CGRect // in original image pixel coordinates
        public let pixelCount: Int
        public let confidence: Float
    }

    public static func preprocessFoodImage(_ image: UIImage, padding: CGFloat = 0.08) -> Result {
        let originalSize = image.size
        if let regions = Optional(preprocessFoodRegions(image, maxRegions: 1, padding: padding)), let first = regions.first {
            return first
        }
        let roi = CGRect(origin: .zero, size: originalSize)
        let padded = roi
        let cropped = crop(image: image, to: padded) ?? image
        let pxCount = Int(cropped.size.width * cropped.size.height)
        return Result(image: cropped, boundingBox: padded.integral, pixelCount: pxCount, confidence: Float(1.0))
    }

    public static func preprocessFoodRegions(_ image: UIImage, maxRegions: Int = 3, padding: CGFloat = 0.08, confidenceThreshold: Float = 0.05) -> [Result] {
        if let segmented = segmentedFoodRegions(image, maxRegions: maxRegions, padding: padding),
           !segmented.isEmpty {
            return segmented.filter { $0.confidence >= confidenceThreshold }
        }

        guard let cg = cgImage(from: image) else { return [] }
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cg, orientation: cgImagePropertyOrientation(from: image.imageOrientation), options: [:])
        do {
            try handler.perform([request])
            let result = request.results?.first
            let regions = (result?.salientObjects ?? []).map { ($0.boundingBox, $0.confidence) }
            let fallback: [(CGRect, Float)] = regions.isEmpty && result != nil ? [(CGRect(x: 0, y: 0, width: 1, height: 1), Float(1.0))] : []
            let all = (regions + fallback)
                .sorted { $0.1 > $1.1 }
                .prefix(maxRegions)
            let originalSize = image.size
            var outputs: [Result] = []
            for (normRect, conf) in all {
                let denorm = denormalizeVisionRect(normRect, imageSize: originalSize)
                let padded = denorm.insetBy(dx: -denorm.width * padding, dy: -denorm.height * padding)
                    .intersection(CGRect(origin: .zero, size: originalSize))
                let cropped = crop(image: image, to: padded) ?? image
                let px = Int(cropped.size.width * cropped.size.height)
                outputs.append(Result(image: cropped, boundingBox: padded.integral, pixelCount: px, confidence: conf))
            }
            return outputs.filter { $0.confidence >= confidenceThreshold }
        } catch {
            return []
        }
    }

    public static func prewarmSegmentationModel() {
        YOLOSegmentationModelProvider.preload()
    }

    public static func prewarmSegmentationModel(completion: @escaping (Bool) -> Void) {
        YOLOSegmentationModelProvider.getModel { model in
            completion(model != nil)
        }
    }

    public static func mosaic(from results: [Result], columns: Int = 1, spacing: CGFloat = 8, background: UIColor = .black) -> UIImage? {
        guard !results.isEmpty else { return nil }
        let cols = max(1, columns)
        let rows = Int(ceil(Double(results.count) / Double(cols)))
        // Normalize widths to the max width among crops
        let maxWidth = results.map { $0.image.size.width }.max() ?? results[0].image.size.width
        var scaledImages: [UIImage] = []
        for r in results {
            let img = r.image
            if img.size.width == maxWidth {
                scaledImages.append(img)
            } else {
                let scale = maxWidth / max(1, img.size.width)
                let newSize = CGSize(width: maxWidth, height: img.size.height * scale)
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                img.draw(in: CGRect(origin: .zero, size: newSize))
                let out = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                scaledImages.append(out ?? img)
            }
        }
        // Compute canvas size (simple vertical stack if cols == 1)
        if cols == 1 {
            let totalHeight = scaledImages.reduce(0) { $0 + $1.size.height } + spacing * CGFloat(max(0, scaledImages.count - 1))
            let canvas = CGSize(width: maxWidth, height: totalHeight)
            UIGraphicsBeginImageContextWithOptions(canvas, false, 1.0)
            background.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: canvas)).fill()
            var y: CGFloat = 0
            for img in scaledImages {
                img.draw(in: CGRect(x: 0, y: y, width: maxWidth, height: img.size.height))
                y += img.size.height + spacing
            }
            let out = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return out
        } else {
            // Simple grid layout
            let heights = scaledImages.map { $0.size.height }
            let avgHeight = (heights.reduce(0, +) / CGFloat(max(1, heights.count)))
            let tileSize = CGSize(width: maxWidth, height: avgHeight)
            let canvas = CGSize(width: CGFloat(cols) * tileSize.width + CGFloat(cols - 1) * spacing,
                                height: CGFloat(rows) * tileSize.height + CGFloat(rows - 1) * spacing)
            UIGraphicsBeginImageContextWithOptions(canvas, false, 1.0)
            background.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: canvas)).fill()
            for (idx, img) in scaledImages.enumerated() {
                let row = idx / cols
                let col = idx % cols
                let x = CGFloat(col) * (tileSize.width + spacing)
                let y = CGFloat(row) * (tileSize.height + spacing)
                img.draw(in: CGRect(x: x, y: y, width: tileSize.width, height: tileSize.height))
            }
            let out = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            return out
        }
    }
}

private enum YOLOSegmentationModelProvider {
    private static var cached: VNCoreMLModel?
    private static let queue = DispatchQueue(label: "segmentation.model.loader")
    private static var loading = false
    private static var completions: [(VNCoreMLModel?) -> Void] = []

    static func preload() {
        AppLog.debug(AppLog.vision, "🔸 [ImagePreprocessor] Segmentation prewarm requested")
        getModel { _ in }
    }

    static func getModel(completion: @escaping (VNCoreMLModel?) -> Void) {
        queue.async {
            if let cached {
                DispatchQueue.main.async { completion(cached) }
                return
            }
            completions.append(completion)
            if loading { return }
            loading = true
            let start = CFAbsoluteTimeGetCurrent()
            let loaded = load()
            let elapsedMS = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            AppLog.debug(AppLog.vision, "✅ [ImagePreprocessor] Seg prewarm complete in \(elapsedMS) ms (success: \(loaded != nil))")
            let callbacks = completions
            completions.removeAll()
            loading = false
            for cb in callbacks {
                DispatchQueue.main.async { cb(loaded) }
            }
        }
    }

    static func load() -> VNCoreMLModel? {
        if let cached {
            return cached
        }
        let bundle = Bundle.main
        let baseNames = ["YOLO26X-seg", "YOLO26l-seg"]
        let candidates = baseNames.flatMap { baseName in
            [
                bundle.url(forResource: baseName, withExtension: "mlmodelc"),
                bundle.url(forResource: baseName, withExtension: "mlpackage"),
                bundle.url(forResource: baseName, withExtension: "mlmodelc", subdirectory: "CoreML"),
                bundle.url(forResource: baseName, withExtension: "mlpackage", subdirectory: "CoreML")
            ]
        }
        for candidate in candidates {
            guard let url = candidate else { continue }
            do {
                let cfg = MLModelConfiguration()
                cfg.computeUnits = .all
                let ml = try MLModel(contentsOf: url, configuration: cfg)
                let vn = try VNCoreMLModel(for: ml)
                cached = vn
                AppLog.debug(AppLog.vision, "✅ [ImagePreprocessor] Loaded segmentation model: \(url.lastPathComponent)")
                return vn
            } catch {
                continue
            }
        }
        AppLog.debug(AppLog.vision, "ℹ️ [ImagePreprocessor] YOLO26X-seg model not found; falling back to saliency")
        return nil
    }
}

private func segmentedFoodRegions(_ image: UIImage, maxRegions: Int, padding: CGFloat) -> [ImagePreprocessor.Result]? {
    guard let cg = cgImage(from: image),
          let model = YOLOSegmentationModelProvider.load() else {
        return nil
    }

    let request = VNCoreMLRequest(model: model)
    request.imageCropAndScaleOption = .scaleFill
    let handler = VNImageRequestHandler(cgImage: cg, orientation: cgImagePropertyOrientation(from: image.imageOrientation), options: [:])
    do {
        try handler.perform([request])
    } catch {
        AppLog.error(AppLog.vision, "[ImagePreprocessor] Segmentation request failed: \(error.localizedDescription)")
        return nil
    }

    let observations = request.results ?? []
    if let mask = maskBuffer(from: observations) {
        let regions = regionsFromMask(mask, image: image, maxRegions: maxRegions, padding: padding)
        if !regions.isEmpty {
            return regions
        }
    }

    if let detections = observations as? [VNRecognizedObjectObservation], !detections.isEmpty {
        let ranked = detections
            .sorted { $0.confidence > $1.confidence }
            .prefix(maxRegions)
        var outputs: [ImagePreprocessor.Result] = []
        for obs in ranked {
            guard let top = obs.labels.first else { continue }
            let denorm = denormalizeVisionRect(obs.boundingBox, imageSize: image.size)
            let padded = denorm.insetBy(dx: -denorm.width * padding, dy: -denorm.height * padding)
                .intersection(CGRect(origin: .zero, size: image.size))
            guard padded.width >= 2, padded.height >= 2 else { continue }
            let cropped = crop(image: image, to: padded) ?? image
            let px = Int(cropped.size.width * cropped.size.height)
            outputs.append(.init(image: cropped, boundingBox: padded.integral, pixelCount: px, confidence: top.confidence))
        }
        if !outputs.isEmpty {
            AppLog.debug(AppLog.vision, "ℹ️ [ImagePreprocessor] Seg model returned detections but no mask; using box regions")
            return outputs
        }
    }
    return nil
}

private func maskBuffer(from observations: [VNObservation]) -> CVPixelBuffer? {
    if let pixelObs = observations.compactMap({ $0 as? VNPixelBufferObservation }).first {
        return pixelObs.pixelBuffer
    }
    if let featureObs = observations.compactMap({ $0 as? VNCoreMLFeatureValueObservation }).first,
       let multiArray = featureObs.featureValue.multiArrayValue {
        return pixelBufferFromMaskMultiArray(multiArray)
    }
    return nil
}

private func pixelBufferFromMaskMultiArray(_ multiArray: MLMultiArray) -> CVPixelBuffer? {
    guard let decoded = decodeMaskMultiArray(multiArray) else { return nil }
    let width = decoded.width
    let height = decoded.height
    let mask = normalizeToByteMask(decoded.values)

    var buffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_OneComponent8,
        nil,
        &buffer
    )
    guard status == kCVReturnSuccess, let buffer else { return nil }

    CVPixelBufferLockBaseAddress(buffer, [])
    defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
    guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
    let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
    mask.withUnsafeBytes { srcRaw in
        guard let srcBase = srcRaw.baseAddress else { return }
        for row in 0..<height {
            let src = srcBase.advanced(by: row * width)
            let dst = base.advanced(by: row * bytesPerRow)
            memcpy(dst, src, width)
        }
    }
    return buffer
}

private func decodeMaskMultiArray(_ multiArray: MLMultiArray) -> (width: Int, height: Int, values: [Float])? {
    let shape = multiArray.shape.map { Int(truncating: $0) }
    guard !shape.isEmpty else { return nil }
    let raw = multiArrayValues(multiArray)

    if shape.count == 2 {
        let h = shape[0], w = shape[1]
        guard raw.count >= h * w else { return nil }
        return (w, h, Array(raw.prefix(h * w)))
    }

    if shape.count == 3 {
        let d0 = shape[0], d1 = shape[1], d2 = shape[2]
        let (channels, height, width, channelFirst): (Int, Int, Int, Bool)
        if d0 <= d1 && d0 <= d2 {
            channels = d0
            height = d1
            width = d2
            channelFirst = true
        } else if d2 <= d0 && d2 <= d1 {
            channels = d2
            height = d0
            width = d1
            channelFirst = false
        } else {
            channels = d0
            height = d1
            width = d2
            channelFirst = true
        }
        guard channels > 0, height > 0, width > 0 else { return nil }
        var output = Array(repeating: Float.zero, count: height * width)
        if channelFirst {
            for c in 0..<channels {
                let channelOffset = c * height * width
                for idx in 0..<(height * width) {
                    let value = raw[channelOffset + idx]
                    if value > output[idx] {
                        output[idx] = value
                    }
                }
            }
        } else {
            for y in 0..<height {
                for x in 0..<width {
                    let base = (y * width + x) * channels
                    var maxValue = -Float.greatestFiniteMagnitude
                    for c in 0..<channels {
                        let value = raw[base + c]
                        if value > maxValue {
                            maxValue = value
                        }
                    }
                    output[y * width + x] = maxValue
                }
            }
        }
        return (width, height, output)
    }

    return nil
}

private func multiArrayValues(_ multiArray: MLMultiArray) -> [Float] {
    switch multiArray.dataType {
    case .float32:
        let ptr = multiArray.dataPointer.bindMemory(to: Float32.self, capacity: multiArray.count)
        return (0..<multiArray.count).map { Float(ptr[$0]) }
    case .double:
        let ptr = multiArray.dataPointer.bindMemory(to: Double.self, capacity: multiArray.count)
        return (0..<multiArray.count).map { Float(ptr[$0]) }
    case .int32:
        let ptr = multiArray.dataPointer.bindMemory(to: Int32.self, capacity: multiArray.count)
        return (0..<multiArray.count).map { Float(ptr[$0]) }
    default:
        let shape = multiArray.shape.map { Int(truncating: $0) }
        let strides = multiArray.strides.map { Int(truncating: $0) }
        return (0..<multiArray.count).map { linear in
            var remainder = linear
            var indices: [NSNumber] = Array(repeating: 0, count: shape.count)
            for dim in 0..<shape.count {
                let stride = max(1, strides[dim])
                let idx = remainder / stride
                remainder = remainder % stride
                indices[dim] = NSNumber(value: idx)
            }
            return multiArray[indices].floatValue
        }
    }
}

private func normalizeToByteMask(_ values: [Float]) -> [UInt8] {
    guard let minValue = values.min(), let maxValue = values.max() else {
        return []
    }
    let denom = max(1e-6, maxValue - minValue)
    return values.map { value in
        let normalized = (value - minValue) / denom
        return UInt8(max(0, min(255, Int(normalized * 255))))
    }
}

private func regionsFromMask(_ maskBuffer: CVPixelBuffer, image: UIImage, maxRegions: Int, padding: CGFloat) -> [ImagePreprocessor.Result] {
    CVPixelBufferLockBaseAddress(maskBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(maskBuffer, .readOnly) }
    guard let base = CVPixelBufferGetBaseAddress(maskBuffer) else { return [] }

    let width = CVPixelBufferGetWidth(maskBuffer)
    let height = CVPixelBufferGetHeight(maskBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(maskBuffer)
    let threshold: UInt8 = 110
    let minComponentArea = max(24, (width * height) / 800)

    var visited = Array(repeating: false, count: width * height)
    var components: [(rect: CGRect, pixels: Int, confidence: Float)] = []

    func index(_ x: Int, _ y: Int) -> Int { y * width + x }
    func value(_ x: Int, _ y: Int) -> UInt8 {
        let row = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
        return row[x]
    }

    for y in 0..<height {
        for x in 0..<width {
            let startIndex = index(x, y)
            if visited[startIndex] || value(x, y) < threshold { continue }

            var queue: [(Int, Int)] = [(x, y)]
            visited[startIndex] = true
            var q = 0
            var minX = x
            var maxX = x
            var minY = y
            var maxY = y
            var pixelCount = 0
            var sumIntensity: Int = 0

            while q < queue.count {
                let (cx, cy) = queue[q]
                q += 1
                let pixel = Int(value(cx, cy))
                pixelCount += 1
                sumIntensity += pixel
                minX = min(minX, cx)
                maxX = max(maxX, cx)
                minY = min(minY, cy)
                maxY = max(maxY, cy)

                let neighbors = [(cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)]
                for (nx, ny) in neighbors {
                    guard nx >= 0, nx < width, ny >= 0, ny < height else { continue }
                    let idx = index(nx, ny)
                    if visited[idx] { continue }
                    if value(nx, ny) < threshold { continue }
                    visited[idx] = true
                    queue.append((nx, ny))
                }
            }

            guard pixelCount >= minComponentArea else { continue }

            let rectInMask = CGRect(
                x: minX,
                y: minY,
                width: max(1, maxX - minX + 1),
                height: max(1, maxY - minY + 1)
            )
            let confidence = Float(sumIntensity) / Float(max(1, pixelCount * 255))
            components.append((rectInMask, pixelCount, confidence))
        }
    }

    guard !components.isEmpty else { return [] }
    let imageSize = image.size
    let sx = imageSize.width / CGFloat(width)
    let sy = imageSize.height / CGFloat(height)

    return components
        .sorted { lhs, rhs in
            if lhs.confidence == rhs.confidence {
                return lhs.pixels > rhs.pixels
            }
            return lhs.confidence > rhs.confidence
        }
        .prefix(maxRegions)
        .compactMap { component in
            var rect = CGRect(
                x: component.rect.origin.x * sx,
                y: component.rect.origin.y * sy,
                width: component.rect.width * sx,
                height: component.rect.height * sy
            )
            rect = rect.insetBy(dx: -rect.width * padding, dy: -rect.height * padding)
                .intersection(CGRect(origin: .zero, size: imageSize))
            guard rect.width >= 2, rect.height >= 2 else { return nil }
            let cropped = crop(image: image, to: rect) ?? image
            let px = Int(cropped.size.width * cropped.size.height)
            return .init(image: cropped, boundingBox: rect.integral, pixelCount: px, confidence: component.confidence)
        }
}

private func saliencyBoundingBox(for image: UIImage) -> CGRect? {
    guard let cg = cgImage(from: image) else { return nil }
    let request = VNGenerateAttentionBasedSaliencyImageRequest()
    let handler = VNImageRequestHandler(cgImage: cg, orientation: cgImagePropertyOrientation(from: image.imageOrientation), options: [:])
    do {
        try handler.perform([request])
        guard let result = request.results?.first else { return nil }
        // Pick the most salient region
        let regions = result.salientObjects ?? []
        let best = regions.max(by: { ($0.confidence) < ($1.confidence) })?.boundingBox ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        // Vision bounding boxes are in normalized coordinates with origin at bottom-left
        return denormalizeVisionRect(best, imageSize: image.size)
    } catch {
        return nil
    }
}

private func crop(image: UIImage, to rect: CGRect) -> UIImage? {
    guard let cg = cgImage(from: image) else { return nil }
    let scale = image.scale
    let pixelRect = CGRect(x: rect.origin.x * scale,
                           y: rect.origin.y * scale,
                           width: rect.size.width * scale,
                           height: rect.size.height * scale)
    guard let croppedCG = cg.cropping(to: pixelRect) else { return nil }
    return UIImage(cgImage: croppedCG, scale: scale, orientation: image.imageOrientation)
}

private func cgImage(from image: UIImage) -> CGImage? {
    if let cg = image.cgImage { return cg }
    let format = UIGraphicsImageRendererFormat.default()
    format.opaque = false
    format.scale = image.scale
    let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
    let rendered = renderer.image { _ in
        image.draw(at: .zero)
    }
    return rendered.cgImage
}

private func denormalizeVisionRect(_ rect: CGRect, imageSize: CGSize) -> CGRect {
    // Vision rect is normalized (0-1), origin at bottom-left. UIKit has origin at top-left.
    let w = rect.width * imageSize.width
    let h = rect.height * imageSize.height
    let x = rect.origin.x * imageSize.width
    let yFromBottom = rect.origin.y * imageSize.height
    let y = imageSize.height - yFromBottom - h
    return CGRect(x: max(0, x), y: max(0, y), width: max(1, w), height: max(1, h))
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
