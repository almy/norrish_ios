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
}

