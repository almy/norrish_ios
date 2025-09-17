//
//  SettingsView.swift
//  healthScanner
//
//  Created by Claude on 16/09/25.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var themeManager = ThemeManager.shared
    @State private var showingAbout = false

    var body: some View {
        NavigationView {
            List {
                // Profile Section
                Section {
                    HStack(spacing: 16) {
                        // Adaptive profile image that changes with theme
                        Image("profile_avatar")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(.mint, lineWidth: 3)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Health Scanner User")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)

                            Text(NSLocalizedString("profile.tagline", comment: "Profile tagline"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 12)
                }
                .listRowBackground(Color.clear)

                // App Appearance Section
                Section {
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "paintbrush.fill")
                                .foregroundColor(.mint)
                                .frame(width: 24)

                            Text(NSLocalizedString("settings.appearance", comment: "Appearance section title"))
                                .font(.body)

                            Spacer()
                        }
                        .padding(.vertical, 8)

                        Picker(NSLocalizedString("settings.theme", comment: "Theme picker label"), selection: $themeManager.currentTheme) {
                            ForEach(AppTheme.allCases, id: \.self) { theme in
                                HStack {
                                    themeIcon(for: theme)
                                    Text(theme.title)
                                }
                                .tag(theme)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.top, 8)
                    }
                } header: {
                    Text(NSLocalizedString("settings.appearance_header", comment: "Appearance section header"))
                }

                // App Info Section
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.mint)
                            .frame(width: 24)

                        Text(NSLocalizedString("settings.version", comment: "App version label"))

                        Spacer()

                        Text(getAppVersion())
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                    Button {
                        showingAbout = true
                    } label: {
                        HStack {
                            Image(systemName: "questionmark.circle.fill")
                                .foregroundColor(.mint)
                                .frame(width: 24)

                            Text(NSLocalizedString("settings.about", comment: "About button"))
                                .foregroundColor(.primary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                } header: {
                    Text(NSLocalizedString("settings.app_info_header", comment: "App info section header"))
                }

                // Privacy & Data Section
                Section {
                    HStack {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.mint)
                            .frame(width: 24)

                        Text(NSLocalizedString("settings.privacy", comment: "Privacy label"))

                        Spacer()

                        Text(NSLocalizedString("settings.local_only", comment: "Local only text"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)

                } header: {
                    Text(NSLocalizedString("settings.privacy_header", comment: "Privacy section header"))
                } footer: {
                    Text(NSLocalizedString("settings.privacy_footer", comment: "Privacy section footer"))
                }
            }
            .navigationTitle(NSLocalizedString("settings.title", comment: "Settings navigation title"))
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }

    private func themeIcon(for theme: AppTheme) -> some View {
        Group {
            switch theme {
            case .system:
                Image(systemName: "gear")
            case .light:
                Image(systemName: "sun.max.fill")
            case .dark:
                Image(systemName: "moon.fill")
            }
        }
        .foregroundColor(.mint)
    }

    private func getAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            return "\(version) (\(build))"
        }
        return "1.0"
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon and Name
                    VStack(spacing: 16) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.mint)

                        Text("Health Scanner")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text(NSLocalizedString("about.tagline", comment: "App tagline"))
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Divider()

                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        Text(NSLocalizedString("about.features", comment: "Features section title"))
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 12) {
                            FeatureRow(icon: "barcode.viewfinder", title: NSLocalizedString("about.feature_scan", comment: "Barcode scanning feature"))
                            FeatureRow(icon: "fork.knife", title: NSLocalizedString("about.feature_plate", comment: "Plate analysis feature"))
                            FeatureRow(icon: "lock.shield", title: NSLocalizedString("about.feature_privacy", comment: "Privacy feature"))
                            FeatureRow(icon: "moon.fill", title: NSLocalizedString("about.feature_themes", comment: "Theme support feature"))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("about.title", comment: "About navigation title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("about.done", comment: "Done button")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.mint)
                .frame(width: 20)

            Text(title)
                .font(.body)

            Spacer()
        }
    }
}

#Preview {
    SettingsView()
}

#Preview("About") {
    AboutView()
}