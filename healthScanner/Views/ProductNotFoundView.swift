import SwiftUI

struct ProductNotFoundView: View {
    let onClose: () -> Void
    let onScanAgain: () -> Void
    let onAddManually: () -> Void
    let onReport: () -> Void

    @State private var ringRotation: Double = 0
    @State private var glowScale: CGFloat = 1.0
    @State private var scanLineY: CGFloat = 0.22
    @State private var imageRingScale: CGFloat = 1.0
    @State private var imageRingTilt: Double = -3

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                Color.nordicBone.ignoresSafeArea()

                VStack(spacing: 0) {
                    hero(height: max(220, proxy.size.height * 0.33))
                    card
                    Spacer(minLength: 0)
                }

                HStack {
                    Spacer()
                    Button(action: onClose) {
                        ZStack {
                            Circle().fill(Color.white.opacity(0.55))
                            Circle().stroke(Color.white.opacity(0.75), lineWidth: 1)
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.midnightSpruce)
                        }
                        .frame(width: 40, height: 40)
                    }
                }
                .padding(.trailing, 20)
                .padding(.top, max(-40, proxy.safeAreaInsets.top - 40))
            }
        }
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
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                imageRingScale = 1.08
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                imageRingTilt = 3
            }
        }
    }

    private func hero(height: CGFloat) -> some View {
        ZStack {
            if let inspirational = UIImage(named: "plate_analysis") {
                Image(uiImage: inspirational)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color(red: 0.89, green: 0.92, blue: 0.95), Color(red: 0.80, green: 0.84, blue: 0.89), Color(red: 0.60, green: 0.66, blue: 0.74)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

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
        .frame(height: height)
        .clipped()
        .clipShape(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .padding(.horizontal, 10)
    }

    private var scanGlyph: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Color.nordicSlate.opacity(0.15), .clear], center: .center, startRadius: 6, endRadius: 42))
                .frame(width: 86, height: 86)
                .scaleEffect(glowScale)

            Group {
                if let funImage = UIImage(named: "plate_analysis") {
                    Image(uiImage: funImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [Color.momentumAmber.opacity(0.25), Color.mossInsight.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.nordicSlate.opacity(0.8))
                    )
                }
            }
            .frame(width: 84, height: 84)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.45), lineWidth: 1))
            .rotationEffect(.degrees(ringRotation))
            .scaleEffect(imageRingScale)
            .rotation3DEffect(.degrees(imageRingTilt), axis: (x: 0, y: 1, z: 0))

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
                    .font(AppFonts.serif(32, weight: .semibold))
                    .foregroundColor(.midnightSpruce)
                    .multilineTextAlignment(.center)

                Text("We couldn't match this scan to our collection yet.\nOur AI is always learning. Try again or add it yourself.")
                    .font(AppFonts.sans(13, weight: .regular))
                    .foregroundColor(.nordicSlate)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, 18)

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
            .padding(.bottom, 16)

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
                    .frame(height: 56)
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
                    .frame(height: 56)
                    .overlay(Capsule().stroke(Color.cardBorder, lineWidth: 1))
                }

                Button(action: onClose) {
                    Text("Close")
                        .font(AppFonts.sans(12, weight: .semibold))
                        .kerning(1.2)
                        .foregroundColor(.nordicSlate)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .overlay(Capsule().stroke(Color.cardBorder, lineWidth: 1))
                }

                /*
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
                */
            }
            .padding(.top, 18)
        }
        .padding(.horizontal, 24)
        .padding(.top, 30)
        .padding(.bottom, 24)
        .background(
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .fill(Color.white)
        )
        .offset(y: 42)
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

// Preview-only: static callbacks for product-not-found UI review.
#Preview("Product Not Found") {
    ProductNotFoundView(
        onClose: {},
        onScanAgain: {},
        onAddManually: {},
        onReport: {}
    )
}
