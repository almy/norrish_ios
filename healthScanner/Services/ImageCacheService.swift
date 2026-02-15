//
//  ImageCacheService.swift
//  norrish
//
//  Created by myftiu on 06/09/25.
//

import Foundation
import UIKit

// MARK: - UIImage Safety Extensions
extension UIImage {
    var isValid: Bool {
        guard let cgImage = self.cgImage else { return false }
        return cgImage.width > 0 && cgImage.height > 0
    }

    func safeJPEGData(compressionQuality: CGFloat = 0.8) -> Data? {
        guard isValid else { return nil }

        return self.jpegData(compressionQuality: compressionQuality)
    }
}

class ImageCacheService: ObservableObject {
    static let shared = ImageCacheService()
    private let shouldLogVerbose = ProcessInfo.processInfo.environment["IMAGE_CACHE_DEBUG"] == "1"
    private let maxCacheImageDimension: CGFloat = 1280
    private let cacheJPEGQuality: CGFloat = 0.75
    private let maxCacheSizeBytes = 100_000_000 // 100 MB
    private let maxCacheFileCount = 500
    
    private let fileManager = FileManager.default
    private var cacheDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDir = documentsPath.appendingPathComponent("ImageCache")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDir.path) {
            do {
                try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
                log("📁 ImageCacheService: Created cache directory at: \(cacheDir.path)")
            } catch {
                log("❌ ImageCacheService: Failed to create cache directory: \(error)")
            }
        }
        
        return cacheDir
    }
    
    private init() {
        log("🎯 ImageCacheService: Singleton initialized")
        log("📁 ImageCacheService: Cache directory: \(cacheDirectory.path)")
        setupMemoryWarningHandler()
        enforceQuota()
    }

    private func setupMemoryWarningHandler() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }

    @objc private func handleMemoryWarning() {
        log("🧠 Memory warning - clearing image cache")
        clearOldCacheFiles()
    }

    private func clearOldCacheFiles() {
        enforceQuota(targetSizeBytes: maxCacheSizeBytes / 2, targetFileCount: max(50, maxCacheFileCount / 2))
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // Save image to local cache
    func saveImage(_ image: UIImage, forKey key: String) {
        log("💾 ImageCacheService: Attempting to save image for key: \(key)")

        // Validate image first
        guard image.isValid else {
            log("❌ ImageCacheService: Invalid UIImage (no CGImage or invalid dimensions) for key: \(key)")
            return
        }

        let preparedImage = downscaledImageIfNeeded(image, maxDimension: maxCacheImageDimension)
        guard let imageData = preparedImage.safeJPEGData(compressionQuality: cacheJPEGQuality) else {
            log("❌ ImageCacheService: Failed to convert image to JPEG data for key: \(key)")
            return
        }
        let filename = sanitizeFilename(key) + ".jpg"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        do {
            try imageData.write(to: fileURL, options: .atomic)
            log("✅ ImageCacheService: Successfully saved image to: \(fileURL.path)")
            log("📊 ImageCacheService: Image size: \(imageData.count) bytes, dimensions: \(preparedImage.size)")
            touchAccessDate(for: fileURL)
            enforceQuota()
        } catch {
            log("❌ ImageCacheService: Failed to save image: \(error)")
        }
    }
    
    // Load image from local cache
    func loadImage(forKey key: String) -> UIImage? {
        log("🔍 ImageCacheService: Attempting to load cached image for key: \(key)")
        let filename = sanitizeFilename(key) + ".jpg"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        log("📂 ImageCacheService: Looking for file at: \(fileURL.path)")
        
        guard let imageData = try? Data(contentsOf: fileURL) else {
            log("❌ ImageCacheService: No cached image found for key: \(key)")
            return nil
        }
        
        guard let image = UIImage(data: imageData) else {
            log("❌ ImageCacheService: Failed to create UIImage from cached data for key: \(key)")
            return nil
        }
        touchAccessDate(for: fileURL)

        log("✅ ImageCacheService: Successfully loaded cached image for key: \(key)")
        log("📊 ImageCacheService: Loaded image size: \(imageData.count) bytes, dimensions: \(image.size)")
        return image
    }
    
    // Check if image exists in cache
    func imageExists(forKey key: String) -> Bool {
        let filename = sanitizeFilename(key) + ".jpg"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        let exists = fileManager.fileExists(atPath: fileURL.path)
        log("🔍 ImageCacheService: Image exists check for key '\(key)': \(exists ? "YES" : "NO")")
        return exists
    }
    
    // Download and cache image from URL
    func downloadAndCacheImage(from urlString: String, forKey key: String) async -> UIImage? {
        log("🌐 ImageCacheService: Starting download for URL: \(urlString), key: \(key)")
        
        // Check if image already exists in cache
        if let cachedImage = loadImage(forKey: key) {
            log("♻️ ImageCacheService: Found existing cached image for key: \(key)")
            return cachedImage
        }
        
        log("📥 ImageCacheService: No cached image found, downloading from: \(urlString)")
        
        // Download image from URL
        guard let url = URL(string: urlString) else {
            log("❌ ImageCacheService: Invalid URL: \(urlString)")
            return nil
        }
        
        do {
            log("🌐 ImageCacheService: Making network request...")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                log("📡 ImageCacheService: HTTP response status: \(httpResponse.statusCode)")
                log("📊 ImageCacheService: Downloaded data size: \(data.count) bytes")
            }
            
            guard let image = UIImage(data: data) else {
                log("❌ ImageCacheService: Failed to create UIImage from downloaded data")
                return nil
            }
            
            log("✅ ImageCacheService: Successfully created UIImage from downloaded data")
            log("📊 ImageCacheService: Image dimensions: \(image.size)")
            
            // Save to cache
            saveImage(image, forKey: key)
            
            return image
        } catch {
            log("❌ ImageCacheService: Download failed with error: \(error)")
            return nil
        }
    }
    
    // Clean up old cached images (optional)
    func clearCache() {
        log("🗑️ ImageCacheService: Clearing entire cache...")
        do {
            try fileManager.removeItem(at: cacheDirectory)
            log("✅ ImageCacheService: Cache cleared successfully")
        } catch {
            log("❌ ImageCacheService: Failed to clear cache: \(error)")
        }
    }
    
    // Expose cached file path if present
    func cachedFilePath(forKey key: String) -> String? {
        let filename = sanitizeFilename(key) + ".jpg"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: fileURL.path) ? fileURL.path : nil
    }

    // Delete cached image if present
    func deleteImage(forKey key: String) {
        let filename = sanitizeFilename(key) + ".jpg"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        try? fileManager.removeItem(at: fileURL)
    }
    
    private func sanitizeFilename(_ filename: String) -> String {
        let sanitized = filename.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
        log("🔧 ImageCacheService: Sanitized filename '\(filename)' to '\(sanitized)'")
        return sanitized
    }

    private func downscaledImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension, maxDimension > 0 else { return image }

        let scale = maxDimension / longestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private struct CacheFileEntry {
        let url: URL
        let sizeBytes: Int
        let lastAccessDate: Date
    }

    private func enforceQuota(targetSizeBytes: Int? = nil, targetFileCount: Int? = nil) {
        let targetSize = targetSizeBytes ?? maxCacheSizeBytes
        let targetCount = targetFileCount ?? maxCacheFileCount
        let resourceKeys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .fileSizeKey,
            .contentAccessDateKey,
            .contentModificationDateKey,
            .creationDateKey
        ]

        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: cacheDirectory,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsHiddenFiles]
            )

            var entries: [CacheFileEntry] = []
            entries.reserveCapacity(fileURLs.count)

            for fileURL in fileURLs {
                let values = try fileURL.resourceValues(forKeys: resourceKeys)
                guard values.isRegularFile == true else { continue }
                let size = values.fileSize ?? 0
                let lastAccess = values.contentAccessDate ?? values.contentModificationDate ?? values.creationDate ?? Date.distantPast
                entries.append(CacheFileEntry(url: fileURL, sizeBytes: size, lastAccessDate: lastAccess))
            }

            var currentSize = entries.reduce(0) { $0 + $1.sizeBytes }
            if currentSize <= targetSize && entries.count <= targetCount {
                return
            }

            // Most recently used first, eviction from the tail (least recently used).
            entries.sort { $0.lastAccessDate > $1.lastAccessDate }

            while currentSize > targetSize || entries.count > targetCount {
                guard let victim = entries.popLast() else { break }
                do {
                    try fileManager.removeItem(at: victim.url)
                    currentSize -= victim.sizeBytes
                    log("🗑️ Evicted cached image: \(victim.url.lastPathComponent)")
                } catch {
                    log("❌ Failed to evict cached image \(victim.url.lastPathComponent): \(error)")
                }
            }
        } catch {
            log("❌ Failed enforcing image cache quota: \(error)")
        }
    }

    private func touchAccessDate(for fileURL: URL) {
        var values = URLResourceValues()
        values.contentAccessDate = Date()
        do {
            var mutableFileURL = fileURL
            try mutableFileURL.setResourceValues(values)
        } catch {
            log("❌ Failed to update access date for \(fileURL.lastPathComponent): \(error)")
        }
    }

    private func log(_ message: @autoclosure () -> String) {
        guard shouldLogVerbose else { return }
        AppLog.debug(AppLog.storage, message())
    }
}
