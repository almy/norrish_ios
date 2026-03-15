import Foundation
import UIKit

#if DEBUG && targetEnvironment(simulator)

/// Loads plate fixture images from external files on the host filesystem.
/// Only available in simulator debug builds. Production builds never compile this code.
enum ExternalPlateFixtureLoader {

    // MARK: - Manifest Types

    private struct FixtureManifest: Decodable {
        let plates_directory: String?
        let personas: [String: PersonaFixtures]
    }

    private struct PersonaFixtures: Decodable {
        let plates: [String]?
        let notes: String?
    }

    // MARK: - Public API

    /// Resolved fixture root from FIXTURE_PATH environment variable.
    static var fixturePath: String? {
        ProcessInfo.processInfo.environment["FIXTURE_PATH"]
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

    /// Whether external plate fixtures are available and usable.
    /// Returns true only when FIXTURE_PATH points to a directory
    /// containing at least one loadable plate filename.
    static var isAvailable: Bool {
        guard let path = fixturePath,
              FileManager.default.fileExists(atPath: path) else { return false }
        if let persona = personaName {
            return !loadPersonaPlates(persona: persona).isEmpty
        }
        return !loadAllPlateFilenames().isEmpty
    }

    /// Loads all plate filenames from the manifest's persona entries.
    static func loadAllPlateFilenames() -> [String] {
        guard let manifest = loadManifest() else { return [] }
        var seen = Set<String>()
        var result: [String] = []
        for (_, persona) in manifest.personas.sorted(by: { $0.key < $1.key }) {
            for plate in persona.plates ?? [] {
                if seen.insert(plate).inserted {
                    result.append(plate)
                }
            }
        }
        return result
    }

    /// Loads persona-specific plate filenames from the manifest.
    static func loadPersonaPlates(persona: String) -> [String] {
        guard let manifest = loadManifest() else { return [] }
        return manifest.personas[persona.lowercased()]?.plates ?? []
    }

    /// Returns the plate image to auto-inject based on PERSONA_NAME and FIXTURE_INDEX.
    /// Returns nil if either env var is missing or the index is out of range.
    static func autoInjectPlateImage() -> UIImage? {
        guard let persona = personaName else { return nil }
        let plates = loadPersonaPlates(persona: persona)
        guard !plates.isEmpty else { return nil }
        let index = fixtureIndex ?? 0
        guard index >= 0, index < plates.count else { return nil }
        return loadImage(filename: plates[index])
    }

    /// Returns display items for the debug plate picker UI.
    static func loadDisplayItems() -> [PlateDisplayItem] {
        if let persona = personaName {
            let plates = loadPersonaPlates(persona: persona)
            return plates.enumerated().map { index, filename in
                PlateDisplayItem(
                    filename: filename,
                    label: "\(persona.capitalized) plate \(index + 1)",
                    subtitle: filename
                )
            }
        }

        let allPlates = loadAllPlateFilenames()
        return allPlates.map { filename in
            PlateDisplayItem(
                filename: filename,
                label: humanReadableLabel(filename),
                subtitle: personaForPlate(filename) ?? "unassigned"
            )
        }
    }

    /// Loads a UIImage from the plates directory.
    static func loadImage(filename: String) -> UIImage? {
        guard let root = fixturePath else { return nil }
        let url = URL(fileURLWithPath: root)
            .appendingPathComponent("plates")
            .appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Private

    private static func loadManifest() -> FixtureManifest? {
        guard let root = fixturePath else { return nil }
        let url = URL(fileURLWithPath: root)
            .appendingPathComponent("fixtures.manifest.json")
        guard let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(FixtureManifest.self, from: data) else {
            return nil
        }
        return manifest
    }

    /// Reverse-lookup: which persona owns this plate?
    private static func personaForPlate(_ filename: String) -> String? {
        guard let manifest = loadManifest() else { return nil }
        for (name, fixtures) in manifest.personas {
            if (fixtures.plates ?? []).contains(filename) { return name }
        }
        return nil
    }

    /// Converts "plate-food-01-roast-chicken.jpg" → "Roast Chicken"
    private static func humanReadableLabel(_ filename: String) -> String {
        var name = filename
        // Remove extension
        if let dotIndex = name.lastIndex(of: ".") {
            name = String(name[name.startIndex..<dotIndex])
        }
        // Remove "plate-food-NN-" or "plate-nonfood-NN-" prefix
        if let match = name.range(of: #"^plate-(?:non)?food-\d+-"#, options: .regularExpression) {
            name = String(name[match.upperBound...])
        }
        // Hyphen to space, capitalize words
        return name.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
    }
}

/// Simple display model for the debug plate picker.
struct PlateDisplayItem: Identifiable, Hashable {
    let filename: String
    let label: String
    let subtitle: String

    var id: String { filename }
}

#endif
