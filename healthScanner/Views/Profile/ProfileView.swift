//
//  ProfileView.swift
//  healthScanner
//
//  Created by Claude on 16/09/25.
//

import SwiftUI
import SwiftData
import UIKit

@MainActor
final class ProfileIdentityStore: ObservableObject {
    static let shared = ProfileIdentityStore()

    @Published private(set) var displayName: String
    @Published private(set) var avatarPath: String?

    private let defaults = UserDefaults.standard
    private let nameKey = "profile.displayName"
    private let avatarPathKey = "profile.avatarPath"
    private let avatarDataKey = "profile.avatarData"

    private init() {
        let savedName = defaults.string(forKey: nameKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveName = (savedName?.isEmpty == false) ? savedName! : "Sophia Bennett"
        self.displayName = effectiveName
        let savedPath = defaults.string(forKey: avatarPathKey)
        if let savedPath, FileManager.default.fileExists(atPath: savedPath) {
            self.avatarPath = savedPath
        } else if let fallbackData = defaults.data(forKey: avatarDataKey) {
            let fileURL = avatarFileURL()
            do {
                try fallbackData.write(to: fileURL, options: .atomic)
                self.avatarPath = fileURL.path
                defaults.set(fileURL.path, forKey: avatarPathKey)
            } catch {
                self.avatarPath = nil
            }
        } else {
            self.avatarPath = nil
        }
    }

    func updateDisplayName(_ newValue: String) {
        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        displayName = trimmed
        defaults.set(trimmed, forKey: nameKey)
    }

    func updateAvatar(_ image: UIImage) {
        guard let data = encodedAvatarData(from: image) else { return }
        let fileURL = avatarFileURL()
        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            avatarPath = fileURL.path
            defaults.set(fileURL.path, forKey: avatarPathKey)
            defaults.set(data, forKey: avatarDataKey)
        } catch {
            return
        }
    }

    func removeAvatar() {
        if let avatarPath {
            try? FileManager.default.removeItem(atPath: avatarPath)
        }
        self.avatarPath = nil
        defaults.removeObject(forKey: avatarPathKey)
        defaults.removeObject(forKey: avatarDataKey)
    }

    func avatarImage() -> UIImage? {
        if let avatarPath, let image = UIImage(contentsOfFile: avatarPath) {
            return image
        }
        if let data = defaults.data(forKey: avatarDataKey), let image = UIImage(data: data) {
            if avatarPath == nil {
                let fileURL = avatarFileURL()
                do {
                    try data.write(to: fileURL, options: .atomic)
                    self.avatarPath = fileURL.path
                    defaults.set(fileURL.path, forKey: avatarPathKey)
                } catch {
                    // Keep in-memory fallback from defaults data.
                }
            }
            return image
        }
        return nil
    }

    private func avatarFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return appSupport
            .appendingPathComponent("ProfileIdentity", isDirectory: true)
            .appendingPathComponent("profile_avatar.jpg")
    }

    private func encodedAvatarData(from image: UIImage) -> Data? {
        let prepared = image.downsized(maxSide: 1200)
        return prepared.jpegData(compressionQuality: 0.82) ?? prepared.pngData()
    }
}

