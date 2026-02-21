import SwiftUI
import SwiftData

struct HomeView: View {
    private static let recommendationEngine = OnDeviceNutritionRecommendationEngine()

    @Environment(\.modelContext) private var modelContext
    @StateObject private var profileIdentity = ProfileIdentityStore.shared
    @Query private var products: [Product]
    @Query private var plates: [PlateAnalysisHistory]
    @State private var showingScanner = false
    @State private var selectedPlate: PlateAnalysisHistory?
    @State private var selectedProduct: Product?
    let onViewAllHistory: () -> Void

    init(onViewAllHistory: @escaping () -> Void = {}) {
        self.onViewAllHistory = onViewAllHistory
    }

    private var insights: [PersonalizedInsight] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
        let recentPlates = plates.filter { $0.analyzedDate >= cutoff }
        let recentProducts = products.filter { $0.scannedDate >= cutoff }
        let recs = Self.recommendationEngine.generateAdaptiveTrendInsights(plates: recentPlates, products: recentProducts)
        return recs.prefix(5).map { r in
            let icon: String
            let color: Color
            if r.tags.contains("fiber") { icon = "leaf.fill"; color = .mossInsight }
            else if r.tags.contains("protein") { icon = "bolt.heart.fill"; color = .momentumAmber }
            else { icon = "lightbulb.fill"; color = .nordicSlate }
            return PersonalizedInsight(icon: icon, iconColor: color, title: r.title, message: r.message, category: .health, reason: r.reason, evidence: r.evidence, tags: r.tags)
        }
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Welcome back")
                                    .font(AppFonts.display)
                                    .foregroundColor(.midnightSpruce)
                                Text("Keep using the app to see more personalized insights")
                                    .font(AppFonts.sans(13, weight: .regular))
                                    .foregroundColor(.nordicSlate)
                                    .tracking(0.2)
                            }
                            Spacer()
                            // Persisted profile avatar
                            ZStack {
                                Circle().stroke(Color.black.opacity(0.08), lineWidth: 1)
                                Group {
                                    if let avatar = profileIdentity.avatarImage() {
                                        Image(uiImage: avatar)
                                            .resizable()
                                            .scaledToFill()
                                    } else if let bundledAvatar = UIImage(named: "profile_avatar") {
                                        Image(uiImage: bundledAvatar)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Image(systemName: "person.crop.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundColor(.nordicSlate.opacity(0.7))
                                            .padding(6)
                                    }
                                }
                                .clipShape(Circle())
                            }
                            .frame(width: 48, height: 48)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                        // Insights carousel
                        VStack(alignment: .leading, spacing: 10) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                                        EditorialInsightCard(title: insight.title, subtitle: insight.message, label: labelForCategory(insight.category))
                                            .frame(width: 280)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        // Weekly Trends (data-driven)
                        VStack(spacing: 10) {
                            HStack {
                                Text("Weekly Trends")
                                    .font(AppFonts.label)
                                    .textCase(.uppercase)
                                    .tracking(2)
                                    .foregroundColor(.nordicSlate)
                                Spacer()
                                Button("View All") { }
                                    .font(AppFonts.sans(10, weight: .semibold))
                                    .foregroundColor(.nordicSlate)
                            }
                            .padding(.horizontal, 16)

                            if trendInsights.isEmpty {
                                // Hide section if we have no meaningful trend insights
                                EmptyView()
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(trendInsights, id: \.title) { ti in
                                            TrendCard(icon: ti.icon,
                                                      iconColor: ti.color,
                                                      title: ti.title,
                                                      value: ti.value,
                                                      unit: ti.unit,
                                                      note: ti.note)
                                            .frame(width: 220)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                        // Recent Activity
                        VStack(spacing: 10) {
                            HStack {
                                Text(NSLocalizedString("recent.activity", comment: "Recent activity title"))
                                    .font(AppFonts.label)
                                    .textCase(.uppercase)
                                    .tracking(2)
                                    .foregroundColor(.nordicSlate)
                                Spacer()
                                Button("View all") {
                                    onViewAllHistory()
                                }
                                    .font(AppFonts.sans(10, weight: .semibold))
                                    .foregroundColor(.nordicSlate)
                            }
                            .padding(.horizontal, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(recentActivity.prefix(5)) { item in
                                        Button {
                                            switch item.kind {
                                            case .plate(let plate):
                                                selectedPlate = plate
                                            case .product(let product):
                                                selectedProduct = product
                                            }
                                        } label: {
                                            RecentActivityTile(item: item)
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                deleteRecentItem(item)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 4)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
                .background(Color.nordicBone)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingScanner) {
            BarcodeScannerView(scannedCode: .constant(nil), isScanning: .constant(false))
        }
        .sheet(item: $selectedPlate) { plate in
            PlateDetailView(plateAnalysis: plate)
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product)
        }
    }
}

extension HomeView {
    private var recentActivity: [RecentActivityItem] {
        let plateItems = plates.map { plate in
            RecentActivityItem(
                id: "plate-\(plate.id.uuidString)",
                date: plate.analyzedDate,
                kind: .plate(plate)
            )
        }
        let productItems = products.map { product in
            RecentActivityItem(
                id: "product-\(product.barcode)",
                date: product.scannedDate,
                kind: .product(product)
            )
        }
        return (plateItems + productItems).sorted { $0.date > $1.date }
    }

    private func labelForCategory(_ category: PersonalizedInsight.InsightCategory) -> String {
        switch category {
        case .preference: return "Daily Analysis"
        case .health: return "Activity Loop"
        case .habit: return "Sleep Impact"
        case .recommendation: return "Tip"
        }
    }

    private var trendInsights: [(icon: String, color: Color, title: String, value: String?, unit: String?, note: String)] {
        // Select insights that carry measurable tags (e.g., fiber, protein) or have numeric evidence
        let candidates = insights.filter { !$0.message.isEmpty || !$0.evidence.isEmpty }
        return candidates.prefix(6).compactMap { ins in
            // Choose icon/color from tags if available
            let icon: String
            let color: Color
            if ins.tags.contains("fiber") { icon = "leaf"; color = .mossInsight }
            else if ins.tags.contains("protein") { icon = "bolt.heart"; color = .momentumAmber }
            else { icon = "lightbulb"; color = .nordicSlate }

            // Try to extract a metric from message or evidence
            let metric = extractMetric(from: ins.message) ?? ins.evidence.compactMap { extractMetric(from: $0) }.first

            return (
                icon: icon,
                color: color,
                title: ins.title,
                value: metric?.value,
                unit: metric?.unit,
                note: metric == nil ? (ins.reason ?? ins.message) : ins.message
            )
        }
    }

    private func extractMetric(from text: String) -> (value: String, unit: String)? {
        // Naive extraction of first number and trailing unit token
        // e.g., "78%", "112 g", "2.1 L"
        let pattern = #"([0-9]+(?:\.[0-9]+)?)\s*([%a-zA-Z]+)?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(location: 0, length: (text as NSString).length)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        let v = (text as NSString).substring(with: match.range(at: 1))
        var u: String = ""
        if match.numberOfRanges >= 3, match.range(at: 2).location != NSNotFound {
            u = (text as NSString).substring(with: match.range(at: 2))
        }
        // Basic sanity: require at least a digit
        return v.isEmpty ? nil : (v, u.isEmpty ? nilToEmptyUnit(v) : u)
    }

    private func nilToEmptyUnit(_ value: String) -> String { "" }

    private func deleteRecentItem(_ item: RecentActivityItem) {
        switch item.kind {
        case .plate(let plate):
            ImageCacheService.shared.deleteImage(forKey: plate.cacheKey)
            modelContext.delete(plate)
        case .product(let product):
            if let localPath = product.localImagePath, FileManager.default.fileExists(atPath: localPath) {
                try? FileManager.default.removeItem(atPath: localPath)
            }
            modelContext.delete(product)
        }
    }
}

fileprivate enum RecentActivityKind {
    case plate(PlateAnalysisHistory)
    case product(Product)
}

fileprivate struct RecentActivityItem: Identifiable {
    let id: String
    let date: Date
    let kind: RecentActivityKind
}

private struct EditorialInsightCard: View {
    let title: String
    let subtitle: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(AppFonts.label)
                .foregroundColor(.nordicSlate)
                .tracking(2)
            Text(title)
                .font(AppFonts.serif(22, weight: .regular))
                .foregroundColor(.midnightSpruce)
                .lineLimit(3)
            Text(subtitle)
                .font(AppFonts.sans(12, weight: .regular))
                .foregroundColor(.nordicSlate)
                .lineLimit(3)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        )
    }
}

private struct DashboardPill: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    var suffix: String? = nil
    var italic: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
            Text(title.uppercased())
                .font(AppFonts.label)
                .foregroundColor(.nordicSlate)
                .tracking(2)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                if italic {
                    Text(value).font(AppFonts.serif(20, weight: .regular)).italic()
                } else {
                    Text(value).font(AppFonts.serif(20, weight: .regular))
                }
                if let suffix { Text(suffix).font(AppFonts.sans(11, weight: .regular)) }
            }
            .foregroundColor(.midnightSpruce)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.cardSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
        )
    }
}

