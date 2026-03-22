#if DEBUG || TESTFLIGHT
import SwiftUI
import SwiftData
import InchShared

// MARK: - Debug UI extension on SettingsView

extension SettingsView {

    /// All debug sections, embedded in SettingsView's List via #if DEBUG || TESTFLIGHT.
    @ViewBuilder
    var debugContent: some View {
        debugSchedulingSection
        debugNotificationsSection
        debugHistorySection
        debugWatchSection
        debugUploadSection
        debugDangerSection
    }

    // MARK: - Scheduling & State

    var debugSchedulingSection: some View {
        Section("Scheduling & State") {
            debugRow("Set exercises due today",
                     sub: "Schedule all enrolments for today",
                     key: .schedDueToday) {
                debugViewModel.setDueToday(context: modelContext)
            }
            debugRow("Force rest day",
                     sub: "Push all exercises to tomorrow → RestDayView",
                     key: .schedRestDay) {
                debugViewModel.forceRestDay(context: modelContext)
            }
            debugRow("Set exercises due tomorrow",
                     sub: "RestDayView 'next training tomorrow' subtext",
                     key: .schedDueTomorrow) {
                debugViewModel.setDueTomorrow(context: modelContext)
            }
            debugRow("Trigger double-test conflict",
                     sub: "Two exercises on test day → 'Two test days scheduled today'",
                     key: .conflictDoubleTest) {
                debugViewModel.triggerDoubleTestConflict(context: modelContext)
            }
            debugRow("Trigger same-group conflict",
                     sub: "Squats (test) + Glute Bridges → 'Same muscle group as today's test'",
                     key: .conflictSameGroup) {
                debugViewModel.triggerSameGroupConflict(context: modelContext)
            }
            debugRow("Set exercise to test day",
                     sub: "Advance Push-Ups currentDay to its test day",
                     key: .schedTestDay) {
                debugViewModel.setExerciseToTestDay(context: modelContext)
            }
            debugRow("Advance exercise to L2",
                     sub: "Push-Ups → Level 2 Day 1",
                     key: .advanceL2) {
                debugViewModel.advancePushUpsToLevel(2, context: modelContext, key: .advanceL2)
            }
            debugRow("Advance exercise to L3",
                     sub: "Push-Ups → Level 3 Day 1",
                     key: .advanceL3) {
                debugViewModel.advancePushUpsToLevel(3, context: modelContext, key: .advanceL3)
            }
            debugRow("Show demographics nudge",
                     sub: "Clear all demographic fields → nudge reappears on Today",
                     key: .showDemoNudge) {
                debugViewModel.showDemographicsNudge(context: modelContext)
            }
            debugRow("Set streak → 0 days",
                     sub: "No flame badge, no streak card on rest day",
                     key: .streak0) {
                debugViewModel.setStreak(0, key: .streak0, context: modelContext)
            }
            debugRow("Set streak → 1 day",
                     sub: "Edge case: 'Start building your streak' messaging",
                     key: .streak1) {
                debugViewModel.setStreak(1, key: .streak1, context: modelContext)
            }
            debugRow("Set streak → 7 days",
                     sub: "Flame badge, streak card, streak protection messaging",
                     key: .streak7) {
                debugViewModel.setStreak(7, key: .streak7, context: modelContext)
            }
            debugRow("Set streak → 30 days",
                     sub: "Tests large number rendering throughout",
                     key: .streak30) {
                debugViewModel.setStreak(30, key: .streak30, context: modelContext)
            }
        }
    }

    // MARK: - Notifications

    var debugNotificationsSection: some View {
        Section("Notifications") {
            debugRow("Fire daily reminder now",
                     sub: "Title: 'Time to train' · Body: 'Push-Ups'",
                     key: .notifDailyReminder) {
                debugViewModel.fireDailyReminder()
            }
            debugRow("Fire daily reminder (multi) now",
                     sub: "Body: '3 exercises today — Push-Ups, Squats, Sit-Ups'",
                     key: .notifDailyReminderMulti) {
                debugViewModel.fireDailyReminderMulti()
            }
            debugRow("Fire test-day reminder now",
                     sub: "Title: 'Test day' · Body: 'Push-Ups — max reps today'",
                     key: .notifTestDay) {
                debugViewModel.fireTestDayReminder()
            }
            debugRow("Fire streak protection (streak = 0) now",
                     sub: "Title: 'Start building your streak'",
                     key: .notifStreakProtect0) {
                debugViewModel.fireStreakProtection(streak: 0, key: .notifStreakProtect0)
            }
            debugRow("Fire streak protection (streak = 7) now",
                     sub: "Title: 'Don't break your streak'",
                     key: .notifStreakProtect7) {
                debugViewModel.fireStreakProtection(streak: 7, key: .notifStreakProtect7)
            }
            debugRow("Fire level unlock now",
                     sub: "Title: 'Level 2 unlocked!' · Push-Ups starts in 2 days",
                     key: .notifLevelUnlock) {
                debugViewModel.fireLevelUnlock(notificationService: notificationService)
            }
            debugRow("Fire schedule adjustment now",
                     sub: "Title: 'Schedule adjusted' · Push-Ups moved to tomorrow",
                     key: .notifScheduleAdj) {
                debugViewModel.fireScheduleAdjustment(notificationService: notificationService)
            }
            debugRow("List pending notifications",
                     sub: "Shows count + identifiers in an alert",
                     key: .notifList) {
                debugViewModel.listPendingNotifications()
            }
        }
    }

