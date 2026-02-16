import SwiftUI

struct AppInlineSpinner: View {
    var size: CGFloat = 16
    @State private var spinning = false
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.nordicSlate.opacity(0.25), lineWidth: max(1.5, size * 0.12))
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(
                    AngularGradient(
                        colors: [.momentumAmber, .mossInsight, .momentumAmber],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: max(1.8, size * 0.16), lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: spinning)

            Circle()
                .fill(Color.nordicBone.opacity(0.92))
                .frame(width: size * 0.33, height: size * 0.33)
                .scaleEffect(pulsing ? 1.0 : 0.72)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsing)
        }
        .onAppear {
            spinning = true
            pulsing = true
        }
    }
}

struct AppLoadingOverlay: View {
    var title: String = "Loading…"
    var subtitle: String? = nil
    @State private var messageIndex = 0

    private let messages = [
        "Measuring portions",
        "Estimating nutrients",
        "Cross-checking confidence"
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.36).ignoresSafeArea()

            VStack(spacing: 14) {
                AppInlineSpinner(size: 42)

                Text(title)
                    .font(AppFonts.sans(14, weight: .semibold))
                    .foregroundColor(.nordicBone)

                Text(subtitle ?? messages[messageIndex % messages.count])
                    .font(AppFonts.sans(12, weight: .regular))
                    .foregroundColor(.nordicBone.opacity(0.82))
                    .transition(.opacity)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.midnightSpruce.opacity(0.9))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.nordicBone.opacity(0.18), lineWidth: 1)
                    )
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Loading")
            .accessibilityHint(title)
        }
        .task {
            while true {
                try? await Task.sleep(nanoseconds: 1_100_000_000)
                withAnimation(.easeInOut(duration: 0.25)) {
                    messageIndex += 1
                }
            }
        }
    }
}

