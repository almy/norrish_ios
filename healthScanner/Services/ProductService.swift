import Foundation

@MainActor
final class ProductService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetchProductInfo(for barcode: String) async throws -> Product {
        isLoading = true
        defer { isLoading = false }

        let request = BackendBarcodeRequest(
            barcode: barcode,
            locale: Locale.current.identifier
        )

        let response: BackendBarcodeResponse = try await BackendAPIClient.shared.post(
            endpoint: BackendAPIClient.shared.endpoints.scanBarcode,
            body: request
        )

        let payload = response.product
        let nutritionData = NutritionData(
            calories: payload.nutritionData.calories,
            fat: payload.nutritionData.fat,
            saturatedFat: payload.nutritionData.saturatedFat,
            sugar: payload.nutritionData.sugar,
            sodium: payload.nutritionData.sodium,
            protein: payload.nutritionData.protein,
            fiber: payload.nutritionData.fiber,
            carbohydrates: payload.nutritionData.carbohydrates,
            fruitsVegetablesNutsPercent: payload.nutritionData.fruitsVegetablesNutsPercent
        )

        let product = Product(
            barcode: payload.barcode,
            name: payload.name,
            brand: payload.brand,
            nutritionData: nutritionData,
            imageURL: payload.imageURL,
            localImagePath: nil,
            categoriesTags: payload.categoriesTags,
            ingredients: payload.ingredients
        )

        if let scannedDate = parseDate(payload.scannedDate) {
            product.scannedDate = scannedDate
        }

        cacheImageIfNeeded(urlString: payload.imageURL, barcode: payload.barcode, product: product)

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

    private func parseDate(_ value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }

        let formatterWithFraction = ISO8601DateFormatter()
        formatterWithFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatterWithFraction.date(from: value) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
