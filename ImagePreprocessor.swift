import Foundation
import UIKit
import Vision

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
