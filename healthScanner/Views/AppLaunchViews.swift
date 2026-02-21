import SwiftUI
import Foundation
import UIKit

struct LaunchStaticBackgroundView: View {
    var body: some View {
        LaunchStoryboardReplicaView()
            .ignoresSafeArea()
    }
}

private struct LaunchStoryboardReplicaView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        if let vc = UIStoryboard(name: "LaunchScreenFresh", bundle: nil).instantiateInitialViewController() {
            let launchView = vc.view ?? UIView()
            launchView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(launchView)

            NSLayoutConstraint.activate([
                launchView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                launchView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                launchView.topAnchor.constraint(equalTo: container.topAnchor),
                launchView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        } else {
            // Keep a sane fallback if the storyboard can't be instantiated.
            container.backgroundColor = UIColor(red: 0.976, green: 0.969, blue: 0.949, alpha: 1.0)
        }

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct SplashOverlayView: View {
    let startTime: Date
    let duration: TimeInterval
    @State private var overlayOpacity: Double = 0

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let elapsed = max(0, timeline.date.timeIntervalSince(startTime))
                let progress = CGFloat(min(1, elapsed / max(duration, 0.001)))
                let pulse = 0.5 + 0.5 * sin(elapsed * 8.5)
                let canvas = geometry.size
                let designSize = CGSize(width: 393, height: 852)
                let scale = max(canvas.width / designSize.width, canvas.height / designSize.height)
                let fittedSize = CGSize(width: designSize.width * scale, height: designSize.height * scale)
                let origin = CGPoint(x: (canvas.width - fittedSize.width) / 2, y: (canvas.height - fittedSize.height) / 2)

                ZStack(alignment: .topLeading) {
                    animatedBarsOverlay(progress: progress, pulse: pulse)
                        .scaleEffect(scale, anchor: .topLeading)
                        .offset(x: origin.x, y: origin.y)
                }
                .frame(width: canvas.width, height: canvas.height)
                .ignoresSafeArea()
            }
        }
        .opacity(overlayOpacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.18)) {
                overlayOpacity = 1
            }
        }
    }

    private func animatedBarsOverlay(progress: CGFloat, pulse: Double) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear.frame(width: 393, height: 852)

            VStack(spacing: 9) {
                progressBar(index: 0, minWidth: 30, maxWidth: 56, alpha: 0.30, progress: progress, pulse: pulse)
                progressBar(index: 1, minWidth: 34, maxWidth: 74, alpha: 0.60, progress: progress, pulse: pulse)
                progressBar(index: 2, minWidth: 26, maxWidth: 46, alpha: 1.00, progress: progress, pulse: pulse)
                progressBar(index: 3, minWidth: 32, maxWidth: 64, alpha: 0.40, progress: progress, pulse: pulse)
            }
            .frame(width: 74, height: 57)
            .offset(x: 160, y: 378)

            rotatingTagline(progress: progress)
                .frame(width: 300)
                .offset(x: 46, y: 458)
        }
    }

    private func progressBar(
        index: Int,
        minWidth: CGFloat,
        maxWidth: CGFloat,
        alpha: Double,
        progress: CGFloat,
        pulse: Double
    ) -> some View {
        let segmentSize: CGFloat = 0.25
        let segmentStart = CGFloat(index) * segmentSize
        let localProgress = max(0, min(1, (progress - segmentStart) / segmentSize))
        let currentWidth = minWidth + (maxWidth - minWidth) * localProgress
        let isCurrentSegment = progress >= segmentStart && progress < (segmentStart + segmentSize)
        let pulseBoost = isCurrentSegment ? 0.12 * pulse : 0

        return Rectangle()
            .fill(Color.midnightSpruce.opacity(min(alpha + localProgress * 0.28 + pulseBoost, 1.0)))
            .frame(width: currentWidth, height: 7)
    }

    private func rotatingTagline(progress: CGFloat) -> some View {
        let taglines = [
            "Eat with insight.",
            "See food differently.",
            "Know what you eat.",
            "Snap a plate.",
            "Scan a label.",
            "Skip the guesswork."
        ]
        let cycleDuration: CGFloat = 2.15
        let totalCycle = cycleDuration * CGFloat(taglines.count)
        let phase = (progress * CGFloat(duration)).truncatingRemainder(dividingBy: totalCycle)
        let currentIndex = min(taglines.count - 1, Int(phase / cycleDuration))
        let nextIndex = (currentIndex + 1) % taglines.count
        let local = phase.truncatingRemainder(dividingBy: cycleDuration)
        let t = local / cycleDuration
        let crossfadeStart: CGFloat = 0.62
        let crossfade = max(0, min(1, (t - crossfadeStart) / (1 - crossfadeStart)))
        let smoothed = crossfade * crossfade * (3 - 2 * crossfade)
        let currentOpacity = 1 - smoothed
        let nextOpacity = smoothed

        return ZStack {
            Text(taglines[currentIndex])
                .opacity(Double(currentOpacity))

            Text(taglines[nextIndex])
                .opacity(Double(nextOpacity))
        }
        .font(.system(size: 14, weight: .medium, design: .rounded))
        .foregroundStyle(Color.midnightSpruce.opacity(0.92))
        .multilineTextAlignment(.center)
        .lineSpacing(2)
    }
}