struct ProfileView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var preferencesManager = DietaryPreferencesManager.shared
    @StateObject private var profileIdentity = ProfileIdentityStore.shared
    @State private var mealRemindersEnabled = false
    @State private var promotionalUpdatesEnabled = false
    @State private var showingLogoutAlert = false
    @State private var showingLanguageSheet = false
    @State private var showingAbout = false
    @State private var showingPrivacy = false
    @State private var showingDietaryPreferences = false
    @State private var showingManageAccount = false
    @State private var showingEditNameSheet = false
    @State private var draftDisplayName = ""
    @State private var showingAvatarSourceDialog = false
    @State private var showingAvatarCamera = false
    @State private var showingAvatarLibrary = false
    @State private var showingPhotoPermissionAlert = false
    @State private var selectedAvatarImage: UIImage?
    @Query private var plates: [PlateAnalysisHistory]
    @Query private var products: [Product]

    var body: some View {
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
        .background(Color.nordicBone.ignoresSafeArea())
        .accessibilityIdentifier("screen.profile")
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
        .sheet(isPresented: $showingEditNameSheet) {
            editNameSheet
        }
        .fullScreenCover(isPresented: $showingAvatarCamera) {
            CameraCaptureView(image: $selectedAvatarImage)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingAvatarLibrary) {
            PhotoLibraryPickerView(image: $selectedAvatarImage)
                .ignoresSafeArea()
        }
        .confirmationDialog("Edit Photo", isPresented: $showingAvatarSourceDialog, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { showingAvatarCamera = true }
            }
            Button("Choose from Library") { requestPhotoLibraryAccessForAvatar() }
            if PhotoLibraryPermission.canManageLimitedSelection {
                Button("Manage Selected Photos") {
                    PhotoLibraryPermission.presentLimitedLibraryPicker()
                }
            }
            if profileIdentity.avatarImage() != nil {
                Button("Remove Photo", role: .destructive) {
                    profileIdentity.removeAvatar()
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert("Photo Access Needed", isPresented: $showingPhotoPermissionAlert) {
            Button("Open Settings") {
                PhotoLibraryPermission.openSettings()
            }
            Button("Not Now", role: .cancel) { }
        } message: {
            Text("Allow Photos access to choose an avatar. You can grant Full Access or select Limited Photos.")
        }
        .onChange(of: selectedAvatarImage) { _, newValue in
            guard let image = newValue else { return }
            profileIdentity.updateAvatar(image)
            selectedAvatarImage = nil
        }
    }
}

private extension ProfileView {
    func requestPhotoLibraryAccessForAvatar() {
        Task {
            let status = await PhotoLibraryPermission.requestReadWriteAccess()
            await MainActor.run {
                if PhotoLibraryPermission.hasAccess(status) {
                    showingAvatarLibrary = true
                } else {
                    showingPhotoPermissionAlert = true
                }
            }
        }
    }
}

private extension ProfileView {
    var topBar: some View {
        HStack {
            Color.clear.frame(width: 40, height: 40)
            Spacer()
            Text("tab.profile".localized())
                .font(AppFonts.label)
                .kerning(2.5)
                .foregroundColor(.nordicSlate)
                .textCase(.uppercase)
            Spacer()
            Button(action: { showingManageAccount = true }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 20, weight: .light))
                    .foregroundColor(.midnightSpruce)
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
    }

    var profileHeader: some View {
        VStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let avatarImage = profileIdentity.avatarImage() {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if let bundledAvatar = UIImage(named: "profile_avatar") {
                        Image(uiImage: bundledAvatar)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.nordicSlate.opacity(0.7))
                            .padding(10)
                    }
                }
                .frame(width: 96, height: 96)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.momentumAmber.opacity(0.2), lineWidth: 1))
                .onTapGesture {
                    showingAvatarSourceDialog = true
                }

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.momentumAmber)
                    .padding(6)
                    .background(Color.nordicBone)
                    .clipShape(Circle())
            }

            VStack(spacing: 6) {
                Text(profileIdentity.displayName)
                    .font(AppFonts.serif(32, weight: .semibold))
                    .foregroundColor(.midnightSpruce)
                    .onTapGesture {
                        draftDisplayName = profileIdentity.displayName
                        showingEditNameSheet = true
                    }
                Text("profile.membership".localized())
                    .font(AppFonts.sans(11, weight: .medium))
                    .kerning(2)
                    .foregroundColor(.nordicSlate)
                    .textCase(.uppercase)
            }

            Button("Edit profile") {
                draftDisplayName = profileIdentity.displayName
                showingEditNameSheet = true
            }
            .font(AppFonts.sans(12, weight: .semibold))
            .foregroundColor(.midnightSpruce)
        }
        .padding(.horizontal, 20)
    }

    var dietaryOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("profile.overview".localized())
                .font(AppFonts.serif(22, weight: .semibold))
                .foregroundColor(.midnightSpruce)
                .padding(.horizontal, 20)

            let daysLabel = activeDays == 1
                ? NSLocalizedString("profile.day", comment: "Day label (singular)")
                : NSLocalizedString("profile.days", comment: "Days label (plural)")
            HStack(spacing: 12) {
                ProfileMetricCard(title: "profile.primary_goal".localized(), value: primaryGoalText)
                ProfileMetricCard(title: "profile.daily_streak".localized(), value: "\(activeDays) \(daysLabel)")
            }
            .padding(.horizontal, 20)

            HStack(spacing: 16) {
                ProfileStatCell(value: healthScoreText, label: "profile.health_score".localized(), accent: true)
                Divider().frame(height: 36).background(Color.softDivider)
                ProfileStatCell(value: "\(plates.count)", label: "profile.analyzed_plates".localized(), accent: false)
                Divider().frame(height: 36).background(Color.softDivider)
                ProfileStatCell(value: averageGradeText, label: "profile.avg_grade".localized(), accent: false)
            }
            .padding(.horizontal, 20)
        }
    }

    var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("profile.preferences".localized())
                .font(AppFonts.serif(22, weight: .semibold))
                .foregroundColor(.midnightSpruce)
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
                .font(AppFonts.serif(22, weight: .semibold))
                .foregroundColor(.midnightSpruce)
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
                ) {
                    draftDisplayName = profileIdentity.displayName
                    showingEditNameSheet = true
                }

                ProfileListRow(
                    title: "profile.privacy".localized(),
                    icon: "hand.raised",
                    trailing: .chevron
                ) { showingPrivacy = true }

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
            Text("profile.version".localized())
                .font(AppFonts.label)
                .kerning(2.5)
                .foregroundColor(.nordicSlate.opacity(0.7))
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

    var editNameSheet: some View {
        NavigationStack {
            Form {
                Section("Profile Name") {
                    TextField("Enter your name", text: $draftDisplayName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showingEditNameSheet = false }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        profileIdentity.updateDisplayName(draftDisplayName)
                        showingEditNameSheet = false
                    }
                    .disabled(draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct ProfileMetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(AppFonts.label)
                .kerning(2)
                .foregroundColor(.nordicSlate)
            Text(value)
                .font(AppFonts.serif(20, weight: .semibold))
                .foregroundColor(.midnightSpruce)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.cardBorder, lineWidth: 1)
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
                .font(AppFonts.serif(28, weight: .medium))
                .foregroundColor(.midnightSpruce)
            Text(label.uppercased())
                .font(AppFonts.label)
                .kerning(2)
                .foregroundColor(accent ? Color.momentumAmber : Color.nordicSlate)
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
    var tint: Color = Color.nordicSlate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .light))
                    .foregroundColor(tint)
                    .frame(width: 24)
                Text(title)
                    .font(AppFonts.serif(18, weight: .medium))
                    .foregroundColor(.midnightSpruce)
                Spacer()
                trailingView
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(Color.cardSurface)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .overlay(
            Rectangle()
                .fill(Color.softDivider)
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
                .foregroundColor(Color.nordicSlate.opacity(0.7))
        case .value(let value):
            Text(value)
                .font(AppFonts.sans(12, weight: .medium))
                .foregroundColor(.nordicSlate)
        case .badge(let value):
            Text(value.uppercased())
                .font(AppFonts.label)
                .kerning(1)
                .foregroundColor(.nordicSlate)
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
                .foregroundColor(.nordicSlate)
                .frame(width: 24)
            Text(title)
                .font(AppFonts.serif(18, weight: .medium))
                .foregroundColor(.midnightSpruce)
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(Color.cardSurface)
        .cornerRadius(12)
        .overlay(
            Rectangle()
                .fill(Color.softDivider)
                .frame(height: isLast ? 0 : 1),
            alignment: .bottom
        )
    }
}

