import Foundation
import SwiftData

@Model
final class ScanEventEntity {
    @Attribute(.unique) var id: UUID
    var date: Date
    var barcode: String?
    var productName: String?
    
    init(id: UUID = UUID(), date: Date = Date(), barcode: String? = nil, productName: String? = nil) {
        self.id = id
        self.date = date
        self.barcode = barcode
        self.productName = productName
    }
    
    // TODO: Expand model with additional properties and relationships as needed
}
