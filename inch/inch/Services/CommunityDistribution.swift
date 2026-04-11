import Foundation

nonisolated struct CommunityDistribution: Codable, Sendable {
    let exerciseId: String
    let level: Int
    let metricType: String
    let breakpoints: [Int: Int]  // percentile (5,10,...,95) -> threshold value
    let totalUsers: Int

    /// Linearly interpolates the user's percentile from the stored breakpoints.
    func percentile(for value: Int) -> Int {
        let sorted = breakpoints.sorted { $0.key < $1.key }
        guard let first = sorted.first else { return 50 }

        if value < first.value { return max(1, first.key - 1) }

        guard let last = sorted.last else { return 50 }
        if value >= last.value { return min(99, last.key + 4) }

        for i in 0..<(sorted.count - 1) {
            let lower = sorted[i]
            let upper = sorted[i + 1]
            if value >= lower.value && value < upper.value {
                if upper.value == lower.value { return upper.key }
                let fraction = Double(value - lower.value) / Double(upper.value - lower.value)
                return lower.key + Int(fraction * Double(upper.key - lower.key))
            }
        }
        return 50
    }
}

nonisolated struct StreakDistribution: Codable, Sendable {
    let breakpoints: [Int: Int]
    let totalUsers: Int

    func percentile(for value: Int) -> Int {
        let sorted = breakpoints.sorted { $0.key < $1.key }
        guard let first = sorted.first else { return 50 }

        if value < first.value { return max(1, first.key - 1) }

        guard let last = sorted.last else { return 50 }
        if value >= last.value { return min(99, last.key + 4) }

        for i in 0..<(sorted.count - 1) {
            let lower = sorted[i]
            let upper = sorted[i + 1]
            if value >= lower.value && value < upper.value {
                if upper.value == lower.value { return upper.key }
                let fraction = Double(value - lower.value) / Double(upper.value - lower.value)
                return lower.key + Int(fraction * Double(upper.key - lower.key))
            }
        }
        return 50
    }
}

nonisolated struct CommunityDistributionCache: Sendable {
    var exercises: [String: CommunityDistribution] = [:]  // key: "exerciseId_level_metricType"
    var streak: StreakDistribution?
    var lastFetched: Date?

    var isStale: Bool {
        guard let last = lastFetched else { return true }
        return Date.now.timeIntervalSince(last) > 86_400  // 24 hours
    }

    static func cacheKey(exerciseId: String, level: Int, metricType: String) -> String {
        "\(exerciseId)_\(level)_\(metricType)"
    }
}
