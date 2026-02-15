import UIKit
import Vision
import CoreML
import CoreImage

public final class SegmentationEnhancer {
    private static var cachedModel: VNCoreMLModel?

    private static func loadModel() -> VNCoreMLModel? {
        if let cached = cachedModel {
            return cached
        }

        let config = MLModelConfiguration()
        config.computeUnits = .all

        let bundle = Bundle.main
        let modelNames = ["yolov8x-oiv7"]
        let modelExtensions = ["mlmodelc", "mlpackage"]
        let subdirectory = "CoreML"

        for modelName in modelNames {
            for ext in modelExtensions {
                if let url = bundle.url(forResource: modelName, withExtension: ext) ?? bundle.url(forResource: modelName, withExtension: ext, subdirectory: subdirectory) {
                    do {
                        let mlModel = try MLModel(contentsOf: url, configuration: config)
                        let vnModel = try VNCoreMLModel(for: mlModel)
                        cachedModel = vnModel
                        print("✅ [SegEnhance] YOLOv8x model loaded: \(url.lastPathComponent)")
                        return vnModel
                    } catch {
                        continue
                    }
                }
            }
        }
        print("❌ [SegEnhance] YOLOv8x model not found in bundle; falling back")
        return nil
    }

    public init() {}

    public func enhance(_ image: UIImage, preferredVibrance: CGFloat = 0.22) -> UIImage {
        guard let cg = cgImage(from: image) else {
            return image
        }
        let size = CGSize(width: cg.width, height: cg.height)
        let ciContext = CIContext()

        let ciInput = CIImage(cgImage: cg)
        print("📐 [SegEnhance] Input size: \(Int(size.width))x\(Int(size.height))")

        // 1) Try YOLO segmentation-like mask (feature outputs), else detections → boxes, else saliency
        var boxes: [CGRect] = []
        var maskCI: CIImage? = nil
        let yoloModel = Self.loadModel()
        print("🔧 [SegEnhance] YOLO available: \(yoloModel != nil ? "YES" : "NO")")
        if let model = yoloModel {
            let handler = VNImageRequestHandler(cgImage: cg, orientation: cgImagePropertyOrientation(from: image.imageOrientation), options: [:])
            let request = VNCoreMLRequest(model: model)
            request.imageCropAndScaleOption = .scaleFill
            do {
                try handler.perform([request])
                let results = request.results ?? []
                let types = results.map { String(describing: type(of: $0)) }
                let detCount = (results as? [VNRecognizedObjectObservation])?.count ?? 0
                let pbCount = results.compactMap { $0 as? VNPixelBufferObservation }.count
                let fvCount = results.compactMap { $0 as? VNCoreMLFeatureValueObservation }.count
                print("🔎 [SegEnhance] Vision results types: \(types)")
                print("🔎 [SegEnhance] counts — det:\(detCount), pixbuf:\(pbCount), feat:\(fvCount)")
                if detCount > 0, let dets = results as? [VNRecognizedObjectObservation] {
                    let tops = dets.prefix(3).compactMap { obs -> String? in
                        guard let lab = obs.labels.first else { return nil }
                        return "\(lab.identifier)(\(Int(obs.confidence * 100))%)"
                    }
                    print("🔎 [SegEnhance] top dets: \(tops)")
                }
                if let m = self.segmentationMask(from: results, targetSize: size) {
                    print("🟢 [SegEnhance] Using YOLO feature mask")
                    maskCI = m
                } else if let detections = results as? [VNRecognizedObjectObservation], !detections.isEmpty {
                    let top = detections
                        .sorted(by: { $0.confidence > $1.confidence })
                        .prefix(5)
                        .filter { $0.confidence >= 0.20 }
                        .map { Self.denormalizeVisionRect($0.boundingBox, imageSize: size) }
                    boxes.append(contentsOf: top)
                    print("🟢 [SegEnhance] YOLO detections used: \(boxes.count)")
                }
            } catch {
                print("❌ [SegEnhance] YOLO Vision perform error: \(error)")
                // fall through to saliency
            }
        }

        // 2) Saliency fallback if neither mask nor boxes available
        if maskCI == nil && boxes.isEmpty {
            let salReq = VNGenerateAttentionBasedSaliencyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cg, orientation: cgImagePropertyOrientation(from: image.imageOrientation), options: [:])
            do {
                try handler.perform([salReq])
                if let obs = salReq.results?.first as? VNSaliencyImageObservation,
                   let salient = obs.salientObjects, !salient.isEmpty {
                    boxes = salient.map { Self.denormalizeVisionRect($0.boundingBox, imageSize: size) }
                    print("🟡 [SegEnhance] Saliency boxes used: \(boxes.count)")
                }
            } catch {
                // ignore
            }
        }

