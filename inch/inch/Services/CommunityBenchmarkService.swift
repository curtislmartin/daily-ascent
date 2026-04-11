import Foundation
import OSLog
import SwiftData
import InchShared

@Observable
final class CommunityBenchmarkService {
    private let logger = Logger(subsystem: "dev.clmartin.inch", category: "CommunityBenchmark")

    var distributionCache = CommunityDistributionCache()

    // MARK: - Exercise Benchmark Upload

    func uploadExerciseBenchmark(
        exerciseId: String,
        level: Int,
        bestSetReps: Int?,
        bestSetDuration: Int?,
        sessionTotalReps: Int,
        sessionDurationSecs: Int,
        isTestDay: Bool,
        testReps: Int?
    ) {
        Task.detached(priority: .utility) { [self] in
            await _uploadExerciseBenchmark(
                exerciseId: exerciseId, level: level,
                bestSetReps: bestSetReps, bestSetDuration: bestSetDuration,
                sessionTotalReps: sessionTotalReps, sessionDurationSecs: sessionDurationSecs,
                isTestDay: isTestDay, testReps: testReps
            )
        }
    }

    // MARK: - Streak Benchmark Upload

    func uploadStreakBenchmark(streakDays: Int, exercisesCompletedToday: Int) {
        Task.detached(priority: .utility) { [self] in
            await _uploadStreakBenchmark(
                streakDays: streakDays,
                exercisesCompletedToday: exercisesCompletedToday
            )
        }
    }

    // MARK: - Lifetime Benchmark Upload

    func uploadLifetimeBenchmark(totalWorkouts: Int, totalLifetimeReps: Int, enrolledExerciseCount: Int) {
        Task.detached(priority: .utility) { [self] in
            await _uploadLifetimeBenchmark(
                totalWorkouts: totalWorkouts,
                totalLifetimeReps: totalLifetimeReps,
                enrolledExerciseCount: enrolledExerciseCount
            )
        }
    }

    // MARK: - Fetch Distributions

    func fetchDistributions(exerciseIds: [(id: String, level: Int)]) async {
        guard !distributionCache.isStale || distributionCache.lastFetched == nil else { return }

        guard let config = supabaseConfig() else { return }

        // Fetch exercise distributions
        guard let url = URL(string: "\(config.url)/rest/v1/exercise_distributions?select=*") else { return }
        var request = URLRequest(url: url)
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }

            let rows = try JSONDecoder().decode([DistributionRow].self, from: data)
            var cache = CommunityDistributionCache()
            for row in rows {
                let dist = CommunityDistribution(
                    exerciseId: row.exerciseId,
                    level: row.level,
                    metricType: row.metricType,
                    breakpoints: row.breakpoints,
                    totalUsers: row.totalUsers
                )
                let key = CommunityDistributionCache.cacheKey(
                    exerciseId: row.exerciseId, level: row.level, metricType: row.metricType
                )
                cache.exercises[key] = dist
            }

            // Fetch streak distribution
            if let streakURL = URL(string: "\(config.url)/rest/v1/streak_distributions?select=*&limit=1") {
                var streakRequest = URLRequest(url: streakURL)
                streakRequest.setValue(config.anonKey, forHTTPHeaderField: "apikey")
                streakRequest.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
                if let (streakData, streakResponse) = try? await URLSession.shared.data(for: streakRequest),
                   let streakHTTP = streakResponse as? HTTPURLResponse, streakHTTP.statusCode == 200,
                   let streakRows = try? JSONDecoder().decode([StreakDistributionRow].self, from: streakData),
                   let first = streakRows.first {
                    cache.streak = StreakDistribution(breakpoints: first.breakpoints, totalUsers: first.totalUsers)
                }
            }

