import Foundation
import SwiftData
import InchShared

enum WorkoutPhase: Equatable {
    case loading
    case ready
    case preparingTimedSet(targetSeconds: Int)  // pre-set countdown
    case inTimedSet(targetSeconds: Int)          // active hold (view owns elapsed timer)
    case inSet(startedAt: Date)
    case confirming(targetReps: Int, duration: Double)
    case resting(restSeconds: Int)
    case complete
}

@Observable
final class WorkoutViewModel {
    private let enrolmentId: PersistentIdentifier
    private var analytics: AnalyticsService?
    private var sessionStartDate: Date = .now

    var phase: WorkoutPhase = .loading
    var currentSetIndex: Int = 0
    var enrolment: ExerciseEnrolment?
    var prescription: DayPrescription?

    private(set) var sessionDate: Date = .now
    var sessionTotalReps: Int = 0
    private(set) var previousSessionReps: Int? = nil
    private(set) var didAdvanceLevel: Bool = false
    private(set) var newLevel: Int = 0
    private(set) var completedLevel: Int = 0
    private(set) var completedDay: Int = 0
    var pendingAchievements: [Achievement] = []
    private let scheduler = SchedulingEngine()

    var exerciseName: String { enrolment?.exerciseDefinition?.name ?? "" }
    var accentColorHex: String { enrolment?.exerciseDefinition?.color ?? "" }
    var countingMode: CountingMode { enrolment?.exerciseDefinition?.countingMode ?? .postSetConfirmation }
    var restSeconds: Int { enrolment?.exerciseDefinition?.defaultRestSeconds ?? 60 }
    var currentTargetReps: Int { prescription?.sets[safe: currentSetIndex] ?? 0 }
    var isTimedExercise: Bool { countingMode == .timed }
    var totalSets: Int { prescription?.sets.count ?? 0 }
    var isTestDay: Bool { prescription?.isTest ?? false }
    var variationName: String? {
        enrolment?.exerciseDefinition?
            .levels?
            .first(where: { $0.level == (enrolment?.currentLevel ?? 0) })?
            .variationName
    }

    init(enrolmentId: PersistentIdentifier) {
        self.enrolmentId = enrolmentId
    }

    func configure(analytics: AnalyticsService) {
        self.analytics = analytics
    }

    func load(context: ModelContext) {
        let enrolment: ExerciseEnrolment? = context.registeredModel(for: enrolmentId)
            ?? fetchEnrolment(context: context)
        guard let enrolment else { return }
        self.enrolment = enrolment
        self.prescription = currentPrescription(for: enrolment)
        loadPreviousSession(exerciseId: enrolment.exerciseDefinition?.exerciseId, context: context)
        sessionDate = .now
        phase = .ready
        guard let def = enrolment.exerciseDefinition else { return }
        sessionStartDate = .now
        analytics?.record(AnalyticsEvent(
            name: "workout_started",
            properties: .workoutStarted(
                exerciseId: def.exerciseId,
                level: enrolment.currentLevel,
                dayNumber: enrolment.currentDay
            )
        ))
    }

    func startSet() {
        phase = .inSet(startedAt: .now)
    }

    func endSet() {
        guard case .inSet(let startedAt) = phase else { return }
        let duration = Date.now.timeIntervalSince(startedAt)
        phase = .confirming(targetReps: currentTargetReps, duration: duration)
    }

    func startTimedSet() {
        phase = .preparingTimedSet(targetSeconds: currentTargetReps)
    }

    func countdownComplete() {
        guard case .preparingTimedSet(let target) = phase else { return }
        phase = .inTimedSet(targetSeconds: target)
    }

    func confirmSet(actual: Int, context: ModelContext, recordingURL: URL? = nil, duration: Double = 0) {
        saveSet(actualReps: actual, duration: duration, context: context, recordingURL: recordingURL)
        advanceAfterSet(context: context)
    }

