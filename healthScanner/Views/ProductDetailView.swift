//
//  ProductDetailView.swift
//  healthScanner
//
//  Created by user on 09/09/25.
//

import SwiftUI
import UIKit

struct ProductDetailView: View {
    let product: Product
    @Environment(\.dismiss) private var dismiss
    @State private var showNutriInfo = false
    @State private var didLogProduct = false
    @State private var similarSuggestions: [SimilarProductSuggestion] = []
    @State private var isLoadingSimilar = false
    @State private var didLoadSimilar = false
    @State private var similarError: String?
    @StateObject private var productService = ProductService()
    
    private let nordicBackground = Color.nordicBone

    var body: some View {
        ZStack(alignment: .top) {
            nordicBackground
                .ignoresSafeArea()

            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroHeader
                        contentCard
                    }
                    .frame(width: proxy.size.width, alignment: .top)
                    .padding(.bottom, 150)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            }

            headerBar
            bottomCTA
        }
        .sheet(isPresented: $showNutriInfo) {
            NutriScoreInfoView(
                productBreakdown: computeNutriScoreBreakdown(product.nutritionData, categories: product.categoriesTags),
                plateScore: nil
            )
        }
        .onAppear {
            print("[ProductDetailView] Appeared for barcode=\(product.barcode) name=\(product.name) brand=\(product.brand) imageURL=\(product.imageURL ?? "nil") localImagePath=\(product.localImagePath ?? "nil")")
            if product.localImagePath == nil, let path = ImageCacheService.shared.cachedFilePath(forKey: product.barcode) {
                product.localImagePath = path
                print("[ProductDetailView] Set missing localImagePath=\(path)")
            }
            if !didLoadSimilar {
                didLoadSimilar = true
                isLoadingSimilar = true
                Task {
                    do {
                        let results = try await productService.fetchSimilarProducts(for: product.barcode, limit: 5)
                        await MainActor.run {
                            similarSuggestions = results
                            isLoadingSimilar = false
                        }
                    } catch {
                        await MainActor.run {
                            similarError = error.localizedDescription
                            isLoadingSimilar = false
                        }
                    }
                }
            }
        }
    }

    private var heroHeader: some View {
        ZStack {
            productHeroImage
                .frame(height: UIScreen.main.bounds.height * 0.45)
                .clipped()

            LinearGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.6), Color.black.opacity(0.0)]),
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(height: UIScreen.main.bounds.height * 0.45)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Button(action: { showNutriInfo = true }) {
                        nutriScoreBadge
                    }
                    .buttonStyle(.plain)
                    Text(productCategoryLabel.uppercased())
                        .font(AppFonts.label)
                        .kerning(2.5)
                        .foregroundColor(.white.opacity(0.8))
                }
                Text(product.name)
                    .font(AppFonts.serif(32, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text(productSubtitle.uppercased())
                    .font(AppFonts.sans(11, weight: .medium))
                    .kerning(2.5)
                    .foregroundColor(.white.opacity(0.7))
                    .italic()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 44)
            .frame(height: UIScreen.main.bounds.height * 0.45, alignment: .bottom)
        }
    }

    private var headerBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    )
            }
            Spacer()
            Text(NSLocalizedString("product.analysis", comment: "Product analysis title"))
                .font(AppFonts.label)
                .kerning(2.5)
                .foregroundColor(.white.opacity(0.9))
                .textCase(.uppercase)
            Spacer()
            Circle()
                .fill(Color.clear)
                .frame(width: 40, height: 40)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var contentCard: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundColor(.nordicSlate)
                    Text(NSLocalizedString("product.insight", comment: "Product insight header"))
                        .font(AppFonts.label)
                        .foregroundColor(.nordicSlate)
                        .kerning(2)
                        .textCase(.uppercase)
                }
                Text("“\(productInsightText)”")
                    .font(AppFonts.serif(22, weight: .regular))
                    .italic()
                    .foregroundColor(.midnightSpruce)
                    .lineSpacing(6)
            }

            if let chips = parsedIngredients, !chips.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "book")
                            .font(.system(size: 16))
                            .foregroundColor(.nordicSlate)
                        Text(NSLocalizedString("ingredients.detected", comment: "Detected ingredients header"))
                            .font(AppFonts.label)
                            .foregroundColor(.nordicSlate)
                            .kerning(2)
                            .textCase(.uppercase)
                    }

                    FlowLayout(alignment: .leading, spacing: 8) {
                        ForEach(chips, id: \.self) { ing in
                            Text(ing)
                                .font(AppFonts.sans(10, weight: .semibold))
                                .textCase(.uppercase)
                                .kerning(1.5)
                                .foregroundColor(.nordicSlate)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(Color.cardSurface)
                                        .overlay(Capsule().stroke(Color.cardBorder, lineWidth: 1))
                                )
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(NSLocalizedString("macro.profile", comment: "Macro profile header"))
                        .font(AppFonts.label)
                        .foregroundColor(.nordicSlate)
                        .kerning(3)
                        .textCase(.uppercase)
                    Spacer()
                    if let badge = glycemicBadgeText {
                        Text(badge)
                            .font(AppFonts.sans(9, weight: .bold))
                            .foregroundColor(.momentumAmber)
                            .kerning(1.5)
                            .textCase(.uppercase)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.momentumAmber.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                VStack(spacing: 10) {
                    MacroRow(title: String(format: NSLocalizedString("macro.carbs", comment: "Carbohydrates label with amount placeholder"), String(format: "%.1f", product.nutritionData.carbohydrates)),
                             level: macroLevelText(for: .carbs),
                             widthFraction: macroWidth(for: .carbs),
                             color: .momentumAmber)
                    MacroRow(title: String(format: NSLocalizedString("macro.sugar", comment: "Sugar label with amount placeholder"), String(format: "%.1f", product.nutritionData.sugar)),
                             level: macroLevelText(for: .sugar),
                             widthFraction: macroWidth(for: .sugar),
                             color: .midnightSpruce)
                    MacroRow(title: String(format: NSLocalizedString("macro.protein", comment: "Protein label with amount placeholder"), String(format: "%.1f", product.nutritionData.protein)),
                             level: macroLevelText(for: .protein),
                             widthFraction: macroWidth(for: .protein),
                             color: .nordicSlate)
                    MacroRow(title: String(format: NSLocalizedString("macro.fat", comment: "Fat label with amount placeholder"), String(format: "%.1f", product.nutritionData.fat)),
                             level: macroLevelText(for: .fat),
                             widthFraction: macroWidth(for: .fat),
                             color: .nordicSlate)
                }
            }

            if isLoadingSimilar {
                Text("Loading alternatives…")
                    .font(AppFonts.sans(12, weight: .medium))
                    .foregroundColor(.nordicSlate)
            } else if !similarSuggestions.isEmpty {
                similarSection
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
        .padding(.bottom, 40)
        .background(
            Color.cardSurface
                .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .stroke(Color.cardBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: -6)
        )
        .offset(y: -28)
    }

    private var similarSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16))
                    .foregroundColor(.nordicSlate)
                Text("Better Swaps")
                    .font(AppFonts.label)
                    .foregroundColor(.nordicSlate)
                    .kerning(2)
                    .textCase(.uppercase)
            }

            ForEach(similarSuggestions) { suggestion in
                HStack(spacing: 12) {
                    if let url = suggestion.imageUrl, !url.isEmpty {
                        CachedAsyncImage(urlString: url, cacheKey: suggestion.ean)
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.cardSurface)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.cardBorder, lineWidth: 1))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Image(systemName: "cart")
                                    .font(.system(size: 18))
                                    .foregroundColor(.nordicSlate)
                            )
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(suggestion.name)
                            .font(AppFonts.sans(14, weight: .semibold))
                            .foregroundColor(.midnightSpruce)
                            .lineLimit(1)
                        if let reason = suggestion.reason, !reason.isEmpty {
                            Text(reason)
                                .font(AppFonts.sans(11, weight: .medium))
                                .foregroundColor(.nordicSlate)
                                .lineLimit(2)
                        }
                        if let warning = suggestion.allergenWarning, !warning.isEmpty {
                            Text(warning)
                                .font(AppFonts.sans(11, weight: .semibold))
                                .foregroundColor(.momentumAmber)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.cardSurface)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cardBorder, lineWidth: 1))
                )
            }
        }
    }

    private var bottomCTA: some View {
        VStack {
            Spacer()
            Button(action: { logThisProduct(); dismiss() }) {
                HStack(spacing: 10) {
                    Text(NSLocalizedString("product.log", comment: "Log this product CTA"))
                        .font(AppFonts.sans(12, weight: .bold))
                        .kerning(1.5)
                        .textCase(.uppercase)
                    Image(systemName: "plus.circle")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: 360)
                .frame(height: 64)
                .background(Color.midnightSpruce)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 10)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 90)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var productHeroImage: some View {
        Group {
            if let localPath = product.localImagePath,
               FileManager.default.fileExists(atPath: localPath),
               let uiImage = UIImage(contentsOfFile: localPath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let productImageURL = product.imageURL, !productImageURL.isEmpty {
                CachedAsyncImage(urlString: productImageURL, cacheKey: product.barcode)
                    .scaledToFill()
            } else {
                Color.nordicBone.opacity(0.8)
                    .overlay(
                        Image(systemName: "cart")
                            .font(.system(size: 48))
                            .foregroundColor(.nordicSlate)
                    )
            }
        }
    }

    private var nutriScoreBadge: some View {
        let color = nutriColor
        return HStack(spacing: 4) {
            Text(NSLocalizedString("nutri.score", comment: "Nutri-score label"))
                .font(AppFonts.sans(9, weight: .bold))
            Text(product.nutriScoreLetter.rawValue)
                .font(AppFonts.sans(13, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var nutriColor: Color {
        let rgb = product.nutriScoreLetter.color
        return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    private var productCategoryLabel: String {
        if let tag = product.categoriesTags?.first {
            let cleaned = tag.replacingOccurrences(of: "en:", with: "").replacingOccurrences(of: "-", with: " ")
            return cleaned.capitalized
        }
        if !product.brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return product.brand
        }
        return NSLocalizedString("product.category.default", comment: "Fallback category label")
    }

    private var productSubtitle: String {
        if !product.brand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return product.brand
        }
        return NSLocalizedString("product.subtitle.default", comment: "Fallback subtitle")
    }

    // MARK: - Macro helpers
    private enum MacroType { case carbs, sugar, protein, fat }

    private func macroWidth(for type: MacroType) -> CGFloat {
        let v: Double
        switch type {
        case .carbs: v = product.nutritionData.carbohydrates
        case .sugar: v = product.nutritionData.sugar
        case .protein: v = product.nutritionData.protein
        case .fat: v = product.nutritionData.fat
        }
        switch type {
        case .carbs: return min(1.0, max(0.0, v / 25.0))
        case .sugar: return min(1.0, max(0.0, v / 20.0))
        case .protein: return min(1.0, max(0.0, v / 20.0))
        case .fat: return min(1.0, max(0.0, v / 20.0))
        }
    }

    private func macroLevelText(for type: MacroType) -> String {
        let f = macroWidth(for: type)
        switch type {
        case .carbs:
            if f >= 0.8 { return NSLocalizedString("level.high", comment: "High level") }
            if f >= 0.6 { return NSLocalizedString("level.moderate_high", comment: "Moderate-High level") }
            if f >= 0.3 { return NSLocalizedString("level.moderate", comment: "Moderate level") }
            return NSLocalizedString("level.low", comment: "Low level")
        case .sugar:
            if f >= 0.7 { return NSLocalizedString("level.high", comment: "High level") }
            if f >= 0.5 { return NSLocalizedString("level.moderate_high", comment: "Moderate-High level") }
            if f >= 0.25 { return NSLocalizedString("level.moderate", comment: "Moderate level") }
            return NSLocalizedString("level.minimal", comment: "Minimal level")
        case .protein, .fat:
            if f < 0.1 { return NSLocalizedString("level.minimal", comment: "Minimal level") }
            if f < 0.3 { return NSLocalizedString("level.low", comment: "Low level") }
            if f < 0.6 { return NSLocalizedString("level.moderate", comment: "Moderate level") }
            return NSLocalizedString("level.high", comment: "High level")
        }
    }

    private var glycemicBadgeText: String? {
        let carbs = product.nutritionData.carbohydrates
        let sugar = product.nutritionData.sugar
        if sugar >= 12 || carbs >= 20 {
            return NSLocalizedString("glycemic.high", comment: "High Glycemic Load badge")
        }
        return nil
    }

    private var parsedIngredients: [String]? {
        guard let raw = product.ingredients, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let seps = CharacterSet(charactersIn: ",;•|/")
        let parts = raw.components(separatedBy: seps).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let chips = parts.filter { !$0.isEmpty }
        return chips
    }

    private var productInsightText: String {
        let sugar = product.nutritionData.sugar
        let carbs = product.nutritionData.carbohydrates
        let hasVitC = product.ingredients?.lowercased().contains("vitamin c") == true
        var pieces: [String] = []
        if hasVitC { pieces.append(NSLocalizedString("insight.vitc", comment: "Vitamin C enriched")) }
        if sugar >= 12 || carbs >= 20 {
            pieces.append(NSLocalizedString("insight.sugars", comment: "Significant sugars"))
        }
        if pieces.isEmpty { pieces.append(NSLocalizedString("insight.generic", comment: "Generic product insight")) }
        return pieces.joined(separator: ", ")
    }

    private func logThisProduct() {
        didLogProduct = true
        print("[ProductDetailView] Logged product: \(product.name)")
    }

    // MARK: - MacroRow view
    private struct MacroRow: View {
        let title: String
        let level: String
        let widthFraction: CGFloat
        let color: Color

        var body: some View {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.12))
                        .frame(width: max(8, proxy.size.width * widthFraction), height: 32)
                    HStack {
                        Text(title)
                            .font(AppFonts.label)
                            .foregroundColor(.nordicSlate)
                            .kerning(2)
                        Spacer()
                        Text(level)
                            .font(AppFonts.serif(18, weight: .regular))
                            .foregroundColor(.midnightSpruce)
                    }
                    .padding(.horizontal, 6)
                }
            }
            .frame(height: 32)
            .padding(.vertical, 4)
        }
    }
}

// Preview-only: static sample product and in-memory model context.
#Preview("Product Detail") {
    ProductDetailView(product: Product.sampleProduct)
        .modelContainer(for: Product.self, inMemory: true)
}

// CachedAsyncImage moved to Views/Components/CachedAsyncImage.swift

struct FlowLayout<Content: View>: View {
    let alignment: HorizontalAlignment
    let spacing: CGFloat
    let content: () -> Content
    init(alignment: HorizontalAlignment = .leading, spacing: CGFloat = 8, @ViewBuilder content: @escaping () -> Content) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content
    }
    var body: some View {
        FlowLayoutContainer(spacing: spacing) { content() }
    }
}

private struct FlowLayoutContainer: Layout {
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
            rowHeight = Swift.max(rowHeight, size.height)
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
            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: ProposedViewSize(width: size.width, height: size.height))
            x += size.width + spacing
            rowHeight = Swift.max(rowHeight, size.height)
        }
    }
}
