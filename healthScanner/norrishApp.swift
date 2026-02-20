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

enum NorrishSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 1, 0) }

    static var models: [any PersistentModel.Type] {
        [
            Product.self,
            PlateAnalysisHistory.self,
            PlateIngredientEntity.self,
            PlateInsightEntity.self,
            Item.self,
            DailyNutritionAggregateEntity.self,
            ScanEventEntity.self
        ]
    }
}

enum NorrishMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [NorrishSchemaV2.self] }
    static var stages: [MigrationStage] { [] }
}

@main
struct norrishApp: App {
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var profileIdentity = ProfileIdentityStore.shared
    @StateObject private var preferencesManager = DietaryPreferencesManager.shared
    @AppStorage("onboarding.completed") private var onboardingCompleted = false
    @State private var showSplash = true
    @State private var startupConfigError: String?

    init() {
        // Kick off Core ML model prewarm at app launch (guaranteed entry point)
        DualCameraPlateScannerViewController.prewarmModels()
        YOLOModelProvider.preload()
        ImagePreprocessor.prewarmSegmentationModel()
    }

    var sharedModelContainer: ModelContainer = {
        do {
            // Explicitly list models to build the container schema
            return try ModelContainer(
                for: Product.self,
                PlateAnalysisHistory.self,
                PlateIngredientEntity.self,
                PlateInsightEntity.self,
                Item.self,
                DailyNutritionAggregateEntity.self,
                ScanEventEntity.self,
                migrationPlan: NorrishMigrationPlan.self
            )
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

                if !showSplash && !onboardingCompleted {
                    FirstTimeOnboardingView(onComplete: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            onboardingCompleted = true
                        }
                    })
                    .environmentObject(profileIdentity)
                    .environmentObject(preferencesManager)
                    .transition(.opacity)
                    .zIndex(2)
                }
            }
            .onAppear {
                if startupConfigError == nil {
                    startupConfigError = AppConfig.startupValidationError()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeOut(duration: 0.45)) {
                        showSplash = false
                    }
                }
            }
            .alert("Configuration Error", isPresented: Binding(
                get: { startupConfigError != nil },
                set: { if !$0 { startupConfigError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(startupConfigError ?? "Missing API configuration.")
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
