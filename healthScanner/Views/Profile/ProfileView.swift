//
//  ProfileView.swift
//  healthScanner
//
//  Created by Claude on 16/09/25.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var preferencesManager = DietaryPreferencesManager.shared
    @State private var mealRemindersEnabled = false
    @State private var promotionalUpdatesEnabled = false
    @State private var showingLogoutAlert = false
    @State private var showingLanguageSheet = false
    @State private var showingAbout = false
    @State private var showingPrivacy = false
    @State private var showingDietaryPreferences = false
    @State private var showingManageAccount = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header with profile image and info
                    VStack(spacing: 16) {
                        // Profile Image
                        Image("profile_avatar")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .background(
                                Circle()
                                    .fill(Color.secondary.opacity(0.1))
                                    .frame(width: 130, height: 130)
                            )

                        // Name and membership info
                        VStack(spacing: 4) {
                            Text("Sophia Bennett")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Text("profile.membership".localized())
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 20)

                    // Dietary Preferences Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("profile.dietary_preferences".localized())
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)

                            Spacer()

                            Button("profile.edit".localized()) {
                                showingDietaryPreferences = true
                            }
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.mint)
                        }
                        .padding(.horizontal, 20)

                        VStack(alignment: .leading, spacing: 16) {
                            // Diet section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("profile.diet".localized())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(preferencesManager.selectedDietaryRestrictions), id: \.self) { restriction in
                                            DietaryPill(
                                                text: restriction.displayName,
                                                color: .mint
                                            )
                                        }

                                        if preferencesManager.selectedDietaryRestrictions.isEmpty {
                                            DietaryPill(
                                                text: "profile.none".localized(),
                                                color: .gray
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }

                            // Allergies section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("profile.allergies".localized())
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(Array(preferencesManager.selectedAllergies), id: \.self) { allergy in
                                            DietaryPill(
                                                text: allergy.displayName,
                                                color: .red
                                            )
                                        }

                                        if preferencesManager.selectedAllergies.isEmpty {
                                            DietaryPill(
                                                text: "profile.none".localized(),
                                                color: .gray
                                            )
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }

                    // Notification Settings Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("profile.notification_settings".localized())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            ProfileToggleRow(
                                label: "profile.meal_reminders".localized(),
                                isOn: $mealRemindersEnabled
                            )

                            ProfileToggleRow(
                                label: "profile.promotional_updates".localized(),
                                isOn: $promotionalUpdatesEnabled
                            )

                            ProfileToggleRow(
                                label: "profile.dark_mode".localized(),
                                isOn: .init(
                                    get: { themeManager.currentTheme == .dark },
                                    set: { newValue in
                                        themeManager.currentTheme = newValue ? .dark : .light
                                    }
                                ),
                                isLast: true
                            )
                        }
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }

                    // Privacy & Account Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("profile.privacy_account".localized())
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            ProfileSelectionRow(
                                label: "profile.language".localized(),
                                value: localizationManager.currentLanguage.displayName,
                                showChevron: true
                            ) {
                                showingLanguageSheet = true
                            }

                            ProfileSelectionRow(
                                label: "profile.manage_account".localized(),
                                value: "",
                                isLast: true,
                                showChevron: true
                            ) {
                                showingManageAccount = true
                            }
                        }
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }

                    // Logout Button
                    Button {
                        showingLogoutAlert = true
                    } label: {
                        HStack {
                            Text("profile.logout".localized())
                                .font(.body)
                                .fontWeight(.medium)

                            Spacer()

                            Image(systemName: "rectangle.portrait.and.arrow.right")
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("tab.profile".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        // Handle back navigation if needed
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .alert("profile.logout".localized(), isPresented: $showingLogoutAlert) {
            Button("profile.cancel".localized(), role: .cancel) { }
            Button("profile.logout".localized(), role: .destructive) {
                // Handle logout
            }
        } message: {
            Text("profile.logout_confirmation".localized())
        }
        .sheet(isPresented: $showingLanguageSheet) {
            LanguageSelectionView()
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
        .sheet(isPresented: $showingPrivacy) {
            PrivacyView()
        }
        .sheet(isPresented: $showingDietaryPreferences) {
            DietaryPreferencesView()
        }
    }
}


struct ProfileToggleRow: View {
    let label: String
    @Binding var isOn: Bool
    let isLast: Bool

    init(label: String, isOn: Binding<Bool>, isLast: Bool = false) {
        self.label = label
        self._isOn = isOn
        self.isLast = isLast
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.body)
                    .foregroundColor(.primary)

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isLast {
                Divider()
                    .padding(.leading, 16)
            }
        }
    }
}

struct ProfileSelectionRow: View {
    let label: String
    let value: String
    let isLast: Bool
    let showChevron: Bool
    let action: () -> Void

    init(label: String, value: String, isLast: Bool = false, showChevron: Bool = true, action: @escaping () -> Void) {
        self.label = label
        self.value = value
        self.isLast = isLast
        self.showChevron = showChevron
        self.action = action
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack {
                    Text(label)
                        .font(.body)
                        .foregroundColor(.primary)

                    Spacer()

                    if !value.isEmpty {
                        Text(value)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    if showChevron {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }

            if !isLast {
                Divider()
                    .padding(.leading, 16)
            }
        }
    }
}

struct LanguageSelectionView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    HStack {
                        Text(language.displayName)
                            .font(.body)

                        Spacer()

                        if language == localizationManager.currentLanguage {
                            Image(systemName: "checkmark")
                                .foregroundColor(.mint)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        localizationManager.currentLanguage = language
                        dismiss()
                    }
                }
            }
            .navigationTitle("profile.language".localized())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("profile.done".localized()) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Data Collection")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text("Health Scanner is committed to protecting your privacy. All your data is stored locally on your device and is never shared with third parties.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Information We Store")
                            .font(.headline)
                            .fontWeight(.semibold)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Scanned product information")
                            Text("• Plate analysis results")
                            Text("• Your dietary preferences")
                            Text("• App settings and preferences")
                        }
                        .font(.body)
                        .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Data Security")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text("Your data is encrypted and stored securely on your device using iOS's built-in security features. We use industry-standard encryption methods to protect your information.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Third-Party Services")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text("Health Scanner may use third-party services for product information lookup, but no personal data is transmitted. Only product barcodes are sent to retrieve nutritional information.")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Contact Us")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Text("If you have any questions about this privacy policy, please contact us at privacy@healthscanner.app")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct DietaryPill: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color)
            .cornerRadius(12)
    }
}

#Preview {
    ProfileView()
}