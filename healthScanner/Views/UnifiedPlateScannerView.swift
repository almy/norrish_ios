import SwiftUI
import UIKit

// MARK: - Unified scan payload returned to callers
struct UnifiedScanPayload {
    struct ScaleInfo {
        let depthSource: String   // e.g. "sceneDepth" or "monocular"
        let depthUnits: String    // e.g. "meters"
    }
    let scaleInfo: ScaleInfo
    let image: UIImage?
    let nutrition: ARPlateScanNutrition?
}

// MARK: - UnifiedPlateScannerView
// Wraps the real scanners and emits a lightweight payload the caller expects.
// Uses ARPlateScannerView when ARKit is available; otherwise provides a simple simulator fallback.
struct UnifiedPlateScannerView: View {
    let onComplete: (UnifiedScanPayload) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if canImport(ARKit)
        UnifiedARWrapper(onComplete: onComplete)
        #else
        SimulatorFallback(onComplete: onComplete)
        #endif
    }
}

#if canImport(ARKit)
import ARKit

private struct UnifiedARWrapper: View {
    let onComplete: (UnifiedScanPayload) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ARPlateScannerView { scan, img in
            // Determine depth source based on device capabilities
            let depthSource = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) ? "sceneDepth" : "monocular"
            let payload = UnifiedScanPayload(
                scaleInfo: .init(depthSource: depthSource, depthUnits: "meters"),
                image: img,
                nutrition: scan
            )
            onComplete(payload)
            dismiss()
        } onCancel: {
            dismiss()
        }
        .ignoresSafeArea()
    }
}
#else

private struct SimulatorFallback: View {
    let onComplete: (UnifiedScanPayload) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isSimulating = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.94).ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Unified Scanner (Simulator)")
                    .font(.title3).bold().foregroundColor(.white)
                if isSimulating {
                    ProgressView("Analyzing…")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                } else {
                    Button {
                        isSimulating = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            let scan = ARPlateScanNutrition(
                                label: "Sample",
                                confidence: 0.7,
                                volumeML: 250,
                                massG: 200,
                                calories: 300,
                                protein: 12,
                                carbs: 35,
                                fat: 10
                            )
                            let img = UIImage(systemName: "fork.knife")?.withTintColor(.white, renderingMode: .alwaysOriginal)
                            let payload = UnifiedScanPayload(
                                scaleInfo: .init(depthSource: "simulator", depthUnits: "meters"),
                                image: img,
                                nutrition: scan
                            )
                            onComplete(payload)
                            dismiss()
                        }
                    } label: {
                        HStack { Image(systemName: "sparkles"); Text("Simulate Scan") }
                            .font(.headline).foregroundColor(.black)
                            .padding(.horizontal, 34).padding(.vertical, 14)
                            .background(Color.green).cornerRadius(28)
                    }
                }
                Button("Cancel", role: .cancel) { dismiss() }
                    .foregroundColor(.white)
            }
            .padding(.top, 60)
        }
    }
}
#endif

#Preview {
    UnifiedPlateScannerView { payload in
        print("Unified payload: depthSource=\(payload.scaleInfo.depthSource), units=\(payload.scaleInfo.depthUnits)")
    }
}
