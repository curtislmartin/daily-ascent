#if DEBUG || TESTFLIGHT
import Foundation

enum DebugCheckKey: String, CaseIterable {
    // Scheduling & State
    case schedDueToday      = "debug.schedDueToday"
    case schedRestDay       = "debug.schedRestDay"
    case schedDueTomorrow   = "debug.schedDueTomorrow"
    case conflictDoubleTest = "debug.conflictDoubleTest"
    case conflictSameGroup  = "debug.conflictSameGroup"
    case schedTestDay       = "debug.schedTestDay"
    case advanceL2          = "debug.advanceL2"
    case advanceL3          = "debug.advanceL3"
    case showDemoNudge      = "debug.showDemoNudge"
    case streak0            = "debug.streak0"
    case streak1            = "debug.streak1"
    case streak7            = "debug.streak7"
    case streak30           = "debug.streak30"
    // Notifications
    case notifDailyReminder      = "debug.notifDailyReminder"
    case notifDailyReminderMulti = "debug.notifDailyReminderMulti"
    case notifTestDay            = "debug.notifTestDay"
    case notifStreakProtect0     = "debug.notifStreakProtect0"
    case notifStreakProtect7     = "debug.notifStreakProtect7"
    case notifLevelUnlock        = "debug.notifLevelUnlock"
    case notifScheduleAdj        = "debug.notifScheduleAdj"
    case notifList               = "debug.notifList"
    // History & Charts
    case histSeed4w    = "debug.histSeed4w"
    case histSeed12w   = "debug.histSeed12w"
    case histSeedGaps  = "debug.histSeedGaps"
    case histTestPass  = "debug.histTestPass"
    case histTestFail  = "debug.histTestFail"
    // Watch & HealthKit
    case watchSimReport    = "debug.watchSimReport"
    case watchPushSchedule = "debug.watchPushSchedule"
    case hkLogWorkout      = "debug.hkLogWorkout"
    // Upload & Sensor Data
    case uploadSeedPending = "debug.uploadSeedPending"
    case uploadTrigger     = "debug.uploadTrigger"
    case uploadStatus      = "debug.uploadStatus"
}
#endif
