//
//  DietaryPreferencesView.swift
//  healthScanner
//
//  Created by Claude on 16/09/25.
//

import SwiftUI

struct DietaryPreferencesView: View {
    @StateObject private var preferencesManager = DietaryPreferencesManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingCustomAllergySheet = false
    @State private var showingCustomRestrictionSheet = false
    @State private var showingAddActionSheet = false
    @State private var customAllergyText = ""
    @State private var customRestrictionText = ""

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    topBar
                    header
                    preferenceGrid
                    searchButton
                    footer
                }
                .padding(.bottom, 32)
            }
            .background(Color.nordicBone)
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingCustomAllergySheet) {
            CustomAllergySheet(
                text: $customAllergyText,
                onSave: { text in
                    preferencesManager.addCustomAllergy(text)
                    customAllergyText = ""
                }
            )
        }
        .sheet(isPresented: $showingCustomRestrictionSheet) {
            CustomRestrictionSheet(
                text: $customRestrictionText,
                onSave: { text in
                    preferencesManager.addCustomRestriction(text)
                    customRestrictionText = ""
                }
            )
        }
        .confirmationDialog(
            "preferences.add_custom".localized(),
            isPresented: $showingAddActionSheet,
            titleVisibility: .visible
        ) {
            Button("preferences.add_custom_allergy".localized()) {
                showingCustomAllergySheet = true
            }
            Button("preferences.add_custom_restriction".localized()) {
                showingCustomRestrictionSheet = true
            }
            Button("preferences.cancel".localized(), role: .cancel) {}
        }
    }

    private var progressBarWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width - 120
        let percentage = preferencesManager.profileCompletionPercentage / 100
        return screenWidth * CGFloat(percentage)
    }

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(Color.midnightSpruce)
                    .frame(width: 40, height: 40)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.nordicBone.opacity(0.8))
                        .frame(height: 2)
                    Capsule()
                        .fill(Color.momentumAmber)
                        .frame(width: progressBarWidth, height: 2)
                }
                .frame(width: UIScreen.main.bounds.width - 140)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Text("preferences.skip".localized())
                    .font(AppFonts.sans(12, weight: .medium))
                    .kerning(1.5)
                    .foregroundColor(.momentumAmber)
            }
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("preferences.title".localized())
                .font(AppFonts.serif(32, weight: .semibold))
                .foregroundColor(.midnightSpruce)
            Text("preferences.dietary_description".localized())
                .font(AppFonts.sans(14, weight: .regular))
                .foregroundColor(.nordicSlate)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private var preferenceGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            PreferenceSection(
                title: "preferences.category.allergy".localized(),
                items: allergyItems,
                onToggle: toggle
            )

            PreferenceSection(
                title: "preferences.category.restriction".localized(),
                items: restrictionItems,
                onToggle: toggle
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private var searchButton: some View {
        Button(action: { showingAddActionSheet = true }) {
            HStack {
                Text("preferences.search_placeholder".localized())
                    .font(AppFonts.sans(13, weight: .regular))
                    .foregroundColor(.nordicSlate)
                Spacer()
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.nordicSlate.opacity(0.7))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 999)
                    .stroke(Color.cardBorder, lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Button(action: { dismiss() }) {
                HStack(spacing: 8) {
                    Text("preferences.save_preferences".localized())
                        .font(AppFonts.serif(16, weight: .medium))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.midnightSpruce)
                .clipShape(Capsule())
            }

            Text(String(format: NSLocalizedString("preferences.step_label", comment: "Step label"), "\(Int(preferencesManager.profileCompletionPercentage))%"))
                .font(AppFonts.sans(11, weight: .medium))
                .kerning(1.5)
                .foregroundColor(.nordicSlate)
                .textCase(.uppercase)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var allergyItems: [PreferenceItem] {
        var items: [PreferenceItem] = []
        items.append(contentsOf: Allergy.allCases.map { allergy in
            PreferenceItem(
                id: "allergy-\(allergy.rawValue)",
                title: allergy.displayName,
                category: "preferences.category.allergy".localized(),
                icon: iconForAllergy(allergy),
                isSelected: preferencesManager.selectedAllergies.contains(allergy),
                kind: .allergy(allergy)
            )
        })
        items.append(contentsOf: preferencesManager.customAllergies.map { custom in
            PreferenceItem(
                id: "custom-allergy-\(custom)",
                title: custom,
                category: "preferences.category.custom".localized(),
                icon: "exclamationmark.triangle",
                isSelected: true,
                kind: .customAllergy(custom)
            )
        })
        return items
    }

    private var restrictionItems: [PreferenceItem] {
        var items: [PreferenceItem] = []
        items.append(contentsOf: DietaryRestriction.allCases.map { restriction in
            PreferenceItem(
                id: "restriction-\(restriction.rawValue)",
                title: restriction.displayName,
                category: "preferences.category.restriction".localized(),
                icon: iconForRestriction(restriction),
                isSelected: preferencesManager.selectedDietaryRestrictions.contains(restriction),
                kind: .restriction(restriction)
            )
        })
        items.append(contentsOf: preferencesManager.customRestrictions.map { custom in
            PreferenceItem(
                id: "custom-restriction-\(custom)",
                title: custom,
                category: "preferences.category.custom".localized(),
                icon: "leaf",
                isSelected: true,
                kind: .customRestriction(custom)
            )
        })
        return items
    }

    private func toggle(_ item: PreferenceItem) {
        switch item.kind {
        case .allergy(let allergy):
            preferencesManager.toggleAllergy(allergy)
        case .restriction(let restriction):
            preferencesManager.toggleDietaryRestriction(restriction)
        case .customAllergy(let value):
            preferencesManager.removeCustomAllergy(value)
        case .customRestriction(let value):
            preferencesManager.removeCustomRestriction(value)
        }
    }

    private func iconForAllergy(_ allergy: Allergy) -> String {
        switch allergy {
        case .peanuts, .treeNuts: return "leaf"
        case .shellfish, .fish: return "fish"
        case .dairy: return "drop"
        case .gluten: return "leaf"
        case .eggs: return "egg"
        case .soy: return "leaf"
        case .sesame: return "leaf"
        }
    }

    private func iconForRestriction(_ restriction: DietaryRestriction) -> String {
        switch restriction {
        case .vegan, .vegetarian: return "leaf"
        case .pescatarian: return "fish"
        case .paleo: return "flame"
        case .keto: return "bolt"
        case .lowSodium: return "drop"
        case .lowCarb: return "bolt"
        case .dairyfree, .glutenFree: return "leaf"
        case .halal, .kosher: return "star"
        }
    }
}

private enum PreferenceKind {
    case allergy(Allergy)
    case restriction(DietaryRestriction)
    case customAllergy(String)
    case customRestriction(String)
}

private struct PreferenceItem: Identifiable {
    let id: String
    let title: String
    let category: String
    let icon: String
    let isSelected: Bool
    let kind: PreferenceKind
}

private struct PreferenceListRow: View {
    let item: PreferenceItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .light))
                    .foregroundColor(item.isSelected ? .momentumAmber : .nordicSlate)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(AppFonts.serif(16, weight: .medium))
                        .foregroundColor(.midnightSpruce)
                    Text(item.category.uppercased())
                        .font(AppFonts.label)
                        .kerning(1)
                        .foregroundColor(item.isSelected ? Color.momentumAmber.opacity(0.8) : Color.nordicSlate.opacity(0.6))
                }
                Spacer()
                Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(item.isSelected ? .momentumAmber : Color.nordicSlate.opacity(0.4))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(Color.cardSurface)
            .overlay(
                Rectangle()
                    .fill(Color.softDivider)
                    .frame(height: 1),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}

