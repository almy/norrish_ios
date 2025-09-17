//
//  LocalizationDebug.swift
//  healthScanner
//
//  Debug utilities for localization
//

import Foundation

extension Bundle {
    /// Debug function to check localization setup
    static func debugLocalization() {
        print("=== Localization Debug ===")

        // Check current language
        let currentLanguage = Locale.current.languageCode
        print("Current language code: \(currentLanguage ?? "unknown")")

        // Check preferred languages
        let preferredLanguages = Locale.preferredLanguages
        print("Preferred languages: \(preferredLanguages)")

        // Check bundle localizations
        let mainBundle = Bundle.main
        print("Main bundle localizations: \(mainBundle.localizations)")
        print("Main bundle preferredLocalizations: \(mainBundle.preferredLocalizations)")

        // Test a specific key
        let testKey = "tab.scan"
        let localizedString = NSLocalizedString(testKey, comment: "Test")
        print("Test key '\(testKey)' -> '\(localizedString)'")

        // Check if localization files exist in bundle
        if let enPath = mainBundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "en") {
            print("English localization file found at: \(enPath)")
        } else {
            print("❌ English localization file NOT found in bundle")
        }

        if let svPath = mainBundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "sv") {
            print("Swedish localization file found at: \(svPath)")
        } else {
            print("❌ Swedish localization file NOT found in bundle")
        }

        // Check bundle resource files
        if let resourcePath = mainBundle.resourcePath {
            print("Resource path: \(resourcePath)")

            let fileManager = FileManager.default
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: resourcePath)
                let lprojFiles = contents.filter { $0.hasSuffix(".lproj") }
                print("Found .lproj directories: \(lprojFiles)")

                // Check contents of each lproj directory
                for lprojDir in lprojFiles {
                    let lprojPath = "\(resourcePath)/\(lprojDir)"
                    let lprojContents = try fileManager.contentsOfDirectory(atPath: lprojPath)
                    print("Contents of \(lprojDir): \(lprojContents)")
                }
            } catch {
                print("Error reading bundle contents: \(error)")
            }
        }

        print("=== End Debug ===")
    }
}

#if DEBUG
extension String {
    /// Debug version of localized string that prints the key being looked up
    var debugLocalized: String {
        let result = NSLocalizedString(self, comment: "")
        print("🔍 Localizing key: '\(self)' -> '\(result)'")
        return result
    }
}

#endif
