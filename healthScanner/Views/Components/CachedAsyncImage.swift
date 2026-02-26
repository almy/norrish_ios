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
            AppLog.debug(AppLog.storage, "CachedAsyncImage appeared: key=\(cacheKey)")
            loadImage()
        }
    }
    
    private func loadImage() {
        AppLog.debug(AppLog.storage, "CachedAsyncImage load start: key=\(cacheKey)")
        // First try loading from cache
        if let cachedImage = ImageCacheService.shared.loadImage(forKey: cacheKey) {
            AppLog.debug(AppLog.storage, "CachedAsyncImage cache hit: key=\(cacheKey)")
            self.image = cachedImage
            self.isLoading = false
            return
        }
        
        AppLog.debug(AppLog.storage, "CachedAsyncImage cache miss: key=\(cacheKey)")
        // If not in cache, download and cache
        Task {
            AppLog.debug(AppLog.storage, "CachedAsyncImage download started: key=\(cacheKey)")
            isLoading = true
            if let downloadedImage = await ImageCacheService.shared.downloadAndCacheImage(from: urlString, forKey: cacheKey) {
                await MainActor.run {
                    AppLog.debug(AppLog.storage, "CachedAsyncImage download success: key=\(cacheKey)")
                    self.image = downloadedImage
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    AppLog.error(AppLog.storage, "CachedAsyncImage download failed: key=\(cacheKey)")
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
