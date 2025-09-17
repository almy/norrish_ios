//
//  ProductService.swift
//  norrish
//
//  Created by myftiu on 06/09/25.
//

import Foundation

class ProductService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - JSON Logging Helpers
    private func prettyJSONString(from data: Data, limit: Int = 8000) -> String {
        if let obj = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]) {
            var str = String(data: prettyData, encoding: .utf8) ?? "<unreadable JSON>"
            if str.count > limit { str = String(str.prefix(limit)) + "\n…(truncated, total chars=\(str.count))" }
            return str
        }
        return "<raw bytes=\(data.count)>"
    }
    
    private func encodePretty<T: Encodable>(_ value: T, limit: Int = 8000) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(value) {
            var str = String(data: data, encoding: .utf8) ?? "<unreadable encoded JSON>"
            if str.count > limit { str = String(str.prefix(limit)) + "\n…(truncated, total chars=\(str.count))" }
            return str
        }
        return "<encode failed>"
    }
    
    @MainActor
    func fetchProductInfo(for barcode: String) async throws -> Product {
        print("🔍 ProductService: Starting to fetch product info for barcode: \(barcode)")
        let urlString = "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
        
        guard let url = URL(string: urlString) else {
            print("❌ ProductService: Invalid URL for barcode: \(barcode)")
            throw ProductServiceError.invalidURL
        }
        
        print("🌐 ProductService: Making API request to: \(urlString)")
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Raw JSON log
        print("📄 OpenFoodFacts RAW JSON BEGIN\n\(prettyJSONString(from: data))\n📄 OpenFoodFacts RAW JSON END")
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            print("❌ ProductService: Invalid response. Status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            throw ProductServiceError.invalidResponse
        }
        
        print("✅ ProductService: Received valid response, parsing JSON…")
        let openFoodFactsResponse = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
        print("ℹ️ OpenFoodFacts: status=\(openFoodFactsResponse.status)")
        
        if let productData = openFoodFactsResponse.product {
            print("🧩 OpenFoodFacts PRODUCT JSON BEGIN\n\(encodePretty(productData))\n🧩 OpenFoodFacts PRODUCT JSON END")
            // Concise summary
            let summary: [String: Any?] = [
                "barcode": barcode,
                "product_name": productData.productName,
                "brands": productData.brands,
                "image_front_url": productData.imageFrontURL,
                "image_small_url": productData.imageSmallURL,
                "energy_kcal_100g": productData.nutriments?.energyKcal100g,
                "fat_100g": productData.nutriments?.fat100g,
                "saturated_fat_100g": productData.nutriments?.saturatedFat100g,
                "sugars_100g": productData.nutriments?.sugars100g,
                "sodium_100g": productData.nutriments?.sodium100g,
                "proteins_100g": productData.nutriments?.proteins100g,
                "fiber_100g": productData.nutriments?.fiber100g,
                "carbohydrates_100g": productData.nutriments?.carbohydrates100g
            ]
            if let conciseData = try? JSONSerialization.data(withJSONObject: summary.compactMapValues { $0 }, options: [.prettyPrinted]),
               let conciseStr = String(data: conciseData, encoding: .utf8) {
                print("🔎 OpenFoodFacts PRODUCT SUMMARY\n\(conciseStr)")
            }
        } else {
            print("⚠️ OpenFoodFacts: product section missing for barcode=\(barcode)")
        }
        
        guard let productData = openFoodFactsResponse.product else {
            print("❌ ProductService: Product not found in API response")
            throw ProductServiceError.productNotFound
        }
        
        print("📦 ProductService: Product data found. Name: \(productData.productName ?? "Unknown"), Brand: \(productData.brands ?? "Unknown")")
        print("🖼️ ProductService: Image URL: \(productData.imageFrontURL ?? "No image URL")")
        
        let product = convertToProduct(from: productData, barcode: barcode)
        print("✅ ProductService: Product conversion completed")
        return product
    }
    
    private func convertToProduct(from productData: OpenFoodFactsProduct, barcode: String) -> Product {
        print("🔄 ProductService: Converting OpenFoodFacts data to Product model")
        
        let nutritionData = NutritionData(
            calories: productData.nutriments?.energyKcal100g ?? 0,
            fat: productData.nutriments?.fat100g ?? 0,
            saturatedFat: productData.nutriments?.saturatedFat100g ?? 0,
            sugar: productData.nutriments?.sugars100g ?? 0,
            sodium: productData.nutriments?.sodium100g ?? 0,
            protein: productData.nutriments?.proteins100g ?? 0,
            fiber: productData.nutriments?.fiber100g ?? 0,
            carbohydrates: productData.nutriments?.carbohydrates100g ?? 0,
            fruitsVegetablesNutsPercent: productData.nutriments?.fruitsVegetablesNutsEstimate100g
        )
        
        let product = Product(
            barcode: barcode,
            name: productData.productName ?? "Unknown Product",
            brand: productData.brands ?? "Unknown Brand",
            nutritionData: nutritionData,
            imageURL: productData.imageFrontURL,
            localImagePath: nil,
            categoriesTags: productData.categoriesTags
        )
        
        print("✅ ProductService: Product created - Name: \(product.name), Brand: \(product.brand)")
        print("🖼️ ProductService: Product imageURL: \(product.imageURL ?? "nil")")
        
        // Cache the image immediately if available
        if let imageUrlString = productData.imageFrontURL {
            print("📥 ProductService: Starting background image caching for: \(imageUrlString)")
            Task {
                let result = await ImageCacheService.shared.downloadAndCacheImage(from: imageUrlString, forKey: barcode)
                if result != nil {
                    if let path = ImageCacheService.shared.cachedFilePath(forKey: barcode) {
                        await MainActor.run {
                            product.localImagePath = path
                            print("✅ ProductService: Set localImagePath=\(path) for barcode \(barcode)")
                        }
                    }
                    print("✅ ProductService: Image successfully cached for barcode: \(barcode)")
                } else {
                    print("❌ ProductService: Failed to cache image for barcode: \(barcode)")
                }
            }
        } else {
            print("⚠️ ProductService: No image URL available for caching")
        }
        
        return product
    }
    
    enum ProductServiceError: Error, LocalizedError {
        case invalidURL
        case invalidResponse
        case productNotFound
        case decodingError
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid response from server"
            case .productNotFound:
                return "Product not found"
            case .decodingError:
                return "Failed to decode product data"
            }
        }
    }
    
    // OpenFoodFacts API Response Models
    struct OpenFoodFactsResponse: Codable {
        let status: Int
        let product: OpenFoodFactsProduct?
    }
    
    struct OpenFoodFactsProduct: Codable {
        let productName: String?
        let brands: String?
        let nutriments: Nutriments?
        let imageURL: String?
        let imageFrontURL: String?
        let imageSmallURL: String?
        let categories: String?
        let categoriesTags: [String]?
        
        enum CodingKeys: String, CodingKey {
            case productName = "product_name"
            case brands
            case nutriments
            case imageURL = "image_url"
            case imageFrontURL = "image_front_url"
            case imageSmallURL = "image_small_url"
            case categories
            case categoriesTags = "categories_tags"
        }
    }
    
    struct Nutriments: Codable {
        let energyKcal100g: Double?
        let fat100g: Double?
        let saturatedFat100g: Double?
        let sugars100g: Double?
        let sodium100g: Double?
        let proteins100g: Double?
        let fiber100g: Double?
        let carbohydrates100g: Double?
        let fruitsVegetablesNutsEstimate100g: Double?
        
        enum CodingKeys: String, CodingKey {
            case energyKcal100g = "energy-kcal_100g"
            case fat100g = "fat_100g"
            case saturatedFat100g = "saturated-fat_100g"
            case sugars100g = "sugars_100g"
            case sodium100g = "sodium_100g"
            case proteins100g = "proteins_100g"
            case fiber100g = "fiber_100g"
            case carbohydrates100g = "carbohydrates_100g"
            case fruitsVegetablesNutsEstimate100g = "fruits-vegetables-nuts-estimate-from-ingredients_100g"
        }
    }
}
