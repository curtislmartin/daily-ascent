import Foundation
import SwiftData

@Model
public final class UserEntitlement {
    public var productId: String = ""
    public var purchaseDate: Date = Date.now
    public var expiresDate: Date? = nil
    public var transactionId: String = ""

    public init(productId: String = "", purchaseDate: Date = Date.now, expiresDate: Date? = nil, transactionId: String = "") {
        self.productId = productId
        self.purchaseDate = purchaseDate
        self.expiresDate = expiresDate
        self.transactionId = transactionId
    }
}
