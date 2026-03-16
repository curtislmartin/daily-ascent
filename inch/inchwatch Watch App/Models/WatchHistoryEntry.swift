import Foundation

struct WatchHistoryEntry: Codable, Identifiable {
    let id: UUID
    let exerciseName: String
    let level: Int
    let dayNumber: Int
    let totalReps: Int
    let setCount: Int
    let completedAt: Date

    init(exerciseName: String, level: Int, dayNumber: Int, totalReps: Int, setCount: Int, completedAt: Date) {
        self.id = UUID()
        self.exerciseName = exerciseName
        self.level = level
        self.dayNumber = dayNumber
        self.totalReps = totalReps
        self.setCount = setCount
        self.completedAt = completedAt
    }
}
