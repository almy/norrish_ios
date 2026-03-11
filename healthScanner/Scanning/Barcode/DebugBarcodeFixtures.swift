import Foundation

#if DEBUG
struct DebugBarcodeFixture: Identifiable, Hashable {
    let barcode: String
    let name: String
    let brand: String
    let categoryTags: [String]
    let ingredients: String
    let nutritionData: NutritionData

    var id: String { barcode }
}

enum DebugBarcodeFixtures {
    static let samples: [DebugBarcodeFixture] = [
        DebugBarcodeFixture(
            barcode: "7390000000001",
            name: "Lingongrovbrod Sample",
            brand: "ICA",
            categoryTags: ["en:breads"],
            ingredients: "Whole grain rye flour, water, lingonberries, wheat flour, rapeseed oil, yeast, salt",
            nutritionData: NutritionData(
                calories: 242,
                fat: 4.2,
                saturatedFat: 0.4,
                sugar: 6.1,
                sodium: 0.48,
                protein: 7.4,
                fiber: 9.6,
                carbohydrates: 38.0,
                fruitsVegetablesNutsPercent: nil
            )
        ),
        DebugBarcodeFixture(
            barcode: "7390000000002",
            name: "Filmjolk Naturell Sample",
            brand: "Arla",
            categoryTags: ["en:dairies", "en:fermented-milks"],
            ingredients: "Milk, lactic acid culture",
            nutritionData: NutritionData(
                calories: 45,
                fat: 1.5,
                saturatedFat: 1.0,
                sugar: 4.7,
                sodium: 0.05,
                protein: 3.5,
                fiber: 0.0,
                carbohydrates: 4.7,
                fruitsVegetablesNutsPercent: nil
            )
        ),
        DebugBarcodeFixture(
            barcode: "7390000000003",
            name: "Havredryck Barista Sample",
            brand: "Oatly",
            categoryTags: ["en:plant-based-milks", "en:oat-drinks"],
            ingredients: "Oat base, rapeseed oil, acidity regulator, calcium carbonate, iodised salt, vitamins",
            nutritionData: NutritionData(
                calories: 61,
                fat: 3.0,
                saturatedFat: 0.3,
                sugar: 4.0,
                sodium: 0.10,
                protein: 1.0,
                fiber: 0.8,
                carbohydrates: 6.7,
                fruitsVegetablesNutsPercent: nil
            )
        )
    ]

    static func fixture(for barcode: String) -> DebugBarcodeFixture? {
        samples.first { $0.barcode == barcode }
    }
}
#endif
