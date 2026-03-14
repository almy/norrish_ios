import SwiftUI
import UIKit

struct HistoryTabView: View {
    let filteredHistoryItems: [HistoryItemType]
    let historyTrendInsights: [PersonalizedInsight]
    @Binding var historyDigestIndex: Int
    let onSelectItem: (HistoryItemType) -> Void
    let onDeleteItem: (HistoryItemType) -> Void

    var body: some View {
        Group {
            if isFirstUseHistory {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        historyHeader
                        FirstUseHistoryStateView()
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
                .background(Color.nordicBone.ignoresSafeArea())
            } else {
                List {
                    Section {
                        historyHeader
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)

                        if !historyTrendInsights.isEmpty {
                            digestSection
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    }

                    ForEach(historySections) { section in
                        Section(header: sectionHeader(for: section.date)) {
                            ForEach(section.items) { item in
                                HistoryTimelineCard(item: item) {
                                    onSelectItem(item)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        onDeleteItem(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        onDeleteItem(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 16, trailing: 20))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.nordicBone.ignoresSafeArea())
                .padding(.bottom, 0)
            }
        }
        .accessibilityIdentifier("screen.history")
    }

    private var isFirstUseHistory: Bool {
        filteredHistoryItems.isEmpty
    }

    private var historyHeader: some View {
        FirstUseTabHeaderView(
            title: NSLocalizedString("tab.history", comment: "History tab title"),
            subtitle: NSLocalizedString("history.journal_title", comment: "History journal subtitle"),
            accent: .momentumAmber,
            icon: "book"
        )
    }

    private var digestSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(NSLocalizedString("history.digest_title", comment: "Digest title"))
                    .font(AppFonts.serif(20, weight: .bold))
                    .foregroundColor(.midnightSpruce)
                Spacer()
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Text(NSLocalizedString("history.digest_action", comment: "Digest action"))
                            .font(AppFonts.sans(11, weight: .bold))
                            .kerning(1.2)
                            .textCase(.uppercase)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.momentumAmber)
                }
            }
            .padding(.horizontal, 20)

            VStack(spacing: 10) {
                TabView(selection: $historyDigestIndex) {
                    ForEach(Array(historyTrendInsights.enumerated()), id: \.offset) { idx, insight in
                        HistoryDigestCard(insight: insight)
                            .tag(idx)
                            .padding(.horizontal, 4)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .frame(height: 150)

                HStack(spacing: 6) {
                    ForEach(0..<historyTrendInsights.count, id: \.self) { idx in
                        Circle()
                            .fill(idx == historyDigestIndex ? Color.momentumAmber : Color.nordicSlate.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
    }

    private var historySections: [HistorySection] {
        let grouped = Dictionary(grouping: filteredHistoryItems) { item in
            Calendar.current.startOfDay(for: item.date)
        }
        return grouped.keys.sorted(by: >).map { key in
            let items = grouped[key]?.sorted { $0.date > $1.date } ?? []
            return HistorySection(date: key, items: items)
        }
    }

    private func sectionTitle(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let label = NSLocalizedString("history.today", comment: "Today label")
            return "\(label) • \(date.formatted(date: .abbreviated, time: .omitted))"
        }
        if calendar.isDateInYesterday(date) {
            let label = NSLocalizedString("history.yesterday", comment: "Yesterday label")
            return "\(label) • \(date.formatted(date: .abbreviated, time: .omitted))"
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func sectionHeader(for date: Date) -> some View {
        Text(sectionTitle(for: date))
            .font(AppFonts.label)
            .kerning(2.5)
            .foregroundColor(.nordicSlate)
            .textCase(.uppercase)
            .padding(.leading, 24)
            .padding(.top, 8)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}

private struct HistorySection: Identifiable {
    let date: Date
    let items: [HistoryItemType]
    var id: Date { date }
}

private struct HistoryDigestCard: View {
    let insight: PersonalizedInsight

    private var accent: Color {
        switch insight.category {
        case .health: return .mossInsight
        case .habit: return .momentumAmber
        case .preference: return .nordicSlate
        case .recommendation: return .momentumAmber
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: insight.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(accent)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(AppFonts.serif(16, weight: .semibold))
                        .foregroundColor(.midnightSpruce)
                    Text(insight.message)
                        .font(AppFonts.sans(12, weight: .regular))
                        .foregroundColor(.nordicSlate)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 6)
    }
}

private struct HistoryTimelineCard: View {
    let item: HistoryItemType
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                imageView
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.name)
                            .font(AppFonts.serif(16, weight: .semibold))
                            .foregroundColor(.midnightSpruce)
                            .lineLimit(1)
                        Spacer()
                        nutriBadge
                    }
                    HStack(spacing: 8) {
                        let kcal = NSLocalizedString("unit.kilocalories", comment: "Kilocalories unit")
                        Text("\(caloriesText) \(kcal)")
                            .font(AppFonts.sans(10, weight: .bold))
                            .foregroundColor(.nordicSlate)
                        Text(macroText)
                            .font(AppFonts.sans(10, weight: .medium))
                            .foregroundColor(.nordicSlate.opacity(0.85))
                    }
                    if let mealIntentText {
                        Text(mealIntentText)
                            .font(AppFonts.sans(10, weight: .semibold))
                            .foregroundColor(.mossInsight)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 8)
                            .background(Color.mossInsight.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    if let note = noteText {
                        Text("“\(note)”")
                            .font(AppFonts.sans(11, weight: .regular))
                            .foregroundColor(.nordicSlate.opacity(0.7))
                            .italic()
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var imageView: some View {
        switch item {
        case .plate(let plate):
            if let cached = ImageCacheService.shared.loadImage(forKey: plate.cacheKey) {
                Image(uiImage: cached).resizable().scaledToFill()
            } else if let image = plate.image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.nordicBone.opacity(0.8)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.system(size: 18))
                            .foregroundColor(.nordicSlate)
                    )
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
                    .overlay(
                        Image(systemName: "cart")
                            .font(.system(size: 18))
                            .foregroundColor(.nordicSlate)
                    )
            }
        }
    }

    private var nutriBadge: some View {
        let rgb = item.nutriScoreLetter.color
        let color = Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
        return Text(item.nutriScoreLetter.rawValue)
            .font(AppFonts.sans(10, weight: .bold))
            .foregroundColor(color)
            .frame(width: 22, height: 22)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var caloriesText: String {
        switch item {
        case .plate(let plate):
            return "\(plate.calories)"
        case .product(let product):
            return String(format: "%.0f", product.nutritionData.calories)
        }
    }

    private var macroText: String {
        switch item {
        case .plate(let plate):
            return "\(plate.protein)g P • \(plate.carbs)g C • \(plate.fat)g F"
        case .product(let product):
            let protein = String(format: "%.0f", product.nutritionData.protein)
            let carbs = String(format: "%.0f", product.nutritionData.carbohydrates)
            let fat = String(format: "%.0f", product.nutritionData.fat)
            return "\(protein)g P • \(carbs)g C • \(fat)g F"
        }
    }

    private var noteText: String? {
        switch item {
        case .plate(let plate):
            return plate.insights.first?.description ?? plate.analysisDescription
        case .product(let product):
            if let ingredients = product.ingredients?.trimmingCharacters(in: .whitespacesAndNewlines), !ingredients.isEmpty {
                return ingredients.components(separatedBy: CharacterSet(charactersIn: ",;•|/")).first
            }
            if !product.brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return product.brand
            }
            return nil
        }
    }

    private var mealIntentText: String? {
        switch item {
        case .plate(let plate):
            return plate.mealLogIntent?.shortBadge
        case .product(let product):
            return product.mealLogIntent?.shortBadge
        }
    }
}

// Preview-only: minimal mixed dataset (product + plate) for timeline rendering.
#Preview("History Tab") {
    // Sample product used to render product row styling.
    let product = Product(
        barcode: "1234567890123",
        name: "Granola Bar",
        brand: "Norrish",
        nutritionData: NutritionData(
            calories: 210,
            fat: 8,
            saturatedFat: 1.2,
            sugar: 9,
            sodium: 0.19,
            protein: 6,
            fiber: 4,
            carbohydrates: 30,
            fruitsVegetablesNutsPercent: 35
        ),
        imageURL: nil,
        localImagePath: nil,
        categoriesTags: ["en:snacks"],
        ingredients: "Oats, nuts, honey"
    )

    // Sample plate entry used to render plate row styling.
    let plate = PlateAnalysisHistory.mockData()

    return HistoryTabView(
        filteredHistoryItems: [.product(product), .plate(plate)],
        historyTrendInsights: [
            PersonalizedInsight(
                icon: "leaf.fill",
                iconColor: .mossInsight,
                title: "Fiber Trend",
                message: "You increased average daily fiber this week.",
                category: .health
            )
        ],
        historyDigestIndex: .constant(0),
        onSelectItem: { _ in },
        onDeleteItem: { _ in }
    )
    .modelContainer(for: [Product.self, PlateAnalysisHistory.self], inMemory: true)
}

private struct FirstUseHistoryStateView: View {
    var body: some View {
        VStack(spacing: 28) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.momentumAmber.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "heart.text.square")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.momentumAmber)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Journey")
                        .font(AppFonts.sans(10, weight: .bold))
                        .textCase(.uppercase)
                        .kerning(1.6)
                        .foregroundColor(.momentumAmber)
                    Text("We’re excited to meet you")
                        .font(AppFonts.sans(16, weight: .semibold))
                        .foregroundColor(.midnightSpruce)
                    Text("Start your first scan to unlock personal insights designed around your meals and products.")
                        .font(AppFonts.sans(12, weight: .regular))
                        .foregroundColor(.nordicSlate)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(18)
            .background(Color.cardSurface.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.momentumAmber.opacity(0.18), lineWidth: 1)
            )

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.momentumAmber.opacity(0.08))
                        .frame(width: 220, height: 220)
                        .blur(radius: 18)

                    VStack(spacing: 12) {
                        HStack(spacing: 14) {
                            Image(systemName: "leaf.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.mossInsight.opacity(0.7))
                                .rotationEffect(.degrees(-12))
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 42))
                                .foregroundColor(.midnightSpruce)
                            Image(systemName: "sparkles")
                                .font(.system(size: 28))
                                .foregroundColor(.momentumAmber.opacity(0.7))
                                .rotationEffect(.degrees(12))
                        }

                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(Color.cardSurface)
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "fork.knife.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.mossInsight)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 28, style: .continuous)
                                    .stroke(Color.cardBorder, lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 8)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 12) {
                    Text("Let’s begin your wellness story together")
                        .font(AppFonts.serif(30, weight: .bold))
                        .foregroundColor(.midnightSpruce)
                        .multilineTextAlignment(.center)

                    Text("Whenever you’re ready, analyzing your first meal helps Noorish understand your needs and begin building a useful history.")
                        .font(AppFonts.sans(13, weight: .regular))
                        .foregroundColor(.nordicSlate)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 18)
                }
            }

            FirstUseGuidanceChip(
                text: "Tap + to begin your first entry",
                accent: .momentumAmber
            )
        }
    }
}
