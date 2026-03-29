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
    /// Legacy hardcoded samples — used as fallback when FIXTURE_PATH is not set.
    static let fallbackSamples: [DebugBarcodeFixture] = [
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
        fallbackSamples.first { $0.barcode == barcode }
    }

    /// Returns the legacy fallback samples (used when FIXTURE_PATH is not configured).
    static var samples: [DebugBarcodeFixture] {
        fallbackSamples
    }
}

// MARK: - External Fixture Loading

/// Loads barcode fixtures from external JSON files on the host filesystem.
/// Only available in simulator debug builds. Production builds never compile this code.
#if targetEnvironment(simulator)
enum ExternalBarcodeFixtureLoader {

    // MARK: - Manifest Types

    private struct FixtureManifest: Decodable {
        let personas: [String: PersonaFixtures]
    }

    private struct PersonaFixtures: Decodable {
        let barcodes: [String]
        let notes: String?
    }

    // MARK: - Cached Manifest

    private static var _cachedManifest: FixtureManifest?
    private static var _manifestLoaded = false

    // MARK: - Public API

    /// Resolved fixture root from FIXTURE_PATH environment variable.
    static var fixturePath: String? {
        ProcessInfo.processInfo.environment["FIXTURE_PATH"]
    }

    /// Whether external fixtures are available and usable.
    /// If PERSONA_NAME is set but unrecognized, falls through to all available barcodes.
    static var isAvailable: Bool {
        guard let path = fixturePath,
              FileManager.default.fileExists(atPath: path) else { return false }
        return !resolvedBarcodes().isEmpty
    }

    /// Active persona name from PERSONA_NAME environment variable.
    static var personaName: String? {
        ProcessInfo.processInfo.environment["PERSONA_NAME"]
    }

    /// Active fixture index from FIXTURE_INDEX environment variable.
    static var fixtureIndex: Int? {
        guard let raw = ProcessInfo.processInfo.environment["FIXTURE_INDEX"] else { return nil }
        return Int(raw)
    }

    /// Loads all EAN strings from the external BarcodeFixtures.json.
    static func loadAllBarcodes() -> [String] {
        guard let root = fixturePath else { return [] }
        let url = URL(fileURLWithPath: root)
            .appendingPathComponent("barcodes")
            .appendingPathComponent("BarcodeFixtures.json")
        guard let data = try? Data(contentsOf: url),
              let eans = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return eans
    }

    /// Loads persona-specific barcodes from the manifest.
    static func loadPersonaBarcodes(persona: String) -> [String] {
        guard let manifest = loadManifest() else { return [] }
        return manifest.personas[persona.lowercased()]?.barcodes ?? []
    }

    /// Returns the barcode to auto-inject based on PERSONA_NAME and FIXTURE_INDEX.
    /// Falls through to all barcodes if persona is unrecognized.
    /// Returns nil if PERSONA_NAME is missing or the index is out of range.
    static func autoInjectBarcode() -> String? {
        guard personaName != nil else { return nil }
        let barcodes = resolvedBarcodes()
        guard !barcodes.isEmpty else { return nil }
        let index = fixtureIndex ?? 0
        guard index >= 0, index < barcodes.count else { return nil }
        return barcodes[index]
    }

    /// Returns display items for the debug barcode picker UI.
    /// If PERSONA_NAME is set and recognized, shows only that persona's barcodes.
    /// If PERSONA_NAME is set but unrecognized, falls through to all barcodes.
    static func loadDisplayItems() -> [BarcodeDisplayItem] {
        if let persona = personaName {
            let barcodes = loadPersonaBarcodes(persona: persona)
            if !barcodes.isEmpty {
                return barcodes.enumerated().map { index, ean in
                    BarcodeDisplayItem(
                        barcode: ean,
                        label: "\(persona.capitalized) fixture \(index + 1)",
                        subtitle: ean
                    )
                }
            }
        }

        let allBarcodes = loadAllBarcodes()
        return allBarcodes.map { ean in
            BarcodeDisplayItem(
                barcode: ean,
                label: "EAN \(ean)",
                subtitle: barcodeToPersona[ean] ?? "unassigned"
            )
        }
    }

    // MARK: - Private

    /// Returns persona-specific barcodes if recognized, otherwise all barcodes.
    private static func resolvedBarcodes() -> [String] {
        if let persona = personaName {
            let barcodes = loadPersonaBarcodes(persona: persona)
            if !barcodes.isEmpty { return barcodes }
        }
        return loadAllBarcodes()
    }

    private static func loadManifest() -> FixtureManifest? {
        if _manifestLoaded { return _cachedManifest }
        _manifestLoaded = true
        guard let root = fixturePath else { return nil }
        let url = URL(fileURLWithPath: root)
            .appendingPathComponent("fixtures.manifest.json")
        guard let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(FixtureManifest.self, from: data) else {
            return nil
        }
        _cachedManifest = manifest
        return manifest
    }

    /// Pre-built reverse lookup: barcode EAN → persona name.
    private static let barcodeToPersona: [String: String] = {
        guard let manifest = loadManifest() else { return [:] }
        var map: [String: String] = [:]
        for (name, fixtures) in manifest.personas {
            for ean in fixtures.barcodes {
                map[ean] = name
            }
        }
        return map
    }()
}

/// Simple display model for the debug barcode picker.
struct BarcodeDisplayItem: Identifiable, Hashable {
    let barcode: String
    let label: String
    let subtitle: String

    var id: String { barcode }
}
#endif
#endif
