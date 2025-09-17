import Foundation

struct RecentScan: Identifiable {
    let id: UUID
    let barcode: String
    let productName: String
    let scanDate: Date
    let nutriScoreLetter: NutriScoreLetter
    let imageURL: String?
}

