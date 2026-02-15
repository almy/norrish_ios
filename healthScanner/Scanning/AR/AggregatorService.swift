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

        do {
            try modelContext.save()
        } catch {
            AppLog.error(AppLog.storage, "AggregatorService.save failed: \(error.localizedDescription)")
        }
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

@MainActor
final class PlateHistoryMigrationService {
    static let shared = PlateHistoryMigrationService()

    private let migrationFlagKey = "plate_history_relational_migration_v1_complete"

    private init() {}

    func migrateIfNeeded(modelContext: ModelContext) async {
        if UserDefaults.standard.bool(forKey: migrationFlagKey) {
            return
        }

        do {
            let histories = try modelContext.fetch(FetchDescriptor<PlateAnalysisHistory>())
            var changed = false

            for history in histories {
                if history.ingredientEntities.isEmpty {
                    let decodedIngredients = (try? JSONDecoder().decode([PlateIngredient].self, from: history.ingredientsData)) ?? []
                    if !decodedIngredients.isEmpty {
                        history.ingredientEntities = decodedIngredients.enumerated().map { idx, item in
                            PlateIngredientEntity(name: item.name, amount: item.amount, order: idx)
                        }
                        changed = true
                    }
                }

                if history.insightEntities.isEmpty {
                    let decodedInsights = (try? JSONDecoder().decode([PlateInsight].self, from: history.insightsData)) ?? []
                    if !decodedInsights.isEmpty {
                        history.insightEntities = decodedInsights.enumerated().map { idx, item in
                            PlateInsightEntity(typeRawValue: item.type.rawValue, title: item.title, detail: item.description, order: idx)
                        }
                        changed = true
                    }
                }
            }

            if changed {
                try modelContext.save()
                AppLog.debug(AppLog.storage, "Plate history relational migration completed with updates.")
            } else {
                AppLog.debug(AppLog.storage, "Plate history relational migration skipped (no updates needed).")
            }

            UserDefaults.standard.set(true, forKey: migrationFlagKey)
        } catch {
            AppLog.error(AppLog.storage, "Plate history relational migration failed: \(error.localizedDescription)")
        }
    }
}
