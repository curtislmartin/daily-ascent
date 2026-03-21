import Foundation
import SwiftData

@Model
public final class SensorRecording {
    public var recordedAt: Date = Date.now
    public var device: SensorDevice = SensorDevice.iPhone
    public var exerciseId: String = ""
    public var level: Int = 0
    public var dayNumber: Int = 0
    public var setNumber: Int = 0
    public var confirmedReps: Int = 0
    public var sampleRateHz: Int = 100
    public var durationSeconds: Double = 0
    public var countingMode: String = ""
    public var filePath: String = ""
    public var fileSizeBytes: Int = 0
    public var sessionId: String = ""

    public var uploadStatus: UploadStatus = UploadStatus.pending
    public var uploadedAt: Date? = nil

    public var completedSet: CompletedSet?

    public init(
        recordedAt: Date = Date.now,
        device: SensorDevice = .iPhone,
        exerciseId: String = "",
        level: Int = 0,
        dayNumber: Int = 0,
        setNumber: Int = 0,
        confirmedReps: Int = 0,
        sampleRateHz: Int = 100,
        durationSeconds: Double = 0,
        countingMode: String = "",
        filePath: String = "",
        fileSizeBytes: Int = 0,
        sessionId: String = "",
        uploadStatus: UploadStatus = .pending,
        uploadedAt: Date? = nil
    ) {
        self.recordedAt = recordedAt
        self.device = device
        self.exerciseId = exerciseId
        self.level = level
        self.dayNumber = dayNumber
        self.setNumber = setNumber
        self.confirmedReps = confirmedReps
        self.sampleRateHz = sampleRateHz
        self.durationSeconds = durationSeconds
        self.countingMode = countingMode
        self.filePath = filePath
        self.fileSizeBytes = fileSizeBytes
        self.sessionId = sessionId
        self.uploadStatus = uploadStatus
        self.uploadedAt = uploadedAt
    }
}
