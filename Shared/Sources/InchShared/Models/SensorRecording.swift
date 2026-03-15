import Foundation
import SwiftData

@Model
final class SensorRecording {
    var recordedAt: Date = Date.now
    var device: SensorDevice = SensorDevice.iPhone
    var exerciseId: String = ""
    var level: Int = 0
    var dayNumber: Int = 0
    var setNumber: Int = 0
    var confirmedReps: Int = 0
    var sampleRateHz: Int = 100
    var durationSeconds: Double = 0
    var filePath: String = ""
    var fileSizeBytes: Int = 0

    var uploadStatus: UploadStatus = UploadStatus.pending
    var uploadedAt: Date? = nil

    var completedSet: CompletedSet?

    init(
        recordedAt: Date = Date.now,
        device: SensorDevice = .iPhone,
        exerciseId: String = "",
        level: Int = 0,
        dayNumber: Int = 0,
        setNumber: Int = 0,
        confirmedReps: Int = 0,
        sampleRateHz: Int = 100,
        durationSeconds: Double = 0,
        filePath: String = "",
        fileSizeBytes: Int = 0,
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
        self.filePath = filePath
        self.fileSizeBytes = fileSizeBytes
        self.uploadStatus = uploadStatus
        self.uploadedAt = uploadedAt
    }
}
