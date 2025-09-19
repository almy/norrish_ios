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
    @State private var customAllergyText = ""
    @State private var customRestrictionText = ""

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header with progress bar
                    VStack(spacing: 16) {
                        // Progress bar
                        VStack(spacing: 8) {
                            HStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.mint)
                                    .frame(height: 8)
                                    .frame(width: progressBarWidth)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.3))
                                    .frame(height: 8)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text("preferences.profile_complete".localized(comment: "\(Int(preferencesManager.profileCompletionPercentage))%"))
                                .font(.subheadline)
                                .foregroundColor(.mint)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }

                    // Allergies Section
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("preferences.allergies".localized())
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Text("preferences.allergies_description".localized())
                                .font(.body)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 20)

                        // Allergy pills
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(Allergy.allCases) { allergy in
                                AllergyPill(
                                    title: allergy.displayName,
                                    isSelected: preferencesManager.selectedAllergies.contains(allergy)
                                ) {
                                    preferencesManager.toggleAllergy(allergy)
                                }
                            }

                            // Custom allergies
                            ForEach(preferencesManager.customAllergies, id: \.self) { customAllergy in
                                AllergyPill(
                                    title: customAllergy,
                                    isSelected: true,
                                    isCustom: true
                                ) {
                                    preferencesManager.removeCustomAllergy(customAllergy)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Dietary Restrictions Section
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("preferences.dietary_restrictions".localized())
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Text("preferences.dietary_description".localized())
                                .font(.body)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 20)

                        // Dietary restriction pills
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
                            ForEach(DietaryRestriction.allCases) { restriction in
                                AllergyPill(
                                    title: restriction.displayName,
                                    isSelected: preferencesManager.selectedDietaryRestrictions.contains(restriction)
                                ) {
                                    preferencesManager.toggleDietaryRestriction(restriction)
                                }
                            }

                            // Custom restrictions
                            ForEach(preferencesManager.customRestrictions, id: \.self) { customRestriction in
                                AllergyPill(
                                    title: customRestriction,
                                    isSelected: true,
                                    isCustom: true
                                ) {
                                    preferencesManager.removeCustomRestriction(customRestriction)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Add custom option
                    Button {
                        showingCustomAllergySheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Text("preferences.add_custom".localized())
                                .font(.body)
                                .foregroundColor(.mint)

                            Spacer()

                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.mint)
                                .font(.title2)
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(25)
                    }
                    .padding(.horizontal, 20)

                    // Save button
                    Button {
                        dismiss()
                    } label: {
                        Text("preferences.save_preferences".localized())
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.mint)
                            .cornerRadius(25)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("preferences.your_preferences".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                    }
                }
            }
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
    }

    private var progressBarWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width - 40 // Account for padding
        let percentage = preferencesManager.profileCompletionPercentage / 100
        return screenWidth * CGFloat(percentage)
    }
}

struct AllergyPill: View {
    let title: String
    let isSelected: Bool
    let isCustom: Bool
    let action: () -> Void

    init(title: String, isSelected: Bool, isCustom: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.isCustom = isCustom
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)

                if isSelected {
                    Image(systemName: isCustom ? "minus" : "xmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: "plus")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(isSelected ? Color.mint : Color(.secondarySystemBackground))
            .cornerRadius(25)
            .overlay(
                RoundedRectangle(cornerRadius: 25)
                    .stroke(Color(.separator), lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
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
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("preferences.custom_allergy_description".localized())
                        .font(.body)
                        .foregroundColor(.secondary)
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
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.mint)
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

#Preview {
    DietaryPreferencesView()
}