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

enum HomeScreenQuickAction: String {
    case analyzePlate = "com.myftiu.ios.norrish.quickaction.analyze_plate"
    case scanProduct = "com.myftiu.ios.norrish.quickaction.scan_product"
}

@MainActor
final class HomeScreenQuickActionState: ObservableObject {
    static let shared = HomeScreenQuickActionState()

    @Published private(set) var pendingAction: HomeScreenQuickAction?

    @discardableResult
    func enqueue(shortcutType: String) -> Bool {
        guard let action = HomeScreenQuickAction(rawValue: shortcutType) else { return false }
        pendingAction = action
        return true
    }

    func consumePendingAction() -> HomeScreenQuickAction? {
        defer { pendingAction = nil }
        return pendingAction
    }
}

final class NorrishAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            Task { @MainActor in
                _ = HomeScreenQuickActionState.shared.enqueue(shortcutType: shortcutItem.type)
            }
        }

        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            let handled = HomeScreenQuickActionState.shared.enqueue(shortcutType: shortcutItem.type)
            completionHandler(handled)
        }
    }
}

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
    @UIApplicationDelegateAdaptor(NorrishAppDelegate.self) private var appDelegate
    @StateObject private var themeManager = ThemeManager.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @StateObject private var profileIdentity = ProfileIdentityStore.shared
    @StateObject private var preferencesManager = DietaryPreferencesManager.shared
    @StateObject private var quickActionState = HomeScreenQuickActionState.shared
    @AppStorage("onboarding.completed") private var onboardingCompleted = false
    @State private var showSplash = true
    @State private var splashStartTime = Date()
    @State private var startupConfigError: String?
    private let splashMinimumDuration: TimeInterval = 5.062
    private let screenshotMode = ProcessInfo.processInfo.environment["NORRISH_SCREENSHOT_MODE"] == "1"

    init() {
        // Kick off Core ML model prewarm at app launch (guaranteed entry point)
        DualCameraPlateScannerViewController.prewarmModels()
        YOLOModelProvider.preload()
        ImagePreprocessor.prewarmSegmentationModel()
    }

    var sharedModelContainer: ModelContainer = {
        do {
            // Ensure CoreData/SwiftData parent directory exists on first launch
            // before SQLite store creation is attempted.
            if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true)
            }

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
                Color.white.ignoresSafeArea()

                if !showSplash {
                    ContentView()
                        .environmentObject(themeManager)
                        .environmentObject(localizationManager)
                        .environmentObject(quickActionState)
                        .preferredColorScheme(themeManager.currentTheme.colorScheme)
                        .localized()
                        .transition(.opacity)
                }

                if showSplash {
                    LaunchStaticBackgroundView()
                        .zIndex(1)
                        .transition(.opacity)

                    SplashOverlayView(startTime: splashStartTime, duration: splashMinimumDuration)
                        .zIndex(2)
                        .transition(.opacity)
                }

                if !showSplash && !onboardingCompleted {
                    FirstTimeOnboardingView(onComplete: {
                        withAnimation(.easeOut(duration: 0.3)) {
                            onboardingCompleted = true
                        }
                    }, onSnapMeal: {
                        NotificationCenter.default.post(name: .onboardingOpenPlatePhoto, object: nil)
                    }, onScanProduct: {
                        NotificationCenter.default.post(name: .onboardingOpenProductScan, object: nil)
                    })
                    .environmentObject(profileIdentity)
                    .environmentObject(preferencesManager)
                    .zIndex(3)
                }
            }
            .onAppear {
                if screenshotMode {
                    onboardingCompleted = true
                    showSplash = false
                    return
                }
                if startupConfigError == nil {
                    startupConfigError = AppConfig.startupValidationError()
                }
                splashStartTime = Date()
                DispatchQueue.main.asyncAfter(deadline: .now() + splashMinimumDuration) {
                    withAnimation(.easeInOut(duration: 0.28)) {
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
