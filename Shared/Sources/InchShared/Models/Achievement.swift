import Foundation
import SwiftData

@Model
public final class Achievement {
    public var id: String = ""
    public var category: String = ""
    public var unlockedAt: Date = Date.now
    public var exerciseId: String? = nil
    public var numericValue: Int? = nil
    public var wasCelebrated: Bool = false
    public var sessionDate: Date? = nil

    public init(
        id: String,
        category: String,
        unlockedAt: Date = .now,
        exerciseId: String? = nil,
        numericValue: Int? = nil,
        sessionDate: Date? = nil
    ) {
        self.id = id
        self.category = category
        self.unlockedAt = unlockedAt
        self.exerciseId = exerciseId
        self.numericValue = numericValue
        self.wasCelebrated = false
        self.sessionDate = sessionDate
    }
}
