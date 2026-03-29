/*
 ADR-0001 Summary: Multi-horizon insights with short-window on-device regression and model snapshot persistence.
 
 Context:
 - Personalized recommendations are produced by fitting a tiny linear regression on device from persisted history (Products and PlateAnalysisHistory), aggregated per day.
 - Raw training data is NOT persisted; it is derived on demand from SwiftData history.
 
 Decision:
 - Keep the training window short (driven by the engine) to capture near-term patterns for next-day signals.
 - Persist a lightweight snapshot (featureNames + coefficients) so recommendations can warm-start and survive history wipes.
 - Keep this module stateless aside from snapshot helpers.
 
 Consequences:
 - Fast training and privacy-preserving behavior.
 - Snapshot enables recommendations even when recent history is insufficient or unavailable.
 
 See also: docs/adr/0001-insights-strategy-and-ml-snapshot.md
*/
import Foundation

struct MLFeatureSpace {
    let featureNames: [String] // aligns with vector order
}

/// In-memory training dataset for the on-device linear regressor.
/// - X: rows = samples (days), cols = ordered features (includes an intercept at index 0 as produced by `buildTrainingData`).
/// - y: target = next-day average plate score (0..10).
/// - space: carries the feature ordering via `featureNames`.
struct MLTrainingData {
    let X: [[Double]] // rows = samples (days), cols = features
    let y: [Double]   // target: next-day avg plate score (0..10)
    let space: MLFeatureSpace
}

final class LinearRegressor {
    private(set) var coefficients: [Double] = [] // includes intercept at index 0

    // Ridge regression: w = (X^T X + λI)^-1 X^T y
    func fit(data: MLTrainingData, lambda: Double = 0.5) {
        let rows = data.X.count
        guard rows > 0 else { coefficients = []; return }
        let cols = data.X.first?.count ?? 0
        guard cols > 0 else { coefficients = []; return }

        // Build A = X^T X + λI and b = X^T y
        var A = Array(repeating: 0.0, count: cols * cols)
        var b = Array(repeating: 0.0, count: cols)
        for r in 0..<rows {
            let xr = data.X[r]
            for i in 0..<cols {
                b[i] += xr[i] * data.y[r]
                for j in 0..<cols {
                    A[i*cols + j] += xr[i] * xr[j]
                }
            }
        }
        // λI (no regularization on intercept)
        for i in 1..<cols { A[i*cols + i] += lambda }

        // Solve A w = b using Accelerate
        coefficients = solveLinearSystem(A: A, b: b, dimension: cols) ?? Array(repeating: 0.0, count: cols)
    }

    func predict(x: [Double]) -> Double {
        guard !coefficients.isEmpty else { return 0 }
        return zip(coefficients, x).map(*).reduce(0, +)
    }

    private func solveLinearSystem(A: [Double], b: [Double], dimension n: Int) -> [Double]? {
        // Simple Gaussian elimination with partial pivoting
        // Avoids deprecated Linear Algebra APIs
        var matrix = A
        var rhs = b

        // Forward elimination with partial pivoting
        for k in 0..<n {
            // Find pivot
            var maxRow = k
            for i in (k+1)..<n {
                if abs(matrix[i*n + k]) > abs(matrix[maxRow*n + k]) {
                    maxRow = i
                }
            }

            // Check for singular matrix
            if abs(matrix[maxRow*n + k]) < 1e-10 {
                return nil
            }

            // Swap rows if needed
            if maxRow != k {
                for j in 0..<n {
                    let temp = matrix[k*n + j]
                    matrix[k*n + j] = matrix[maxRow*n + j]
                    matrix[maxRow*n + j] = temp
                }
                let temp = rhs[k]
                rhs[k] = rhs[maxRow]
                rhs[maxRow] = temp
            }

            // Eliminate column
            for i in (k+1)..<n {
                let factor = matrix[i*n + k] / matrix[k*n + k]
                for j in k..<n {
                    matrix[i*n + j] -= factor * matrix[k*n + j]
                }
                rhs[i] -= factor * rhs[k]
            }
        }

        // Back substitution
        var solution = Array(repeating: 0.0, count: n)
        for i in stride(from: n-1, through: 0, by: -1) {
            solution[i] = rhs[i]
            for j in (i+1)..<n {
                solution[i] -= matrix[i*n + j] * solution[j]
            }
            solution[i] /= matrix[i*n + i]
        }

        return solution
    }
}

// MARK: - Feature builder from app data

