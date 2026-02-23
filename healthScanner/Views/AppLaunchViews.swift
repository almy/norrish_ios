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
                    AuroraWavesView(elapsed: elapsed, intensity: 0.92 - (Double(progress) * 0.08))
                        .opacity(0.92)

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

private struct AuroraWavesView: View {
    let elapsed: TimeInterval
    let intensity: Double

    var body: some View {
        Canvas(opaque: false, rendersAsynchronously: true) { context, size in
            let frameTime = CGFloat(elapsed * 60.0)
            let w = size.width
            let h = size.height

            for spec in Self.ribbons {
                let baseY = h * spec.y

                var ribbonFill = Path()
                var ribbonEdge = Path()

                let startX: CGFloat = -30
                let endX = w + 30
                let step: CGFloat = 3

                let firstY = waveY(x: startX, baseY: baseY, t: frameTime, spec: spec)
                ribbonFill.move(to: CGPoint(x: startX, y: firstY))
                ribbonEdge.move(to: CGPoint(x: startX, y: firstY))

                var x = startX + step
                while x <= endX {
                    let y = waveY(x: x, baseY: baseY, t: frameTime, spec: spec)
                    ribbonFill.addLine(to: CGPoint(x: x, y: y))
                    ribbonEdge.addLine(to: CGPoint(x: x, y: y))
                    x += step
                }

                ribbonFill.addLine(to: CGPoint(x: endX, y: h + 50))
                ribbonFill.addLine(to: CGPoint(x: startX, y: h + 50))
                ribbonFill.closeSubpath()

                let color = Color(
                    red: Double(spec.color.0) / 255.0,
                    green: Double(spec.color.1) / 255.0,
                    blue: Double(spec.color.2) / 255.0
                )

                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: spec.blur))
                    layer.fill(
                        ribbonFill,
                        with: .linearGradient(
                            Gradient(stops: [
                                .init(color: color.opacity(0), location: 0.0),
                                .init(color: color.opacity(0.08 * intensity), location: 0.20),
                                .init(color: color.opacity(0.14 * intensity), location: 0.42),
                                .init(color: color.opacity(0.10 * intensity), location: 0.64),
                                .init(color: color.opacity(0), location: 1.0)
                            ]),
                            startPoint: CGPoint(x: w * 0.5, y: baseY - spec.width * 0.7),
                            endPoint: CGPoint(x: w * 0.5, y: baseY + spec.width)
                        )
                    )
                }

                context.stroke(
                    ribbonEdge,
                    with: .color(color.opacity(0.12 * intensity)),
                    lineWidth: 1.35
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func waveY(x: CGFloat, baseY: CGFloat, t: CGFloat, spec: AuroraRibbonSpec) -> CGFloat {
        let wave1 = sin(x * spec.frequency + t * spec.speed + spec.phase) * spec.amplitude
        let wave2 = sin(x * spec.frequency * 1.7 + t * spec.speed * 0.6 + spec.phase + 1.3) * spec.amplitude * 0.35
        let wave3 = cos(x * spec.frequency * 0.4 + t * spec.speed * 1.4 + 0.7) * spec.amplitude * 0.25
        return baseY + wave1 + wave2 + wave3
    }

    private struct AuroraRibbonSpec {
        let y: CGFloat
        let amplitude: CGFloat
        let frequency: CGFloat
        let speed: CGFloat
        let color: (Int, Int, Int)
        let width: CGFloat
        let phase: CGFloat
        let blur: CGFloat
    }

    private static let ribbons: [AuroraRibbonSpec] = [
        .init(y: 0.28, amplitude: 90, frequency: 0.0025, speed: 0.007, color: (72, 180, 130), width: 220, phase: 0.0, blur: 40),
        .init(y: 0.36, amplitude: 70, frequency: 0.0030, speed: 0.005, color: (56, 152, 188), width: 180, phase: 1.5, blur: 35),
        .init(y: 0.48, amplitude: 110, frequency: 0.0020, speed: 0.009, color: (120, 200, 155), width: 260, phase: 3.0, blur: 50),
        .init(y: 0.40, amplitude: 55, frequency: 0.0040, speed: 0.006, color: (180, 160, 220), width: 150, phase: 0.8, blur: 30),
        .init(y: 0.55, amplitude: 80, frequency: 0.0030, speed: 0.008, color: (200, 180, 100), width: 200, phase: 2.2, blur: 45),
        .init(y: 0.32, amplitude: 65, frequency: 0.0035, speed: 0.011, color: (100, 210, 180), width: 170, phase: 4.5, blur: 38),
        .init(y: 0.60, amplitude: 95, frequency: 0.0018, speed: 0.007, color: (90, 170, 210), width: 240, phase: 5.0, blur: 55)
    ]
}
