//
//  ProfileView.swift
//  healthScanner
//
//  Created by Claude on 16/09/25.
//

import SwiftUI
import SwiftData

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
    @Query private var plates: [PlateAnalysisHistory]
    @Query private var products: [Product]

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    topBar
                    profileHeader
                    dietaryOverviewSection
                    preferencesSection
                    accountSection
                    footerActions
                }
                .padding(.bottom, 32)
            }
            .background(Color(red: 252 / 255, green: 252 / 255, blue: 252 / 255))
            .navigationBarHidden(true)
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

private extension ProfileView {
    var topBar: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255))
                    .frame(width: 40, height: 40)
            }
            Spacer()
            Text("tab.profile".localized())
                .font(.system(size: 12, weight: .semibold))
                .kerning(3)
                .foregroundColor(Color(red: 43 / 255, green: 108 / 255, blue: 238 / 255).opacity(0.6))
                .textCase(.uppercase)
            Spacer()
            Button(action: { showingManageAccount = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255))
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    var profileHeader: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image("profile_avatar")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 96, height: 96)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color(red: 43 / 255, green: 108 / 255, blue: 238 / 255).opacity(0.1), lineWidth: 1))

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 43 / 255, green: 108 / 255, blue: 238 / 255))
                    .padding(6)
                    .background(Color.white)
                    .clipShape(Circle())
            }

            VStack(spacing: 6) {
                Text("Sophia Bennett")
                    .font(.system(size: 34, weight: .medium, design: .serif))
                    .foregroundColor(Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255))
                Text("profile.membership".localized())
                    .font(.system(size: 11, weight: .medium))
                    .kerning(2)
                    .foregroundColor(Color(red: 97 / 255, green: 111 / 255, blue: 137 / 255))
                    .textCase(.uppercase)
            }
        }
        .padding(.horizontal, 20)
    }

    var dietaryOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("profile.overview".localized())
                .font(.system(size: 22, weight: .medium, design: .serif))
                .foregroundColor(Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255))
                .padding(.horizontal, 20)

            let daysLabel = NSLocalizedString("profile.days", comment: "Days label")
            HStack(spacing: 12) {
                ProfileMetricCard(title: "profile.primary_goal".localized(), value: primaryGoalText)
                ProfileMetricCard(title: "profile.daily_streak".localized(), value: "\(activeDays) \(daysLabel)")
            }
            .padding(.horizontal, 20)

            HStack(spacing: 16) {
                ProfileStatCell(value: healthScoreText, label: "profile.health_score".localized(), accent: true)
                Divider().frame(height: 36).background(Color.gray.opacity(0.2))
                ProfileStatCell(value: "\(plates.count)", label: "profile.analyzed_plates".localized(), accent: false)
                Divider().frame(height: 36).background(Color.gray.opacity(0.2))
                ProfileStatCell(value: averageGradeText, label: "profile.avg_grade".localized(), accent: false)
            }
            .padding(.horizontal, 20)
        }
    }

    var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("profile.preferences".localized())
                .font(.system(size: 22, weight: .medium, design: .serif))
                .foregroundColor(Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255))
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ProfileListRow(
                    title: "profile.dietary_preferences".localized(),
                    icon: "fork.knife",
                    trailing: .chevron
                ) { showingDietaryPreferences = true }

                let activeLabel = NSLocalizedString("profile.active", comment: "Active label")
                ProfileListRow(
                    title: "profile.allergies".localized(),
                    icon: "exclamationmark.triangle",
                    trailing: .badge("\(preferencesManager.selectedAllergies.count) \(activeLabel)")
                ) { showingDietaryPreferences = true }

                ProfileToggleListRow(
                    title: "profile.meal_reminders".localized(),
                    icon: "bell",
                    isOn: $mealRemindersEnabled
                )

                ProfileToggleListRow(
                    title: "profile.promotional_updates".localized(),
                    icon: "sparkles",
                    isOn: $promotionalUpdatesEnabled
                )

                ProfileToggleListRow(
                    title: "profile.dark_mode".localized(),
                    icon: "moon",
                    isOn: .init(
                        get: { themeManager.currentTheme == .dark },
                        set: { newValue in
                            themeManager.currentTheme = newValue ? .dark : .light
                        }
                    ),
                    isLast: true
                )
            }
            .padding(.horizontal, 20)
        }
    }

    var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("profile.privacy_account".localized())
                .font(.system(size: 22, weight: .medium, design: .serif))
                .foregroundColor(Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255))
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ProfileListRow(
                    title: "profile.language".localized(),
                    icon: "globe",
                    trailing: .value(localizationManager.currentLanguage.displayName)
                ) { showingLanguageSheet = true }

                ProfileListRow(
                    title: "profile.manage_account".localized(),
                    icon: "person.crop.circle",
                    trailing: .chevron
                ) { showingManageAccount = true }

                ProfileListRow(
                    title: "profile.logout".localized(),
                    icon: "rectangle.portrait.and.arrow.right",
                    trailing: .chevron,
                    isLast: true,
                    tint: .red
                ) { showingLogoutAlert = true }
            }
            .padding(.horizontal, 20)
        }
    }

    var footerActions: some View {
        VStack(spacing: 12) {
            Button(action: { showingAbout = true }) {
                HStack(spacing: 8) {
                    Text("profile.download_report".localized())
                        .font(.system(size: 16, weight: .medium, design: .serif))
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 16))
                }
                .foregroundColor(Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 999)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .clipShape(Capsule())
            }

            Text("profile.version".localized())
                .font(.system(size: 10, weight: .medium))
                .kerning(3)
                .foregroundColor(Color(red: 97 / 255, green: 111 / 255, blue: 137 / 255).opacity(0.7))
                .textCase(.uppercase)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    var primaryGoalText: String {
        if let first = preferencesManager.selectedDietaryRestrictions.first {
            return first.displayName
        }
        return "profile.goal.balance".localized()
    }

    var activeDays: Int {
        let cutoff = Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date.distantPast
        let plateDays = plates.filter { $0.analyzedDate >= cutoff }.map { Calendar.current.startOfDay(for: $0.analyzedDate) }
        let productDays = products.filter { $0.scannedDate >= cutoff }.map { Calendar.current.startOfDay(for: $0.scannedDate) }
        return Set(plateDays + productDays).count
    }

    var healthScoreText: String {
        guard let avg = averagePlateScore else { return "—" }
        return "\(Int(avg * 10))%"
    }

    var averageGradeText: String {
        guard let avg = averagePlateScore else { return "—" }
        return nutriScoreForPlate(score0to10: avg).rawValue
    }

    var averagePlateScore: Double? {
        guard !plates.isEmpty else { return nil }
        let total = plates.map { $0.nutritionScore }.reduce(0, +)
        return total / Double(plates.count)
    }
}

