import Foundation
import SwiftData

@Model
final class UserEntitlement {
    var productId: String = ""
    var purchaseDate: Date = Date.now
    var expiresDate: Date? = nil
    var transactionId: String = ""

    init(productId: String = "", purchaseDate: Date = Date.now, expiresDate: Date? = nil, transactionId: String = "") {
        self.productId = productId
        self.purchaseDate = purchaseDate
        self.expiresDate = expiresDate
        self.transactionId = transactionId
    }
}
