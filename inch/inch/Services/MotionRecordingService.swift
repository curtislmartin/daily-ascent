import Foundation
import CoreMotion

/// Records accelerometer data to binary files during active sets.
/// Uses OperationQueue callbacks per Core Motion framework guidance.
@Observable
final class MotionRecordingService {
    nonisolated(unsafe) private let motionManager = CMMotionManager()
    // flushAndClose captures the in-flight buffer and FileHandle from startAccelerometerUpdates.
    // It is assigned on @MainActor (inside startRecording) and called on @MainActor (inside
    // stopRecording), so there is no actual data race. nonisolated(unsafe) is required to satisfy
    // Swift's strict concurrency checker, following the same pattern as motionManager above.
    nonisolated(unsafe) private var flushAndClose: (() -> Void)?
    private var sensorQueue: OperationQueue?
    private(set) var currentRecordingURL: URL?
    private(set) var isRecording: Bool = false

    func startRecording(exerciseId: String, setNumber: Int) {
        flushAndClose = nil
        guard motionManager.isAccelerometerAvailable else { return }

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

        writeHeader(to: fileHandle, sensorType: 0)

        let queue = OperationQueue()
        queue.name = "motion-recording"
        queue.maxConcurrentOperationCount = 1
        sensorQueue = queue

        let recordingStart = Date.now
        motionManager.accelerometerUpdateInterval = 1.0 / 100.0

        // Must call via nonisolated method so the handler closure is defined in a
        // nonisolated context. A closure literal defined inside a @MainActor method
        // inherits @MainActor isolation — even when typed as CMAccelerometerHandler —
        // causing Swift to insert an actor hop. CMMotionManager asserts via
        // dispatch_assert_queue that the callback runs on the provided OperationQueue,
        // not the main queue, so that hop triggers a crash.
        startAccelerometerUpdates(to: queue, fileHandle: fileHandle, recordingStart: recordingStart)

        currentRecordingURL = fileURL
        isRecording = true
    }

    /// Stops recording and returns the file URL. Returns nil if not recording.
    func stopRecording() -> URL? {
        motionManager.stopAccelerometerUpdates()
        flushAndClose?()
        flushAndClose = nil
        sensorQueue = nil
        isRecording = false
        let url = currentRecordingURL
        currentRecordingURL = nil
        return url
    }

    // MARK: - Private

    private nonisolated func startAccelerometerUpdates(
        to queue: OperationQueue,
        fileHandle: FileHandle,
        recordingStart: Date
    ) {
        // Buffer 50 samples (~0.5s at 100Hz) before flushing to reduce syscall overhead.
        var buffer = Data(capacity: 50 * 20)
        let handler: CMAccelerometerHandler = { data, _ in
            guard let data else { return }
            let t = Float64(Date.now.timeIntervalSince(recordingStart))
            let x = Float32(data.acceleration.x)
            let y = Float32(data.acceleration.y)
            let z = Float32(data.acceleration.z)
            var sample = Data(count: 20)
            sample.withUnsafeMutableBytes { ptr in
                ptr.storeBytes(of: t, toByteOffset: 0, as: Float64.self)
                ptr.storeBytes(of: x, toByteOffset: 8, as: Float32.self)
                ptr.storeBytes(of: y, toByteOffset: 12, as: Float32.self)
                ptr.storeBytes(of: z, toByteOffset: 16, as: Float32.self)
            }
            buffer.append(sample)
            if buffer.count >= 50 * 20 {
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
        motionManager.startAccelerometerUpdates(to: queue, withHandler: handler)
    }

    private func writeHeader(to fileHandle: FileHandle, sensorType: UInt8) {
        var header = Data()
        header.append(contentsOf: [0x49, 0x4E, 0x43, 0x48]) // "INCH"
        header.append(1) // version
        var sampleRate: UInt16 = 100
        withUnsafeBytes(of: &sampleRate) { header.append(contentsOf: $0) }
        header.append(sensorType)
        try? fileHandle.write(contentsOf: header)
    }
}
