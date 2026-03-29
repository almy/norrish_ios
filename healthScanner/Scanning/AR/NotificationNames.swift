// NotificationNames.swift
// Centralized names for app-wide notifications

import Foundation
import OSLog

extension Notification.Name {
    // AR scanning
    static let plateScanCompleted = Notification.Name("PlateScanCompleted")
    static let barcodeScanCompleted = Notification.Name("BarcodeScanCompleted")

    // Plate scan flow
    static let closePlateScanFlow = Notification.Name("closePlateScanFlow")
    static let retakePlateScanFlow = Notification.Name("retakePlateScanFlow")

    // Camera
    static let enhancedCapturePhoto = Notification.Name("enhancedCapturePhoto")
    static let liveFoodDetectionUpdate = Notification.Name("liveFoodDetectionUpdate")

    // Onboarding
    static let onboardingOpenPlatePhoto = Notification.Name("onboardingOpenPlatePhoto")
    static let onboardingOpenProductScan = Notification.Name("onboardingOpenProductScan")

    // Localization
    static let languageChanged = Notification.Name("languageChanged")
}

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "healthScanner"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let scanner = Logger(subsystem: subsystem, category: "scanner")
    static let vision = Logger(subsystem: subsystem, category: "vision")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let storage = Logger(subsystem: subsystem, category: "storage")

    static func debug(_ logger: Logger, _ message: String) {
        #if DEBUG
        logger.debug("\(message, privacy: .public)")
        #endif
    }

    static func error(_ logger: Logger, _ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
