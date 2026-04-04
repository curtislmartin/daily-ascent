import SwiftData
import Foundation
import InchShared

@Observable
final class TodayViewModel {
    var dueExercises: [ExerciseEnrolment] = []
    var completedTodayIds: Set<String> = []
    var inProgressTodayIds: Set<String> = []
    var isRestDay: Bool = false
    var conflictWarnings: [String: String] = [:]
    var nextTrainingDate: Date? = nil
    var nextTrainingCount: Int = 0
    private(set) var nextTrainingDayExercises: [(exerciseName: String, level: Int, dayNumber: Int)] = []
    private(set) var hasTrainedBefore: Bool = false
    /// Set to true on the load cycle where resetStreakForMissedDayIfNeeded resets the streak.
    /// Consumed by TodayView to schedule a recovery notification.
    private(set) var streakWasJustReset: Bool = false
    /// Advisor recommendation for today's training load. Nil until the first exercise is completed.
    var advisory: LoadAdvisory? = nil
    private(set) var pendingCelebrations: [Achievement] = []
    private let detector = ConflictDetector()
    private var analytics: AnalyticsService?
    /// Exercise IDs whose nextScheduledDate was before today when loadToday() ran.
    /// Captured each load call so rescheduled status is always current.
    private var rescheduledExerciseIds: Set<String> = []

    func configure(analytics: AnalyticsService) {
        self.analytics = analytics
    }

    func loadToday(context: ModelContext, showWarnings: Bool = true) {
        streakWasJustReset = false
        let today = Calendar.current.startOfDay(for: .now)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) ?? today
        let descriptor = FetchDescriptor<ExerciseEnrolment>(
            predicate: #Predicate { $0.isActive }
        )
        let all = (try? context.fetch(descriptor)) ?? []

        let todayStart = Calendar.current.startOfDay(for: .now)
        for enrolment in all {
            guard let scheduled = enrolment.nextScheduledDate,
                  Calendar.current.startOfDay(for: scheduled) < todayStart,
                  let def = enrolment.exerciseDefinition else { continue }
            let skips = max(1, Calendar.current.dateComponents([.day], from: scheduled, to: todayStart).day ?? 1)
            analytics?.record(AnalyticsEvent(
                name: "scheduled_session_skipped",
                properties: .scheduledSessionSkipped(
                    exerciseId: def.exerciseId,
                    level: enrolment.currentLevel,
                    dayNumber: enrolment.currentDay,
                    consecutiveSkips: skips
                )
            ))
        }

        let hasAnySets = (try? context.fetch(FetchDescriptor<CompletedSet>()))?.isEmpty == false
        hasTrainedBefore = hasAnySets

        // Exercises due today (scheduled today or overdue)
        let dueToday = all.filter { enrolment in
            guard let scheduled = enrolment.nextScheduledDate else { return false }
            return Calendar.current.startOfDay(for: scheduled) <= today
        }

        // Exercises completed today (may have advanced nextScheduledDate)
        let setsDescriptor = FetchDescriptor<CompletedSet>(
            predicate: #Predicate { $0.sessionDate >= today && $0.sessionDate < tomorrow }
        )
        let todaySets = (try? context.fetch(setsDescriptor)) ?? []

        // Group today's sets by exercise ID
        let setsByExercise = Dictionary(grouping: todaySets, by: \.exerciseId)

        // An exercise is fully complete when all prescribed sets are done
        let fullyCompletedIds = Set(all.compactMap { enrolment -> String? in
            guard let id = enrolment.exerciseDefinition?.exerciseId else { return nil }
            let completedCount = setsByExercise[id]?.count ?? 0
            let prescribedCount = currentPrescription(for: enrolment)?.sets.count ?? 0
            guard prescribedCount > 0, completedCount >= prescribedCount else { return nil }
            return id
        })

        completedTodayIds = fullyCompletedIds

        inProgressTodayIds = Set(all.compactMap { enrolment -> String? in
            guard let id = enrolment.exerciseDefinition?.exerciseId else { return nil }
            let completedCount = setsByExercise[id]?.count ?? 0
            let prescribedCount = currentPrescription(for: enrolment)?.sets.count ?? 0
            guard prescribedCount > 0, completedCount > 0, completedCount < prescribedCount else { return nil }
            return id
        })

