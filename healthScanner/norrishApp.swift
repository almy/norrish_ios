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

                    SplashOverlayView()
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

private struct LaunchStaticBackgroundView: View {
    var body: some View {
        LaunchStoryboardReplicaView()
            .ignoresSafeArea()
    }
}

private struct LaunchStoryboardReplicaView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = .clear

        if let vc = UIStoryboard(name: "LaunchScreenFresh", bundle: nil).instantiateInitialViewController() {
            let launchView = vc.view ?? UIView()
            launchView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(launchView)

            NSLayoutConstraint.activate([
                launchView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                launchView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                launchView.topAnchor.constraint(equalTo: container.topAnchor),
                launchView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
        } else {
            // Keep a sane fallback if the storyboard can't be instantiated.
            container.backgroundColor = UIColor(red: 0.976, green: 0.969, blue: 0.949, alpha: 1.0)
        }

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private struct SplashOverlayView: View {
    @State private var activeBarIndex = 2
    @State private var overlayOpacity: Double = 0

    var body: some View {
        GeometryReader { geometry in
            let canvas = geometry.size
            let designSize = CGSize(width: 393, height: 852)
            let scale = max(canvas.width / designSize.width, canvas.height / designSize.height)
            let fittedSize = CGSize(width: designSize.width * scale, height: designSize.height * scale)
            let origin = CGPoint(x: (canvas.width - fittedSize.width) / 2, y: (canvas.height - fittedSize.height) / 2)

            ZStack(alignment: .topLeading) {
                animatedBarsOverlay
                    .scaleEffect(scale, anchor: .topLeading)
                    .offset(x: origin.x, y: origin.y)
            }
            .frame(width: canvas.width, height: canvas.height)
            .ignoresSafeArea()
        }
        .opacity(overlayOpacity)
        .onAppear {
            withAnimation(.easeOut(duration: 0.18)) {
                overlayOpacity = 1
            }
        }
        .task {
            while !Task.isCancelled {
                activeBarIndex = (activeBarIndex + 1) % 4
                try? await Task.sleep(nanoseconds: 320_000_000)
            }
        }
    }

    private var animatedBarsOverlay: some View {
        ZStack(alignment: .topLeading) {
            Color.clear.frame(width: 393, height: 852)

            VStack(spacing: 8) {
                animatedBar(width: 48, alpha: 0.30, isActive: activeBarIndex == 0)
                animatedBar(width: 64, alpha: 0.60, isActive: activeBarIndex == 1)
                animatedBar(width: 40, alpha: 1.00, isActive: activeBarIndex == 2)
                animatedBar(width: 56, alpha: 0.40, isActive: activeBarIndex == 3)
            }
            .frame(width: 64, height: 48)
            .offset(x: 164, y: 340.6667)
        }
    }

    private func animatedBar(width: CGFloat, alpha: Double, isActive: Bool) -> some View {
        Rectangle()
            .fill(Color.midnightSpruce.opacity(isActive ? min(alpha + 0.22, 1.0) : alpha))
            .frame(width: width, height: 6)
            .animation(.easeInOut(duration: 0.18), value: isActive)
    }
}
