import SwiftUI
import UIKit

// MARK: - CachedAsyncImage Component
struct CachedAsyncImage: View {
    let urlString: String
    let cacheKey: String
    
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if isLoading {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.nordicBone.opacity(0.8))
                    .overlay(
                        AppInlineSpinner(size: 22)
                    )
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.nordicBone.opacity(0.8))
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 30))
                                .foregroundColor(.momentumAmber)
                            Text("Image not available")
                                .font(AppFonts.sans(11, weight: .regular))
                                .foregroundColor(.nordicSlate)
                        }
                    )
            }
        }
        .onAppear {
            #if DEBUG
            print("🎬 CachedAsyncImage: View appeared for key: \(cacheKey), URL: \(urlString)")
            #endif
            loadImage()
        }
    }
    
    private func loadImage() {
        #if DEBUG
        print("🔄 CachedAsyncImage: Starting loadImage() for key: \(cacheKey)")
        #endif
        // First try loading from cache
        if let cachedImage = ImageCacheService.shared.loadImage(forKey: cacheKey) {
            #if DEBUG
            print("✅ CachedAsyncImage: Found cached image, setting state")
            #endif
            self.image = cachedImage
            self.isLoading = false
            return
        }
        
        #if DEBUG
        print("📥 CachedAsyncImage: No cached image found, starting download task")
        #endif
        // If not in cache, download and cache
        Task {
            #if DEBUG
            print("🚀 CachedAsyncImage: Background task started for download")
            #endif
            isLoading = true
            if let downloadedImage = await ImageCacheService.shared.downloadAndCacheImage(from: urlString, forKey: cacheKey) {
                await MainActor.run {
                    #if DEBUG
                    print("✅ CachedAsyncImage: Download successful, updating UI")
                    #endif
                    self.image = downloadedImage
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    #if DEBUG
                    print("❌ CachedAsyncImage: Download failed, showing error state")
                    #endif
                    self.isLoading = false
                }
            }
        }
    }
}

// Preview-only: uses a non-resolving URL to exercise loading/error placeholder states.
#Preview("Cached Async Image") {
    CachedAsyncImage(
        urlString: "https://example.invalid/image.jpg",
        cacheKey: "preview-cache-key"
    )
    .frame(width: 180, height: 180)
    .padding()
    .background(Color.nordicBone)
}
