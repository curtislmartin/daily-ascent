#if DEBUG
import Foundation
import SwiftData
import UserNotifications
import InchShared

@Observable
final class DebugViewModel {
    // MARK: - Checkmark State

    private let defaults = UserDefaults.standard
    private var doneKeys: Set<DebugCheckKey>  // @Observable-tracked mirror of UserDefaults

    init() {
        doneKeys = Set(DebugCheckKey.allCases.filter {
            UserDefaults.standard.bool(forKey: $0.rawValue)
        })
    }

    func isDone(_ key: DebugCheckKey) -> Bool {
        doneKeys.contains(key)
    }

    func markDone(_ key: DebugCheckKey) {
        doneKeys.insert(key)
        defaults.set(true, forKey: key.rawValue)
    }

    func resetAllDone() {
        doneKeys.removeAll()
        for key in DebugCheckKey.allCases {
            defaults.removeObject(forKey: key.rawValue)
        }
    }

    // MARK: - Info Alert State (non-destructive feedback)

    var alertTitle: String = ""
    var alertMessage: String = ""
    var showAlert: Bool = false

    // MARK: - Danger Confirmation State

    var dangerTitle: String = ""
    var dangerMessage: String = ""
    var pendingDangerAction: (() -> Void)? = nil
    var showDangerConfirmation: Bool = false

    func confirmDanger(title: String, message: String, action: @escaping () -> Void) {
        dangerTitle = title
        dangerMessage = message
        pendingDangerAction = action
        showDangerConfirmation = true
    }

    // MARK: - Scheduling & State Actions

    func setDueToday(context: ModelContext) {
        let desc = FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
        guard let enrolments = try? context.fetch(desc) else { return }
        for e in enrolments { e.nextScheduledDate = Date.now }
        try? context.save()
        markDone(.schedDueToday)
    }

