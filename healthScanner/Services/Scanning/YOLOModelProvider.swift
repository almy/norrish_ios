import Foundation
import Vision
import CoreML

enum YOLOModelProvider {
    private static var cached: VNCoreMLModel?

    static func load() -> VNCoreMLModel? {
        if let cached {
            return cached
        }

        let bundle = Bundle.main
        let candidates: [URL?] = [
            bundle.url(forResource: "yolov8x-oiv7", withExtension: "mlmodelc"),
            bundle.url(forResource: "yolov8x-oiv7", withExtension: "mlpackage"),
            bundle.url(forResource: "yolov8x-oiv7", withExtension: "mlmodelc", subdirectory: "CoreML"),
            bundle.url(forResource: "yolov8x-oiv7", withExtension: "mlpackage", subdirectory: "CoreML")
        ]

        for url in candidates {
            if let url {
                do {
                    let cfg = MLModelConfiguration()
                    cfg.computeUnits = .all
                    let ml = try MLModel(contentsOf: url, configuration: cfg)
                    let vn = try VNCoreMLModel(for: ml)
                    cached = vn
                    AppLog.debug(AppLog.vision, "✅ [EnhancedCamera] YOLOv8x model loaded: \(url.lastPathComponent)")
                    return vn
                } catch {
                    continue
                }
            }
        }

        AppLog.debug(AppLog.vision, "ℹ️ [EnhancedCamera] YOLOv8x model not found in bundle; using fallback classifier")
        return nil
    }
}