private struct ProfileMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .kerning(2)
                .foregroundColor(Color(red: 97 / 255, green: 111 / 255, blue: 137 / 255))
            Text(value)
                .font(.system(size: 20, weight: .medium, design: .serif))
                .foregroundColor(Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct ProfileStatCell: View {
    let value: String
    let label: String
    let accent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .light, design: .serif))
                .foregroundColor(Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255))
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .kerning(2)
                .foregroundColor(accent ? Color(red: 43 / 255, green: 108 / 255, blue: 238 / 255) : Color(red: 97 / 255, green: 111 / 255, blue: 137 / 255))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private enum ProfileRowTrailing {
    case chevron
    case value(String)
    case badge(String)
}

private struct ProfileListRow: View {
    let title: String
    let icon: String
    let trailing: ProfileRowTrailing
    var isLast: Bool = false
    var tint: Color = Color(red: 97 / 255, green: 111 / 255, blue: 137 / 255)
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(tint)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 18, weight: .medium, design: .serif))
                    .foregroundColor(Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255))
                Spacer()
                trailingView
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(Color.white)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: isLast ? 0 : 1),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private var trailingView: some View {
        switch trailing {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Color.gray.opacity(0.5))
        case .value(let value):
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(red: 97 / 255, green: 111 / 255, blue: 137 / 255))
        case .badge(let value):
            Text(value.uppercased())
                .font(.system(size: 10, weight: .bold))
                .kerning(1)
                .foregroundColor(Color(red: 97 / 255, green: 111 / 255, blue: 137 / 255))
        }
    }
}

private struct ProfileToggleListRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    var isLast: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .light))
                .foregroundColor(Color(red: 97 / 255, green: 111 / 255, blue: 137 / 255))
                .frame(width: 24)
            Text(title)
                .font(.system(size: 18, weight: .medium, design: .serif))
                .foregroundColor(Color(red: 17 / 255, green: 19 / 255, blue: 24 / 255))
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.1))
                .frame(height: isLast ? 0 : 1),
            alignment: .bottom
        )
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
