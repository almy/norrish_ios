import SwiftUI
import Combine

public final class ScanHUDModel: ObservableObject {
    @Published public var progress: CGFloat = 0         // 0...1
    @Published public var hint: String = "Move slightly…"
    @Published public var ringCenter: CGPoint = .zero   // in overlay's coordinate space
    @Published public var ringSize: CGFloat = 220       // diameter
    @Published public var hasDepth: Bool = false        // readiness component (fallback/non‑LiDAR)
    @Published public var planeStable: Bool = false     // readiness component (fallback/non‑LiDAR)
    public init() {}
}

public struct PlateProgressRingView: View {
    @ObservedObject var model: ScanHUDModel

    public init(model: ScanHUDModel) { self.model = model }

    public var body: some View {
        ZStack {
            // top gradient for legibility
            LinearGradient(colors: [.black.opacity(0.45), .clear],
                           startPoint: .top, endPoint: .center)
                .ignoresSafeArea()

            // ring + reticle
            GeometryReader { geo in
                let center = model.ringCenter == .zero
                    ? CGPoint(x: geo.size.width/2, y: geo.size.height/2)
                    : model.ringCenter

                ZStack {
                    // background ring
                    Circle()
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 8)
                        .frame(width: model.ringSize, height: model.ringSize)
                        .position(center)

                    // progress ring
                    Circle()
                        .trim(from: 0, to: max(0.04, min(1, model.progress)))
                        .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .fill(AngularGradient(
                            gradient: Gradient(colors: [.yellow, .orange, .green]),
                            center: .center))
                        .rotationEffect(.degrees(-90))
                        .frame(width: model.ringSize, height: model.ringSize)
                        .position(center)
                        .animation(.easeInOut(duration: 0.22), value: model.progress)

                    // progress percentage label
                    VStack(spacing: 4) {
                        Text("\(Int(model.progress*100))%")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(model.progress >= 0.999 ? .green : .yellow)
                        Text(model.progress >= 0.999 ? "Ready" : "")
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .position(center)
                    .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 3)

                    // status pills (Depth, Plane)
                    let pillY = min(geo.size.height - 50, center.y + model.ringSize/2 + 24)
                    HStack(spacing: 8) {
                        StatusPill(title: "Depth", ok: model.hasDepth)
                        StatusPill(title: "Plane", ok: model.planeStable)
                    }
                    .position(x: center.x, y: pillY)

                    // (Square framing removed per revert request)
                }
            }

            // bottom hint
            VStack {
                Spacer()
                Text(model.hint)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Capsule())
                    .padding(.bottom, 26)
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct StatusPill: View {
    let title: String
    let ok: Bool
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: ok ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(ok ? .green : .gray)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.black.opacity(0.35))
        .clipShape(Capsule())
    }
}
