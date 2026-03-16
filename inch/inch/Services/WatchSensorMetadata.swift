import Foundation

/// Typed, Sendable metadata extracted from a WatchConnectivity file transfer.
/// [String: Any] is not Sendable — all values are extracted into typed fields
/// within the nonisolated delegate before this struct is created.
struct WatchSensorMetadata: Sendable {
    let exerciseId: String
    let setNumber: Int
    let device: String
    let level: Int
    let dayNumber: Int
    let confirmedReps: Int
    let durationSeconds: Double
    let countingMode: String
    let sampleRateHz: Int
    let recordedAt: Double  // Unix timestamp
}

struct ReceivedSensorFile: Sendable {
    let fileURL: URL
    let metadata: WatchSensorMetadata
    let fileSizeBytes: Int
}