    func completeRealTimeSet(actual: Int, context: ModelContext, recordingURL: URL? = nil, duration: Double = 0) {
        saveSet(actualReps: actual, duration: duration, context: context, recordingURL: recordingURL)
        advanceAfterSet(context: context)
    }

    func completeTimedSet(actualDuration: Double, context: ModelContext, recordingURL: URL? = nil) {
        guard case .inTimedSet(let target) = phase else { return }
        saveTimedSet(targetDuration: target, actualDuration: actualDuration, context: context, recordingURL: recordingURL)
        advanceAfterSet(context: context)
    }

    func finishRest() {
        phase = .ready
    }

    // MARK: - Private

    private func advanceAfterSet(context: ModelContext) {
        let nextIndex = currentSetIndex + 1
        if nextIndex >= totalSets {
            completeSession(context: context)
        } else {
            currentSetIndex = nextIndex
            phase = .resting(restSeconds: restSeconds)
        }
    }

    private func saveTimedSet(targetDuration: Int, actualDuration: Double, context: ModelContext, recordingURL: URL? = nil) {
        guard let enrolment, let prescription, let def = enrolment.exerciseDefinition else { return }

        let todayStart = Calendar.current.startOfDay(for: Date.now)
        let allSets = (try? context.fetch(FetchDescriptor<CompletedSet>())) ?? []
        let totalSetsToday = allSets.filter { $0.completedAt >= todayStart }.count

        let completedSet = CompletedSet(
            sessionDate: sessionDate,
            exerciseId: def.exerciseId,
            level: enrolment.currentLevel,
            dayNumber: enrolment.currentDay,
            setNumber: currentSetIndex + 1,
            targetReps: 0,
            actualReps: 0,
            isTest: prescription.isTest,
            countingMode: .timed,
            setDurationSeconds: actualDuration,
            targetDurationSeconds: targetDuration
        )
        completedSet.enrolment = enrolment
        context.insert(completedSet)

        if let recordingURL {
            let attrs = try? FileManager.default.attributesOfItem(atPath: recordingURL.path)
            let fileSize = (attrs?[.size] as? Int) ?? 0

            let recording = SensorRecording(
                device: .iPhone,
                exerciseId: def.exerciseId,
                level: enrolment.currentLevel,
                dayNumber: enrolment.currentDay,
                setNumber: currentSetIndex + 1,
                confirmedReps: 0,
                sampleRateHz: 100,
                durationSeconds: actualDuration,
                countingMode: CountingMode.timed.rawValue,
                filePath: recordingURL.path,
                fileSizeBytes: fileSize
            )
            recording.completedSet = completedSet
            context.insert(recording)
        }

        sessionTotalReps += 0
        try? context.save()
    }

    private func saveSet(actualReps: Int, duration: Double = 0, context: ModelContext, recordingURL: URL? = nil) {
        guard let enrolment, let prescription, let def = enrolment.exerciseDefinition else { return }
        let completedSet = CompletedSet(
            sessionDate: sessionDate,
            exerciseId: def.exerciseId,
            level: enrolment.currentLevel,
            dayNumber: enrolment.currentDay,
            setNumber: currentSetIndex + 1,
            targetReps: currentTargetReps,
            actualReps: actualReps,
            isTest: prescription.isTest,
            countingMode: countingMode
        )
        completedSet.enrolment = enrolment
        context.insert(completedSet)

        if let recordingURL {
            let attrs = try? FileManager.default.attributesOfItem(atPath: recordingURL.path)
            let fileSize = (attrs?[.size] as? Int) ?? 0
            let recording = SensorRecording(
                device: .iPhone,
                exerciseId: def.exerciseId,
                level: enrolment.currentLevel,
                dayNumber: enrolment.currentDay,
                setNumber: currentSetIndex + 1,
                confirmedReps: actualReps,
                sampleRateHz: 100,
                durationSeconds: duration,
                countingMode: countingMode.rawValue,
                filePath: recordingURL.path,
                fileSizeBytes: fileSize
            )
            recording.completedSet = completedSet
            context.insert(recording)
        }

        sessionTotalReps += actualReps
        try? context.save()
    }

