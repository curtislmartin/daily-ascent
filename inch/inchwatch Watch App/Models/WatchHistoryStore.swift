import Foundation
import InchShared

@Observable @MainActor final class WatchHistoryStore {
    private let key = "watch.historyEntries"
    private let limit = 30  // oldest entries dropped beyond this cap

    private(set) var entries: [WatchHistoryEntry] = []

    init() {
        load()
    }

    func record(_ report: WatchCompletionReport, exerciseName: String) {
        let totalReps = report.completedSets.reduce(0) { $0 + $1.actualReps }
        let entry = WatchHistoryEntry(
            exerciseName: exerciseName,
            level: report.level,
            dayNumber: report.dayNumber,
            totalReps: totalReps,
            setCount: report.completedSets.count,
            completedAt: report.completedAt
        )
        entries.insert(entry, at: 0)
        if entries.count > limit {
            entries = Array(entries.prefix(limit))
        }
        save()
    }

    // MARK: - Private

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([WatchHistoryEntry].self, from: data)
        else { return }  // decode failure silently returns []
        entries = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
