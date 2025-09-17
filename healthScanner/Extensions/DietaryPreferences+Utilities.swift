//
//  DietaryPreferences+Utilities.swift
//  healthScanner
//
//  Created by Claude on 16/09/25.
//

import Foundation

// MARK: - Product Extension for Allergy Checking
extension Product {
    /// Checks if this product contains any of the user's allergies
    var containsUserAllergies: Bool {
        let manager = DietaryPreferencesManager.shared
        return containsAllergies(manager.selectedAllergies) || containsCustomAllergies(manager.customAllergies)
    }

    /// Checks if product contains specific allergies
    func containsAllergies(_ allergies: Set<Allergy>) -> Bool {
        let searchText = getSearchableText()

        for allergy in allergies {
            if searchText.contains(allergyKeywords(for: allergy)) {
                return true
            }
        }
        return false
    }

    /// Checks if product contains custom allergies
    func containsCustomAllergies(_ customAllergies: [String]) -> Bool {
        let searchText = getSearchableText()

        for allergy in customAllergies {
            if searchText.contains(allergy.lowercased()) {
                return true
            }
        }
        return false
    }

    /// Gets searchable text from product (ingredients, name, brand, categories)
    private func getSearchableText() -> String {
        var searchableText = ""

        // Add ingredients if available
        if let ingredients = self.ingredients {
            searchableText += ingredients.lowercased() + " "
        }

        // Add product name and brand as fallback
        searchableText += self.name.lowercased() + " "
        searchableText += self.brand.lowercased() + " "

        // Add category tags if available
        if let categories = self.categoriesTags {
            searchableText += categories.joined(separator: " ").lowercased()
        }

        return searchableText
    }

    /// Gets allergy warnings for this product
    var allergyWarnings: [String] {
        let manager = DietaryPreferencesManager.shared
        var warnings: [String] = []

        // Check standard allergies
        for allergy in manager.selectedAllergies {
            if containsAllergies([allergy]) {
                warnings.append(allergy.displayName)
            }
        }

        // Check custom allergies
        for customAllergy in manager.customAllergies {
            if containsCustomAllergies([customAllergy]) {
                warnings.append(customAllergy)
            }
        }

        return warnings
    }

    /// Checks if product meets dietary restrictions
    var meetsDietaryRestrictions: Bool {
        let manager = DietaryPreferencesManager.shared
        return meetsDietaryRestrictions(manager.selectedDietaryRestrictions)
    }

    /// Checks if product meets specific dietary restrictions
    func meetsDietaryRestrictions(_ restrictions: Set<DietaryRestriction>) -> Bool {
        let searchText = getSearchableText()

        for restriction in restrictions {
            if !meetsRestriction(restriction, searchText: searchText) {
                return false
            }
        }
        return true
    }

    private func meetsRestriction(_ restriction: DietaryRestriction, searchText: String) -> Bool {
        switch restriction {
        case .vegan:
            return !searchText.contains(animalProducts)
        case .vegetarian:
            return !searchText.contains(meatProducts)
        case .pescatarian:
            return !searchText.contains(meatProducts) // Fish is allowed
        case .dairyfree:
            return !searchText.contains(dairyProducts)
        case .glutenFree:
            return !searchText.contains(glutenProducts)
        case .halal:
            return !searchText.contains(nonHalalProducts)
        case .kosher:
            return !searchText.contains(nonKosherProducts)
        default:
            return true // For restrictions we can't verify from searchable text
        }
    }

    // MARK: - Allergy Keywords
    private func allergyKeywords(for allergy: Allergy) -> String {
        switch allergy {
        case .peanuts:
            return "peanut"
        case .shellfish:
            return "shellfish"
        case .soy:
            return "soy"
        case .dairy:
            return "milk"
        case .gluten:
            return "wheat"
        case .eggs:
            return "egg"
        case .treeNuts:
            return "nuts"
        case .fish:
            return "fish"
        case .sesame:
            return "sesame"
        }
    }

    // MARK: - Dietary Restriction Keywords
    private var animalProducts: String {
        "meat,chicken,beef,pork,lamb,fish,egg,milk,cheese,butter,honey"
    }

    private var meatProducts: String {
        "meat,chicken,beef,pork,lamb,bacon,ham,sausage"
    }

    private var dairyProducts: String {
        "milk,cheese,butter,cream,yogurt,lactose"
    }

    private var glutenProducts: String {
        "wheat,barley,rye,gluten"
    }

    private var nonHalalProducts: String {
        "pork,alcohol,wine,beer"
    }

    private var nonKosherProducts: String {
        "pork,shellfish,mixing of meat and dairy"
    }
}

// MARK: - String Extension for Ingredient Checking
extension String {
    func contains(_ keywords: String) -> Bool {
        let keywordList = keywords.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return keywordList.contains { self.contains($0) }
    }
}