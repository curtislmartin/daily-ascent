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

    // MARK: - Action stubs (replaced in Tasks 5–10)
    func setDueToday(context: ModelContext) { markDone(.schedDueToday) }
    func forceRestDay(context: ModelContext) { markDone(.schedRestDay) }
    func setDueTomorrow(context: ModelContext) { markDone(.schedDueTomorrow) }
    func triggerDoubleTestConflict(context: ModelContext) { markDone(.conflictDoubleTest) }
    func triggerSameGroupConflict(context: ModelContext) { markDone(.conflictSameGroup) }
    func setExerciseToTestDay(context: ModelContext) { markDone(.schedTestDay) }
    func advancePushUpsToLevel(_ level: Int, context: ModelContext, key: DebugCheckKey) { markDone(key) }
    func showDemographicsNudge(context: ModelContext) { markDone(.showDemoNudge) }
    func setStreak(_ value: Int, key: DebugCheckKey, context: ModelContext) { markDone(key) }
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
