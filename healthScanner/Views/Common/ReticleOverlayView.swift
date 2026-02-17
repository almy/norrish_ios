import SwiftUI

struct ReticleOverlayView: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let cornerLength: CGFloat = 28
            let cornerLineWidth: CGFloat = 2
            let circleRadius: CGFloat = 70
            let center = CGPoint(x: w / 2, y: h / 2)
            let cornerColor = Color.white.opacity(0.3)
            let circleColor = Color.white.opacity(0.15)

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: cornerLength))
                    path.addLine(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: cornerLength, y: 0))
                }
                .stroke(cornerColor, lineWidth: cornerLineWidth)

                Path { path in
                    path.move(to: CGPoint(x: w - cornerLength, y: 0))
                    path.addLine(to: CGPoint(x: w, y: 0))
                    path.addLine(to: CGPoint(x: w, y: cornerLength))
                }
                .stroke(cornerColor, lineWidth: cornerLineWidth)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: h - cornerLength))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.addLine(to: CGPoint(x: cornerLength, y: h))
                }
                .stroke(cornerColor, lineWidth: cornerLineWidth)

                Path { path in
                    path.move(to: CGPoint(x: w - cornerLength, y: h))
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: w, y: h - cornerLength))
                }
                .stroke(cornerColor, lineWidth: cornerLineWidth)

                Circle()
                    .stroke(circleColor, lineWidth: 1.5)
                    .frame(width: circleRadius * 2, height: circleRadius * 2)
                    .position(center)
            }
            .padding(24)
        }
    }
}

// Preview-only: overlay on dark gradient to mimic camera contrast.
#Preview("Reticle Overlay") {
    ZStack {
        LinearGradient(
            colors: [Color.black.opacity(0.7), Color.black],
            startPoint: .top,
            endPoint: .bottom
        )
        ReticleOverlayView()
    }
    .frame(height: 360)
}
