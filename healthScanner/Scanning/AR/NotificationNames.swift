// NotificationNames.swift
// Centralized names for app-wide notifications

import Foundation
import OSLog

extension Notification.Name {
    // Posted when a plate scan completes. userInfo: ["result": ARPlateScanNutrition, "image": UIImage]
    static let plateScanCompleted = Notification.Name("PlateScanCompleted")
    
    // Posted when a barcode scan completes. userInfo: ["upc": String, "title": String?, "store": String?]
    static let barcodeScanCompleted = Notification.Name("BarcodeScanCompleted")
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
