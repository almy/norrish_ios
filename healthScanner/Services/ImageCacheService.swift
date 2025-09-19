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
        guard isValid else {
            print("⚠️ Invalid UIImage - cannot convert to JPEG")
            return nil
        }

        return self.jpegData(compressionQuality: compressionQuality)
    }
}

class ImageCacheService: ObservableObject {
    static let shared = ImageCacheService()
    
    private let fileManager = FileManager.default
    private var cacheDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cacheDir = documentsPath.appendingPathComponent("ImageCache")
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDir.path) {
            do {
                try fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
                print("📁 ImageCacheService: Created cache directory at: \(cacheDir.path)")
            } catch {
                print("❌ ImageCacheService: Failed to create cache directory: \(error)")
            }
        }
        
        return cacheDir
    }
    
    private init() {
        print("🎯 ImageCacheService: Singleton initialized")
        print("📁 ImageCacheService: Cache directory: \(cacheDirectory.path)")
        setupMemoryWarningHandler()
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
        print("🧠 Memory warning - clearing image cache")
        clearOldCacheFiles()
    }

    private func clearOldCacheFiles() {
        let cacheDir = cacheDirectory
        do {
            let files = try fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: [.creationDateKey])
            let sortedFiles = files.sorted { file1, file2 in
                let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                return date1 < date2
            }

            // Keep only the 10 most recent files
            let filesToDelete = Array(sortedFiles.dropLast(10))
            for file in filesToDelete {
                try? fileManager.removeItem(at: file)
                print("🗑️ Deleted old cache file: \(file.lastPathComponent)")
            }
        } catch {
            print("❌ Failed to clean cache directory: \(error)")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // Save image to local cache
    func saveImage(_ image: UIImage, forKey key: String) {
        print("💾 ImageCacheService: Attempting to save image for key: \(key)")

        // Validate image first
        guard image.isValid else {
            print("❌ ImageCacheService: Invalid UIImage (no CGImage or invalid dimensions) for key: \(key)")
            return
        }

        guard let imageData = image.safeJPEGData() else {
            print("❌ ImageCacheService: Failed to convert image to JPEG data for key: \(key)")
            return
        }
        let filename = sanitizeFilename(key) + ".jpg"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        do {
            try imageData.write(to: fileURL)
            print("✅ ImageCacheService: Successfully saved image to: \(fileURL.path)")
            print("📊 ImageCacheService: Image size: \(imageData.count) bytes")
        } catch {
            print("❌ ImageCacheService: Failed to save image: \(error)")
        }
    }
    
    // Load image from local cache
    func loadImage(forKey key: String) -> UIImage? {
        print("🔍 ImageCacheService: Attempting to load cached image for key: \(key)")
        let filename = sanitizeFilename(key) + ".jpg"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        
        print("📂 ImageCacheService: Looking for file at: \(fileURL.path)")
        
        guard let imageData = try? Data(contentsOf: fileURL) else {
            print("❌ ImageCacheService: No cached image found for key: \(key)")
            return nil
        }
        
        guard let image = UIImage(data: imageData) else {
            print("❌ ImageCacheService: Failed to create UIImage from cached data for key: \(key)")
            return nil
        }
        
        print("✅ ImageCacheService: Successfully loaded cached image for key: \(key)")
        print("📊 ImageCacheService: Loaded image size: \(imageData.count) bytes, dimensions: \(image.size)")
        return image
    }
    
    // Check if image exists in cache
    func imageExists(forKey key: String) -> Bool {
        let filename = sanitizeFilename(key) + ".jpg"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        let exists = fileManager.fileExists(atPath: fileURL.path)
        print("🔍 ImageCacheService: Image exists check for key '\(key)': \(exists ? "YES" : "NO")")
        return exists
    }
    
    // Download and cache image from URL
    func downloadAndCacheImage(from urlString: String, forKey key: String) async -> UIImage? {
        print("🌐 ImageCacheService: Starting download for URL: \(urlString), key: \(key)")
        
        // Check if image already exists in cache
        if let cachedImage = loadImage(forKey: key) {
            print("♻️ ImageCacheService: Found existing cached image for key: \(key)")
            return cachedImage
        }
        
        print("📥 ImageCacheService: No cached image found, downloading from: \(urlString)")
        
        // Download image from URL
        guard let url = URL(string: urlString) else {
            print("❌ ImageCacheService: Invalid URL: \(urlString)")
            return nil
        }
        
        do {
            print("🌐 ImageCacheService: Making network request...")
            let (data, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 ImageCacheService: HTTP response status: \(httpResponse.statusCode)")
                print("📊 ImageCacheService: Downloaded data size: \(data.count) bytes")
            }
            
            guard let image = UIImage(data: data) else {
                print("❌ ImageCacheService: Failed to create UIImage from downloaded data")
                return nil
            }
            
            print("✅ ImageCacheService: Successfully created UIImage from downloaded data")
            print("📊 ImageCacheService: Image dimensions: \(image.size)")
            
            // Save to cache
            saveImage(image, forKey: key)
            
            return image
        } catch {
            print("❌ ImageCacheService: Download failed with error: \(error)")
            return nil
        }
    }
    
    // Clean up old cached images (optional)
    func clearCache() {
        print("🗑️ ImageCacheService: Clearing entire cache...")
        do {
            try fileManager.removeItem(at: cacheDirectory)
            print("✅ ImageCacheService: Cache cleared successfully")
        } catch {
            print("❌ ImageCacheService: Failed to clear cache: \(error)")
        }
    }
    
    // Expose cached file path if present
    func cachedFilePath(forKey key: String) -> String? {
        let filename = sanitizeFilename(key) + ".jpg"
        let fileURL = cacheDirectory.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: fileURL.path) ? fileURL.path : nil
    }
    
    private func sanitizeFilename(_ filename: String) -> String {
        let sanitized = filename.replacingOccurrences(of: "[^a-zA-Z0-9]", with: "_", options: .regularExpression)
        print("🔧 ImageCacheService: Sanitized filename '\(filename)' to '\(sanitized)'")
        return sanitized
    }
}
