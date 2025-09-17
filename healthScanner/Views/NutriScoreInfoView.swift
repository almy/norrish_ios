import SwiftUI

struct NutriScoreInfoView: View {
    let productBreakdown: NutriScoreBreakdown?
    let plateScore: Double?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let breakdown = productBreakdown {
                        productSection(breakdown)
                    }
                    if let plateScore = plateScore {
                        plateSection(score: plateScore)
                    }
                    howItWorks
                    categoriesSection
                    references
                }
                .padding(20)
            }
            .navigationTitle("Nutri‑Score")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What is Nutri‑Score?")
                .font(.title3).fontWeight(.semibold)
            Text("Nutri‑Score is a front‑of‑pack nutrition label that classifies foods and beverages from A (best) to E (lowest) based on a balance of nutrients and ingredients per 100g/ml.")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private func productSection(_ b: NutriScoreBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Product")
                .font(.headline)
            Text("Category: \(b.category)  •  Final points: \(b.finalScore) → \(b.letter.rawValue)")
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 6) {
                Text("Negatives (higher is worse)").font(.subheadline).fontWeight(.semibold)
                ForEach(0..<b.negatives.count, id: \.self) { idx in
                    let item = b.negatives[idx]
                    HStack {
                        Text("• \(item.name)")
                        Spacer()
                        Text("\(item.points)")
                    }
                    .font(.callout)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            VStack(alignment: .leading, spacing: 6) {
                Text("Positives (higher is better)").font(.subheadline).fontWeight(.semibold)
                ForEach(0..<b.positives.count, id: \.self) { idx in
                    let item = b.positives[idx]
                    HStack {
                        Text("• \(item.name)")
                        Spacer()
                        Text("\(item.points)")
                    }
                    .font(.callout)
                }
            }
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private func plateSection(score: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Plate")
                .font(.headline)
            Text("We map the plate's 0–10 analysis score to a Nutri‑Score letter:")
                .font(.subheadline)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("• A: ≥ 8.0")
                Text("• B: 6.5 – 7.9")
                Text("• C: 5.0 – 6.4")
                Text("• D: 3.5 – 4.9")
                Text("• E: < 3.5")
            }
            .font(.callout)
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            Text("This plate's score: \(String(format: "%.1f", score)) → \(nutriScoreForPlate(score0to10: score).rawValue)")
                .font(.subheadline)
        }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How the score is computed")
                .font(.title3).fontWeight(.semibold)
            Text("Nutri‑Score sums negative points (energy, sugars, saturated fat, sodium) and subtracts positive points (fruits/vegetables/nuts %, fiber, protein). For cheese, protein points always count; beverages use beverage‑specific thresholds and mapping; plain water is always A.")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category specifics")
                .font(.headline)
            Text("• Beverages: lower thresholds and a specific A–E mapping.\n• Cheese: protein points are always counted.\n• Oils (olive, rapeseed, walnut): best achievable grade is typically C.\n• Other categories may have special rules in newer guidance.")
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }

    private var references: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("References")
                .font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                Link("Official Nutri‑Score (France)", destination: URL(string: "https://www.santepubliquefrance.fr/en/nutri-score")!)
                Link("Open Food Facts Nutri‑Score", destination: URL(string: "https://world.openfoodfacts.org/nutriscore")!)
            }
            .font(.callout)
        }
    }
}
