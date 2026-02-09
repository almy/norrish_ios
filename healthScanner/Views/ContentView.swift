//
//  ContentView.swift
//  norrish
//
//  Created by myftiu on 06/09/25.
//

import SwiftUI
import SwiftData

enum ProductFilter: CaseIterable {
    case all, gradeA, gradeB, gradeC, gradeD, gradeE

    var title: String {
        switch self {
        case .all: return NSLocalizedString("filter.all", comment: "Filter option for all items")
        case .gradeA: return NSLocalizedString("filter.grade_a", comment: "Filter for Nutri-Score grade A")
        case .gradeB: return NSLocalizedString("filter.grade_b", comment: "Filter for Nutri-Score grade B")
        case .gradeC: return NSLocalizedString("filter.grade_c", comment: "Filter for Nutri-Score grade C")
        case .gradeD: return NSLocalizedString("filter.grade_d", comment: "Filter for Nutri-Score grade D")
        case .gradeE: return NSLocalizedString("filter.grade_e", comment: "Filter for Nutri-Score grade E")
        }
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var localizationManager: LocalizationManager
    @Query private var products: [Product]
    @Query private var plateAnalyses: [PlateAnalysisHistory]
    @StateObject private var productService = ProductService()
    @StateObject private var barcodeScanVM = BarcodeScannerViewModel()
    @StateObject private var insightService = InsightDataService.shared
    
    @State private var showingScanner = false
    @State private var scannedCode: String?
    @State private var isScanning = false
    @State private var selectedProduct: Product?
    @State private var selectedPlateAnalysis: PlateAnalysisHistory?
    @State private var showingProductDetail = false
    @State private var showingQuickAdd = false
    @State private var showingPlateScan = false
    @State private var showingPlateUpload = false
    @State private var selectedTab = 0
    
    // New state properties for history tab
    @State private var searchText = ""
    @State private var selectedFilter: ProductFilter = .all
    @State private var selectedHistoryType: HistoryType = .all
    @State private var selectedSort: SortOption = .date
    @State private var historyDigestIndex = 0
    
    enum HistoryType: CaseIterable {
        case all, products, plates
        
        var title: String {
            switch self {
            case .all: return NSLocalizedString("history_type.all", comment: "History type filter for all items")
            case .products: return NSLocalizedString("history_type.products", comment: "History type filter for products")
            case .plates: return NSLocalizedString("history_type.plates", comment: "History type filter for plates")
            }
        }
    }
    
    enum SortOption: CaseIterable {
        case date, nutri

        var rawValue: String {
            switch self {
            case .date: return NSLocalizedString("sort.date", comment: "Sort option by date")
            case .nutri: return NSLocalizedString("sort.nutri_score", comment: "Sort option by Nutri-Score")
            }
        }
    }
    
    // Adaptive insights banner for History tab
    private var historyTrendInsights: [PersonalizedInsight] {
        let engine = OnDeviceNutritionRecommendationEngine()
        // Use SwiftData queries already present: products, plateAnalyses
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
        let recentPlates = plateAnalyses.filter { $0.analyzedDate >= cutoff }
        let recentProducts = products.filter { $0.scannedDate >= cutoff }
        let recs = engine.generateAdaptiveTrendInsights(plates: recentPlates, products: recentProducts)

        return recs.prefix(3).map { r in
            let icon: String
            let color: Color
            if r.tags.contains("fiber") { icon = "leaf.fill"; color = .green }
            else if r.tags.contains("protein") { icon = "bolt.heart.fill"; color = .pink }
            else { icon = "lightbulb.fill"; color = .yellow }
            return PersonalizedInsight(icon: icon, iconColor: color, title: r.title, message: r.message, category: .health, reason: r.reason, evidence: r.evidence, tags: r.tags)
        }
    }
    
    // Computed property for combined and filtered history items
    var filteredHistoryItems: [HistoryItemType] {
        var allItems: [HistoryItemType] = []
        
        // Add products to the list based on filter
        if selectedHistoryType == .all || selectedHistoryType == .products {
            let filteredProducts = products.filter { product in
                let matchesSearchText = searchText.isEmpty || product.name.localizedCaseInsensitiveContains(searchText)
                let matchesFilter: Bool
                switch selectedFilter {
                case .all:
                    matchesFilter = true
                case .gradeA:
                    matchesFilter = product.nutriScoreLetter == .A
                case .gradeB:
                    matchesFilter = product.nutriScoreLetter == .B
                case .gradeC:
                    matchesFilter = product.nutriScoreLetter == .C
                case .gradeD:
                    matchesFilter = product.nutriScoreLetter == .D
                case .gradeE:
                    matchesFilter = product.nutriScoreLetter == .E
                }
                return matchesSearchText && matchesFilter
            }
            allItems.append(contentsOf: filteredProducts.map { .product($0) })
        }
        
        // Add plate analyses to the list based on filter
        if selectedHistoryType == .all || selectedHistoryType == .plates {
            let filteredPlates = plateAnalyses.filter { plate in
                let matchesSearchText = searchText.isEmpty || plate.name.localizedCaseInsensitiveContains(searchText)
                let matchesFilter: Bool
                switch selectedFilter {
                case .all:
                    matchesFilter = true
                case .gradeA:
                    matchesFilter = plate.nutriScoreLetter == .A
                case .gradeB:
                    matchesFilter = plate.nutriScoreLetter == .B
                case .gradeC:
                    matchesFilter = plate.nutriScoreLetter == .C
                case .gradeD:
                    matchesFilter = plate.nutriScoreLetter == .D
                case .gradeE:
                    matchesFilter = plate.nutriScoreLetter == .E
                }
                return matchesSearchText && matchesFilter
            }
            allItems.append(contentsOf: filteredPlates.map { .plate($0) })
        }
        
        // Sort
        switch selectedSort {
        case .date:
            return allItems.sorted { $0.date > $1.date }
        case .nutri:
            return allItems.sorted { nutriRank(for: $0) > nutriRank(for: $1) }
        }
    }
    
    private func nutriRank(for item: HistoryItemType) -> Int {
        let letter = item.nutriScoreLetter
        switch letter {
        case .A: return 5
        case .B: return 4
        case .C: return 3
        case .D: return 2
        case .E: return 1
        }
    }

    private var historyJournalView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                historyHeader

                if !historyTrendInsights.isEmpty {
                    digestSection
                }

                historyTimeline
            }
            .padding(.bottom, 120)
        }
        .background(Color(red: 252 / 255, green: 252 / 255, blue: 252 / 255))
    }

    private var historyHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(NSLocalizedString("history.story_label", comment: "History header label"))
                    .font(.system(size: 10, weight: .bold))
                    .kerning(3)
                    .foregroundColor(Color.gray.opacity(0.6))
                    .textCase(.uppercase)
                Text(NSLocalizedString("history.journal_title", comment: "History journal title"))
                    .font(.system(size: 30, weight: .black, design: .serif))
                    .foregroundColor(Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255))
            }
            Spacer()
            Image(systemName: "book")
                .font(.system(size: 20))
                .foregroundColor(Color(red: 43 / 255, green: 108 / 255, blue: 238 / 255))
                .padding(8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var digestSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text(NSLocalizedString("history.digest_title", comment: "Digest title"))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255))
                Spacer()
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Text(NSLocalizedString("history.digest_action", comment: "Digest action"))
                            .font(.system(size: 11, weight: .bold))
                            .kerning(1.5)
                            .textCase(.uppercase)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(Color(red: 43 / 255, green: 108 / 255, blue: 238 / 255))
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
                            .fill(idx == historyDigestIndex ? Color(red: 43 / 255, green: 108 / 255, blue: 238 / 255) : Color.gray.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
    }

    private var historyTimeline: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 1)
                    .padding(.leading, 14)

                VStack(alignment: .leading, spacing: 24) {
                    ForEach(historySections) { section in
                        VStack(alignment: .leading, spacing: 16) {
                            Text(sectionTitle(for: section.date))
                                .font(.system(size: 10, weight: .black))
                                .kerning(3)
                                .foregroundColor(Color.gray.opacity(0.6))
                                .textCase(.uppercase)
                                .padding(.leading, 4)

                            VStack(spacing: 16) {
                                ForEach(section.items) { item in
                                    HistoryTimelineCard(item: item) {
                                        switch item {
                                        case .product(let product):
                                            selectedProduct = product
                                        case .plate(let plate):
                                            selectedPlateAnalysis = plate
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
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
    
    var body: some View {
        PromptOverlayHost {
            TabView(selection: $selectedTab) {
                // Home Tab
                ZStack {
                    HomeView()
                    VStack { Spacer() ; HStack { Spacer() ; Button(action: { showingQuickAdd = true }) { Image(systemName: "plus").font(.title2).foregroundColor(.white).padding() }.background(Color.green).clipShape(Circle()).shadow(radius: 4).padding(.trailing, 20).padding(.bottom, 20) } }
                }
                .tabItem { VStack { Image(systemName: "house"); Text(NSLocalizedString("home.title", comment: "Home tab title")) } }
                .tag(0)

                // History Tab
                ZStack {
                    historyJournalView

                    // Floating + button
                    VStack { Spacer() ; HStack { Spacer() ; Button(action: { showingQuickAdd = true }) { Image(systemName: "plus").font(.title2).foregroundColor(.white).padding() }.background(Color.green).clipShape(Circle()).shadow(radius: 4).padding(.trailing, 20).padding(.bottom, 20) } }
                }
                .tabItem { VStack { Image(systemName: "clock"); Text("tab.history".localized()) } }
                .tag(1)

                // Profile Tab
                ProfileView()
                    .tabItem { VStack { Image(systemName: "person"); Text("tab.profile".localized()) } }
                    .tag(2)
            }
            .accentColor(.green)
            .fullScreenCover(isPresented: $showingScanner) {
                QuickBarcodeScanView(
                    scannedCode: $scannedCode,
                    isScanning: $isScanning,
                    isPresented: $showingScanner
                )
            }
            .fullScreenCover(isPresented: $showingPlateScan) {
                PlateAnalysisView()
            }
            .fullScreenCover(isPresented: $showingPlateUpload) {
                PlateAnalysisView()
            }
            .sheet(item: $selectedProduct) { product in
                ProductDetailView(product: product)
            }
            .sheet(item: $selectedPlateAnalysis) { plateAnalysis in
                PlateDetailView(plateAnalysis: plateAnalysis) {
                    selectedPlateAnalysis = nil
                }
            }
            .sheet(isPresented: $showingQuickAdd) {
                VStack(spacing: 12) {
                    Text(NSLocalizedString("home.section.suggestions", comment: "Quick actions title")).font(.headline).padding(.top, 16)
                    Button { showingScanner = true ; showingQuickAdd = false } label: {
                        HStack { Image(systemName: "barcode.viewfinder"); Text("tab.scan".localized()) }.frame(maxWidth: .infinity).padding().background(Color.indigo).foregroundColor(.white).cornerRadius(12)
                    }
                    Button { showingPlateScan = true ; showingQuickAdd = false } label: {
                        HStack { Image(systemName: "fork.knife"); Text("tab.plate".localized()) }.frame(maxWidth: .infinity).padding().background(Color(.secondarySystemBackground)).cornerRadius(12)
                    }
                    Button { showingPlateUpload = true ; showingQuickAdd = false } label: {
                        HStack { Image(systemName: "photo"); Text(NSLocalizedString("plate.upload_photo", comment: "Upload photo")) }.frame(maxWidth: .infinity).padding().background(Color(.secondarySystemBackground)).cornerRadius(12)
                    }
                    Spacer()
                }
                .padding(20)
                .presentationDetents([.height(220)])
            }
            .onChange(of: scannedCode) { _, newValue in
                guard let code = newValue else { return }
                Task {
                    if let product = try? await barcodeScanVM.fetchProduct(barcode: code, existing: products, modelContext: modelContext) {
                        selectedProduct = product
                    }
                }
            }
        }
    }
}

// Filter Button Component
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.mint : Color.gray.opacity(0.1))
                .cornerRadius(20)
        }
    }
}

private struct QuickBarcodeScanView: View {
    @Binding var scannedCode: String?
    @Binding var isScanning: Bool
    @Binding var isPresented: Bool

    var body: some View {
        BarcodeCameraOverlayView(
            scannedCode: $scannedCode,
            isScanning: $isScanning,
            isPresented: $isPresented
        )
        .onAppear {
            isScanning = true
        }
        .ignoresSafeArea()
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
        case .health: return Color(red: 34 / 255, green: 197 / 255, blue: 94 / 255)
        case .habit: return Color(red: 168 / 255, green: 85 / 255, blue: 247 / 255)
        case .preference: return Color(red: 59 / 255, green: 130 / 255, blue: 246 / 255)
        case .recommendation: return Color(red: 249 / 255, green: 115 / 255, blue: 22 / 255)
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
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255))
                    Text(insight.message)
                        .font(.system(size: 12))
                        .foregroundColor(Color.gray.opacity(0.7))
                }
                Spacer()
            }
        }
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
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
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255))
                            .lineLimit(1)
                        Spacer()
                        nutriBadge
                    }
                    HStack(spacing: 8) {
                        let kcal = NSLocalizedString("unit.kilocalories", comment: "Kilocalories unit")
                        Text("\(caloriesText) \(kcal)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.gray.opacity(0.8))
                        Text(macroText)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Color.gray.opacity(0.6))
                    }
                    if let note = noteText {
                        Text("“\(note)”")
                            .font(.system(size: 11))
                            .foregroundColor(Color.gray.opacity(0.5))
                            .italic()
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 3)
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
                Color.gray.opacity(0.08)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
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
                Color.gray.opacity(0.08)
                    .overlay(
                        Image(systemName: "cart")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                    )
            }
        }
    }

    private var nutriBadge: some View {
        let rgb = item.nutriScoreLetter.color
        let color = Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
        return Text(item.nutriScoreLetter.rawValue)
            .font(.system(size: 10, weight: .black))
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
}

#Preview {
    ContentView()
        .modelContainer(for: Product.self, inMemory: true)
}