    // MARK: - History & Charts

    var debugHistorySection: some View {
        Section("History & Charts") {
            debugRow("Seed 4 weeks of history",
                     sub: "Push-Ups, Squats, Sit-Ups on alternating schedule",
                     key: .histSeed4w) {
                debugViewModel.seedHistory(weeks: 4, withGaps: false, key: .histSeed4w, context: modelContext)
            }
            debugRow("Seed 12 weeks of history",
                     sub: "Tests chart scrolling and week group headers",
                     key: .histSeed12w) {
                debugViewModel.seedHistory(weeks: 12, withGaps: false, key: .histSeed12w, context: modelContext)
            }
            debugRow("Seed history with missed days",
                     sub: "4 weeks with gaps → 'Pushed to tomorrow' + streak reset",
                     key: .histSeedGaps) {
                debugViewModel.seedHistory(weeks: 4, withGaps: true, key: .histSeedGaps, context: modelContext)
            }
            debugRow("Add test day pass to history",
                     sub: "Push-Ups: 55/50 reps — 🏆 row in history log",
                     key: .histTestPass) {
                debugViewModel.addTestDayResult(passed: true, context: modelContext)
            }
            debugRow("Add test day fail to history",
                     sub: "Push-Ups: 43/50 reps — 'Retry next' row in history log",
                     key: .histTestFail) {
                debugViewModel.addTestDayResult(passed: false, context: modelContext)
            }
        }
    }

    // MARK: - Watch & HealthKit

    var debugWatchSection: some View {
        Section("Watch & HealthKit") {
            debugRow("Simulate watch completion report",
                     sub: "Push-Ups L1 D1 · 3 sets × 10 reps → injects into live stream",
                     key: .watchSimReport) {
                debugViewModel.simulateWatchReport(context: modelContext, watchConnectivity: watchConnectivity)
            }
            debugRow("Push today's schedule to watch",
                     sub: "Calls sendTodaySchedule with live enrolments",
                     key: .watchPushSchedule) {
                debugViewModel.pushScheduleToWatch(context: modelContext, watchConnectivity: watchConnectivity)
            }
            debugRow("Log test HealthKit workout",
                     sub: "10-min functional strength training workout, 1 hour ago",
                     key: .hkLogWorkout) {
                debugViewModel.logTestHealthKitWorkout(healthKit: healthKit)
            }
        }
    }

    // MARK: - Upload & Sensor Data

    var debugUploadSection: some View {
        Section("Upload & Sensor Data") {
            debugRow("Seed fake sensor recordings (pending)",
                     sub: "3 × 1 KB stub files + SensorRecording rows with status .pending",
                     key: .uploadSeedPending) {
                debugViewModel.seedPendingRecordings(context: modelContext)
            }
            debugRow("Trigger foreground upload now",
                     sub: "Calls uploadPending() directly, bypasses BGProcessingTask",
                     key: .uploadTrigger) {
                debugViewModel.triggerForegroundUpload(context: modelContext, dataUpload: dataUpload)
            }
            debugRow("Show upload status",
                     sub: "Alert with counts per status (pending / uploaded / failed / localOnly)",
                     key: .uploadStatus) {
                debugViewModel.showUploadStatus(context: modelContext)
            }
        }
    }

    // MARK: - Danger Zone

    var debugDangerSection: some View {
        Section("Danger Zone") {
            Button("Clear all history") {
                debugViewModel.confirmDanger(
                    title: "Clear all history?",
                    message: "Deletes all CompletedSet records. Cannot be undone."
                ) {
                    debugViewModel.clearAllHistory(context: modelContext)
                }
            }
            .foregroundStyle(.red)

            Button("Reset all enrolments") {
                debugViewModel.confirmDanger(
                    title: "Reset all enrolments?",
                    message: "Resets all exercise progress to Level 1 Day 1. Cannot be undone."
                ) {
                    debugViewModel.resetAllEnrolments(context: modelContext)
                }
            }
            .foregroundStyle(.red)

            Button("Reset done ✓") {
                debugViewModel.resetAllDone()
            }
            .foregroundStyle(.red)
        }
    }

    // MARK: - Row Helper

    func debugRow(
        _ title: String,
        sub: String,
        key: DebugCheckKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(debugViewModel.isDone(key) ? "✓" : "—")
                    .foregroundStyle(debugViewModel.isDone(key) ? Color.green : .secondary)
                    .font(.subheadline)
                    .monospacedDigit()
            }
        }
    }
}
#endif
