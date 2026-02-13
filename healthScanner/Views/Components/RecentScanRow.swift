import SwiftUI

struct RecentScanRow: View {
    let scan: RecentScan
    let products: [Product]
    var onProductSelected: (Product) -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Product Image (cached)
            Group {
                if let url = scan.imageURL, !url.isEmpty {
                    CachedAsyncImage(urlString: url, cacheKey: scan.barcode)
                        .aspectRatio(contentMode: .fill)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.momentumAmber.opacity(0.15))
                        .overlay(
                            Image(systemName: "cart.fill")
                                .font(.title3)
                                .foregroundColor(.momentumAmber)
                        )
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Product Info
            VStack(alignment: .leading, spacing: 4) {
                Text(scan.productName)
                    .font(AppFonts.serif(16, weight: .semibold))
                    .foregroundColor(.midnightSpruce)
                Text(dateFormatter.string(from: scan.scanDate))
                    .font(AppFonts.sans(12, weight: .regular))
                    .foregroundColor(.nordicSlate)
            }
            Spacer()
            NutriScoreBadge(letter: scan.nutriScoreLetter, compact: true)
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundColor(.nordicSlate.opacity(0.7))
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if let product = products.first(where: { $0.barcode == scan.barcode }) {
                onProductSelected(product)
            } else {
                print("[RecentScanRow] Product not found for barcode=\(scan.barcode) name=\(scan.productName)")
            }
        }
    }
}