        // Include completed-today exercises that are no longer in the due list
        let completedEnrolments = all.filter { enrolment in
            guard let id = enrolment.exerciseDefinition?.exerciseId else { return false }
            return fullyCompletedIds.contains(id) && !dueToday.contains(where: { $0.persistentModelID == enrolment.persistentModelID })
        }

        dueExercises = dueToday + completedEnrolments
        isRestDay = dueExercises.isEmpty

        // Any active enrolment whose nextScheduledDate is strictly before today was missed.
        let hasOverdueExercises = dueToday.contains { enrolment in
            guard let scheduled = enrolment.nextScheduledDate else { return false }
            return Calendar.current.startOfDay(for: scheduled) < today
        }

        computeNextTraining(from: all, after: today)

        if showWarnings {
            detectConflictsForToday()
        } else {
            conflictWarnings = [:]
        }
        deduplicateStreakRecordsIfNeeded(context: context)
        resetStreakForMissedDayIfNeeded(context: context, hasOverdueExercises: hasOverdueExercises)
        if !isRestDay {
            updateLastDueDateIfNeeded(context: context, today: today)
        }
        healStreakFromHistoryIfNeeded(context: context, today: today)
        buildAndRunAdvisor(context: context, all: all, todaySets: todaySets, today: today)

        let uncelebrated = (try? context.fetch(
            FetchDescriptor<Achievement>(predicate: #Predicate { !$0.wasCelebrated })
        )) ?? []
        pendingCelebrations = uncelebrated
    }

    private func computeNextTraining(from all: [ExerciseEnrolment], after today: Date) {
        nextTrainingDate = nil
        nextTrainingCount = 0
        nextTrainingDayExercises = []
        let futureDates = all.compactMap(\.nextScheduledDate)
            .map { Calendar.current.startOfDay(for: $0) }
            .filter { $0 > today }
        guard let nearest = futureDates.min() else { return }
        nextTrainingDate = nearest
        nextTrainingCount = all.filter { enrolment in
            guard let d = enrolment.nextScheduledDate else { return false }
            return Calendar.current.startOfDay(for: d) == nearest
        }.count
        // Populate exercise list for rest day upcoming session card
        nextTrainingDayExercises = all
            .filter { enrolment in
                guard let date = enrolment.nextScheduledDate else { return false }
                return Calendar.current.isDate(date, inSameDayAs: nearest)
            }
            .compactMap { enrolment -> (exerciseName: String, level: Int, dayNumber: Int)? in
                guard let name = enrolment.exerciseDefinition?.name else { return nil }
                return (exerciseName: name, level: enrolment.currentLevel, dayNumber: enrolment.currentDay)
            }
            .sorted { $0.exerciseName < $1.exerciseName }
    }

    private func detectConflictsForToday() {
        conflictWarnings = [:]
        let sessions: [ProjectedSession] = dueExercises.compactMap { enrolment in
            guard let def = enrolment.exerciseDefinition else { return nil }
            let isTest = currentPrescription(for: enrolment)?.isTest ?? false
            return ProjectedSession(
                exerciseId: def.exerciseId,
                muscleGroup: def.muscleGroup,
                isTest: isTest,
                date: .now,
                enrolmentId: def.exerciseId
            )
        }
        let conflicts = detector.detectConflicts(in: sessions)
        for conflict in conflicts {
            switch conflict {
            case .doubleTest(_, let ids):
                for id in ids {
                    conflictWarnings[id] = "Two test days scheduled today"
                }
            case .testWithSameGroupTraining(_, _, let trainingId):
                conflictWarnings[trainingId] = "Same muscle group as today's test"
            }
        }
    }

    private func deduplicateStreakRecordsIfNeeded(context: ModelContext) {
        let streaks = (try? context.fetch(FetchDescriptor<StreakState>())) ?? []
        guard streaks.count > 1 else { return }
        // Merge all records into the first one by taking the best value from each field,
        // then delete the rest. Multiple records accumulate when different ModelContexts
        // each create a new StreakState without seeing records saved by other contexts.
        let winner = streaks[0]
        for other in streaks.dropFirst() {
            if other.currentStreak > winner.currentStreak {
                winner.currentStreak = other.currentStreak
            }
            if other.longestStreak > winner.longestStreak {
                winner.longestStreak = other.longestStreak
            }
            if let d = other.lastActiveDate, d > (winner.lastActiveDate ?? .distantPast) {
                winner.lastActiveDate = d
            }
            if let d = other.lastDueDate, d > (winner.lastDueDate ?? .distantPast) {
                winner.lastDueDate = d
            }
            if let d = other.previousLastDueDate, d > (winner.previousLastDueDate ?? .distantPast) {
                winner.previousLastDueDate = d
            }
            context.delete(other)
        }
        try? context.save()
    }

