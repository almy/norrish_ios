import Foundation
import AVFoundation
import CoreGraphics
import simd

struct DepthFrameSnapshot: @unchecked Sendable {
    let depthMap: CVPixelBuffer
    let intrinsics: simd_float3x3
    let imageSize: CGSize
}

enum EnhancedCaptureMetricsEstimator {
    static func compute(depth: CVPixelBuffer,
                        intrinsics: simd_float3x3,
                        label: String) -> (volumeML: Float?, massG: Float?) {
        let plane = estimatePlane(depth: depth, intrinsics: intrinsics)
        let volumeML = integrateVolume(depth: depth, mask: nil, intrinsics: intrinsics, plane: plane)
        guard volumeML.isFinite, volumeML > 0 else {
            return (nil, nil)
        }

        let density = estimatedDensity(for: label)
        let mass = max(0, volumeML * density)
        return (volumeML, mass)
    }

    static func compute(snapshot: DepthFrameSnapshot,
                        selectedRects: [CGRect],
                        label: String) -> (volumeML: Float?, massG: Float?) {
        let mask = makeSelectionMask(
            selectedRects: selectedRects,
            imageSize: snapshot.imageSize,
            depthWidth: CVPixelBufferGetWidth(snapshot.depthMap),
            depthHeight: CVPixelBufferGetHeight(snapshot.depthMap)
        )
        let plane = estimatePlane(depth: snapshot.depthMap, intrinsics: snapshot.intrinsics)
        let volumeML = integrateVolume(depth: snapshot.depthMap, mask: mask, intrinsics: snapshot.intrinsics, plane: plane)
        guard volumeML.isFinite, volumeML > 0 else {
            return (nil, nil)
        }
        let density = estimatedDensity(for: label)
        let mass = max(0, volumeML * density)
        return (volumeML, mass)
    }

    private static func estimatedDensity(for label: String) -> Float {
        let key = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let defaults: [String: Float] = [
            "rice": 0.80, "pasta": 0.65, "salad": 0.30, "soup": 1.00,
            "meat": 1.05, "chicken": 1.00, "fish": 1.00, "bread": 0.27,
            "potato": 0.75, "food": 0.80
        ]
        return defaults[key] ?? defaults["food"] ?? 0.80
    }

    private static func estimatePlane(depth: CVPixelBuffer, intrinsics: simd_float3x3) -> simd_float4? {
        CVPixelBufferLockBaseAddress(depth, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depth, .readOnly) }

        let width = CVPixelBufferGetWidth(depth)
        let height = CVPixelBufferGetHeight(depth)
        guard let ptr = CVPixelBufferGetBaseAddress(depth)?.assumingMemoryBound(to: Float32.self) else {
            return nil
        }

        let fx = intrinsics.columns.0.x
        let fy = intrinsics.columns.1.y
        let cx = intrinsics.columns.2.x
        let cy = intrinsics.columns.2.y
        guard fx > 0, fy > 0 else { return nil }

        var points: [SIMD3<Float>] = []
        let step = max(2, min(width, height) / 160)

        var y = 0
        while y < height {
            var x = 0
            while x < width {
                let z = ptr[y * width + x]
                if z.isFinite && z > 0 {
                    let xc = (Float(x) - cx) * z / fx
                    let yc = (Float(y) - cy) * z / fy
                    points.append(SIMD3<Float>(xc, yc, z))
                }
                x += step
            }
            y += step
        }
        guard points.count > 50 else { return nil }

        var a: simd_float3x3 = .init(rows: [
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(0, 0, 0)
        ])
        var b = SIMD3<Float>(0, 0, 0)

        for p in points {
            a += simd_float3x3(rows: [
                SIMD3<Float>(p.x * p.x, p.x * p.y, p.x * p.z),
                SIMD3<Float>(p.y * p.x, p.y * p.y, p.y * p.z),
                SIMD3<Float>(p.z * p.x, p.z * p.y, p.z * p.z)
            ])
            b += SIMD3<Float>(-p.x, -p.y, -p.z)
        }