    private func completeSession(context: ModelContext) {
        guard let enrolment,
              let def = enrolment.exerciseDefinition,
              let levelDef = def.levels?.first(where: { $0.level == enrolment.currentLevel })
        else { return }

        let snapshot = EnrolmentSnapshot(enrolment)
        let levelSnap = LevelSnapshot(levelDef)
        let updated = scheduler.applyCompletion(
            to: snapshot,
            level: levelSnap,
            actualDate: sessionDate,
            totalReps: sessionTotalReps
        )
        completedLevel = snapshot.currentLevel
        completedDay = snapshot.currentDay
        didAdvanceLevel = updated.currentLevel > snapshot.currentLevel
        newLevel = updated.currentLevel
        let nextDate = scheduler.computeNextDate(enrolment: updated, level: levelSnap)
        scheduler.writeBack(updated, to: enrolment, nextDate: nextDate)
        resolveScheduleConflicts(context: context)
        updateStreak(context: context)
        try? context.save()
        phase = .complete

        // Achievement check — capture values before analytics
        let achChecker = AchievementChecker()
        let achExerciseId = def.exerciseId
        let achLevel = completedLevel
        let achReps = sessionTotalReps
        let achDidAdvance = didAdvanceLevel
        let achIsTestDay = isTestDay
        let achSessionDate = sessionDate

        var newAchievements = achChecker.check(
            after: .workoutCompleted(
                exerciseId: achExerciseId,
                totalReps: achReps,
                level: achLevel,
                sessionDate: achSessionDate
            ),
            in: context
        )

        if achIsTestDay && achDidAdvance {
            newAchievements += achChecker.check(
                after: .testPassed(
                    exerciseId: achExerciseId,
                    level: achLevel,
                    sessionDate: achSessionDate
                ),
                in: context
            )
        }

        for achievement in newAchievements {
            if achievement.category == "performance",
               let existingAch = (try? context.fetch(FetchDescriptor<Achievement>()))?.first(where: { $0.id == achievement.id }) {
                existingAch.numericValue = achievement.numericValue
                existingAch.unlockedAt = .now
            } else {
                context.insert(achievement)
            }
        }
        try? context.save()
        pendingAchievements = newAchievements

        let exerciseId = def.exerciseId
        let duration = Int(Date.now.timeIntervalSince(sessionStartDate))
        let wasTestDay = isTestDay
        let didAdvance = didAdvanceLevel
        let advancedToLevel = newLevel
        let capturedTotalReps = sessionTotalReps
        let capturedTotalSets = totalSets
        let capturedCompletedLevel = completedLevel
        let capturedCompletedDay = completedDay
        let capturedCountingMode = countingMode.rawValue

        analytics?.record(AnalyticsEvent(
            name: "workout_completed",
            properties: .workoutCompleted(
                exerciseId: exerciseId,
                level: capturedCompletedLevel,
                dayNumber: capturedCompletedDay,
                totalSets: capturedTotalSets,
                totalReps: capturedTotalReps,
                durationSeconds: duration,
                countingMode: capturedCountingMode
            )
        ))
        if wasTestDay {
            analytics?.record(AnalyticsEvent(
                name: "level_test_attempted",
                properties: .levelTestAttempted(
                    exerciseId: exerciseId,
                    currentLevel: capturedCompletedLevel
                )
            ))
        }
        if didAdvance {
            analytics?.record(AnalyticsEvent(
                name: "level_advanced",
                properties: .levelAdvanced(
                    exerciseId: exerciseId,
                    fromLevel: capturedCompletedLevel,
                    toLevel: advancedToLevel,
                    maxRepsAchieved: capturedTotalReps
                )
            ))
        }
    }

