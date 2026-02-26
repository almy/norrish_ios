//
//  ContentView.swift
//  norrish
//
//  Created by myftiu on 06/09/25.
//

import SwiftUI
import SwiftData
import Photos

extension Notification.Name {
    static let onboardingOpenPlatePhoto = Notification.Name("onboardingOpenPlatePhoto")
    static let onboardingOpenProductScan = Notification.Name("onboardingOpenProductScan")
}

// Shared grade filter used by History presentation controls.
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

// Pure helper that merges product + plate history and applies UI-selected
// filtering/sorting rules before the list is rendered.
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
                guard isHistoryEligibleProduct(product) else { return false }
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

    private static func isHistoryEligibleProduct(_ product: Product) -> Bool {
        let normalizedName = product.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedName.isEmpty { return false }
        if normalizedName == "unknown product" { return false }
        if normalizedName.contains("not found") || normalizedName.contains("unknown") { return false }
        return true
    }
}

struct ContentView: View {
    private static let recommendationEngine = OnDeviceNutritionRecommendationEngine()

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var localizationManager: LocalizationManager
    @EnvironmentObject private var quickActionState: HomeScreenQuickActionState
    @Query private var products: [Product]
    @Query private var plateAnalyses: [PlateAnalysisHistory]
    @StateObject private var barcodeScanVM = BarcodeScannerViewModel()

    // Global navigation/sheet state for scan and detail flows.
    @State private var showingScanner = false
    @State private var scannedCode: String?
    @State private var isScanning = false
    @State private var selectedProduct: Product?
    @State private var selectedPlateAnalysis: PlateAnalysisHistory?
    @State private var showingQuickAdd = false
    @State private var showingPlateScan = false
    @State private var showingPlateUpload = false
    @State private var showingProductNotFound = false
    @State private var quickPlateCapturePayload: QuickPlateCapturePayload?
    @State private var showingPhotoPermissionAlert = false
    @State private var photoPermissionStatus: PHAuthorizationStatus = PhotoLibraryPermission.currentStatus()
    @State private var selectedTab = 0
    @State private var appliedScreenshotInitialTab = false

    // History controls (query-like UI state).
    @State private var searchText = ""
    @State private var selectedFilter: ProductFilter = .all
    @State private var selectedHistoryType: HistoryType = .all
    @State private var selectedSort: SortOption = .date
    @State private var historyDigestIndex = 0
    @State private var didRunPlateHistoryMigration = false

    // Segment control for which domain to show in History.
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

    // Sort mode used by the history feed.
    enum SortOption: CaseIterable {
        case date, nutri

        var rawValue: String {
            switch self {
            case .date: return NSLocalizedString("sort.date", comment: "Sort option by date")
            case .nutri: return NSLocalizedString("sort.nutri_score", comment: "Sort option by Nutri-Score")
            }
        }
    }

    // Lightweight insight feed for the History screen header/cards.
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