        let n = a.inverse * b
        let normal = simd_normalize(SIMD3<Float>(n.x, n.y, n.z))
        let sum = points.reduce(SIMD3<Float>(0, 0, 0), +)
        let mean = sum / Float(points.count)
        let d = -simd_dot(normal, mean)
        return simd_float4(normal.x, normal.y, normal.z, d)
    }

    private static func integrateVolume(depth: CVPixelBuffer?,
                                        mask: CVPixelBuffer?,
                                        intrinsics: simd_float3x3,
                                        plane: simd_float4?) -> Float {
        guard let depth, let plane else { return 0 }
        CVPixelBufferLockBaseAddress(depth, .readOnly)
        if let mask { CVPixelBufferLockBaseAddress(mask, .readOnly) }
        defer {
            CVPixelBufferUnlockBaseAddress(depth, .readOnly)
            if let mask { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        }

        let width = CVPixelBufferGetWidth(depth)
        let height = CVPixelBufferGetHeight(depth)
        guard let dptr = CVPixelBufferGetBaseAddress(depth)?.assumingMemoryBound(to: Float32.self) else {
            return 0
        }

        var maskWidth = 0
        var maskHeight = 0
        var mptr: UnsafeMutablePointer<UInt8>?
        if let mask {
            maskWidth = CVPixelBufferGetWidth(mask)
            maskHeight = CVPixelBufferGetHeight(mask)
            mptr = CVPixelBufferGetBaseAddress(mask)?.assumingMemoryBound(to: UInt8.self)
        }

        let fx = intrinsics.columns.0.x
        let fy = intrinsics.columns.1.y
        let cx = intrinsics.columns.2.x
        let cy = intrinsics.columns.2.y
        guard fx > 0, fy > 0 else { return 0 }

        let normal = SIMD3<Float>(plane.x, plane.y, plane.z)
        let d = plane.w
        let sx = maskWidth > 0 ? Float(maskWidth) / Float(width) : 1
        let sy = maskHeight > 0 ? Float(maskHeight) / Float(height) : 1

        var volumeM3: Double = 0
        var y = 0
        while y < height {
            var x = 0
            while x < width {
                let z = dptr[y * width + x]
                if z.isFinite && z > 0 {
                    if let mptr {
                        let mx = min(max(Int(Float(x) * sx), 0), maskWidth - 1)
                        let my = min(max(Int(Float(y) * sy), 0), maskHeight - 1)
                        if mptr[my * maskWidth + mx] <= 127 {
                            x += 1
                            continue
                        }
                    }

                    let xc = (Float(x) - cx) * z / fx
                    let yc = (Float(y) - cy) * z / fy
                    let point = SIMD3<Float>(xc, yc, z)
                    let signedDistance = simd_dot(normal, point) + d
                    if signedDistance > 0 {
                        let heightAbovePlane = Double(signedDistance / simd_length(normal))
                        let area = Double((z * z) / (fx * fy))
                        volumeM3 += heightAbovePlane * area
                    }
                }
                x += 1
            }
            y += 1
        }
        return Float(volumeM3 * 1_000_000.0)
    }

    private static func makeSelectionMask(selectedRects: [CGRect],
                                          imageSize: CGSize,
                                          depthWidth: Int,
                                          depthHeight: Int) -> CVPixelBuffer? {
        guard depthWidth > 0, depthHeight > 0, imageSize.width > 0, imageSize.height > 0 else { return nil }
        guard !selectedRects.isEmpty else { return nil }

        var mask: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            depthWidth,
            depthHeight,
            kCVPixelFormatType_OneComponent8,
            nil,
            &mask
        )
        guard status == kCVReturnSuccess, let mask else { return nil }

        CVPixelBufferLockBaseAddress(mask, [])
        defer { CVPixelBufferUnlockBaseAddress(mask, []) }

        guard let ptr = CVPixelBufferGetBaseAddress(mask)?.assumingMemoryBound(to: UInt8.self) else {
            return nil
        }

        let rowBytes = CVPixelBufferGetBytesPerRow(mask)
        memset(ptr, 0, rowBytes * depthHeight)

        let sx = CGFloat(depthWidth) / imageSize.width
        let sy = CGFloat(depthHeight) / imageSize.height

        for rect in selectedRects {
            let minX = max(0, min(depthWidth - 1, Int((rect.minX * sx).rounded(.down))))
            let minY = max(0, min(depthHeight - 1, Int((rect.minY * sy).rounded(.down))))
            let maxX = max(0, min(depthWidth - 1, Int((rect.maxX * sx).rounded(.up))))
            let maxY = max(0, min(depthHeight - 1, Int((rect.maxY * sy).rounded(.up))))
            if minX > maxX || minY > maxY { continue }

            for y in minY...maxY {
                let row = ptr.advanced(by: y * rowBytes)
                for x in minX...maxX {
                    row[x] = 255
                }
            }
        }

        return mask
    }
}