            cache.lastFetched = .now
            await MainActor.run { self.distributionCache = cache }
        } catch {
            logger.debug("Failed to fetch distributions: \(error.localizedDescription)")
        }
    }

    // MARK: - Delete

    func deleteMyData() async -> Bool {
        guard let config = supabaseConfig() else { return false }
        let deviceHash = CommunityIdentity.deviceHash

        let tables = ["exercise_benchmarks", "streak_benchmarks", "lifetime_benchmarks"]
        var allSucceeded = true

        for table in tables {
            guard let url = URL(string: "\(config.url)/rest/v1/\(table)?device_hash=eq.\(deviceHash)") else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 && http.statusCode != 204 {
                    allSucceeded = false
                }
            } catch {
                allSucceeded = false
            }
        }

        if allSucceeded {
            CommunityIdentity.deleteIdentity()
        }

        return allSucceeded
    }

    // MARK: - Percentile Lookup

    func exercisePercentile(exerciseId: String, level: Int, metricType: String, value: Int) -> Int? {
        let key = CommunityDistributionCache.cacheKey(exerciseId: exerciseId, level: level, metricType: metricType)
        guard let dist = distributionCache.exercises[key], dist.totalUsers >= 20 else { return nil }
        return dist.percentile(for: value)
    }

    func streakPercentile(streakDays: Int) -> Int? {
        guard let dist = distributionCache.streak, dist.totalUsers >= 20 else { return nil }
        return dist.percentile(for: streakDays)
    }

    // MARK: - Private

    private nonisolated struct SupabaseInfo {
        let url: String
        let anonKey: String
    }

    private nonisolated func supabaseConfig() -> SupabaseInfo? {
        guard let plistURL = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: plistURL) as? [String: Any],
              let url = dict["SupabaseURL"] as? String,
              let key = dict["SupabaseAnonKey"] as? String
        else { return nil }
        return SupabaseInfo(url: url, anonKey: key)
    }

    @concurrent
    private func _uploadExerciseBenchmark(
        exerciseId: String, level: Int,
        bestSetReps: Int?, bestSetDuration: Int?,
        sessionTotalReps: Int, sessionDurationSecs: Int,
        isTestDay: Bool, testReps: Int?
    ) async {
        guard let config = supabaseConfig() else { return }
        let deviceHash = CommunityIdentity.deviceHash
        let now = Date.now
        let hour = Calendar.current.component(.hour, from: now)

        let payload = ExerciseBenchmarkPayload(
            deviceHash: deviceHash,
            exerciseId: exerciseId,
            level: level,
            bestSetReps: bestSetReps,
            bestSetDuration: bestSetDuration,
            sessionTotalReps: sessionTotalReps,
            sessionDurationSecs: sessionDurationSecs,
            workoutHour: hour,
            workoutDate: Self.dateString(now),
            isTestDay: isTestDay,
            testReps: testReps
        )

        guard let url = URL(string: "\(config.url)/rest/v1/exercise_benchmarks") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONEncoder().encode(payload)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode < 300 {
                logger.debug("Exercise benchmark uploaded: \(exerciseId) L\(level)")
            }
        } catch {
            logger.debug("Exercise benchmark upload failed: \(error.localizedDescription)")
        }
    }

    @concurrent
    private func _uploadStreakBenchmark(streakDays: Int, exercisesCompletedToday: Int) async {
        guard let config = supabaseConfig() else { return }
        let deviceHash = CommunityIdentity.deviceHash

        let payload = StreakBenchmarkPayload(
            deviceHash: deviceHash,
            streakDays: streakDays,
            exercisesCompletedToday: exercisesCompletedToday
        )

        guard let url = URL(string: "\(config.url)/rest/v1/streak_benchmarks") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONEncoder().encode(payload)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode < 300 {
                logger.debug("Streak benchmark uploaded: \(streakDays) days")
            }
        } catch {
            logger.debug("Streak benchmark upload failed: \(error.localizedDescription)")
        }
    }

    @concurrent
    private func _uploadLifetimeBenchmark(totalWorkouts: Int, totalLifetimeReps: Int, enrolledExerciseCount: Int) async {
        guard let config = supabaseConfig() else { return }
        let deviceHash = CommunityIdentity.deviceHash

        let payload = LifetimeBenchmarkPayload(
            deviceHash: deviceHash,
            totalWorkouts: totalWorkouts,
            totalLifetimeReps: totalLifetimeReps,
            enrolledExerciseCount: enrolledExerciseCount
        )

        guard let url = URL(string: "\(config.url)/rest/v1/lifetime_benchmarks") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONEncoder().encode(payload)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode < 300 {
                logger.debug("Lifetime benchmark uploaded")
            }
        } catch {
            logger.debug("Lifetime benchmark upload failed: \(error.localizedDescription)")
        }
    }

    private nonisolated static func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}