private struct PreferenceSection: View {
    let title: String
    let items: [PreferenceItem]
    let onToggle: (PreferenceItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppFonts.label)
                .kerning(1.5)
                .foregroundColor(.nordicSlate)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    PreferenceListRow(item: item) {
                        onToggle(item)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.cardBorder, lineWidth: 1)
            )
            .background(Color.cardSurface)
        }
    }
}

struct CustomAllergySheet: View {
    @Binding var text: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("preferences.add_custom_allergy".localized())
                        .font(AppFonts.serif(20, weight: .bold))

                    Text("preferences.custom_allergy_description".localized())
                        .font(AppFonts.sans(13, weight: .regular))
                        .foregroundColor(.nordicSlate)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TextField("preferences.allergy_name".localized(), text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .submitLabel(.done)
                    .onSubmit {
                        saveAndDismiss()
                    }

                Spacer()

                Button {
                    saveAndDismiss()
                } label: {
                    Text("preferences.add".localized())
                        .font(AppFonts.sans(14, weight: .semibold))
                        .foregroundColor(.nordicBone)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.nordicSlate.opacity(0.4) : Color.midnightSpruce)
                        .cornerRadius(25)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .navigationTitle("preferences.custom_allergy".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("preferences.cancel".localized()) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveAndDismiss() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onSave(trimmed)
            dismiss()
        }
    }
}

struct CustomRestrictionSheet: View {
    @Binding var text: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("preferences.add_custom_restriction".localized())
                        .font(AppFonts.serif(20, weight: .bold))

                    Text("preferences.custom_allergy_description".localized())
                        .font(AppFonts.sans(13, weight: .regular))
                        .foregroundColor(.nordicSlate)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TextField("preferences.allergy_name".localized(), text: $text)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .submitLabel(.done)
                    .onSubmit {
                        saveAndDismiss()
                    }

                Spacer()

                Button {
                    saveAndDismiss()
                } label: {
                    Text("preferences.add".localized())
                        .font(AppFonts.sans(14, weight: .semibold))
                        .foregroundColor(.nordicBone)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.nordicSlate.opacity(0.4) : Color.midnightSpruce)
                        .cornerRadius(25)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .navigationTitle("preferences.add_custom_restriction".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("preferences.cancel".localized()) {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveAndDismiss() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onSave(trimmed)
            dismiss()
        }
    }
}

#Preview {
    DietaryPreferencesView()
}
