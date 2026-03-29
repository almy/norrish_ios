//
//  LocalizationManager.swift
//  healthScanner
//
//  Created by Claude on 16/09/25.
//

import SwiftUI
import Foundation

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case swedish = "sv"

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .swedish:
            return "Svenska"
        }
    }

    var languageCode: String {
        return self.rawValue
    }
}

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @Published var currentLanguage: AppLanguage = .english {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "selectedLanguage")
            updateCurrentLanguage()
        }
    }

    private var bundle: Bundle = Bundle.main

    private init() {
        loadSavedLanguage()
        updateCurrentLanguage()
    }

    private func loadSavedLanguage() {
        if let savedLanguage = UserDefaults.standard.string(forKey: "selectedLanguage"),
           let language = AppLanguage(rawValue: savedLanguage) {
            currentLanguage = language
        } else {
            // Default to system language if available, otherwise English
            let systemLanguage = Locale.current.language.languageCode?.identifier ?? "en"
            currentLanguage = AppLanguage(rawValue: systemLanguage) ?? .english
        }
    }

    private func updateCurrentLanguage() {
        guard let path = Bundle.main.path(forResource: currentLanguage.languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            self.bundle = Bundle.main
            return
        }
        self.bundle = bundle

        // Notify the app that language has changed
        NotificationCenter.default.post(name: .languageChanged, object: nil)
    }

    func localizedString(forKey key: String, comment: String = "") -> String {
        return NSLocalizedString(key, bundle: bundle, comment: comment)
    }
}

// Helper view modifier to refresh views when language changes
struct LocalizedView: ViewModifier {
    @StateObject private var localizationManager = LocalizationManager.shared

    func body(content: Content) -> some View {
        content
            .environmentObject(localizationManager)
            .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
                // Force view refresh when language changes
                localizationManager.objectWillChange.send()
            }
    }
}

extension View {
    func localized() -> some View {
        modifier(LocalizedView())
    }
}