    /// Runs the conflict detect → resolve loop (up to maxIterations) after any schedule change,
    /// pushing conflicting enrolments forward by 1 day until no conflicts remain.
    private func resolveScheduleConflicts(context: ModelContext) {
        let allEnrolments = (try? context.fetch(
            FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
        )) ?? []

        let detector = ConflictDetector()
        let resolver = ConflictResolver()

        for _ in 0..<resolver.maxIterations {
            let sessions = projectedSessions(from: allEnrolments)
            let conflicts = detector.detectConflicts(in: sessions)
            guard !conflicts.isEmpty else { break }

            let adjustments = resolver.resolve(
                conflicts: conflicts,
                sessions: sessions,
                remainingDays: { exerciseId in
                    guard let e = allEnrolments.first(where: { $0.exerciseDefinition?.exerciseId == exerciseId }),
                          let def = e.exerciseDefinition,
                          let levelDef = def.levels?.first(where: { $0.level == e.currentLevel })
                    else { return 0 }
                    return levelDef.totalDays - e.currentDay
                }
            )
            guard !adjustments.isEmpty else { break }

            for adj in adjustments {
                guard let e = allEnrolments.first(where: { $0.exerciseDefinition?.exerciseId == adj.enrolmentId }),
                      let current = e.nextScheduledDate
                else { continue }
                e.nextScheduledDate = Calendar.current.date(byAdding: .day, value: 1, to: current)
            }
        }
    }

    private func projectedSessions(from enrolments: [ExerciseEnrolment]) -> [ProjectedSession] {
        let today = Calendar.current.startOfDay(for: .now)
        guard let weekOut = Calendar.current.date(byAdding: .day, value: 7, to: today) else { return [] }
        return enrolments.compactMap { e in
            guard let scheduled = e.nextScheduledDate,
                  let def = e.exerciseDefinition
            else { return nil }
            let day = Calendar.current.startOfDay(for: scheduled)
            guard day >= today, day <= weekOut else { return nil }
            let isTest = def.levels?
                .first(where: { $0.level == e.currentLevel })?
                .days?
                .first(where: { $0.dayNumber == e.currentDay })?
                .isTest ?? false
            return ProjectedSession(
                exerciseId: def.exerciseId,
                muscleGroup: def.muscleGroup,
                isTest: isTest,
                date: scheduled,
                enrolmentId: def.exerciseId
            )
        }
    }

    private func updateStreak(context: ModelContext) {
        let calculator = StreakCalculator()
        let streaks = (try? context.fetch(FetchDescriptor<StreakState>())) ?? []
        let streakState: StreakState
        if let existing = streaks.first {
            streakState = existing
        } else {
            streakState = StreakState()
            context.insert(streakState)
        }
        calculator.updateStreakState(streakState, today: sessionDate, hadDueExercises: true, completedAny: true)
    }

    private func currentPrescription(for enrolment: ExerciseEnrolment) -> DayPrescription? {
        enrolment.exerciseDefinition?
            .levels?
            .first(where: { $0.level == enrolment.currentLevel })?
            .days?
            .first(where: { $0.dayNumber == enrolment.currentDay })
    }

    private func fetchEnrolment(context: ModelContext) -> ExerciseEnrolment? {
        let all = (try? context.fetch(FetchDescriptor<ExerciseEnrolment>())) ?? []
        return all.first(where: { $0.persistentModelID == enrolmentId })
    }

    private func loadPreviousSession(exerciseId: String?, context: ModelContext) {
        guard let exerciseId else { return }
        let today = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<CompletedSet>(
            predicate: #Predicate { $0.exerciseId == exerciseId && $0.sessionDate < today },
            sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]
        )
        guard let sets = try? context.fetch(descriptor), let lastSet = sets.first else { return }
        let lastDay = Calendar.current.startOfDay(for: lastSet.sessionDate)
        guard let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: lastDay) else { return }
        previousSessionReps = sets
            .filter { $0.sessionDate >= lastDay && $0.sessionDate < nextDay }
            .reduce(0) { $0 + $1.actualReps }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
