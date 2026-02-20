import SwiftUI

private enum OnboardingStep: Int, CaseIterable {
    case mission = 1
    case trends = 2
    case plateScan = 3
    case productScan = 4
    case profile = 5
    case tailor = 6
    case ready = 7

    var index: Int { rawValue }
}

struct FirstTimeOnboardingView: View {
    let onComplete: () -> Void

    @EnvironmentObject private var profileIdentity: ProfileIdentityStore
    @EnvironmentObject private var preferencesManager: DietaryPreferencesManager
    @State private var step: OnboardingStep = .mission
    @State private var nameDraft = ""
    @State private var exclusions: Set<String> = ["Low Sodium"]
    @State private var needs: Set<String> = ["Dairy Free", "Plant Based"]
    @State private var focus: String = "Clean Eating"

    private let heroURL = URL(string: "https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=1200&q=80&auto=format")

    var body: some View {
        ZStack {
            Color.nordicBone.ignoresSafeArea()

            Group {
                switch step {
                case .mission: missionScreen
                case .trends: trendsScreen
                case .plateScan: plateScanScreen
                case .productScan: productScanScreen
                case .profile: profileScreen
                case .tailor: tailorScreen
                case .ready: readyScreen
                }
            }
            .id(step.rawValue)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            .animation(.easeInOut(duration: 0.32), value: step)
        }
        .onAppear {
            nameDraft = profileIdentity.displayName
        }
    }
}

