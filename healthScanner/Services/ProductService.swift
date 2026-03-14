import Foundation

@MainActor
final class ProductService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetchSimilarProducts(
        for barcode: String,
        limit: Int = 5,
        preferences: DietaryPreferencesManager = .shared
    ) async throws -> [SimilarProductSuggestion] {
        var queryItems = [
            URLQueryItem(name: "ean", value: barcode),
            URLQueryItem(name: "k", value: String(limit))
        ]
        let allergies = preferences.selectedAllergies.map { $0.rawValue }
        let customAllergies = preferences.customAllergies
        if !allergies.isEmpty {
            queryItems.append(URLQueryItem(name: "allergies", value: allergies.joined(separator: ",")))
        }
        if !customAllergies.isEmpty {
            queryItems.append(URLQueryItem(name: "customAllergies", value: customAllergies.joined(separator: ",")))
        }
        let response: BackendSimilarProductsResponse = try await BackendAPIClient.shared.get(
            endpoint: BackendAPIClient.shared.endpoints.similarProducts,
            queryItems: queryItems
        )
        return response.results.map {
            SimilarProductSuggestion(
                ean: $0.ean,
                name: $0.name ?? "Unknown Product",
                score: $0.score,
                imageUrl: $0.imageUrl,
                category: $0.category,
                nutriScore: $0.nutriScore,
                reason: $0.reason,
                allergenWarning: $0.allergenWarning
            )
        }
    }

    func fetchProductInfo(for barcode: String) async throws -> Product {
        isLoading = true
        defer { isLoading = false }

        let request = BackendBarcodeRequest(
            ean: barcode,
            locale: Locale.current.identifier
        )

        let response: BackendBarcodeResponse = try await BackendAPIClient.shared.post(
            endpoint: BackendAPIClient.shared.endpoints.scanBarcode,
            body: request
        )

        let payload = response.product
        let nutritionData = NutritionData(
            calories: payload.nutrition.calories,
            fat: payload.nutrition.fat,
            saturatedFat: payload.nutrition.saturatedFat,
            sugar: payload.nutrition.sugar,
            sodium: payload.nutrition.sodium,
            protein: payload.nutrition.protein,
            fiber: payload.nutrition.fiber,
            carbohydrates: payload.nutrition.carbohydrates,
            fruitsVegetablesNutsPercent: payload.nutrition.fruitsVegetablesNutsPercent
        )

        let product = Product(
            barcode: payload.ean,
            name: payload.name,
            brand: payload.brand,
            nutritionData: nutritionData,
            imageURL: payload.imageUrl,
            localImagePath: nil,
            categoriesTags: payload.category.map { [$0] },
            ingredients: payload.ingredients
        )

        cacheImageIfNeeded(urlString: payload.imageUrl, barcode: payload.ean, product: product)

        return product
    }

    private func cacheImageIfNeeded(urlString: String?, barcode: String, product: Product) {
        guard let urlString else { return }

        Task {
            let result = await ImageCacheService.shared.downloadAndCacheImage(from: urlString, forKey: barcode)
            if result != nil, let path = ImageCacheService.shared.cachedFilePath(forKey: barcode) {
                await MainActor.run {
                    product.localImagePath = path
                }
            }
        }
    }
}
