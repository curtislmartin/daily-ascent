import Foundation
import CoreMotion
import SwiftData
import InchShared

/// Records accelerometer + gyroscope (device motion) to binary files during active sets.
/// Uses OperationQueue callbacks per Core Motion framework guidance.
@Observable
final class MotionRecordingService {
    nonisolated(unsafe) private let motionManager = CMMotionManager()
    // flushAndClose captures the in-flight buffer and FileHandle from startDeviceMotionUpdates.
    // It is assigned on @MainActor (inside startRecording) and called on @MainActor (inside
    // stopRecording), so there is no actual data race. nonisolated(unsafe) is required to satisfy
    // Swift's strict concurrency checker, following the same pattern as motionManager above.
    nonisolated(unsafe) private var flushAndClose: (() -> Void)?
    // Called on the sensor OperationQueue for every sample while recording.
    // Assign before startRecording; stopRecording clears it automatically.
    // nonisolated(unsafe) — only ever set on @MainActor (between sets) and read
    // on the serial sensor OperationQueue (during recording). Same pattern as flushAndClose.
    nonisolated(unsafe) var onSample: ((Double, Double, Double) -> Void)?
    private var sensorQueue: OperationQueue?
    private(set) var currentRecordingURL: URL?
    private(set) var currentSessionId: String = ""
    private(set) var isRecording: Bool = false

    private static let maxSensorDataBytes = 50 * 1024 * 1024   // 50 MB cap on sensor_data folder
    private static let minDeviceFreeBytes: Int64 = 50 * 1024 * 1024  // 50 MB minimum device free space

    func startRecording(exerciseId: String, setNumber: Int, sessionId: String, context: ModelContext) {
        flushAndClose = nil
        guard motionManager.isDeviceMotionAvailable else { return }

        // Skip if device storage is critically low.
        guard hasAdequateDeviceStorage() else { return }

        let dir = URL.documentsDirectory.appending(path: "sensor_data", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var dirForBackup = dir
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? dirForBackup.setResourceValues(resourceValues)

        // Prune oldest uploaded files if folder is over the cap.
        if sensorDataFolderSizeBytes(at: dir) > Self.maxSensorDataBytes {
            pruneUploadedFiles(in: dir, context: context)
            guard sensorDataFolderSizeBytes(at: dir) <= Self.maxSensorDataBytes else { return }
        }

        let fileName = "\(exerciseId)_set\(setNumber)_\(sessionId)_iphone.bin"
        let fileURL = dir.appending(path: fileName)
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)

        guard let fileHandle = try? FileHandle(forWritingTo: fileURL) else { return }

        writeHeader(to: fileHandle)

        let queue = OperationQueue()
        queue.name = "motion-recording"
        queue.maxConcurrentOperationCount = 1
        sensorQueue = queue

        let recordingStart = Date.now
        motionManager.deviceMotionUpdateInterval = 1.0 / 100.0

        // Must call via nonisolated method so the handler closure is defined in a
        // nonisolated context. A closure literal defined inside a @MainActor method
        // inherits @MainActor isolation — even when typed as CMDeviceMotionHandler —
        // causing Swift to insert an actor hop. CMMotionManager asserts via
        // dispatch_assert_queue that the callback runs on the provided OperationQueue,
        // not the main queue, so that hop triggers a crash.
        startDeviceMotionUpdates(to: queue, fileHandle: fileHandle, recordingStart: recordingStart)

        currentRecordingURL = fileURL
        currentSessionId = sessionId
        isRecording = true
    }

    /// Stops recording and returns the file URL. Returns nil if not recording.
    func stopRecording() -> URL? {
        motionManager.stopDeviceMotionUpdates()
        flushAndClose?()
        flushAndClose = nil
        onSample = nil
        sensorQueue = nil
        isRecording = false
        let url = currentRecordingURL
        currentRecordingURL = nil
        currentSessionId = ""
        return url
    }

    // MARK: - Private

