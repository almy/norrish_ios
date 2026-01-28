//
//  norrishApp.swift
//  norrish
//
//  Created by myftiu on 06/09/25.
//

import SwiftUI
import SwiftData
import Foundation
import UIKit

// TypeAlias to ensure PlateAnalysisHistory is explicitly referenced
typealias PlateHistoryType = PlateAnalysisHistory

@main
struct norrishApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared

    init() {
        // Kick off Core ML model prewarm at app launch (guaranteed entry point)
        print("🚀 [Prewarm] Launch prewarm from norrishApp.init()")
        DualCameraPlateScannerViewController.prewarmModels()
    }

    var sharedModelContainer: ModelContainer = {
        do {
            // Explicitly list models to build the container schema
            return try ModelContainer(for: Product.self, PlateAnalysisHistory.self, Item.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(themeManager)
                .environmentObject(localizationManager)
                .preferredColorScheme(themeManager.currentTheme.colorScheme)
                .localized()
                .onAppear {
                    // Debug localization helper (optional)
                    // Re-enable if extension is added to target
                    // #if DEBUG
                    // Bundle.debugLocalization()
                    // #endif
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

