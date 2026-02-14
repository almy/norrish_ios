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
    @State private var showSplash = true

    init() {
        // Kick off Core ML model prewarm at app launch (guaranteed entry point)
        print("🚀 [Prewarm] Launch prewarm from norrishApp.init()")
        DualCameraPlateScannerViewController.prewarmModels()
    }

    var sharedModelContainer: ModelContainer = {
        do {
            // Explicitly list models to build the container schema
            return try ModelContainer(for: Product.self, PlateAnalysisHistory.self, Item.self, DailyNutritionAggregateEntity.self, ScanEventEntity.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(themeManager)
                    .environmentObject(localizationManager)
                    .preferredColorScheme(themeManager.currentTheme.colorScheme)
                    .localized()

                if showSplash {
                    SplashOverlayView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeOut(duration: 0.45)) {
                        showSplash = false
                    }
                }
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

private struct SplashOverlayView: View {
    var body: some View {
        ZStack {
            Color.nordicBone.ignoresSafeArea()
            VStack(spacing: 12) {
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundColor(.momentumAmber)
                Text("Norrish")
                    .font(AppFonts.serif(22, weight: .bold))
                    .foregroundColor(.midnightSpruce)
                Text("Personalized nutrition insights")
                    .font(AppFonts.sans(12, weight: .regular))
                    .foregroundColor(.nordicSlate)
            }
        }
    }
}
