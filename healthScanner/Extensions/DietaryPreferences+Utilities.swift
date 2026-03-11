//
//  DietaryPreferences+Utilities.swift
//  healthScanner
//
//  Created by Claude on 16/09/25.
//

import Foundation

struct IngredientPreferenceFlag: Hashable {
    enum Kind: Hashable {
        case allergy
        case dietaryRestriction
        case customAllergy
        case customRestriction
    }

    let kind: Kind
    let label: String
    let matchedKeyword: String

    var isAllergy: Bool {
        switch kind {
        case .allergy, .customAllergy:
            return true
        case .dietaryRestriction, .customRestriction:
            return false
        }
    }
}

private struct IngredientPreferenceRule {
    let kind: IngredientPreferenceFlag.Kind
    let label: String
    let keywords: [String]
}

extension DietaryPreferencesManager {
    func ingredientFlags(for ingredient: String) -> [IngredientPreferenceFlag] {
        let normalizedIngredient = ingredient.normalizedIngredientSearchText
        guard !normalizedIngredient.isEmpty else { return [] }

        var flags: [IngredientPreferenceFlag] = []
        var seen = Set<String>()

        for rule in ingredientPreferenceRules {
            guard let matchedKeyword = rule.keywords.first(where: { normalizedIngredient.containsIngredientKeyword($0) }) else {
                continue
            }

            let dedupeKey = "\(rule.kind)|\(rule.label.lowercased())"
            guard seen.insert(dedupeKey).inserted else { continue }

            flags.append(
                IngredientPreferenceFlag(
                    kind: rule.kind,
                    label: rule.label,
                    matchedKeyword: matchedKeyword
                )
            )
        }

        return flags
    }

    fileprivate var ingredientPreferenceRules: [IngredientPreferenceRule] {
        let allergyRules = selectedAllergies.map {
            IngredientPreferenceRule(kind: .allergy, label: $0.displayName, keywords: $0.ingredientKeywords)
        }
        let dietaryRules = selectedDietaryRestrictions.map {
            IngredientPreferenceRule(kind: .dietaryRestriction, label: $0.displayName, keywords: $0.ingredientKeywords)
        }
        let customAllergyRules = customAllergies
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map {
                IngredientPreferenceRule(kind: .customAllergy, label: $0, keywords: [$0])
            }
        let customRestrictionRules = customRestrictions
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map {
                IngredientPreferenceRule(kind: .customRestriction, label: $0, keywords: [$0])
            }

        return allergyRules + dietaryRules + customAllergyRules + customRestrictionRules
    }
}

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
        return allergies.contains { allergy in
            allergy.ingredientKeywords.contains { searchText.containsIngredientKeyword($0) }
        }
    }

    /// Checks if product contains custom allergies
    func containsCustomAllergies(_ customAllergies: [String]) -> Bool {
        let searchText = getSearchableText()
        return customAllergies.contains { allergy in
            searchText.containsIngredientKeyword(allergy)
        }
    }

    /// Gets searchable text from product (ingredients, name, brand, categories)
    private func getSearchableText() -> String {
        var searchableText = ""

        if let ingredients = self.ingredients {
            searchableText += ingredients + " "
        }

        searchableText += self.name + " "
        searchableText += self.brand + " "

        if let categories = self.categoriesTags {
            searchableText += categories.joined(separator: " ")
        }

        return searchableText.normalizedIngredientSearchText
    }

    /// Gets allergy warnings for this product
    var allergyWarnings: [String] {
        let manager = DietaryPreferencesManager.shared
        return manager.ingredientFlags(for: getSearchableText())
            .filter(\.isAllergy)
            .map(\.label)
    }

    /// Checks if product meets dietary restrictions
    var meetsDietaryRestrictions: Bool {
        let manager = DietaryPreferencesManager.shared
        return meetsDietaryRestrictions(manager.selectedDietaryRestrictions)
    }

    /// Checks if product meets specific dietary restrictions
    func meetsDietaryRestrictions(_ restrictions: Set<DietaryRestriction>) -> Bool {
        let searchText = getSearchableText()
        return restrictions.allSatisfy { restriction in
            !restriction.ingredientKeywords.contains { searchText.containsIngredientKeyword($0) }
        }
    }
}

private extension Allergy {
    var ingredientKeywords: [String] {
        switch self {
        case .peanuts:
            return ["peanut", "groundnut", "arachis"]
        case .shellfish:
            return ["shellfish", "shrimp", "prawn", "crab", "lobster", "crayfish", "krill", "clam", "mussel", "oyster", "scallop"]
        case .soy:
            return ["soy", "soya", "soybean", "edamame", "miso", "tempeh", "tofu", "tamari"]
        case .dairy:
            return ["milk", "milk powder", "whey", "casein", "butter", "cheese", "cream", "yogurt", "yoghurt", "lactose", "ghee"]
        case .gluten:
            return ["gluten", "wheat", "barley", "rye", "spelt", "malt", "farro", "semolina"]
        case .eggs:
            return ["egg", "albumin", "mayonnaise", "meringue"]
        case .treeNuts:
            return ["almond", "cashew", "hazelnut", "macadamia", "pecan", "pistachio", "walnut", "brazil nut", "pine nut"]
        case .fish:
            return ["fish", "salmon", "tuna", "anchovy", "cod", "haddock", "sardine"]
        case .sesame:
            return ["sesame", "tahini", "benne"]
        }
    }
}

private extension DietaryRestriction {
    var ingredientKeywords: [String] {
        switch self {
        case .vegan:
            return ["meat", "chicken", "beef", "pork", "lamb", "fish", "egg", "milk", "cheese", "butter", "cream", "honey", "gelatin", "gelatine", "whey", "casein"]
        case .vegetarian:
            return ["meat", "chicken", "beef", "pork", "lamb", "bacon", "ham", "sausage", "gelatin", "gelatine", "anchovy"]
        case .pescatarian:
            return ["meat", "chicken", "beef", "pork", "lamb", "bacon", "ham", "sausage", "gelatin", "gelatine"]
        case .paleo:
            return ["wheat", "barley", "rye", "oat", "bean", "soy", "lentil", "pea protein", "corn", "sugar", "dextrose"]
        case .keto:
            return ["sugar", "glucose", "dextrose", "fructose", "maltodextrin", "starch", "corn syrup", "rice flour"]
        case .lowSodium:
            return ["salt", "sodium", "msg", "monosodium glutamate", "soy sauce", "brine"]
        case .lowCarb:
            return ["sugar", "glucose", "dextrose", "fructose", "maltodextrin", "starch", "corn syrup", "rice flour", "wheat flour"]
        case .dairyfree:
            return Allergy.dairy.ingredientKeywords
        case .glutenFree:
            return Allergy.gluten.ingredientKeywords
        case .halal:
            return ["pork", "bacon", "ham", "lard", "gelatin", "gelatine", "wine", "beer", "rum", "brandy"]
        case .kosher:
            return ["pork", "bacon", "ham", "shellfish", "shrimp", "crab", "lobster"]
        }
    }
}

private extension String {
    var normalizedIngredientSearchText: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func containsIngredientKeyword(_ keyword: String) -> Bool {
        let normalizedKeyword = keyword.normalizedIngredientSearchText
        guard !normalizedKeyword.isEmpty else { return false }
        return normalizedIngredientSearchText.contains(normalizedKeyword)
    }
}