private struct TrendCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String?
    let unit: String?
    let note: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ZStack {
                    Circle().fill(Color.cardSurface)
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                Text(title)
                    .font(AppFonts.label)
                    .foregroundColor(.nordicSlate)
                    .tracking(1.5)
            }
            if let value, !value.isEmpty {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(AppFonts.serif(26, weight: .regular))
                    Text(unit ?? "")
                        .font(AppFonts.sans(12, weight: .regular))
                        .foregroundColor(.nordicSlate.opacity(0.6))
                }
            }
            Text(note)
                .font(AppFonts.sans(11, weight: .regular))
                .foregroundColor(.nordicSlate)
                .lineLimit(3)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.cardSurface)
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.cardBorder, lineWidth: 1))
        )
    }
}

private struct RecentActivityTile: View {
    let item: RecentActivityItem

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            activityImage
            .frame(width: 120, height: 120)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
            )
            .overlay(
                LinearGradient(colors: [.black.opacity(0.35), .clear], startPoint: .bottom, endPoint: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            )

            VStack(alignment: .leading, spacing: 4) {
                activityBadge
                Text(activityTitle)
                    .font(AppFonts.sans(11, weight: .regular))
                    .foregroundColor(.nordicBone)
                    .lineLimit(1)
            }
            .padding(8)
            .frame(width: 120, height: 120, alignment: .bottom)
        }
        .frame(width: 120, height: 120)
    }

    private var activityTitle: String {
        switch item.kind {
        case .plate(let plate):
            return plate.name
        case .product(let product):
            return product.name
        }
    }

    @ViewBuilder
    private var activityBadge: some View {
        HStack {
            Spacer()
            switch item.kind {
            case .plate(let plate):
                Text(plate.mealLogIntent?.shortBadge ?? "\(plate.protein)g Pro")
                    .font(AppFonts.sans(9, weight: .bold))
                    .foregroundColor(.mossInsight)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.nordicBone.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            case .product(let product):
                Text(product.mealLogIntent?.shortBadge ?? "Nutri \(product.nutriScoreLetter.rawValue)")
                    .font(AppFonts.sans(9, weight: .bold))
                    .foregroundColor(product.mealLogIntent == nil ? .momentumAmber : .mossInsight)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.nordicBone.opacity(0.95))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    @ViewBuilder
    private var activityImage: some View {
        switch item.kind {
        case .plate(let plate):
            if let cached = ImageCacheService.shared.loadImage(forKey: plate.cacheKey) {
                Image(uiImage: cached).resizable().scaledToFill()
            } else if let img = plate.image {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color.nordicBone.opacity(0.8)
            }
        case .product(let product):
            if let localPath = product.localImagePath,
               FileManager.default.fileExists(atPath: localPath),
               let uiImage = UIImage(contentsOfFile: localPath) {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else if let url = product.imageURL, !url.isEmpty {
                CachedAsyncImage(urlString: url, cacheKey: product.barcode)
                    .scaledToFill()
            } else {
                Color.nordicBone.opacity(0.8)
            }
        }
    }
}

#Preview {
    HomeView()
}