struct DailyAggregate {
    let day: String // yyyy-MM-dd
    var sugarG: Double = 0
    var sodiumG: Double = 0
    var proteinG: Double = 0
    var fiberG: Double = 0
    var caloriesK: Double = 0
    var categories: [String: Int] = [:]
    var plateScoreAvg: Double = 0
}

/// Builds short-horizon daily training data from persisted history.
/// Notes:
/// - Aggregates Products and PlateAnalysisHistory per calendar day.
/// - Includes an intercept term, numeric nutrition features, and one-hot counts for top categories.
/// - Requires at least 7 distinct days to produce meaningful next-day targets; returns `nil` otherwise.
/// - Does not persist raw data; callers may persist snapshots of learned coefficients for warm-starts.
struct LocalRecommendationML {
    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    // Builds training data from recent history. Requires at least 7 samples.
    static func buildTrainingData(plates: [PlateAnalysisHistory], products: [Product], maxCategories: Int = 8) -> MLTrainingData? {
        let df = dayFormatter

        // Aggregate per day
        var byDay: [String: DailyAggregate] = [:]
        for p in products {
            let d = df.string(from: p.scannedDate)
            var g = byDay[d] ?? DailyAggregate(day: d)
            g.sugarG += p.nutritionData.sugar
            g.sodiumG += p.nutritionData.sodium
            g.proteinG += p.nutritionData.protein
            g.fiberG += p.nutritionData.fiber
            g.caloriesK += p.nutritionData.calories
            p.categoriesTags?.forEach { g.categories[$0, default: 0] += 1 }
            byDay[d] = g
        }
        var plateByDay: [String: [Double]] = [:]
        for pl in plates {
            let d = df.string(from: pl.analyzedDate)
            plateByDay[d, default: []].append(pl.nutritionScore)
        }
        for (day, scores) in plateByDay { byDay[day, default: DailyAggregate(day: day)].plateScoreAvg = scores.reduce(0,+) / Double(max(scores.count,1)) }

        // Determine top categories overall
        var catCounts: [String:Int] = [:]
        for (_, agg) in byDay { for (c, k) in agg.categories { catCounts[c, default: 0] += k } }
        let topCats = Array(catCounts.sorted { $0.value > $1.value }.prefix(maxCategories).map { $0.key })

        // Sort days chronologically
        let dayKeys = byDay.keys.compactMap { df.date(from: $0) }.sorted().map { df.string(from: $0) }
        guard dayKeys.count >= 7 else { return nil }

        // Build samples where y is next-day plate avg
        var X: [[Double]] = []
        var y: [Double] = []
        for i in 0..<(dayKeys.count - 1) {
            let d = dayKeys[i]
            let next = dayKeys[i+1]
            guard let g = byDay[d], let nextAgg = byDay[next] else { continue }
            var row: [Double] = []
            // intercept
            row.append(1.0)
            // numeric features
            row.append(contentsOf: [g.sugarG, g.sodiumG, g.proteinG, g.fiberG, g.caloriesK, g.plateScoreAvg])
            // category one-hot for top cats
            for c in topCats { row.append(Double(g.categories[c] ?? 0)) }
            X.append(row)
            y.append(nextAgg.plateScoreAvg)
        }
        let featureNames = ["intercept", "sugar_g", "sodium_g", "protein_g", "fiber_g", "calories_k", "plate_score_avg"] + topCats.map { "cat_\($0)" }
        return MLTrainingData(X: X, y: y, space: MLFeatureSpace(featureNames: featureNames))
    }
}

// MARK: - Snapshot Persistence

/// Minimal persisted snapshot of a trained linear model.
/// Stores the feature ordering and coefficients to enable warm-starts
/// when recent history is insufficient or was intentionally cleared.
struct ModelSnapshot: Codable {
    let date: Date
    let featureNames: [String]
    let coefficients: [Double]
}

extension LocalRecommendationML {
    private static let snapshotKey = "ml_model_snapshot_v1"

    /// Persist the learned coefficients and feature ordering.
    /// Uses UserDefaults for simplicity and durability across launches.
    static func saveSnapshot(names: [String], coeffs: [Double]) {
        guard !names.isEmpty, !coeffs.isEmpty, names.count == coeffs.count || (coeffs.count > 0) else { return }
        let snap = ModelSnapshot(date: Date(), featureNames: names, coefficients: coeffs)
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: snapshotKey)
        }
    }

    /// Load the most recent snapshot if present; returns `nil` if none is stored or decoding fails.
    static func loadSnapshot() -> ModelSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(ModelSnapshot.self, from: data)
    }
}