    private nonisolated func startDeviceMotionUpdates(
        to queue: OperationQueue,
        fileHandle: FileHandle,
        recordingStart: Date
    ) {
        // Buffer 50 samples (~0.5s at 100Hz) before flushing.
        // Each sample: [Float64 t, Float32 ax, Float32 ay, Float32 az, Float32 gx, Float32 gy, Float32 gz] = 36 bytes
        var buffer = Data(capacity: 50 * 36)
        let handler: CMDeviceMotionHandler = { data, _ in
            guard let data else { return }
            let t = Float64(Date.now.timeIntervalSince(recordingStart))
            let ax = Float32(data.userAcceleration.x)
            let ay = Float32(data.userAcceleration.y)
            let az = Float32(data.userAcceleration.z)
            self.onSample?(Double(data.userAcceleration.x),
                           Double(data.userAcceleration.y),
                           Double(data.userAcceleration.z))
            let gx = Float32(data.rotationRate.x)
            let gy = Float32(data.rotationRate.y)
            let gz = Float32(data.rotationRate.z)
            var sample = Data(count: 36)
            sample.withUnsafeMutableBytes { ptr in
                ptr.storeBytes(of: t,  toByteOffset: 0,  as: Float64.self)
                ptr.storeBytes(of: ax, toByteOffset: 8,  as: Float32.self)
                ptr.storeBytes(of: ay, toByteOffset: 12, as: Float32.self)
                ptr.storeBytes(of: az, toByteOffset: 16, as: Float32.self)
                ptr.storeBytes(of: gx, toByteOffset: 20, as: Float32.self)
                ptr.storeBytes(of: gy, toByteOffset: 24, as: Float32.self)
                ptr.storeBytes(of: gz, toByteOffset: 28, as: Float32.self)
            }
            buffer.append(sample)
            if buffer.count >= 50 * 36 {
                try? fileHandle.write(contentsOf: buffer)
                buffer.removeAll(keepingCapacity: true)
            }
        }
        flushAndClose = {
            if !buffer.isEmpty {
                try? fileHandle.write(contentsOf: buffer)
            }
            try? fileHandle.close()
        }
        motionManager.startDeviceMotionUpdates(to: queue, withHandler: handler)
    }

    private func writeHeader(to fileHandle: FileHandle) {
        var header = Data()
        header.append(contentsOf: [0x44, 0x41, 0x53, 0x43]) // "DASC"
        header.append(1) // version
        var sampleRate: UInt16 = 100
        withUnsafeBytes(of: &sampleRate) { header.append(contentsOf: $0) }
        header.append(1) // sensorType: 1 = deviceMotion (accel + gyro)
        try? fileHandle.write(contentsOf: header)
    }

    // MARK: - Storage Management

    private func hasAdequateDeviceStorage() -> Bool {
        guard let values = try? URL.documentsDirectory.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        ), let available = values.volumeAvailableCapacityForImportantUsage else {
            return true // Assume adequate if we can't determine
        }
        return available >= Self.minDeviceFreeBytes
    }

    private func sensorDataFolderSizeBytes(at dir: URL) -> Int {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        return contents.reduce(0) { sum, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return sum + size
        }
    }

    /// Deletes binary files for the oldest uploaded SensorRecordings until the folder is under the cap.
    private func pruneUploadedFiles(in dir: URL, context: ModelContext) {
        let uploaded = UploadStatus.uploaded
        var descriptor = FetchDescriptor<SensorRecording>(
            predicate: #Predicate { $0.uploadStatus == uploaded && $0.filePath != "" },
            sortBy: [SortDescriptor(\.recordedAt, order: .forward)]
        )
        descriptor.fetchLimit = 50
        guard let recordings = try? context.fetch(descriptor) else { return }

        for recording in recordings {
            guard sensorDataFolderSizeBytes(at: dir) > Self.maxSensorDataBytes else { break }
            let fileURL = URL(fileURLWithPath: recording.filePath)
            try? FileManager.default.removeItem(at: fileURL)
            recording.filePath = ""
        }
        try? context.save()
    }
}