    // Final data source for HistoryTabView after search/filter/sort is applied.
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
            // Main app shell with Home / History / Profile tabs.
            TabView(selection: $selectedTab) {
                TabWithFloatingAddButton(
                    onAdd: { showingQuickAdd = true },
                    onScanProduct: {
                        showingQuickAdd = false
                        showingScanner = true
                    },
                    onAnalyzePlate: {
                        showingQuickAdd = false
                        showingPlateScan = true
                    }
                ) {
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

                TabWithFloatingAddButton(
                    onAdd: { showingQuickAdd = true },
                    onScanProduct: {
                        showingQuickAdd = false
                        showingScanner = true
                    },
                    onAnalyzePlate: {
                        showingQuickAdd = false
                        showingPlateScan = true
                    }
                ) {
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
            .accessibilityIdentifier("root.tabView")
            .accentColor(.momentumAmber)
            .onAppear {
                guard !appliedScreenshotInitialTab else { return }
                appliedScreenshotInitialTab = true
                if let value = ProcessInfo.processInfo.environment["NORRISH_INITIAL_TAB"] {
                    switch value.lowercased() {
                    case "history":
                        selectedTab = 1
                    case "profile":
                        selectedTab = 2
                    default:
                        selectedTab = 0
                    }
                }
            }
            // Global product-fetch overlay used right after barcode scan returns.
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
            // Full-screen camera barcode scanner entry point.
            .fullScreenCover(isPresented: $showingScanner) {
                QuickBarcodeScanView(
                    scannedCode: $scannedCode,
                    isScanning: $isScanning,
                    isPresented: $showingScanner
                )
            }
            // Plate scan quick flow (camera path).
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
            // Plate scan quick flow (photo-library path).
            .fullScreenCover(isPresented: $showingPlateUpload) {
                PlateQuickScanView(mode: .photo)
            }
            // Not-found UX when backend cannot resolve scanned barcode.
            .fullScreenCover(isPresented: $showingProductNotFound) {
                ProductNotFoundView(
                    onClose: { showingProductNotFound = false },
                    onScanAgain: {
                        showingProductNotFound = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            showingScanner = true
                        }
                    },
                    onAddManually: {
                        showingProductNotFound = false
                        showingQuickAdd = true
                    },
                    onReport: {
                        showingProductNotFound = false
                    }
                )
            }
            // Continuation flow after quick plate capture.
            .fullScreenCover(item: $quickPlateCapturePayload) { payload in
                PlateQuickPostCaptureFlowView(capture: payload)
            }
            // External event hook to restart plate retake flow.
            .onReceive(NotificationCenter.default.publisher(for: .retakePlateScanFlow)) { _ in
                quickPlateCapturePayload = nil
                showingPlateScan = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .onboardingOpenPlatePhoto)) { _ in
                selectedTab = 0
                showingQuickAdd = false
                showingScanner = false
                showingPlateScan = false
                showingPlateUpload = false
                DispatchQueue.main.async {
                    showingPlateScan = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .onboardingOpenProductScan)) { _ in
                selectedTab = 0
                showingQuickAdd = false
                showingPlateUpload = false
                showingPlateScan = false
                showingScanner = false
                DispatchQueue.main.async {
                    showingScanner = true
                }
            }
            // Product details route.
            .sheet(item: $selectedProduct) { product in
                ProductDetailView(product: product)
            }
            // Plate details route.
            .sheet(item: $selectedPlateAnalysis) { plateAnalysis in
                PlateDetailView(plateAnalysis: plateAnalysis) {
                    selectedPlateAnalysis = nil
                }
            }
            // Main "Quick Add" launcher for barcode / plate actions.
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
                        showingQuickAdd = false
                        requestPhotoLibraryAndPresentUpload()
                    }
                )
            }
            .alert("Photo Access Needed", isPresented: $showingPhotoPermissionAlert) {
                Button("Open Settings") {
                    PhotoLibraryPermission.openSettings()
                }
                Button("Not Now", role: .cancel) { }
            } message: {
                Text(photoAccessMessage)
            }
            // Barcode handoff: fetch product, then route to detail or not-found UX.
            .onChange(of: scannedCode) { _, newValue in
                guard let code = newValue else { return }
                withAnimation(.easeInOut(duration: 0.22)) {
                    barcodeScanVM.isLoading = true
                }
                Task {
                    defer { scannedCode = nil }
                    do {
                        let product = try await barcodeScanVM.fetchProduct(
                            barcode: code,
                            existing: products,
                            modelContext: modelContext
                        )
                        selectedProduct = product
                    } catch {
                        if isNotFoundError(error) {
                            showingProductNotFound = true
                        }
                    }
                }
            }
            // One-time startup data migration for older plate history records.
            .task {
                guard !didRunPlateHistoryMigration else { return }
                didRunPlateHistoryMigration = true
                await PlateHistoryMigrationService.shared.migrateIfNeeded(modelContext: modelContext)
            }
            .onAppear {
                consumePendingHomeQuickAction()
            }
            .onChange(of: quickActionState.pendingAction) { _, _ in
                consumePendingHomeQuickAction()
            }
        }
    }

    private func consumePendingHomeQuickAction() {
        guard let action = quickActionState.consumePendingAction() else { return }
        selectedTab = 0
        showingQuickAdd = false
        showingProductNotFound = false
        selectedProduct = nil
        selectedPlateAnalysis = nil
        switch action {
        case .analyzePlate:
            showingScanner = false
            showingPlateUpload = false
            showingPlateScan = false
            DispatchQueue.main.async {
                showingPlateScan = true
            }
        case .scanProduct:
            showingPlateUpload = false
            showingPlateScan = false
            showingScanner = false
            DispatchQueue.main.async {
                showingScanner = true
            }
        }
    }

    private var photoAccessMessage: String {
        switch photoPermissionStatus {
        case .denied:
            return "Allow Photos access in Settings to upload meal pictures. You can grant Full Access or select Limited Photos."
        case .restricted:
            return "Photos access is restricted on this device. Please adjust parental controls or system restrictions."
        default:
            return "Allow Photos access to upload meal pictures."
        }
    }

    private func requestPhotoLibraryAndPresentUpload() {
        Task {
            let status = await PhotoLibraryPermission.requestReadWriteAccess()
            await MainActor.run {
                photoPermissionStatus = status
                if PhotoLibraryPermission.hasAccess(status) {
                    showingPlateUpload = true
                } else {
                    showingPhotoPermissionAlert = true
                }
            }
        }
    }

    // Deletes the selected history entity and cleans related cached media.
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

    // Detects backend "product not found" responses and similar variants.
    private func isNotFoundError(_ error: Error) -> Bool {
        if case BackendAPIError.httpError(let statusCode, _) = error {
            return statusCode == 404
        }
        let normalized = error.localizedDescription.lowercased()
        return normalized.contains("404") || normalized.contains("not found")
    }
}

// Minimal wrapper around scanner overlay used by the full-screen cover.
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
        .accessibilityIdentifier("screen.barcodeScanner")
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
