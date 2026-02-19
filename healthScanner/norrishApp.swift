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
    @StateObject private var startupPrewarm = StartupPrewarmCoordinator()
    @State private var showSplash = true
    @State private var startupConfigError: String?

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
                    SplashOverlayView(progress: startupPrewarm.progress)
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .onAppear {
                if startupConfigError == nil {
                    startupConfigError = AppConfig.startupValidationError()
                }
                startupPrewarm.startIfNeeded()
            }
            .onChange(of: startupPrewarm.shouldDismissSplash) { _, shouldDismiss in
                guard shouldDismiss, showSplash else { return }
                withAnimation(.easeOut(duration: 0.45)) {
                    showSplash = false
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
    let progress: Double
    @State private var morph: CGFloat = 0
    @State private var orbit = false
    @State private var pulse = false
    @State private var loadingSweep = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.nordicBone, Color.nordicBone.opacity(0.98), Color.cardSurface.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                ZStack {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 1.4, dash: [4, 7]))
                        .foregroundColor(.nordicSlate.opacity(0.35))
                        .frame(width: 104, height: 104)
                        .rotationEffect(.degrees(orbit ? 360 : 0))
                        .opacity(Double(morph))
                        .scaleEffect(0.92 + 0.08 * morph)

                    layeredMark
                        .scaleEffect(pulse ? 1.02 : 0.98)
                }
                .frame(height: 124)

                Text("Norrish")
                    .font(AppFonts.serif(24, weight: .bold))
                    .foregroundColor(.midnightSpruce)
                    .padding(.top, 18)

                Text("Personalized nutrition insights")
                    .font(AppFonts.sans(12, weight: .regular))
                    .foregroundColor(.nordicSlate)
                    .opacity(0.92)
                    .padding(.top, 6)

                Spacer()

                VStack(spacing: 9) {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.midnightSpruce.opacity(0.10))
                            .frame(width: 190, height: 2)
                        Capsule()
                            .fill(Color.midnightSpruce.opacity(0.75))
                            .frame(width: 62, height: 2)
                            .offset(x: loadingSweep ? 128 : 0)
                        Capsule()
                            .fill(Color.midnightSpruce.opacity(0.40))
                            .frame(width: 190 * progress.clamped(to: 0...1), height: 2)
                    }

                    Text(progress >= 0.999 ? "READY" : "Small choices. Big momentum.")
                        .font(AppFonts.sans(9, weight: .semibold))
                        .foregroundColor(.midnightSpruce.opacity(0.42))
                        .kerning(2.1)
                }
                .padding(.bottom, 80)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.65)) {
                morph = 1
            }
            withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                orbit = true
            }
            withAnimation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                loadingSweep = true
            }
        }
    }

    private var layeredMark: some View {
        VStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(Color.midnightSpruce.opacity(0.30))
                .frame(width: 52 + 4 * morph, height: 6)
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(Color.midnightSpruce.opacity(0.60))
                .frame(width: 66 + 6 * morph, height: 6)
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(Color.midnightSpruce.opacity(1.00))
                .frame(width: 44 + 2 * morph, height: 6)
            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(Color.midnightSpruce.opacity(0.40))
                .frame(width: 58 + 5 * morph, height: 6)
        }
        .frame(width: 92, height: 92)
        .background(
            Circle()
                .stroke(Color.midnightSpruce.opacity(0.10), lineWidth: 1)
                .scaleEffect(1.08)
        )
    }
}

@MainActor
private final class StartupPrewarmCoordinator: ObservableObject {
    @Published private(set) var progress: Double = 0
    @Published private(set) var shouldDismissSplash = false

    private let totalTasks = 3
    private let splashDuration: TimeInterval = 5.062
    private var completedTasks = 0
    private var started = false
    private var launchDate: Date?
    private var timeoutTask: Task<Void, Never>?

    func startIfNeeded() {
        guard !started else { return }
        started = true
        launchDate = Date()

        // Safety timeout: never block startup indefinitely on model load failures.
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_062_000_000)
            await self?.finishIfNeeded(force: true)
        }

        DualCameraPlateScannerViewController.prewarmModels { [weak self] _ in
            Task { @MainActor in self?.markTaskFinished() }
        }
        YOLOModelProvider.getModel { [weak self] _ in
            Task { @MainActor in self?.markTaskFinished() }
        }
        ImagePreprocessor.prewarmSegmentationModel { [weak self] _ in
            Task { @MainActor in self?.markTaskFinished() }
        }
    }

    private func markTaskFinished() {
        guard completedTasks < totalTasks else { return }
        completedTasks += 1
        progress = Double(completedTasks) / Double(totalTasks)

        if completedTasks == totalTasks {
            finishIfNeeded(force: false)
        }
    }

    private func finishIfNeeded(force: Bool) {
        guard !shouldDismissSplash else { return }
        let minimumDisplay: TimeInterval = splashDuration
        let elapsed = Date().timeIntervalSince(launchDate ?? Date())

        if !force && elapsed < minimumDisplay {
            let waitNs = UInt64((minimumDisplay - elapsed) * 1_000_000_000)
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: waitNs)
                self?.finalizeDismissal()
            }
            return
        }

        finalizeDismissal()
    }

    private func finalizeDismissal() {
        timeoutTask?.cancel()
        timeoutTask = nil
        progress = 1
        shouldDismissSplash = true
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
