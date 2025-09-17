//
//  DietaryPreferences.swift
//  healthScanner
//
//  Created by Claude on 16/09/25.
//

import Foundation

// MARK: - Allergy Model
enum Allergy: String, CaseIterable, Identifiable {
    case peanuts = "peanuts"
    case shellfish = "shellfish"
    case soy = "soy"
    case dairy = "dairy"
    case gluten = "gluten"
    case eggs = "eggs"
    case treeNuts = "tree_nuts"
    case fish = "fish"
    case sesame = "sesame"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .peanuts:
            return "allergies.peanuts".localized()
        case .shellfish:
            return "allergies.shellfish".localized()
        case .soy:
            return "allergies.soy".localized()
        case .dairy:
            return "allergies.dairy".localized()
        case .gluten:
            return "allergies.gluten".localized()
        case .eggs:
            return "allergies.eggs".localized()
        case .treeNuts:
            return "allergies.tree_nuts".localized()
        case .fish:
            return "allergies.fish".localized()
        case .sesame:
            return "allergies.sesame".localized()
        }
    }
}

// MARK: - Dietary Restriction Model
enum DietaryRestriction: String, CaseIterable, Identifiable {
    case vegan = "vegan"
    case vegetarian = "vegetarian"
    case pescatarian = "pescatarian"
    case paleo = "paleo"
    case keto = "keto"
    case lowSodium = "low_sodium"
    case lowCarb = "low_carb"
    case dairyfree = "dairy_free"
    case glutenFree = "gluten_free"
    case halal = "halal"
    case kosher = "kosher"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vegan:
            return "dietary.vegan".localized()
        case .vegetarian:
            return "dietary.vegetarian".localized()
        case .pescatarian:
            return "dietary.pescatarian".localized()
        case .paleo:
            return "dietary.paleo".localized()
        case .keto:
            return "dietary.keto".localized()
        case .lowSodium:
            return "dietary.low_sodium".localized()
        case .lowCarb:
            return "dietary.low_carb".localized()
        case .dairyfree:
            return "dietary.dairy_free".localized()
        case .glutenFree:
            return "dietary.gluten_free".localized()
        case .halal:
            return "dietary.halal".localized()
        case .kosher:
            return "dietary.kosher".localized()
        }
    }
}

// MARK: - User Preferences Manager
class DietaryPreferencesManager: ObservableObject {
    static let shared = DietaryPreferencesManager()

    @Published var selectedAllergies: Set<Allergy> = []
    @Published var selectedDietaryRestrictions: Set<DietaryRestriction> = []
    @Published var customAllergies: [String] = []
    @Published var customRestrictions: [String] = []

    private init() {
        loadPreferences()
    }

    // MARK: - Persistence
    private func loadPreferences() {
        // Load allergies
        if let allergiesData = UserDefaults.standard.array(forKey: "selectedAllergies") as? [String] {
            selectedAllergies = Set(allergiesData.compactMap { Allergy(rawValue: $0) })
        }

        // Load dietary restrictions
        if let restrictionsData = UserDefaults.standard.array(forKey: "selectedDietaryRestrictions") as? [String] {
            selectedDietaryRestrictions = Set(restrictionsData.compactMap { DietaryRestriction(rawValue: $0) })
        }

        // Load custom allergies
        customAllergies = UserDefaults.standard.stringArray(forKey: "customAllergies") ?? []

        // Load custom restrictions
        customRestrictions = UserDefaults.standard.stringArray(forKey: "customRestrictions") ?? []
    }

    func savePreferences() {
        // Save allergies
        UserDefaults.standard.set(selectedAllergies.map { $0.rawValue }, forKey: "selectedAllergies")

        // Save dietary restrictions
        UserDefaults.standard.set(selectedDietaryRestrictions.map { $0.rawValue }, forKey: "selectedDietaryRestrictions")

        // Save custom allergies
        UserDefaults.standard.set(customAllergies, forKey: "customAllergies")

        // Save custom restrictions
        UserDefaults.standard.set(customRestrictions, forKey: "customRestrictions")
    }

    // MARK: - Allergy Management
    func toggleAllergy(_ allergy: Allergy) {
        if selectedAllergies.contains(allergy) {
            selectedAllergies.remove(allergy)
        } else {
            selectedAllergies.insert(allergy)
        }
        savePreferences()
    }

    func addCustomAllergy(_ allergy: String) {
        let trimmed = allergy.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !customAllergies.contains(trimmed) {
            customAllergies.append(trimmed)
            savePreferences()
        }
    }

    func removeCustomAllergy(_ allergy: String) {
        customAllergies.removeAll { $0 == allergy }
        savePreferences()
    }

    // MARK: - Dietary Restriction Management
    func toggleDietaryRestriction(_ restriction: DietaryRestriction) {
        if selectedDietaryRestrictions.contains(restriction) {
            selectedDietaryRestrictions.remove(restriction)
        } else {
            selectedDietaryRestrictions.insert(restriction)
        }
        savePreferences()
    }

    func addCustomRestriction(_ restriction: String) {
        let trimmed = restriction.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !customRestrictions.contains(trimmed) {
            customRestrictions.append(trimmed)
            savePreferences()
        }
    }

    func removeCustomRestriction(_ restriction: String) {
        customRestrictions.removeAll { $0 == restriction }
        savePreferences()
    }

    // MARK: - Utility Methods
    var hasAllergies: Bool {
        !selectedAllergies.isEmpty || !customAllergies.isEmpty
    }

    var hasDietaryRestrictions: Bool {
        !selectedDietaryRestrictions.isEmpty || !customRestrictions.isEmpty
    }

    var allergiesDisplayText: String {
        if selectedAllergies.isEmpty && customAllergies.isEmpty {
            return "profile.none".localized()
        }

        let standardAllergies = selectedAllergies.map { $0.displayName }
        let allAllergies = standardAllergies + customAllergies

        if allAllergies.count <= 2 {
            return allAllergies.joined(separator: ", ")
        } else {
            return "\(allAllergies.prefix(2).joined(separator: ", ")) +\(allAllergies.count - 2)"
        }
    }

    var dietaryRestrictionsDisplayText: String {
        if selectedDietaryRestrictions.isEmpty && customRestrictions.isEmpty {
            return "profile.none".localized()
        }

        let standardRestrictions = selectedDietaryRestrictions.map { $0.displayName }
        let allRestrictions = standardRestrictions + customRestrictions

        if allRestrictions.count <= 2 {
            return allRestrictions.joined(separator: ", ")
        } else {
            return "\(allRestrictions.prefix(2).joined(separator: ", ")) +\(allRestrictions.count - 2)"
        }
    }

    // MARK: - Profile Completion
    var profileCompletionPercentage: Double {
        let maxItems = 4.0 // allergies, dietary restrictions, and potentially 2 more profile items
        var completedItems = 0.0

        if hasAllergies { completedItems += 1 }
        if hasDietaryRestrictions { completedItems += 1 }

        // Add other profile completion factors here
        completedItems += 2 // Base profile info (name, etc.)

        return min(completedItems / maxItems * 100, 100)
    }
}