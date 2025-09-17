//
//  ThemeManager.swift
//  healthScanner
//
//  Created by Claude on 16/09/25.
//

import SwiftUI
import Foundation

enum AppTheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var title: String {
        switch self {
        case .system:
            return NSLocalizedString("theme.system", comment: "System theme option")
        case .light:
            return NSLocalizedString("theme.light", comment: "Light theme option")
        case .dark:
            return NSLocalizedString("theme.dark", comment: "Dark theme option")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var currentTheme: AppTheme = .system {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selectedTheme")
            applyTheme()
        }
    }

    private init() {
        loadSavedTheme()
        applyTheme()
    }

    private func loadSavedTheme() {
        if let savedTheme = UserDefaults.standard.string(forKey: "selectedTheme"),
           let theme = AppTheme(rawValue: savedTheme) {
            currentTheme = theme
        }
    }

    private func applyTheme() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return }

            switch self.currentTheme {
            case .system:
                window.overrideUserInterfaceStyle = .unspecified
            case .light:
                window.overrideUserInterfaceStyle = .light
            case .dark:
                window.overrideUserInterfaceStyle = .dark
            }
        }
    }
}