    func forceRestDay(context: ModelContext) {
        let tomorrow = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date.now) ?? Date.now
        )
        let desc = FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
        guard let enrolments = try? context.fetch(desc) else { return }
        for e in enrolments { e.nextScheduledDate = tomorrow }
        try? context.save()
        markDone(.schedRestDay)
    }

    func setDueTomorrow(context: ModelContext) {
        let tomorrow = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date.now) ?? Date.now
        )
        let desc = FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
        guard let enrolments = try? context.fetch(desc) else { return }
        for e in enrolments { e.nextScheduledDate = tomorrow }
        try? context.save()
        markDone(.schedDueTomorrow)
    }

    func triggerDoubleTestConflict(context: ModelContext) {
        let desc = FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
        guard let enrolments = try? context.fetch(desc) else { return }
        let candidates = enrolments.compactMap { e -> (ExerciseEnrolment, Int)? in
            guard let levelDef = e.exerciseDefinition?.levels?.first(where: { $0.level == e.currentLevel }),
                  let totalDays = levelDef.days?.count, totalDays > 0 else { return nil }
            return (e, totalDays)
        }
        guard candidates.count >= 2 else { return }
        for (e, testDay) in candidates.prefix(2) {
            e.currentDay = testDay
            e.nextScheduledDate = Date.now
        }
        try? context.save()
        markDone(.conflictDoubleTest)
    }

    func triggerSameGroupConflict(context: ModelContext) {
        let desc = FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
        guard let enrolments = try? context.fetch(desc) else { return }
        if let squats = enrolments.first(where: { $0.exerciseDefinition?.exerciseId == "squats" }),
           let levelDef = squats.exerciseDefinition?.levels?.first(where: { $0.level == squats.currentLevel }),
           let totalDays = levelDef.days?.count {
            squats.currentDay = totalDays
            squats.nextScheduledDate = Date.now
        }
        if let glutes = enrolments.first(where: { $0.exerciseDefinition?.exerciseId == "glute_bridges" }) {
            glutes.currentDay = 1
            glutes.nextScheduledDate = Date.now
        }
        try? context.save()
        markDone(.conflictSameGroup)
    }

    func setExerciseToTestDay(context: ModelContext) {
        let desc = FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
        guard let enrolments = try? context.fetch(desc),
              let pushUps = enrolments.first(where: { $0.exerciseDefinition?.exerciseId == "push_ups" }),
              let levelDef = pushUps.exerciseDefinition?.levels?.first(where: { $0.level == pushUps.currentLevel }),
              let totalDays = levelDef.days?.count else { return }
        pushUps.currentDay = totalDays
        pushUps.nextScheduledDate = Date.now
        try? context.save()
        markDone(.schedTestDay)
    }

    func advancePushUpsToLevel(_ level: Int, context: ModelContext, key: DebugCheckKey) {
        let desc = FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
        guard let enrolments = try? context.fetch(desc),
              let pushUps = enrolments.first(where: { $0.exerciseDefinition?.exerciseId == "push_ups" }) else { return }
        pushUps.currentLevel = level
        pushUps.currentDay = 1
        pushUps.restPatternIndex = 0
        pushUps.nextScheduledDate = Date.now
        try? context.save()
        markDone(key)
    }

    func showDemographicsNudge(context: ModelContext) {
        let desc = FetchDescriptor<UserSettings>()
        guard let settings = (try? context.fetch(desc))?.first else { return }
        settings.ageRange = nil
        settings.heightRange = nil
        settings.biologicalSex = nil
        settings.activityLevel = nil
        try? context.save()
        markDone(.showDemoNudge)
    }

    func setStreak(_ value: Int, key: DebugCheckKey, context: ModelContext) {
        let desc = FetchDescriptor<StreakState>()
        let existing = (try? context.fetch(desc))?.first
        let state: StreakState
        if let existing {
            state = existing
        } else {
            state = StreakState()
            context.insert(state)
        }
        state.currentStreak = value
        state.longestStreak = value
        state.lastActiveDate = value > 0 ? Date.now : nil
        try? context.save()
        markDone(key)
    }
    private func postDebugNotification(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        let request = UNNotificationRequest(identifier: "debug-\(id)-\(UUID().uuidString)",
                                            content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func fireDailyReminder() {
        postDebugNotification(id: "daily", title: "Time to train", body: "Push-Ups")
        markDone(.notifDailyReminder)
    }

    func fireDailyReminderMulti() {
        postDebugNotification(id: "daily-multi", title: "Time to train",
                              body: "3 exercises today — Push-Ups, Squats, Sit-Ups")
        markDone(.notifDailyReminderMulti)
    }

    func fireTestDayReminder() {
        postDebugNotification(id: "testday", title: "Test day", body: "Push-Ups — max reps today")
        markDone(.notifTestDay)
    }

    func fireStreakProtection(streak: Int, key: DebugCheckKey) {
        if streak > 1 {
            postDebugNotification(id: "streak-protect", title: "Don't break your streak",
                                  body: "\(streak)-day streak — 3 exercises still waiting")
        } else {
            postDebugNotification(id: "streak-protect-0", title: "Start building your streak",
                                  body: "3 exercises due today")
        }
        markDone(key)
    }

    func fireLevelUnlock(notificationService: NotificationService) {
        notificationService.postLevelUnlock(exerciseName: "Push-Ups", newLevel: 2, startsIn: 2)
        markDone(.notifLevelUnlock)
    }

    func fireScheduleAdjustment(notificationService: NotificationService) {
        notificationService.postScheduleAdjustment(exerciseName: "Push-Ups", newDateDescription: "tomorrow")
        markDone(.notifScheduleAdj)
    }

    func listPendingNotifications() {
        Task {
            let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
            alertTitle = "Pending Notifications (\(pending.count))"
            alertMessage = pending.isEmpty ? "None scheduled" : pending.map(\.identifier).joined(separator: "\n")
            showAlert = true
            markDone(.notifList)  // Inside Task — checkmark set after async fetch completes
        }
    }
    private func insertSets(
        exerciseId: String,
        level: Int,
        dayNumber: Int,
        setCount: Int,
        repsPerSet: Int,
        sessionDate: Date,
        context: ModelContext
    ) {
        for i in 1...setCount {
            context.insert(CompletedSet(
                completedAt: sessionDate,
                sessionDate: sessionDate,
                exerciseId: exerciseId,
                level: level,
                dayNumber: dayNumber,
                setNumber: i,
                targetReps: repsPerSet,
                actualReps: repsPerSet
            ))
        }
    }

    func seedHistory(weeks: Int, withGaps: Bool, key: DebugCheckKey, context: ModelContext) {
        let exercises: [(id: String, reps: Int)] = [
            (id: "push_ups", reps: 10),
            (id: "squats",   reps: 12),
            (id: "sit_ups",  reps: 10),
        ]
        var dayNumbers = [String: Int]()
        exercises.forEach { dayNumbers[$0.id] = 1 }

        let totalCalendarDays = weeks * 7
        let gapStart = totalCalendarDays / 2       // gap begins here
        let gapEnd   = gapStart + 5                // 5-day gap

        var calendarOffset = 0
        var workoutCount = 0

        while calendarOffset < totalCalendarDays {
            if withGaps && calendarOffset >= gapStart && calendarOffset < gapEnd {
                calendarOffset += 1
                continue
            }
            let ex = exercises[workoutCount % exercises.count]
            let daysAgo = totalCalendarDays - calendarOffset
            let sessionDate = Calendar.current.date(
                byAdding: .day,
                value: -daysAgo,
                to: Calendar.current.startOfDay(for: Date.now)
            ) ?? Date.now

            let dn = dayNumbers[ex.id] ?? 1
            insertSets(exerciseId: ex.id, level: 1, dayNumber: dn,
                       setCount: 3, repsPerSet: ex.reps, sessionDate: sessionDate, context: context)
            dayNumbers[ex.id] = dn + 1
            workoutCount += 1

            // Rest pattern: 2, 2, 3, 2, 2, 3...
            calendarOffset += (workoutCount % 3 == 0) ? 3 : 2
        }
        try? context.save()
        markDone(key)
    }

    func addTestDayResult(passed: Bool, context: ModelContext) {
        context.insert(CompletedSet(
            completedAt: Date.now,
            sessionDate: Date.now,
            exerciseId: "push_ups",
            level: 1,
            dayNumber: 10,
            setNumber: 1,
            targetReps: 50,
            actualReps: passed ? 55 : 43,
            isTest: true,
            testPassed: passed
        ))
        try? context.save()
        markDone(passed ? .histTestPass : .histTestFail)
    }
    func simulateWatchReport(context: ModelContext, watchConnectivity: WatchConnectivityService) {
        let report = WatchCompletionReport(
            exerciseId: "push_ups",
            level: 1,
            dayNumber: 1,
            completedSets: [
                WatchSetResult(setNumber: 1, targetReps: 10, actualReps: 10, durationSeconds: 30),
                WatchSetResult(setNumber: 2, targetReps: 10, actualReps: 10, durationSeconds: 28),
                WatchSetResult(setNumber: 3, targetReps: 10, actualReps: 10, durationSeconds: 32),
            ],
            completedAt: Date.now
        )
        watchConnectivity.simulateCompletionReport(report)
        markDone(.watchSimReport)
    }

    func pushScheduleToWatch(context: ModelContext, watchConnectivity: WatchConnectivityService) {
        let enrolmentsDesc = FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive })
        let enrolments = (try? context.fetch(enrolmentsDesc)) ?? []
        let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first
        watchConnectivity.sendTodaySchedule(enrolments: enrolments, settings: settings)
        markDone(.watchPushSchedule)
    }

    func logTestHealthKitWorkout(healthKit: HealthKitService) {
        Task {
            await healthKit.requestAuthorization()
            let end = Date.now
            let start = end.addingTimeInterval(-600) // 10 minutes ago
            await healthKit.saveWorkout(
                startDate: start,
                endDate: end,
                totalEnergyBurned: nil,
                metadata: [:]
            )
            markDone(.hkLogWorkout)
        }
    }
    func seedPendingRecordings(context: ModelContext) { markDone(.uploadSeedPending) }
    func triggerForegroundUpload(context: ModelContext, dataUpload: DataUploadService) { markDone(.uploadTrigger) }
    func showUploadStatus(context: ModelContext) { markDone(.uploadStatus) }
    func clearAllHistory(context: ModelContext) {}    // No markDone — Danger Zone actions have no checkmarks
    func resetAllEnrolments(context: ModelContext) {} // No markDone — Danger Zone actions have no checkmarks
}
#endif
