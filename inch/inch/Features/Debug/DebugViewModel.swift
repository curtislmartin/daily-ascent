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
    func fireDailyReminder() { markDone(.notifDailyReminder) }
    func fireDailyReminderMulti() { markDone(.notifDailyReminderMulti) }
    func fireTestDayReminder() { markDone(.notifTestDay) }
    func fireStreakProtection(streak: Int, key: DebugCheckKey) { markDone(key) }
    func fireLevelUnlock(notificationService: NotificationService) { markDone(.notifLevelUnlock) }
    func fireScheduleAdjustment(notificationService: NotificationService) { markDone(.notifScheduleAdj) }
    func listPendingNotifications() {
        Task {
            let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
            alertTitle = "Pending Notifications (\(pending.count))"
            alertMessage = pending.isEmpty ? "None scheduled" : pending.map(\.identifier).joined(separator: "\n")
            showAlert = true
            markDone(.notifList)  // Inside Task — checkmark set after async fetch completes
        }
    }
    func seedHistory(weeks: Int, withGaps: Bool, key: DebugCheckKey, context: ModelContext) { markDone(key) }
    func addTestDayResult(passed: Bool, context: ModelContext) { markDone(passed ? .histTestPass : .histTestFail) }
    func simulateWatchReport(context: ModelContext, watchConnectivity: WatchConnectivityService) { markDone(.watchSimReport) }
    func pushScheduleToWatch(context: ModelContext, watchConnectivity: WatchConnectivityService) { markDone(.watchPushSchedule) }
    func logTestHealthKitWorkout(healthKit: HealthKitService) { markDone(.hkLogWorkout) }
    func seedPendingRecordings(context: ModelContext) { markDone(.uploadSeedPending) }
    func triggerForegroundUpload(context: ModelContext, dataUpload: DataUploadService) { markDone(.uploadTrigger) }
    func showUploadStatus(context: ModelContext) { markDone(.uploadStatus) }
    func clearAllHistory(context: ModelContext) {}    // No markDone — Danger Zone actions have no checkmarks
    func resetAllEnrolments(context: ModelContext) {} // No markDone — Danger Zone actions have no checkmarks
}
#endif