        // 3) If still nothing at all, do global simple enhance
        if maskCI == nil && boxes.isEmpty {
            print("⚪️ [SegEnhance] Global fallback (simple vibrance)")
            return simpleGlobalEnhance(image, vibrance: preferredVibrance)
        }

        // Build/soften mask
        if maskCI == nil {
            // Expand boxes by ~6% to capture plate edges
            let padX: CGFloat = (size.width) * 0.06
            let padY: CGFloat = (size.height) * 0.06
            let expanded = boxes.map { r in
                CGRect(x: max(0, r.origin.x - padX),
                       y: max(0, r.origin.y - padY),
                       width: min(size.width - max(0, r.origin.x - padX), r.width + 2*padX),
                       height: min(size.height - max(0, r.origin.y - padY), r.height + 2*padY))
            }
            maskCI = makeMask(size: size, boxes: expanded)
        }
        guard let maskCI else {
            return simpleGlobalEnhance(image, vibrance: preferredVibrance)
        }
        let softenedMask = maskCI
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 3.0])

        // Prepare base CIImage
        let baseCI = CIImage(cgImage: cg)

        // Subject variant: vibrance + unsharp mask
        let subjectVibrance = baseCI.applyingFilter("CIVibrance", parameters: ["inputAmount": preferredVibrance])
        let subject = subjectVibrance.applyingFilter("CIUnsharpMask", parameters: ["inputRadius": 2.0, "inputIntensity": 0.6])

        // Background variant: slight blur + reduced saturation
        let backgroundBlur = baseCI.applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 1.5])
        let background = backgroundBlur.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0.85])

        // Composite with mask
        guard let blendFilter = CIFilter(name: "CIBlendWithMask") else {
            return image
        }
        blendFilter.setValue(subject, forKey: kCIInputImageKey)
        blendFilter.setValue(background, forKey: kCIInputBackgroundImageKey)
        blendFilter.setValue(softenedMask, forKey: kCIInputMaskImageKey)
        guard let outputCI = blendFilter.outputImage else {
            return image
        }

        // Render output
        if let outputCG = ciContext.createCGImage(outputCI, from: outputCI.extent) {
            return UIImage(cgImage: outputCG, scale: image.scale, orientation: image.imageOrientation)
        }
        return image
    }

    private func cgImage(from image: UIImage) -> CGImage? {
        if let cgImage = image.cgImage {
            return cgImage
        }
        // Try rendering to CGImage if UIImage.cgImage is nil
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let renderedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return renderedImage.cgImage
    }

    private static func denormalizeVisionRect(_ rect: CGRect, imageSize: CGSize) -> CGRect {
        // Vision rect: normalized with origin bottom-left
        // Convert to pixel rect with origin top-left
        let x = rect.origin.x * imageSize.width
        let height = rect.size.height * imageSize.height
        let y = (1 - rect.origin.y - rect.size.height) * imageSize.height
        let width = rect.size.width * imageSize.width
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func makeMask(size: CGSize, boxes: [CGRect]) -> CIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 1)
        guard let ctx = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: size))
        }
        ctx.setFillColor(UIColor.black.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        ctx.setFillColor(UIColor.white.cgColor)
        for box in boxes {
            ctx.fill(box)
        }
        let maskImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        if let cgMask = maskImage?.cgImage {
            return CIImage(cgImage: cgMask)
        }
        return CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: size))
    }

    private func simpleGlobalEnhance(_ image: UIImage, vibrance: CGFloat) -> UIImage {
        guard let cgImage = cgImage(from: image) else { return image }
        let ciContext = CIContext()
        let inputCI = CIImage(cgImage: cgImage)

        // Vibrance filter
        let vibranceOutput = inputCI.applyingFilter("CIVibrance", parameters: ["inputAmount": vibrance])

        // Vignette filter
        let vignetteOutput = vibranceOutput.applyingFilter("CIVignette", parameters: [
            "inputIntensity": 0.3,
            "inputRadius": 2.0 * max(inputCI.extent.width, inputCI.extent.height)
        ])

        if let outputCG = ciContext.createCGImage(vignetteOutput, from: vignetteOutput.extent) {
            return UIImage(cgImage: outputCG, scale: image.scale, orientation: image.imageOrientation)
        }
        return image
    }


    private func segmentationMask(from results: [VNObservation], targetSize: CGSize) -> CIImage? {
        // Prefer pixel buffer observations
        if let pbObs = results.compactMap({ $0 as? VNPixelBufferObservation }).first {
            let ci = CIImage(cvPixelBuffer: pbObs.pixelBuffer)
            return ci.resized(to: targetSize)
        }
        // Try feature value observations (multi-array)
        if let fvObs = results.compactMap({ $0 as? VNCoreMLFeatureValueObservation }).first,
           let ma = fvObs.featureValue.multiArrayValue {
            if let ci = ciImage(from: ma) {
                return ci.resized(to: targetSize)
            }
        }
        return nil
    }

    private func ciImage(from multiArray: MLMultiArray) -> CIImage? {
        // Support 2D (H x W) or 3D (C x H x W) or (H x W x C)
        let shape = multiArray.shape.map { Int(truncating: $0) }
        guard !shape.isEmpty else { return nil }

        func makeGrayCI(width: Int, height: Int, pixels: [UInt8]) -> CIImage? {
            let bytesPerRow = width
            guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
            let cg = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 8,
                bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGBitmapInfo(rawValue: 0),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
            return cg.map { CIImage(cgImage: $0) }
        }

        func normalizeTo8bit(_ values: [Float]) -> [UInt8] {
            var minV = values.min() ?? 0
            var maxV = values.max() ?? 1
            if maxV - minV < 1e-6 { maxV = minV + 1e-6 }
            let scale = 255.0 / (maxV - minV)
            return values.map { UInt8(max(0, min(255, Int((($0 - minV) * scale))))) }
        }

        // Accessor for Float data
        func floats(from ma: MLMultiArray) -> [Float] {
            switch ma.dataType {
            case .float32:
                let ptr = UnsafeMutablePointer<Float32>(OpaquePointer(ma.dataPointer))
                return (0..<ma.count).map { Float(ptr[$0]) }
            case .double:
                let ptr = UnsafeMutablePointer<Double>(OpaquePointer(ma.dataPointer))
                return (0..<ma.count).map { Float(ptr[$0]) }
            default:
                // Attempt to coerce via NSNumber
                return (0..<ma.count).compactMap { Float(truncating: ma[$0]) }
            }
        }

        let values = floats(from: multiArray)

        if shape.count == 2 {
            let h = shape[0], w = shape[1]
            let pixels = normalizeTo8bit(values)
            return makeGrayCI(width: w, height: h, pixels: pixels)
        } else if shape.count == 3 {
            // Heuristics: identify C, H, W
            var c = 1, h = 1, w = 1
            if shape[0] < 16 { c = shape[0]; h = shape[1]; w = shape[2] } // [C,H,W]
            else if shape[2] < 16 { h = shape[0]; w = shape[1]; c = shape[2] } // [H,W,C]
            else { // fallback assume [C,H,W]
                c = shape[0]; h = shape[1]; w = shape[2]
            }
            // For each pixel, take max across channels (foregroundness)
            var out: [Float] = Array(repeating: 0, count: h*w)
            if shape[0] == c && shape[1] == h && shape[2] == w { // [C,H,W]
                var idx = 0
                for ch in 0..<c {
                    for y in 0..<h {
                        for x in 0..<w {
                            let i = ch*h*w + y*w + x
                            let p = values[i]
                            let j = y*w + x
                            if p > out[j] { out[j] = p }
                            idx += 1
                        }
                    }
                }
            } else { // [H,W,C]
                var i = 0
                for y in 0..<h {
                    for x in 0..<w {
                        var m: Float = -Float.greatestFiniteMagnitude
                        for ch in 0..<c {
                            let p = values[i + ch]
                            if p > m { m = p }
                        }
                        out[y*w + x] = m
                        i += c
                    }
                }
            }
            let pixels = normalizeTo8bit(out)
            return makeGrayCI(width: w, height: h, pixels: pixels)
        }
        return nil
    }
}
private extension CIImage {
    func resized(to target: CGSize) -> CIImage {
        let w = extent.width
        let h = extent.height
        guard w > 0 && h > 0 else { return self }
        let sx = target.width / w
        let sy = target.height / h
        return self.applyingFilter("CILanczosScaleTransform", parameters: [
            kCIInputScaleKey: max(sx, sy),
            kCIInputAspectRatioKey: target.width / max(1, target.height)
        ]).cropped(to: CGRect(origin: .zero, size: target))
    }
}

// Helper to convert UIImageOrientation to CGImagePropertyOrientation
private func cgImagePropertyOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
    switch orientation {
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
