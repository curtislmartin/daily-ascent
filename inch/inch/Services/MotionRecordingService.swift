import Foundation
import CoreMotion

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
    private var sensorQueue: OperationQueue?
    private(set) var currentRecordingURL: URL?
    private(set) var isRecording: Bool = false

    func startRecording(exerciseId: String, setNumber: Int) {
        flushAndClose = nil
        guard motionManager.isDeviceMotionAvailable else { return }

        let dir = URL.documentsDirectory.appending(path: "sensor_data", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var dirForBackup = dir
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? dirForBackup.setResourceValues(resourceValues)

        let fileName = "\(exerciseId)_set\(setNumber)_\(Int(Date.now.timeIntervalSince1970)).bin"
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
        isRecording = true
    }

    /// Stops recording and returns the file URL. Returns nil if not recording.
    func stopRecording() -> URL? {
        motionManager.stopDeviceMotionUpdates()
        flushAndClose?()
        flushAndClose = nil
        sensorQueue = nil
        isRecording = false
        let url = currentRecordingURL
        currentRecordingURL = nil
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
        header.append(contentsOf: [0x49, 0x4E, 0x43, 0x48]) // "INCH"
        header.append(1) // version
        var sampleRate: UInt16 = 100
        withUnsafeBytes(of: &sampleRate) { header.append(contentsOf: $0) }
        header.append(1) // sensorType: 1 = deviceMotion (accel + gyro)
        try? fileHandle.write(contentsOf: header)
    }
}
