import Foundation

enum WatchRecordingTrigger: Sendable {
    case start(exerciseId: String, setNumber: Int, sessionId: String)
    case stop(exerciseId: String, setNumber: Int)
}