// MARK: - Payloads

private nonisolated struct ExerciseBenchmarkPayload: Encodable {
    let deviceHash: String
    let exerciseId: String
    let level: Int
    let bestSetReps: Int?
    let bestSetDuration: Int?
    let sessionTotalReps: Int
    let sessionDurationSecs: Int
    let workoutHour: Int
    let workoutDate: String
    let isTestDay: Bool
    let testReps: Int?

    enum CodingKeys: String, CodingKey {
        case deviceHash = "device_hash"
        case exerciseId = "exercise_id"
        case level
        case bestSetReps = "best_set_reps"
        case bestSetDuration = "best_set_duration"
        case sessionTotalReps = "session_total_reps"
        case sessionDurationSecs = "session_duration_secs"
        case workoutHour = "workout_hour"
        case workoutDate = "workout_date"
        case isTestDay = "is_test_day"
        case testReps = "test_reps"
    }
}

private nonisolated struct StreakBenchmarkPayload: Encodable {
    let deviceHash: String
    let streakDays: Int
    let exercisesCompletedToday: Int

    enum CodingKeys: String, CodingKey {
        case deviceHash = "device_hash"
        case streakDays = "streak_days"
        case exercisesCompletedToday = "exercises_completed_today"
    }
}

private nonisolated struct LifetimeBenchmarkPayload: Encodable {
    let deviceHash: String
    let totalWorkouts: Int
    let totalLifetimeReps: Int
    let enrolledExerciseCount: Int

    enum CodingKeys: String, CodingKey {
        case deviceHash = "device_hash"
        case totalWorkouts = "total_workouts"
        case totalLifetimeReps = "total_lifetime_reps"
        case enrolledExerciseCount = "enrolled_exercise_count"
    }
}

// MARK: - Distribution Row Decoding

private nonisolated struct DistributionRow: Decodable {
    let exerciseId: String
    let level: Int
    let metricType: String
    let totalUsers: Int
    let p5: Int, p10: Int, p15: Int, p20: Int, p25: Int
    let p30: Int, p35: Int, p40: Int, p45: Int, p50: Int
    let p55: Int, p60: Int, p65: Int, p70: Int, p75: Int
    let p80: Int, p85: Int, p90: Int, p95: Int

    var breakpoints: [Int: Int] {
        [5: p5, 10: p10, 15: p15, 20: p20, 25: p25,
         30: p30, 35: p35, 40: p40, 45: p45, 50: p50,
         55: p55, 60: p60, 65: p65, 70: p70, 75: p75,
         80: p80, 85: p85, 90: p90, 95: p95]
    }

    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case level
        case metricType = "metric_type"
        case totalUsers = "total_users"
        case p5, p10, p15, p20, p25
        case p30, p35, p40, p45, p50
        case p55, p60, p65, p70, p75
        case p80, p85, p90, p95
    }
}

private nonisolated struct StreakDistributionRow: Decodable {
    let totalUsers: Int
    let p5: Int, p10: Int, p15: Int, p20: Int, p25: Int
    let p30: Int, p35: Int, p40: Int, p45: Int, p50: Int
    let p55: Int, p60: Int, p65: Int, p70: Int, p75: Int
    let p80: Int, p85: Int, p90: Int, p95: Int

    var breakpoints: [Int: Int] {
        [5: p5, 10: p10, 15: p15, 20: p20, 25: p25,
         30: p30, 35: p35, 40: p40, 45: p45, 50: p50,
         55: p55, 60: p60, 65: p65, 70: p70, 75: p75,
         80: p80, 85: p85, 90: p90, 95: p95]
    }

    enum CodingKeys: String, CodingKey {
        case totalUsers = "total_users"
        case p5, p10, p15, p20, p25
        case p30, p35, p40, p45, p50
        case p55, p60, p65, p70, p75
        case p80, p85, p90, p95
    }
}
