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
    @StateObject private var insightService = InsightDataService.shared
    
    @State private var showingScanner = false
    @State private var scannedCode: String?
    @State private var isScanning = false
    @State private var selectedProduct: Product?
    @State private var selectedPlateAnalysis: PlateAnalysisHistory?
    @State private var showingProductDetail = false
    @State private var selectedTab = 0
    
    // New state properties for history tab
    @State private var searchText = ""
    @State private var selectedFilter: ProductFilter = .all
    @State private var selectedHistoryType: HistoryType = .all
    @State private var selectedSort: SortOption = .date
    
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
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Scan Tab - Replace with BarcodeScannerView
            BarcodeScannerView(
                scannedCode: $scannedCode,
                isScanning: $isScanning
            )
            .tabItem {
                VStack {
                    Image(systemName: "barcode.viewfinder")
                    Text("tab.scan".localized())
                }
            }
            .tag(0)
            
            // Plate Tab - Now using photo-based analysis (AR disabled)
            NavigationView {
                PlateAnalysisView()
                    .navigationBarHidden(true)
            }
            .tabItem {
                VStack {
                    Image(systemName: "fork.knife")
                    Text("tab.plate".localized())
                }
            }
            .tag(1)
            
            // History Tab
            NavigationView {
                VStack(spacing: 0) {
                    // Custom Header
                    HStack {
                        Text("tab.history".localized())
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        // Invisible spacer to center the title
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .opacity(0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    VStack(spacing: 20) {
                        // Search Bar
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField(NSLocalizedString("search.placeholder", comment: "Search placeholder text"), text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(25)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Filter Buttons
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(ProductFilter.allCases, id: \.self) { filter in
                                    FilterButton(title: filter.title, isSelected: selectedFilter == filter) {
                                        selectedFilter = filter
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // History Type Picker
                        Picker(NSLocalizedString("picker.history_type", comment: "History type picker label"), selection: $selectedHistoryType) {
                            ForEach(HistoryType.allCases, id: \.self) { type in
                                Text(type.title).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal, 20)
                        .padding(.top, 10)

                        // Sort Picker
                        Picker(NSLocalizedString("picker.sort", comment: "Sort picker label"), selection: $selectedSort) {
                            ForEach(SortOption.allCases, id: \.self) { opt in
                                Text(opt.rawValue).tag(opt)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal, 20)
                    }
                    
                    // Products List
                    if filteredHistoryItems.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "clock")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            Text(NSLocalizedString("empty.no_scans", comment: "Empty state title"))
                                .font(.title3)
                                .foregroundColor(.secondary)
                            Text(NSLocalizedString("empty.start_scanning", comment: "Empty state description"))
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Spacer()
                        }
                        .padding(.top, 60)
                    } else {
                        List {
                            ForEach(filteredHistoryItems) { item in
                                switch item {
                                case .product(let product):
                                    HistoryProductRowView(product: product) {
                                        print("[History] Row tapped for product barcode=\(product.barcode) name=\(product.name) imageURL=\(product.imageURL ?? "nil")")
                                        // Use only selectedProduct; sheet(item:) will present when non-nil
                                        selectedProduct = product
                                    }
                                case .plate(let plateAnalysis):
                                    HistoryPlateRowView(plateAnalysis: plateAnalysis) {
                                        print("[History] Row tapped for plate id=\(plateAnalysis.id) name=\(plateAnalysis.name)")
                                        selectedPlateAnalysis = plateAnalysis
                                    }
                                }
                            }
                            .onDelete { indexSet in
                                for index in indexSet {
                                    let item = filteredHistoryItems[index]
                                    switch item {
                                    case .product(let product):
                                        modelContext.delete(product)
                                    case .plate(let plateAnalysis):
                                        modelContext.delete(plateAnalysis)
                                    }
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                    }
                }
                .navigationBarHidden(true)
            }
            .tabItem {
                VStack {
                    Image(systemName: "clock")
                    Text("tab.history".localized())
                }
            }
            .tag(2)
            
            // Profile Tab
            ProfileView()
            .tabItem {
                VStack {
                    Image(systemName: "person")
                    Text("tab.profile".localized())
                }
            }
            .tag(3)
        }
        .accentColor(.green)
        .sheet(isPresented: $showingScanner) {
            BarcodeScannerView(
                scannedCode: $scannedCode,
                isScanning: $isScanning
            )
        }
        .sheet(item: $selectedProduct) { product in
            ProductDetailView(product: product)
        }
        .sheet(item: $selectedPlateAnalysis) { plateAnalysis in
            PlateHistoryDetailView(plateAnalysis: plateAnalysis) {
                selectedPlateAnalysis = nil
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

// History Row Views
struct HistoryProductRowView: View {
    let product: Product
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            // Product image or placeholder
            Group {
                if let productImageURL = product.imageURL, !productImageURL.isEmpty {
                    CachedAsyncImage(urlString: productImageURL, cacheKey: product.barcode)
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .overlay(
                            Image(systemName: "cart")
                                .font(.title2)
                                .foregroundColor(.gray)
                        )
                }
            }
            .frame(width: 70, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    NutriScoreBadge(letter: product.nutriScoreLetter, compact: true)
                }
                
                Text(String(format: NSLocalizedString("scanning.scanned_on", comment: "Scanned date format"), product.scannedDate.formatted(date: .abbreviated, time: .shortened)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(product.scannedDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}

struct HistoryPlateRowView: View {
    let plateAnalysis: PlateAnalysisHistory
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 15) {
            // Plate image with health indicator overlay
            ZStack(alignment: .bottomTrailing) {
                // Use cached image first, fallback to stored imageData
                Group {
                    if let cachedImage = ImageCacheService.shared.loadImage(forKey: plateAnalysis.cacheKey) {
                        Image(uiImage: cachedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if let image = plateAnalysis.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.1))
                            .overlay(
                                Image(systemName: "fork.knife")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Nutri-Score badge overlay
                NutriScoreBadge(letter: plateAnalysis.nutriScoreLetter, compact: true)
                    .offset(x: 5, y: 5)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(plateAnalysis.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                
                Text(String(format: NSLocalizedString("scanning.analyzed_on", comment: "Analyzed date format"), plateAnalysis.analyzedDate.formatted(date: .abbreviated, time: .shortened)))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(plateAnalysis.analyzedDate.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Product.self, inMemory: true)
}
