import Foundation
import Vision
import CoreML

enum YOLOModelProvider {
    private static var cached: VNCoreMLModel?
    private static let queue = DispatchQueue(label: "enhanced.yolo.model.loader")
    private static var loading = false
    private static var completions: [(VNCoreMLModel?) -> Void] = []

    static func preload() {
        AppLog.debug(AppLog.vision, "🔸 [EnhancedCamera] YOLO prewarm requested")
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
            let loaded = loadSynchronously()
            let elapsedMS = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
            AppLog.debug(AppLog.vision, "✅ [EnhancedCamera] YOLO prewarm complete in \(elapsedMS) ms (success: \(loaded != nil))")
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
        return loadSynchronously()
    }

    private static func loadSynchronously() -> VNCoreMLModel? {
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
