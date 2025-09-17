//
//  ProductService.swift
//  healthScanner
//
//  Created by myftiu on 06/09/25.
//

import Foundation

class ProductService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func fetchProductInfo(for barcode: String) async -> Product? {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        // Using OpenFoodFacts API - a free database of food products
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(barcode).json") else {
            errorMessage = "Invalid barcode"
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
            
            if response.status == 1, let product = response.product {
                return convertToProduct(barcode: barcode, openFoodFactsProduct: product)
            } else {
                // If product not found in API, create a sample product for demonstration
                return createSampleProduct(barcode: barcode)
            }
        } catch {
            errorMessage = "Failed to fetch product data: \(error.localizedDescription)"
            return createSampleProduct(barcode: barcode)
        }
    }
    
    private func convertToProduct(barcode: String, openFoodFactsProduct: OpenFoodFactsProduct) -> Product {
        let nutrition = openFoodFactsProduct.nutriments
        
        let nutritionData = NutritionData(
            calories: nutrition.energyKcal100g ?? 0,
            fat: nutrition.fat100g ?? 0,
            saturatedFat: nutrition.saturatedFat100g ?? 0,
            sugar: nutrition.sugars100g ?? 0,
            sodium: nutrition.sodium100g ?? 0,
            protein: nutrition.proteins100g ?? 0,
            fiber: nutrition.fiber100g ?? 0,
            carbohydrates: nutrition.carbohydrates100g ?? 0
        )
        
        return Product(
            barcode: barcode,
            name: openFoodFactsProduct.productName ?? "Unknown Product",
            brand: openFoodFactsProduct.brands ?? "Unknown Brand",
            nutritionData: nutritionData
        )
    }
    
    private func createSampleProduct(barcode: String) -> Product {
        // Create sample products for demonstration
        let sampleProducts: [String: (name: String, brand: String, nutrition: NutritionData)] = [
            "default": (
                name: "Sample Product",
                brand: "Sample Brand",
                nutrition: NutritionData(
                    calories: 250,
                    fat: 8.5,
                    saturatedFat: 3.2,
                    sugar: 12.0,
                    sodium: 0.8,
                    protein: 6.0,
                    fiber: 2.5,
                    carbohydrates: 35.0
                )
            )
        ]
        
        let sample = sampleProducts["default"]!
        return Product(
            barcode: barcode,
            name: sample.name,
            brand: sample.brand,
            nutritionData: sample.nutrition
        )
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
    let nutriments: Nutriments
    
    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case nutriments
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
    
    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case fat100g = "fat_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case sugars100g = "sugars_100g"
        case sodium100g = "sodium_100g"
        case proteins100g = "proteins_100g"
        case fiber100g = "fiber_100g"
        case carbohydrates100g = "carbohydrates_100g"
    }
}