import Foundation
import SwiftUI
import SwiftData

@MainActor
final class BarcodeScannerViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var recentScans: [RecentScan] = []

    private let productService = ProductService()

    func loadRecentScans(from products: [Product]) {
        recentScans = Array(products.prefix(10)).map { product in
            RecentScan(
                id: UUID(),
                barcode: product.barcode,
                productName: product.name,
                scanDate: product.scannedDate,
                nutriScoreLetter: product.nutriScoreLetter,
                imageURL: product.imageURL
            )
        }
    }

    /// Fetches or returns existing product, persists if new, and returns it.
    func fetchProduct(barcode: String, existing products: [Product], modelContext: ModelContext) async throws -> Product {
        isLoading = true
        defer { isLoading = false }

        if let existing = products.first(where: { $0.barcode == barcode }) {
            return existing
        }

        do {
            let product = try await productService.fetchProductInfo(for: barcode)
            // Guardrail: do not persist backend placeholders for missing products.
            guard shouldPersistInHistory(product) else {
                throw BackendAPIError.httpError(statusCode: 404, body: "Product not found")
            }
            modelContext.insert(product)
            try modelContext.save()
            NotificationCenter.default.post(name: .barcodeScanCompleted, object: nil, userInfo: [
                "upc": product.barcode,
                "title": product.name,
                "store": nil as String?
            ])
            // Event-driven aggregate update for the product's scan day
            await AggregatorService.shared.upsertDaily(for: product.scannedDate, modelContext: modelContext)
            return product
        } catch {
            errorMessage = "Failed to fetch product information: \(error.localizedDescription)"
            throw error
        }
    }

    private func shouldPersistInHistory(_ product: Product) -> Bool {
        let normalizedName = product.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedBrand = product.brand.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let looksLikeNotFoundName =
            normalizedName.isEmpty
            || normalizedName == "unknown product"
            || normalizedName.contains("not found")
            || normalizedName.contains("unknown")

        let looksLikeNotFoundBrand =
            normalizedBrand.isEmpty
            || normalizedBrand == "unknown"
            || normalizedBrand.contains("not found")

        let n = product.nutritionData
        let hasNoNutritionSignal =
            n.calories <= 0
            && n.fat <= 0
            && n.saturatedFat <= 0
            && n.sugar <= 0
            && n.sodium <= 0
            && n.protein <= 0
            && n.fiber <= 0
            && n.carbohydrates <= 0

        if looksLikeNotFoundName { return false }
        if looksLikeNotFoundBrand && hasNoNutritionSignal { return false }
        return true
    }
}