private extension FirstTimeOnboardingView {
    var missionScreen: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 16)

            Text("Nourishment\nthrough Insight")
                .font(AppFonts.serif(32, weight: .bold))
                .foregroundColor(.midnightSpruce)
                .multilineTextAlignment(.center)

            Group {
                if let heroURL {
                    AsyncImage(url: heroURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.cardSurface
                    }
                } else {
                    Color.cardSurface
                }
            }
            .frame(height: 330)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.cardBorder, lineWidth: 1)
            )
            .padding(.horizontal, 26)
            .padding(.top, 22)

            Text("Norrish uses your camera to reveal the story behind every bite. No judgment, just intelligence.")
                .font(AppFonts.sans(13, weight: .regular))
                .foregroundColor(.nordicSlate)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 42)
                .padding(.top, 22)

            Spacer()

            primaryButton("Begin Discovery") { next() }
                .padding(.horizontal, 26)
                .padding(.bottom, 14)

            progressDots
                .padding(.bottom, 24)
        }
    }

    var trendsScreen: some View {
        VStack(spacing: 0) {
            onboardingHeader(showBack: false, showSkip: true)
            Spacer(minLength: 8)

            ZStack {
                trendCard("Hydro", "2.4L", tint: .blue.opacity(0.20))
                    .rotationEffect(.degrees(-10))
                    .offset(x: -92, y: 8)
                trendCard("Protein", "112g", tint: .pink.opacity(0.20))
                    .rotationEffect(.degrees(10))
                    .offset(x: 92, y: 8)
                trendCard("Fiber", "+12%", tint: .green.opacity(0.20))
                    .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 10)
            }
            .frame(height: 250)

            titleAndBody(
                title: "Evolve with\nyour Trends",
                body: "We replace rigid targets with adaptive personal patterns that grow with you."
            )
            .padding(.top, 20)

            Spacer()
            primaryButton("Next", icon: "arrow_forward") { next() }
                .padding(.horizontal, 26)
                .padding(.bottom, 34)
        }
    }

    var plateScanScreen: some View {
        VStack(spacing: 0) {
            onboardingHeader(showBack: true, showSkip: true)
            Spacer(minLength: 12)

            ZStack {
                Group {
                    if let heroURL {
                        AsyncImage(url: heroURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Color.black.opacity(0.7)
                        }
                    } else {
                        Color.black.opacity(0.7)
                    }
                }
                .frame(height: 332)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

                Circle()
                    .stroke(Color.white.opacity(0.42), lineWidth: 2)
                    .frame(width: 190, height: 190)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.16), lineWidth: 1).scaleEffect(1.08)
                    )

                HStack(spacing: 8) {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                    Text("Analyzing nutrients...")
                        .font(AppFonts.sans(11, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.58))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .offset(y: 122)
            }
            .padding(.horizontal, 26)

            titleAndBody(
                title: "Snap your\nPlate",
                body: "Point, capture, and understand what's on your plate. AI reveals the nutrition story instantly."
            )
            .padding(.top, 20)

            Spacer()
            primaryButton("Next", icon: "arrow_forward") { next() }
                .padding(.horizontal, 26)
                .padding(.bottom, 34)
        }
    }

    var productScanScreen: some View {
        VStack(spacing: 0) {
            onboardingHeader(showBack: true, showSkip: true)
            Spacer(minLength: 12)

            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.95, green: 0.92, blue: 0.89), Color(red: 0.91, green: 0.89, blue: 0.86)],
                                         startPoint: .topLeading,
                                         endPoint: .bottomTrailing))
                    .frame(height: 332)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
                    .frame(width: 120, height: 162)
                    .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 8)
                    .overlay(
                        VStack(spacing: 10) {
                            Image(systemName: "leaf")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.mossInsight)
                            Text("Organic Oats")
                                .font(AppFonts.sans(9, weight: .semibold))
                                .foregroundColor(.nordicSlate)
                                .textCase(.uppercase)
                            Rectangle()
                                .fill(Color.midnightSpruce)
                                .frame(height: 2)
                                .padding(.horizontal, 18)
                        }
                    )

                Rectangle()
                    .fill(LinearGradient(colors: [Color.clear, Color.primary, Color.clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 2)
                    .padding(.horizontal, 26)

                HStack(spacing: 10) {
                    Text("A")
                        .font(AppFonts.sans(13, weight: .bold))
                        .foregroundColor(.mossInsight)
                        .frame(width: 24, height: 24)
                        .background(Color.mossInsight.opacity(0.16))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nutri-Score A")
                            .font(AppFonts.sans(12, weight: .semibold))
                            .foregroundColor(.midnightSpruce)
                        Text("340 kcal · 12g protein · 8g fiber")
                            .font(AppFonts.sans(10, weight: .regular))
                            .foregroundColor(.nordicSlate)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.95))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .offset(y: 123)
            }
            .padding(.horizontal, 26)

            titleAndBody(
                title: "Scan any\nProduct",
                body: "Scan the barcode, skip the fine print. Instant nutrition data from Swedish databases."
            )
            .padding(.top, 20)

            Spacer()
            primaryButton("Next", icon: "arrow_forward") { step = .profile }
                .padding(.horizontal, 26)
                .padding(.bottom, 34)
        }
    }

    var profileScreen: some View {
        VStack(spacing: 0) {
            onboardingHeader(showBack: true, showSkip: false)

            Text("Create Your\nProfile")
                .font(AppFonts.serif(32, weight: .bold))
                .foregroundColor(.midnightSpruce)
                .multilineTextAlignment(.center)
                .padding(.top, 16)

            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.cardSurface)
                    .frame(width: 96, height: 96)
                    .overlay(Circle().stroke(Color.cardBorder, lineWidth: 1))
                    .overlay(Image(systemName: "person").font(.system(size: 34)).foregroundColor(.nordicSlate))
                Circle()
                    .fill(Color.midnightSpruce)
                    .frame(width: 26, height: 26)
                    .overlay(Image(systemName: "camera.fill").font(.system(size: 10, weight: .bold)).foregroundColor(.white))
            }
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 8) {
                Text("Full Name")
                    .font(AppFonts.sans(11, weight: .semibold))
                    .foregroundColor(.nordicSlate)
                    .textCase(.uppercase)
                    .kerning(1.2)
                TextField("e.g. Eleanor Vane", text: $nameDraft)
                    .font(AppFonts.sans(14, weight: .medium))
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.cardBorder, lineWidth: 1))
            }
            .padding(.horizontal, 26)
            .padding(.top, 28)

            VStack(alignment: .leading, spacing: 12) {
                Text("Exclusions")
                    .font(AppFonts.sans(11, weight: .semibold))
                    .foregroundColor(.nordicSlate)
                    .textCase(.uppercase)
                    .kerning(1.2)
                wrappingChips(["No Peanuts", "Low Sodium", "No Added Sugar", "Gluten Free", "Dairy Free"], selection: $exclusions)
            }
            .padding(.horizontal, 26)
            .padding(.top, 20)

            Spacer()

            primaryButton("Continue", icon: "arrow_forward", tint: .mossInsight) {
                applyProfileStep()
                step = .tailor
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 12)

            Text("Secure & Private")
                .font(AppFonts.sans(10, weight: .medium))
                .foregroundColor(.nordicSlate.opacity(0.7))
                .textCase(.uppercase)
                .kerning(1.6)
                .padding(.bottom, 24)
        }
    }

    var tailorScreen: some View {
        VStack(spacing: 0) {
            onboardingHeader(showBack: true, showSkip: false)

            VStack(alignment: .leading, spacing: 10) {
                Text("Tailor your\nJourney")
                    .font(AppFonts.serif(32, weight: .bold))
                    .foregroundColor(.midnightSpruce)
                Text("Set your baseline preferences. Norrish adapts its insights to match your nutritional goals.")
                    .font(AppFonts.sans(13, weight: .regular))
                    .foregroundColor(.nordicSlate)
                    .lineSpacing(3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 26)
            .padding(.top, 12)

            VStack(alignment: .leading, spacing: 12) {
                Text("Dietary Needs")
                    .font(AppFonts.sans(11, weight: .semibold))
                    .foregroundColor(.nordicSlate)
                    .textCase(.uppercase)
                    .kerning(1.2)
                wrappingChips(["Dairy Free", "Gluten Free", "Plant Based", "Paleo", "Keto"], selection: $needs)
            }
            .padding(.horizontal, 26)
            .padding(.top, 24)

            VStack(alignment: .leading, spacing: 12) {
                Text("Primary Focus")
                    .font(AppFonts.sans(11, weight: .semibold))
                    .foregroundColor(.nordicSlate)
                    .textCase(.uppercase)
                    .kerning(1.2)
                focusChips(["Weight Loss", "Clean Eating", "Muscle Gain"])
            }
            .padding(.horizontal, 26)
            .padding(.top, 20)

            Text("Based on these choices, we'll prioritize plant-based protein alternatives and low-lactose products in your scan results.")
                .font(AppFonts.serif(13, weight: .regular))
                .italic()
                .foregroundColor(.mossInsight.opacity(0.8))
                .lineSpacing(4)
                .padding(.horizontal, 26)
                .padding(.top, 24)

            Spacer()
            primaryButton("Complete Profile", icon: "checkmark.circle.fill", tint: .mossInsight) {
                applyTailorStep()
                step = .ready
            }
            .padding(.horizontal, 26)
            .padding(.bottom, 24)
        }
    }

    var readyScreen: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 36)

            Circle()
                .fill(Color.mossInsight.opacity(0.16))
                .frame(width: 118, height: 118)
                .overlay(Circle().stroke(Color.mossInsight.opacity(0.3), lineWidth: 1))
                .overlay(Image(systemName: "checkmark").font(.system(size: 42, weight: .bold)).foregroundColor(.mossInsight))

            Text("You're Ready")
                .font(AppFonts.serif(34, weight: .bold))
                .foregroundColor(.midnightSpruce)
                .padding(.top, 26)

            Text("Your first insight is one tap away. Start by scanning a meal or a product.")
                .font(AppFonts.sans(13, weight: .regular))
                .foregroundColor(.nordicSlate)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
                .padding(.top, 12)

            VStack(spacing: 10) {
                featureRow(icon: "photo_camera", title: "Meal Analysis", subtitle: "AI-powered nutrition breakdown", tint: .orange.opacity(0.2))
                Divider().background(Color.softDivider)
                featureRow(icon: "qr_code_scanner", title: "Product Scanning", subtitle: "Swedish database with fallback", tint: .purple.opacity(0.2))
                Divider().background(Color.softDivider)
                featureRow(icon: "trending_up", title: "Adaptive Trends", subtitle: "Patterns that evolve with you", tint: .green.opacity(0.2))
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.cardBorder, lineWidth: 1))
            .padding(.horizontal, 26)
            .padding(.top, 24)

            Spacer()

            primaryButton("Snap a Meal", icon: "photo_camera") { onComplete() }
                .padding(.horizontal, 26)

            secondaryButton("Scan a Product", icon: "qr_code_scanner") { onComplete() }
                .padding(.horizontal, 26)
                .padding(.top, 12)
                .padding(.bottom, 30)
        }
    }

    func onboardingHeader(showBack: Bool, showSkip: Bool) -> some View {
        HStack {
            if showBack {
                Button(action: previous) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.nordicSlate)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.cardBorder, lineWidth: 1))
                }
            } else {
                Color.clear.frame(width: 40, height: 40)
            }

            Spacer()
            progressDots
            Spacer()

            if showSkip {
                Button("Skip") { step = .profile }
                    .font(AppFonts.sans(13, weight: .medium))
                    .foregroundColor(.nordicSlate.opacity(0.7))
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    var progressDots: some View {
        HStack(spacing: 5) {
            ForEach(1...OnboardingStep.allCases.count, id: \.self) { idx in
                Capsule()
                    .fill(dotColor(for: idx))
                    .frame(width: 24, height: 4)
            }
        }
    }

    func dotColor(for index: Int) -> Color {
        if index < step.index { return Color.mossInsight.opacity(0.4) }
        if index == step.index { return Color.midnightSpruce }
        return Color.cardBorder
    }

    func next() {
        guard let next = OnboardingStep(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    func previous() {
        guard let prev = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        step = prev
    }

    func titleAndBody(title: String, body: String) -> some View {
        VStack(spacing: 14) {
            Text(title)
                .font(AppFonts.serif(32, weight: .bold))
                .foregroundColor(.midnightSpruce)
                .multilineTextAlignment(.center)
            Text(body)
                .font(AppFonts.sans(13, weight: .regular))
                .foregroundColor(.nordicSlate)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 30)
        }
    }

    func trendCard(_ title: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(tint)
                    .frame(width: 20, height: 20)
                Text(title)
                    .font(AppFonts.sans(10, weight: .bold))
                    .foregroundColor(.nordicSlate)
                    .textCase(.uppercase)
            }
            Spacer()
            Text(value)
                .font(AppFonts.serif(20, weight: .medium))
                .foregroundColor(.midnightSpruce)
        }
        .padding(12)
        .frame(width: 136, height: 180)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.cardBorder, lineWidth: 1))
    }

    func primaryButton(_ title: String, icon: String? = nil, tint: Color = .midnightSpruce, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(AppFonts.sans(14, weight: .semibold))
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                }
            }
            .foregroundColor(.nordicBone)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(tint)
            .clipShape(Capsule())
        }
    }

    func secondaryButton(_ title: String, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(AppFonts.sans(14, weight: .semibold))
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .foregroundColor(.midnightSpruce)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.cardBorder, lineWidth: 1))
        }
    }

    func chip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppFonts.sans(12, weight: .semibold))
                .foregroundColor(isSelected ? .midnightSpruce : .nordicSlate)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isSelected ? Color.mossInsight.opacity(0.16) : Color.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? Color.mossInsight.opacity(0.5) : Color.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    func wrappingChips(_ items: [String], selection: Binding<Set<String>>) -> some View {
        OnboardingFlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                chip(item, isSelected: selection.wrappedValue.contains(item)) {
                    if selection.wrappedValue.contains(item) {
                        selection.wrappedValue.remove(item)
                    } else {
                        selection.wrappedValue.insert(item)
                    }
                }
            }
        }
    }

    func focusChips(_ items: [String]) -> some View {
        OnboardingFlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                chip(item, isSelected: focus == item) {
                    focus = item
                }
            }
        }
    }

    func featureRow(icon: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint)
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.midnightSpruce)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.sans(13, weight: .semibold))
                    .foregroundColor(.midnightSpruce)
                Text(subtitle)
                    .font(AppFonts.sans(11, weight: .regular))
                    .foregroundColor(.nordicSlate)
            }
            Spacer()
        }
    }

    func applyProfileStep() {
        profileIdentity.updateDisplayName(nameDraft)
        setAllergy(.peanuts, enabled: exclusions.contains("No Peanuts"))
        setRestriction(.lowSodium, enabled: exclusions.contains("Low Sodium"))
        setRestriction(.glutenFree, enabled: exclusions.contains("Gluten Free"))
        setRestriction(.dairyfree, enabled: exclusions.contains("Dairy Free"))
        setCustomRestriction("No Added Sugar", enabled: exclusions.contains("No Added Sugar"))
    }

    func applyTailorStep() {
        setRestriction(.dairyfree, enabled: needs.contains("Dairy Free"))
        setRestriction(.glutenFree, enabled: needs.contains("Gluten Free"))
        setRestriction(.vegan, enabled: needs.contains("Plant Based"))
        setRestriction(.paleo, enabled: needs.contains("Paleo"))
        setRestriction(.keto, enabled: needs.contains("Keto"))
        UserDefaults.standard.set(focus, forKey: "profile.primaryFocus")
    }

    func setRestriction(_ restriction: DietaryRestriction, enabled: Bool) {
        if enabled {
            if !preferencesManager.selectedDietaryRestrictions.contains(restriction) {
                preferencesManager.toggleDietaryRestriction(restriction)
            }
        } else if preferencesManager.selectedDietaryRestrictions.contains(restriction) {
            preferencesManager.toggleDietaryRestriction(restriction)
        }
    }

    func setAllergy(_ allergy: Allergy, enabled: Bool) {
        if enabled {
            if !preferencesManager.selectedAllergies.contains(allergy) {
                preferencesManager.toggleAllergy(allergy)
            }
        } else if preferencesManager.selectedAllergies.contains(allergy) {
            preferencesManager.toggleAllergy(allergy)
        }
    }

    func setCustomRestriction(_ value: String, enabled: Bool) {
        if enabled {
            if !preferencesManager.customRestrictions.contains(value) {
                preferencesManager.addCustomRestriction(value)
            }
        } else if preferencesManager.customRestrictions.contains(value) {
            preferencesManager.removeCustomRestriction(value)
        }
    }
}

private struct OnboardingFlowLayout<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content

    init(spacing: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        OnboardingFlowLayoutContainer(spacing: spacing) { content() }
    }
}

private struct OnboardingFlowLayoutContainer: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? CGFloat.infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
