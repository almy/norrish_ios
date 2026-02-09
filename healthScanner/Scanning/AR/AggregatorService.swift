import Foundation
import SwiftData

@MainActor
final class AggregatorService {
    static let shared = AggregatorService()
    private init() {}

    // Upsert aggregate for a specific calendar day
    func upsertDaily(for date: Date, modelContext: ModelContext) async {
        let cal = Calendar.current
        let start = cal.startOfDay(for: date)
        guard let end = cal.date(byAdding: .day, value: 1, to: start) else { return }

        // Fetch products in day range
        let productPredicate = #Predicate<Product> { p in
            p.scannedDate >= start && p.scannedDate < end
        }
        var products: [Product] = []
        do {
            let fetch = FetchDescriptor<Product>(predicate: productPredicate)
            products = try modelContext.fetch(fetch)
        } catch {
            // If fetch fails, continue with empty
            products = []
        }

        // Fetch plates in day range
        let platePredicate = #Predicate<PlateAnalysisHistory> { h in
            h.analyzedDate >= start && h.analyzedDate < end
        }
        var plates: [PlateAnalysisHistory] = []
        do {
            let fetch = FetchDescriptor<PlateAnalysisHistory>(predicate: platePredicate)
            plates = try modelContext.fetch(fetch)
        } catch {
            plates = []
        }

        // Aggregate totals
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0

        for p in products {
            calories += p.nutritionData.calories
            protein  += p.nutritionData.protein
            carbs    += p.nutritionData.carbohydrates
            fat      += p.nutritionData.fat
        }
        for h in plates {
            calories += Double(h.calories)
            protein  += Double(h.protein)
            carbs    += Double(h.carbs)
            fat      += Double(h.fat)
        }

        // Find existing aggregate for the day
        let aggPredicate = #Predicate<DailyNutritionAggregateEntity> { a in
            a.date >= start && a.date < end
        }
        var existing: DailyNutritionAggregateEntity?
        do {
            let fetch = FetchDescriptor<DailyNutritionAggregateEntity>(predicate: aggPredicate)
            existing = try modelContext.fetch(fetch).first
        } catch {
            existing = nil
        }

        if let agg = existing {
            agg.date = start
            agg.calories = calories
            agg.proteinGrams = protein
            agg.carbsGrams = carbs
            agg.fatGrams = fat
        } else {
            let agg = DailyNutritionAggregateEntity(
                date: start,
                calories: calories,
                proteinGrams: protein,
                carbsGrams: carbs,
                fatGrams: fat
            )
            modelContext.insert(agg)
        }

        do { try modelContext.save() } catch { /* ignore save errors to avoid blocking UI */ }
    }

    // Ensure aggregates exist for the last `limit` days (including today)
    func upsertMissingDays(limit: Int, modelContext: ModelContext) async {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let count = max(0, limit)
        for i in 0..<count {
            if let day = cal.date(byAdding: .day, value: -i, to: today) {
                await upsertDaily(for: day, modelContext: modelContext)
            }
        }
    }
}
