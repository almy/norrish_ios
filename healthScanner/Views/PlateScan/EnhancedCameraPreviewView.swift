import SwiftUI
import UIKit

final class LiveClassificationState: ObservableObject {
    @Published var label: String = "Scanning food…"
    @Published var confidence: Float = 0
    @Published var isRunning: Bool = false
}

extension Notification.Name {
    static let enhancedCapturePhoto = Notification.Name("enhancedCapturePhoto")
    static let liveFoodDetectionUpdate = Notification.Name("liveFoodDetectionUpdate")
}

struct EnhancedCameraPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var state = LiveClassificationState()
    private let onCaptured: (UIImage, Float?, Float?, DepthFrameSnapshot?, String?, Float?) -> Void

    init(onCaptured: @escaping (UIImage, Float?, Float?, DepthFrameSnapshot?, String?, Float?) -> Void) {
        self.onCaptured = onCaptured
    }

    var body: some View {
        ZStack {
            CameraControllerRepresentable(state: state, onCaptured: onCaptured, onCancel: dismiss.callAsFunction)
                .ignoresSafeArea()
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        NotificationCenter.default.post(name: .enhancedCapturePhoto, object: nil)
                    } label: {
                        Circle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 65, height: 65)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 32)
                    Spacer()
                }
            }
            .allowsHitTesting(true)
        }
    }
}
