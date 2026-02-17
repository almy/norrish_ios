import SwiftUI

struct ProductNotFoundView: View {
    let onBack: () -> Void
    let onScanAgain: () -> Void
    let onAddManually: () -> Void
    let onReport: () -> Void

    @State private var ringRotation: Double = 0
    @State private var glowScale: CGFloat = 1.0
    @State private var scanLineY: CGFloat = 0.22

    var body: some View {
        ZStack(alignment: .top) {
            Color.nordicBone.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    hero
                    card
                }
            }
        }
        .safeAreaInset(edge: .top) { header }
        .task {
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                glowScale = 1.35
            }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                scanLineY = 0.78
            }
        }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.55))
                    Circle().stroke(Color.white.opacity(0.75), lineWidth: 1)
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.midnightSpruce)
                }
                .frame(width: 40, height: 40)
            }

            Spacer()

            HStack(spacing: 8) {
                Circle().fill(Color.momentumAmber).frame(width: 7, height: 7)
                Text("Not Recognised")
                    .font(AppFonts.sans(10, weight: .bold))
                    .textCase(.uppercase)
                    .kerning(2)
                    .foregroundColor(.nordicSlate)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.6))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.75), lineWidth: 1))

            Spacer()

            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var hero: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.89, green: 0.92, blue: 0.95), Color(red: 0.80, green: 0.84, blue: 0.89), Color(red: 0.60, green: 0.66, blue: 0.74)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack {
                Spacer()
                scanGlyph
                Spacer().frame(height: 42)
            }

            LinearGradient(
                colors: [Color.nordicBone.opacity(0), Color.nordicBone.opacity(0.45), Color.nordicBone],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: UIScreen.main.bounds.height * 0.45)
    }

    private var scanGlyph: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color.nordicSlate.opacity(0.15), .clear], center: .center, startRadius: 6, endRadius: 42))
                .frame(width: 86, height: 86)
                .scaleEffect(glowScale)

            Circle()
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [5, 6]))
                .foregroundColor(Color.nordicSlate.opacity(0.3))
                .frame(width: 84, height: 84)
                .rotationEffect(.degrees(ringRotation))

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.42))
                    .frame(width: 64, height: 64)
                    .overlay(Circle().stroke(Color.white.opacity(0.55), lineWidth: 1))

                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.nordicSlate)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.nordicSlate.opacity(0.5), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 34, height: 1.5)
                    .offset(y: (scanLineY - 0.5) * 30)
            }
        }
    }

    private var card: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Text("Product Not Found")
                    .font(AppFonts.serif(36, weight: .semibold))
                    .foregroundColor(.midnightSpruce)
                    .multilineTextAlignment(.center)

                Text("We couldn't match this scan to our collection yet.\nOur AI is always learning. Try again or add it yourself.")
                    .font(AppFonts.sans(14, weight: .regular))
                    .foregroundColor(.nordicSlate)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.bottom, 26)

            VStack(spacing: 12) {
                Text("Possible Reasons")
                    .font(AppFonts.label)
                    .kerning(2)
                    .foregroundColor(.nordicSlate.opacity(0.65))
                    .textCase(.uppercase)

                HStack(spacing: 8) {
                    reasonChip(icon: "drop.triangle", text: "Blurry image")
                    reasonChip(icon: "sun.haze", text: "Low lighting")
                    reasonChip(icon: "sparkles.rectangle.stack", text: "New product")
                }
            }
            .padding(.bottom, 26)

            Divider().overlay(Color.softDivider)

            VStack(spacing: 12) {
                Button(action: onScanAgain) {
                    HStack(spacing: 10) {
                        Image(systemName: "camera")
                        Text("Scan Again")
                            .kerning(2)
                    }
                    .font(AppFonts.sans(12, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(Color.midnightSpruce)
                    .clipShape(Capsule())
                }

                Button(action: onAddManually) {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.pencil")
                        Text("Add Manually")
                            .kerning(2)
                    }
                    .font(AppFonts.sans(12, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundColor(.midnightSpruce)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .overlay(Capsule().stroke(Color.cardBorder, lineWidth: 1))
                }

                Button(action: onReport) {
                    HStack(spacing: 6) {
                        Image(systemName: "flag")
                            .font(.system(size: 11, weight: .regular))
                        Text("Help us learn — report this item")
                            .font(AppFonts.sans(12, weight: .regular))
                    }
                    .foregroundColor(.nordicSlate.opacity(0.75))
                }
                .padding(.top, 2)
            }
            .padding(.top, 24)
        }
        .padding(.horizontal, 24)
        .padding(.top, 44)
        .padding(.bottom, 40)
        .background(
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(Color.white)
        )
        .offset(y: -26)
    }

    private func reasonChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .light))
            Text(text)
                .font(AppFonts.sans(11, weight: .medium))
        }
        .foregroundColor(.nordicSlate)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.cardSurface)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.cardBorder, lineWidth: 1))
    }
}

