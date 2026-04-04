import Foundation
import UIKit

// MARK: - Event types

struct AnalyticsEvent: Sendable, Encodable {
    let id: UUID
    let name: String
    let occurredAt: Date
    let properties: AnalyticsProperties

    init(name: String, occurredAt: Date = .now, properties: AnalyticsProperties) {
        self.id = UUID()
        self.name = name
        self.occurredAt = occurredAt
        self.properties = properties
    }
}

enum AnalyticsProperties: Sendable, Encodable {
    case appInstalled(appVersion: String, osVersion: String)
    case appOpened(appVersion: String)
    case onboardingCompleted(exercisesEnrolled: [String], dataConsentGiven: Bool)
    case workoutStarted(exerciseId: String, level: Int, dayNumber: Int)
    case workoutResumed(exerciseId: String, level: Int, dayNumber: Int, resumedFromSet: Int)
    case workoutCompleted(exerciseId: String, level: Int, dayNumber: Int,
                          totalSets: Int, totalReps: Int,
                          durationSeconds: Int, countingMode: String)
    case workoutAbandoned(exerciseId: String, level: Int, dayNumber: Int,
                          setsCompleted: Int, setsTotal: Int)
    case levelTestAttempted(exerciseId: String, currentLevel: Int)
    case levelAdvanced(exerciseId: String, fromLevel: Int, toLevel: Int, maxRepsAchieved: Int)
    case levelTestFailed(exerciseId: String, testedLevel: Int,
                         maxRepsAchieved: Int, thresholdRequired: Int)
    case streakBroken(streakLengthAtBreak: Int)
    case progressViewed
    case scheduledSessionSkipped(exerciseId: String, level: Int,
                                 dayNumber: Int, consecutiveSkips: Int)

    private enum CodingKeys: String, CodingKey {
        case exercise_id, level, day_number, total_sets, total_reps
        case duration_seconds, counting_mode, sets_completed, sets_total
        case current_level, from_level, to_level, max_reps_achieved
        case tested_level, threshold_required, streak_length_at_break
        case consecutive_skips, exercises_enrolled, data_consent_given
        case app_version, os_version, resumed_from_set
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .appInstalled(let v, let os):
            try c.encode(v, forKey: .app_version)
            try c.encode(os, forKey: .os_version)
        case .appOpened(let v):
            try c.encode(v, forKey: .app_version)
        case .onboardingCompleted(let ids, let consent):
            try c.encode(ids, forKey: .exercises_enrolled)
            try c.encode(consent, forKey: .data_consent_given)
        case .workoutStarted(let id, let lv, let day):
            try c.encode(id, forKey: .exercise_id)
            try c.encode(lv, forKey: .level)
            try c.encode(day, forKey: .day_number)
        case .workoutResumed(let id, let lv, let day, let set):
            try c.encode(id, forKey: .exercise_id)
            try c.encode(lv, forKey: .level)
            try c.encode(day, forKey: .day_number)
            try c.encode(set, forKey: .resumed_from_set)
        case .workoutCompleted(let id, let lv, let day, let sets, let reps, let dur, let mode):
            try c.encode(id, forKey: .exercise_id)
            try c.encode(lv, forKey: .level)
            try c.encode(day, forKey: .day_number)
            try c.encode(sets, forKey: .total_sets)
            try c.encode(reps, forKey: .total_reps)
            try c.encode(dur, forKey: .duration_seconds)
            try c.encode(mode, forKey: .counting_mode)
        case .workoutAbandoned(let id, let lv, let day, let done, let total):
            try c.encode(id, forKey: .exercise_id)
            try c.encode(lv, forKey: .level)
            try c.encode(day, forKey: .day_number)
            try c.encode(done, forKey: .sets_completed)
            try c.encode(total, forKey: .sets_total)
        case .levelTestAttempted(let id, let lv):
            try c.encode(id, forKey: .exercise_id)
            try c.encode(lv, forKey: .current_level)
        case .levelAdvanced(let id, let from, let to, let reps):
            try c.encode(id, forKey: .exercise_id)
            try c.encode(from, forKey: .from_level)
            try c.encode(to, forKey: .to_level)
            try c.encode(reps, forKey: .max_reps_achieved)
        case .levelTestFailed(let id, let lv, let reps, let thresh):
            try c.encode(id, forKey: .exercise_id)
            try c.encode(lv, forKey: .tested_level)
            try c.encode(reps, forKey: .max_reps_achieved)
            try c.encode(thresh, forKey: .threshold_required)
        case .streakBroken(let length):
            try c.encode(length, forKey: .streak_length_at_break)
        case .progressViewed:
            break
        case .scheduledSessionSkipped(let id, let lv, let day, let skips):
            try c.encode(id, forKey: .exercise_id)
            try c.encode(lv, forKey: .level)
            try c.encode(day, forKey: .day_number)
            try c.encode(skips, forKey: .consecutive_skips)
        }
    }
}

// MARK: - Service

@Observable
final class AnalyticsService {
    private let sessionId = UUID()
    private var queue: [AnalyticsEvent] = []
    private let maxQueueSize = 500
    private var analyticsEnabled = false

    private var queueFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "pending_analytics.json")
    }

    func configure(enabled: Bool) {
        analyticsEnabled = enabled
    }

    func setEnabled(_ enabled: Bool) {
        analyticsEnabled = enabled
        if !enabled {
            queue.removeAll()
            try? FileManager.default.removeItem(at: queueFileURL)
        }
    }

    func record(_ event: AnalyticsEvent) {
        guard analyticsEnabled else { return }
        if queue.count >= maxQueueSize {
            queue.removeFirst()
        }
        queue.append(event)
    }

    func persistQueue() {
        guard analyticsEnabled, !queue.isEmpty else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(queue) {
            let tmp = queueFileURL.appendingPathExtension("tmp")
            try? data.write(to: tmp, options: .atomic)
            try? FileManager.default.moveItem(at: tmp, to: queueFileURL)
        }
    }

    func flush(supabaseURL: URL, anonKey: String) async {
        guard analyticsEnabled, !queue.isEmpty else { return }

        let eventsToSend = queue
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase

        struct Row: Encodable {
            let id: UUID
            let session_id: UUID
            let event_name: String
            let occurred_at: Date
            let app_version: String
            let os_version: String
            let properties: AnalyticsProperties
        }

        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let osVersion = UIDevice.current.systemVersion
        let capturedSessionId = sessionId

        let rows = eventsToSend.map { event in
            Row(
                id: event.id,
                session_id: capturedSessionId,
                event_name: event.name,
                occurred_at: event.occurredAt,
                app_version: appVersion,
                os_version: osVersion,
                properties: event.properties
            )
        }

        guard let body = try? encoder.encode(rows) else { return }

        var request = URLRequest(url: supabaseURL.appending(path: "/rest/v1/app_events"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = body

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else { return }

        queue.removeAll()
        try? FileManager.default.removeItem(at: queueFileURL)
    }
}
