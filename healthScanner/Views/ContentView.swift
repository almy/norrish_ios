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

private enum HistoryFilterEngine {
    static func filterItems(
        products: [Product],
        plates: [PlateAnalysisHistory],
        historyType: ContentView.HistoryType,
        filter: ProductFilter,
        searchText: String,
        sort: ContentView.SortOption
    ) -> [HistoryItemType] {
        var allItems: [HistoryItemType] = []

        if historyType == .all || historyType == .products {
            let filteredProducts = products.filter { product in
                let matchesSearchText = searchText.isEmpty || product.name.localizedCaseInsensitiveContains(searchText)
                return matchesSearchText && matches(filter: filter, letter: product.nutriScoreLetter)
            }
            allItems.append(contentsOf: filteredProducts.map { .product($0) })
        }

        if historyType == .all || historyType == .plates {
            let filteredPlates = plates.filter { plate in
                let matchesSearchText = searchText.isEmpty || plate.name.localizedCaseInsensitiveContains(searchText)
                return matchesSearchText && matches(filter: filter, letter: plate.nutriScoreLetter)
            }
            allItems.append(contentsOf: filteredPlates.map { .plate($0) })
        }

        switch sort {
        case .date:
            return allItems.sorted { $0.date > $1.date }
        case .nutri:
            return allItems.sorted { nutriRank(for: $0) > nutriRank(for: $1) }
        }
    }

    private static func matches(filter: ProductFilter, letter: NutriScoreLetter) -> Bool {
        switch filter {
        case .all: return true
        case .gradeA: return letter == .A
        case .gradeB: return letter == .B
        case .gradeC: return letter == .C
        case .gradeD: return letter == .D
        case .gradeE: return letter == .E
        }
    }

    private static func nutriRank(for item: HistoryItemType) -> Int {
        switch item.nutriScoreLetter {
        case .A: return 5
        case .B: return 4
        case .C: return 3
        case .D: return 2
        case .E: return 1
        }
    }
}

struct ContentView: View {
    private static let recommendationEngine = OnDeviceNutritionRecommendationEngine()

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var localizationManager: LocalizationManager
    @Query private var products: [Product]
    @Query private var plateAnalyses: [PlateAnalysisHistory]
    @StateObject private var barcodeScanVM = BarcodeScannerViewModel()

    @State private var showingScanner = false
    @State private var scannedCode: String?
    @State private var isScanning = false
    @State private var selectedProduct: Product?
    @State private var selectedPlateAnalysis: PlateAnalysisHistory?
    @State private var showingQuickAdd = false
    @State private var showingPlateScan = false
    @State private var showingPlateUpload = false
    @State private var quickPlateCapturePayload: QuickPlateCapturePayload?
    @State private var selectedTab = 0

    @State private var searchText = ""
    @State private var selectedFilter: ProductFilter = .all
    @State private var selectedHistoryType: HistoryType = .all
    @State private var selectedSort: SortOption = .date
    @State private var historyDigestIndex = 0
    @State private var didRunPlateHistoryMigration = false

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

    private var historyTrendInsights: [PersonalizedInsight] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date.distantPast
        let recentPlates = plateAnalyses.filter { $0.analyzedDate >= cutoff }
        let recentProducts = products.filter { $0.scannedDate >= cutoff }
        let recs = Self.recommendationEngine.generateAdaptiveTrendInsights(plates: recentPlates, products: recentProducts)