struct LanguageSelectionView: View {
    @StateObject private var localizationManager = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    HStack {
                        Text(language.displayName)
                            .font(AppFonts.sans(14, weight: .regular))

                        Spacer()

                        if language == localizationManager.currentLanguage {
                            Image(systemName: "checkmark")
                                .foregroundColor(.momentumAmber)
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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Data Collection")
                            .font(AppFonts.serif(18, weight: .semibold))

                        Text("Health Scanner is committed to protecting your privacy. All your data is stored locally on your device and is never shared with third parties.")
                            .font(AppFonts.sans(13, weight: .regular))
                            .foregroundColor(.nordicSlate)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Information We Store")
                            .font(AppFonts.serif(18, weight: .semibold))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("• Scanned product information")
                            Text("• Plate analysis results")
                            Text("• Your dietary preferences")
                            Text("• App settings and preferences")
                        }
                        .font(AppFonts.sans(13, weight: .regular))
                        .foregroundColor(.nordicSlate)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Data Security")
                            .font(AppFonts.serif(18, weight: .semibold))

                        Text("Your data is encrypted and stored securely on your device using iOS's built-in security features. We use industry-standard encryption methods to protect your information.")
                            .font(AppFonts.sans(13, weight: .regular))
                            .foregroundColor(.nordicSlate)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Third-Party Services")
                            .font(AppFonts.serif(18, weight: .semibold))

                        Text("Health Scanner may use third-party services for product information lookup, but no personal data is transmitted. Only product barcodes are sent to retrieve nutritional information.")
                            .font(AppFonts.sans(13, weight: .regular))
                            .foregroundColor(.nordicSlate)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Contact Us")
                            .font(AppFonts.serif(18, weight: .semibold))

                        Text("If you have any questions about this privacy policy, please contact us at privacy@healthscanner.app")
                            .font(AppFonts.sans(13, weight: .regular))
                            .foregroundColor(.nordicSlate)
                    }
                }
                .padding()
            }
            .background(Color.nordicBone)
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
            .font(AppFonts.sans(11, weight: .medium))
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