    private func resetStreakForMissedDayIfNeeded(context: ModelContext, hasOverdueExercises: Bool) {
        let streaks = (try? context.fetch(FetchDescriptor<StreakState>())) ?? []
        guard let streakState = streaks.first else { return }
        guard StreakCalculator().shouldBreakStreak(
            currentStreak: streakState.currentStreak,
            hasOverdueExercises: hasOverdueExercises
        ) else { return }

        let brokenStreak = streakState.currentStreak
        streakState.currentStreak = 0
        streakWasJustReset = true
        analytics?.record(AnalyticsEvent(
            name: "streak_broken",
            properties: .streakBroken(streakLengthAtBreak: brokenStreak)
        ))
        try? context.save()
    }

    private func updateLastDueDateIfNeeded(context: ModelContext, today: Date) {
        let streaks = (try? context.fetch(FetchDescriptor<StreakState>())) ?? []
        guard let streakState = streaks.first else { return }
        guard streakState.lastDueDate.map({ !Calendar.current.isDate($0, inSameDayAs: today) }) ?? true else { return }
        // Preserve the old lastDueDate as previousLastDueDate so the streak calculator
        // can use it as the true "previous training day" reference. Without this,
        // lastDueDate equals today by the time a workout completes, and consecutive-day
        // streak increments silently fail.
        streakState.previousLastDueDate = streakState.lastDueDate
        streakState.lastDueDate = today
        try? context.save()
    }

    private func healStreakFromHistoryIfNeeded(context: ModelContext, today: Date) {
        let streaks = (try? context.fetch(FetchDescriptor<StreakState>())) ?? []
        guard let streakState = streaks.first else { return }
        let allSets = (try? context.fetch(FetchDescriptor<CompletedSet>())) ?? []
        let historical = StreakCalculator().recalculateStreak(
            from: allSets.map { $0.sessionDate },
            today: today
        )
        guard historical > streakState.currentStreak else { return }
        streakState.currentStreak = historical
        streakState.longestStreak = max(streakState.longestStreak, historical)
        try? context.save()
    }

    func currentPrescription(for enrolment: ExerciseEnrolment) -> DayPrescription? {
        enrolment.exerciseDefinition?
            .levels?
            .first(where: { $0.level == enrolment.currentLevel })?
            .days?
            .first(where: { $0.dayNumber == enrolment.currentDay })
    }

    // MARK: - Daily Load Advisor