        return recs.prefix(3).map { r in
            let icon: String
            let color: Color
            if r.tags.contains("fiber") { icon = "leaf.fill"; color = .mossInsight }
            else if r.tags.contains("protein") { icon = "bolt.heart.fill"; color = .momentumAmber }
            else { icon = "lightbulb.fill"; color = .nordicSlate }
            return PersonalizedInsight(icon: icon, iconColor: color, title: r.title, message: r.message, category: .health, reason: r.reason, evidence: r.evidence, tags: r.tags)
        }
    }

    private var filteredHistoryItems: [HistoryItemType] {
        HistoryFilterEngine.filterItems(
            products: products,
            plates: plateAnalyses,
            historyType: selectedHistoryType,
            filter: selectedFilter,
            searchText: searchText,
            sort: selectedSort
        )
    }

    var body: some View {
        PromptOverlayHost {
            TabView(selection: $selectedTab) {
                TabWithFloatingAddButton(onAdd: { showingQuickAdd = true }) {
                    HomeView(onViewAllHistory: {
                        selectedTab = 1
                    })
                }
                .tabItem {
                    VStack {
                        Image(systemName: "house")
                        Text(NSLocalizedString("home.title", comment: "Home tab title"))
                    }
                }
                .tag(0)

                TabWithFloatingAddButton(onAdd: { showingQuickAdd = true }) {
                    HistoryTabView(
                        filteredHistoryItems: filteredHistoryItems,
                        historyTrendInsights: historyTrendInsights,
                        historyDigestIndex: $historyDigestIndex,
                        onSelectItem: { item in
                            switch item {
                            case .product(let product):
                                selectedProduct = product
                            case .plate(let plate):
                                selectedPlateAnalysis = plate
                            }
                        },
                        onDeleteItem: { item in
                            deleteHistoryItem(item)
                        }
                    )
                }
                .tabItem {
                    VStack {
                        Image(systemName: "clock")
                        Text("tab.history".localized())
                    }
                }
                .tag(1)

                ProfileView()
                    .tabItem {
                        VStack {
                            Image(systemName: "person")
                            Text("tab.profile".localized())
                        }
                    }
                    .tag(2)
            }
            .accentColor(.momentumAmber)
            .overlay {
                if barcodeScanVM.isLoading {
                    AppLoadingOverlay(
                        title: "Fetching product information...",
                        subtitle: "Looking up barcode details"
                    )
                    .transition(.opacity)
                    .zIndex(1000)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: barcodeScanVM.isLoading)
            .fullScreenCover(isPresented: $showingScanner) {
                QuickBarcodeScanView(
                    scannedCode: $scannedCode,
                    isScanning: $isScanning,
                    isPresented: $showingScanner
                )
            }
            .fullScreenCover(isPresented: $showingPlateScan) {
                PlateQuickScanView(
                    mode: .camera,
                    onCameraCaptured: { payload in
                        showingPlateScan = false
                        DispatchQueue.main.async {
                            quickPlateCapturePayload = payload
                        }
                    }
                )
            }
            .fullScreenCover(isPresented: $showingPlateUpload) {
                PlateQuickScanView(mode: .photo)
            }
            .fullScreenCover(item: $quickPlateCapturePayload) { payload in
                PlateQuickPostCaptureFlowView(capture: payload)
            }
            .onReceive(NotificationCenter.default.publisher(for: .retakePlateScanFlow)) { _ in
                quickPlateCapturePayload = nil
                showingPlateScan = true
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
                QuickAddSheetView(
                    onScanBarcode: {
                        showingScanner = true
                        showingQuickAdd = false
                    },
                    onScanPlate: {
                        showingPlateScan = true
                        showingQuickAdd = false
                    },
                    onUploadPlate: {
                        showingPlateUpload = true
                        showingQuickAdd = false
                    }
                )
            }
            .onChange(of: scannedCode) { _, newValue in
                guard let code = newValue else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    barcodeScanVM.isLoading = true
                }
                Task {
                    defer { scannedCode = nil }
                    if let product = try? await barcodeScanVM.fetchProduct(
                        barcode: code,
                        existing: products,
                        modelContext: modelContext
                    ) {
                        selectedProduct = product
                    }
                }
            }
            .task {
                guard !didRunPlateHistoryMigration else { return }
                didRunPlateHistoryMigration = true
                await PlateHistoryMigrationService.shared.migrateIfNeeded(modelContext: modelContext)
            }
        }
    }

    private func deleteHistoryItem(_ item: HistoryItemType) {
        switch item {
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

#Preview {
    ContentView()
        .modelContainer(for: Product.self, inMemory: true)
}
