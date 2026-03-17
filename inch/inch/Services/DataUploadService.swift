import Foundation
import BackgroundTasks
import SwiftData
import InchShared

enum UploadError: Error {
    case configurationMissing
    case fileNotFound
    case fileUploadFailed(Int)
    case metadataInsertFailed(Int)
    case unlinkFailed
}

/// Uploads pending SensorRecordings to Supabase in the background via BGProcessingTask.
@Observable
final class DataUploadService {
    static let taskIdentifier = "com.inch.bodyweight.sensor-upload"

    private static let validExerciseIds: Set<String> = [
        "push_ups", "squats", "sit_ups", "pull_ups", "glute_bridges", "dead_bugs"
    ]

    func scheduleBGUpload() {
        let request = BGProcessingTaskRequest(identifier: Self.taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = true
        try? BGTaskScheduler.shared.submit(request)
    }

    func handleBGUpload(task: BGProcessingTask, context: ModelContext) async {
        var uploadTask: Task<Void, Never>?
        task.expirationHandler = {
            uploadTask?.cancel()
        }

        uploadTask = Task {
            await uploadPending(context: context)
        }

        await uploadTask?.value
        task.setTaskCompleted(success: true)
        scheduleBGUpload()
    }

    func unlinkContributorData(contributorId: String) async throws {
        guard let plistURL = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: plistURL) as? [String: Any],
              let supabaseURL = dict["SupabaseURL"] as? String,
              let anonKey = dict["SupabaseAnonKey"] as? String
        else { throw UploadError.configurationMissing }

        guard let url = URL(string: "\(supabaseURL)/rest/v1/sensor_recordings?contributor_id=eq.\(contributorId)") else {
            throw UploadError.configurationMissing
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 204 else {
            throw UploadError.unlinkFailed
        }
    }

    // MARK: - Private

    private func uploadPending(context: ModelContext) async {
        guard let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first,
              settings.motionDataUploadConsented,
              !settings.contributorId.isEmpty
        else { return }

        guard let plistURL = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: plistURL) as? [String: Any],
              let supabaseURL = dict["SupabaseURL"] as? String,
              let anonKey = dict["SupabaseAnonKey"] as? String
        else { return }

        let config = SupabaseConfig(
            supabaseURL: supabaseURL,
            anonKey: anonKey,
            contributorId: settings.contributorId,
            ageRange: settings.ageRange,
            heightRange: settings.heightRange,
            biologicalSex: settings.biologicalSex,
            activityLevel: settings.activityLevel
        )

        let pendingStatus = UploadStatus.pending
        let descriptor = FetchDescriptor<SensorRecording>(
            predicate: #Predicate { $0.uploadStatus == pendingStatus }
        )
        let pending = (try? context.fetch(descriptor)) ?? []
        for recording in pending {
            guard !Task.isCancelled else { return }
            do {
                try await uploadRecording(recording, config: config, context: context)
            } catch {
                // Leave as .pending for next BGTask run
            }
        }
    }

    private func uploadRecording(_ recording: SensorRecording, config: SupabaseConfig, context: ModelContext) async throws {
        let fileURL = URL(filePath: recording.filePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            recording.uploadStatus = .localOnly
            try? context.save()
            return
        }

        guard Self.validExerciseIds.contains(recording.exerciseId) else {
            recording.uploadStatus = .localOnly
            try? context.save()
            return
        }

        let rawData = try Data(contentsOf: fileURL)
        let compressedData = (try? (rawData as NSData).compressed(using: .zlib) as Data) ?? rawData
        let timestamp = Int(recording.recordedAt.timeIntervalSince1970)
        let fileName = "\(config.contributorId)_\(timestamp).bin.zlib"
        let storagePath = "\(recording.exerciseId)/\(fileName)"

        // Step 1: Upload binary file to Supabase Storage (zlib-compressed)
        let storageURL = URL(string: "\(config.supabaseURL)/storage/v1/object/sensor-data/\(storagePath)")!
        var uploadRequest = URLRequest(url: storageURL)
        uploadRequest.httpMethod = "POST"
        uploadRequest.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        uploadRequest.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        uploadRequest.setValue("deflate", forHTTPHeaderField: "Content-Encoding")
        uploadRequest.httpBody = compressedData

        let (_, uploadResponse) = try await URLSession.shared.data(for: uploadRequest)
        guard let uploadHTTP = uploadResponse as? HTTPURLResponse, uploadHTTP.statusCode == 200 else {
            throw UploadError.fileUploadFailed((uploadResponse as? HTTPURLResponse)?.statusCode ?? 0)
        }

        // Step 2: Insert metadata row
        let payload = SensorRecordingPayload(
            contributorId: config.contributorId,
            exerciseId: recording.exerciseId,
            level: recording.level,
            dayNumber: recording.dayNumber,
            setNumber: recording.setNumber,
            confirmedReps: recording.confirmedReps,
            countingMode: recording.countingMode,
            device: recording.device.rawValue,
            sampleRateHz: recording.sampleRateHz,
            durationSeconds: recording.durationSeconds,
            filePath: storagePath,
            fileSizeBytes: compressedData.count,
            recordedAt: recording.recordedAt,
            ageRange: config.ageRange,
            heightRange: config.heightRange,
            biologicalSex: config.biologicalSex,
            activityLevel: config.activityLevel
        )

        let metadataURL = URL(string: "\(config.supabaseURL)/rest/v1/sensor_recordings")!
        var metadataRequest = URLRequest(url: metadataURL)
        metadataRequest.httpMethod = "POST"
        metadataRequest.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        metadataRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        metadataRequest.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        metadataRequest.httpBody = try JSONEncoder().encode(payload)

        let (_, metadataResponse) = try await URLSession.shared.data(for: metadataRequest)
        guard let metaHTTP = metadataResponse as? HTTPURLResponse, metaHTTP.statusCode == 201 else {
            throw UploadError.metadataInsertFailed((metadataResponse as? HTTPURLResponse)?.statusCode ?? 0)
        }

        recording.uploadStatus = .uploaded
        recording.uploadedAt = .now
        try? context.save()
    }

}

private struct SupabaseConfig {
    let supabaseURL: String
    let anonKey: String
    let contributorId: String
    let ageRange: String?
    let heightRange: String?
    let biologicalSex: String?
    let activityLevel: String?
}

private struct SensorRecordingPayload: Encodable {
    let contributorId: String
    let exerciseId: String
    let level: Int
    let dayNumber: Int
    let setNumber: Int
    let confirmedReps: Int
    let countingMode: String
    let device: String
    let sampleRateHz: Int
    let durationSeconds: Double
    let filePath: String
    let fileSizeBytes: Int
    let recordedAt: Date
    let ageRange: String?
    let heightRange: String?
    let biologicalSex: String?
    let activityLevel: String?

    enum CodingKeys: String, CodingKey {
        case contributorId = "contributor_id"
        case exerciseId = "exercise_id"
        case level
        case dayNumber = "day_number"
        case setNumber = "set_number"
        case confirmedReps = "confirmed_reps"
        case countingMode = "counting_mode"
        case device
        case sampleRateHz = "sample_rate_hz"
        case durationSeconds = "duration_seconds"
        case filePath = "file_path"
        case fileSizeBytes = "file_size_bytes"
        case recordedAt = "recorded_at"
        case ageRange = "age_range"
        case heightRange = "height_range"
        case biologicalSex = "biological_sex"
        case activityLevel = "activity_level"
    }
}