    private func buildAndRunAdvisor(
        context: ModelContext,
        all: [ExerciseEnrolment],
        todaySets: [CompletedSet],
        today: Date
    ) {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        let endOfYesterday = startOfToday

        // Step 1: Capture rescheduled status.
        // Any active enrolment whose nextScheduledDate is strictly before today
        // was overdue when this load call ran.
        //
        // Timing note: writeBack() advances nextScheduledDate before loadToday() is
        // called again after a workout. This means rescheduledExerciseIds will be
        // non-empty only on a call where no sets have been completed yet (advisor
        // returns nil early). In practice wasRescheduled is always false for completed
        // exercises — the ×1.25 multiplier requires recording this flag into CompletedSet
        // at workout-recording time to work correctly. Tracked for a future improvement.
        rescheduledExerciseIds = Set(all.compactMap { enrolment -> String? in
            guard let scheduled = enrolment.nextScheduledDate,
                  Calendar.current.startOfDay(for: scheduled) < startOfToday,
                  let id = enrolment.exerciseDefinition?.exerciseId else { return nil }
            return id
        })

        // Step 2: Build completedToday records (one per exercise, collapsed from sets)
        let setsByExercise = Dictionary(grouping: todaySets, by: \.exerciseId)
        let completedToday: [CompletedExerciseRecord] = setsByExercise.compactMap { exerciseId, sets in
            guard let enrolment = all.first(where: { $0.exerciseDefinition?.exerciseId == exerciseId }),
                  let definition = enrolment.exerciseDefinition,
                  let anySet = sets.first else { return nil }
            return CompletedExerciseRecord(
                exerciseId: exerciseId,
                exerciseName: definition.name,
                muscleGroup: definition.muscleGroup,
                // Use the set's recorded value, not currentPrescription — after writeBack
                // advances currentDay, the prescription returns the next day's isTest value.
                isTest: anySet.isTest,
                wasRescheduled: rescheduledExerciseIds.contains(exerciseId)
            )
        }

        guard !completedToday.isEmpty else {
            advisory = nil
            return
        }

        // Step 3: Build dueButNotDone
        let completedIds = Set(completedToday.map(\.exerciseId))
        let dueButNotDone: [PendingExerciseRecord] = all.compactMap { enrolment in
            guard enrolment.isActive,
                  let scheduled = enrolment.nextScheduledDate,
                  Calendar.current.startOfDay(for: scheduled) <= startOfToday,
                  let definition = enrolment.exerciseDefinition,
                  !completedIds.contains(definition.exerciseId) else { return nil }
            let isTest = currentPrescription(for: enrolment)?.isTest ?? false
            return PendingExerciseRecord(
                exerciseId: definition.exerciseId,
                exerciseName: definition.name,
                muscleGroup: definition.muscleGroup,
                isTest: isTest
            )
        }

        // Step 4: Build testDaysInNext48h using SchedulingEngine.projectSchedule()
        let engine = SchedulingEngine()
        let fortyEightHoursFromNow = Date.now.addingTimeInterval(48 * 3600)
        var testDaysInNext48h: [(exerciseId: String, exerciseName: String, scheduledDate: Date)] = []

        for enrolment in all where enrolment.isActive {
            guard let definition = enrolment.exerciseDefinition,
                  let levelDef = definition.levels?.first(where: { $0.level == enrolment.currentLevel }),
                  let rawStartDate = enrolment.nextScheduledDate else { continue }
            let startDate = max(rawStartDate, startOfToday)
            let enrolmentSnapshot = EnrolmentSnapshot(enrolment)
            let levelSnapshot = LevelSnapshot(levelDef)
            let daySnapshots = (levelDef.days ?? []).map { DaySnapshot($0) }
            let projected = engine.projectSchedule(
                enrolment: enrolmentSnapshot,
                level: levelSnapshot,
                days: daySnapshots,
                startDate: startDate,
                upTo: 5
            )
            if let upcoming = projected.first(where: {
                $0.isTest && $0.scheduledDate > startOfToday && $0.scheduledDate <= fortyEightHoursFromNow
            }) {
                testDaysInNext48h.append((
                    exerciseId: definition.exerciseId,
                    exerciseName: definition.name,
                    scheduledDate: upcoming.scheduledDate
                ))
            }
        }

        // Step 5: Build yesterdayCompletions
        let yesterdayStart = yesterday
        let yesterdayEnd = endOfYesterday
        let yesterdayDescriptor = FetchDescriptor<CompletedSet>(
            predicate: #Predicate { $0.sessionDate >= yesterdayStart && $0.sessionDate < yesterdayEnd }
        )
        let yesterdaySets = (try? context.fetch(yesterdayDescriptor)) ?? []
        let yesterdayByExercise = Dictionary(grouping: yesterdaySets, by: \.exerciseId)
        let yesterdayCompletions: [CompletedExerciseRecord] = yesterdayByExercise.compactMap { exerciseId, sets in
            guard let enrolment = all.first(where: { $0.exerciseDefinition?.exerciseId == exerciseId }),
                  let definition = enrolment.exerciseDefinition,
                  let anySet = sets.first else { return nil }
            return CompletedExerciseRecord(
                exerciseId: exerciseId,
                exerciseName: definition.name,
                muscleGroup: definition.muscleGroup,
                isTest: anySet.isTest,
                wasRescheduled: false
            )
        }

        // Step 6: Run advisor
        let loadContext = DailyLoadContext(
            completedToday: completedToday,
            dueButNotDone: dueButNotDone,
            testDaysInNext48h: testDaysInNext48h,
            yesterdayCompletions: yesterdayCompletions
        )
        advisory = DailyLoadAdvisor().recommend(context: loadContext)
    }
}
