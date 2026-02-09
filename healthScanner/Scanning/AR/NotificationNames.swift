// NotificationNames.swift
// Centralized names for app-wide notifications

import Foundation

extension Notification.Name {
    // Posted when a plate scan completes. userInfo: ["result": ARPlateScanNutrition, "image": UIImage]
    static let plateScanCompleted = Notification.Name("PlateScanCompleted")
    
    // Posted when a barcode scan completes. userInfo: ["upc": String, "title": String?, "store": String?]
    static let barcodeScanCompleted = Notification.Name("BarcodeScanCompleted")
}
