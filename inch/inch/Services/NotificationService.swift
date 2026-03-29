import Foundation
import UserNotifications
import SwiftData
import InchShared

@Observable
final class NotificationService {
    var isAuthorized: Bool = false
    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Permission

    /// Requests permission if not yet determined. Safe to call on every workout —
    /// UNUserNotificationCenter shows the system prompt only once.
    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        // Read back the real status rather than inferring from the Bool return value.
        await checkAuthorizationStatus()
    }

    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Schedule Refresh

    /// Re-schedules the next 7 days of reminders from scratch.
    /// Call after every workout completion and on app launch.
    func refresh(context: ModelContext, settings: UserSettings) async {
        await checkAuthorizationStatus()
        guard isAuthorized else { return }

        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let idsToRemove = pending
            .map(\.identifier)
            .filter {
                $0.hasPrefix("daily-reminder-") ||
                $0.hasPrefix("streak-protection-") ||
                $0 == "streak-recovery"
            }
        center.removePendingNotificationRequests(withIdentifiers: idsToRemove)

        let enrolments = fetchActiveEnrolments(context: context)
        let streak = fetchStreakState(context: context)?.currentStreak ?? 0
        let schedule = buildSchedule(from: enrolments)

        for (date, scheduledDay) in schedule {
            if settings.dailyReminderEnabled {
                scheduleDailyReminder(
                    for: date,
                    scheduledDay: scheduledDay,
                    hour: settings.dailyReminderHour,
                    minute: settings.dailyReminderMinute
                )
            }
            if settings.streakProtectionEnabled {
                scheduleStreakProtection(
                    for: date,
                    exerciseCount: scheduledDay.exerciseNames.count,
                    streak: streak,
                    hour: settings.streakProtectionHour,
                    minute: settings.streakProtectionMinute
                )
            }
        }
    }

    // MARK: - Cancel

    /// Call when any exercise is completed today to cancel the streak-protection nag.
    func cancelTodayStreakProtection() {
        let today = Calendar.current.startOfDay(for: .now)
        let id = "streak-protection-\(today.timeIntervalSince1970)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    /// Schedules a gentle recovery notification for 8am on the next training day.
    /// Uses a fixed identifier so re-scheduling always replaces the previous one.
    /// Safe to call repeatedly — at most one pending "streak-recovery" notification exists.
    func scheduleStreakRecovery(nextTrainingDate: Date) {
        guard isAuthorized else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time to get back to it"
        content.body = "Everyone misses a day. Your exercises are ready — no streak needed to start."
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: nextTrainingDate)
        components.hour = 8
        components.minute = 0

        guard let fireDate = Calendar.current.date(from: components), fireDate > .now else { return }

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: "streak-recovery",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Immediate Posts

    func postLevelUnlock(exerciseName: String, newLevel: Int, startsIn: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Level \(newLevel) unlocked!"
        content.body = "\(exerciseName) — Level \(newLevel) starts in \(startsIn) day\(startsIn == 1 ? "" : "s")"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "level-unlock-\(UUID())",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func postScheduleAdjustment(exerciseName: String, newDateDescription: String) {
        let content = UNMutableNotificationContent()
        content.title = "Schedule adjusted"
        content.body = "\(exerciseName) moved to \(newDateDescription)"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "schedule-adjustment-\(UUID())",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Private

    private struct ScheduledDay {
        var exerciseNames: [String] = []
        var hasTestDay: Bool = false
    }

    private func buildSchedule(from enrolments: [ExerciseEnrolment]) -> [Date: ScheduledDay] {
        let today = Calendar.current.startOfDay(for: .now)
        guard let weekOut = Calendar.current.date(byAdding: .day, value: 7, to: today) else { return [:] }
        var schedule: [Date: ScheduledDay] = [:]
        for enrolment in enrolments {
            guard let scheduled = enrolment.nextScheduledDate else { continue }
            let day = Calendar.current.startOfDay(for: scheduled)
            guard day >= today, day <= weekOut else { continue }
            let name = enrolment.exerciseDefinition?.name ?? "Exercise"
            let isTest = enrolment.exerciseDefinition?
                .levels?
                .first(where: { $0.level == enrolment.currentLevel })?
                .days?
                .first(where: { $0.dayNumber == enrolment.currentDay })?
                .isTest ?? false
            schedule[day, default: ScheduledDay()].exerciseNames.append(name)
            if isTest { schedule[day]?.hasTestDay = true }
        }
        return schedule
    }

    private func scheduleDailyReminder(for date: Date, scheduledDay: ScheduledDay, hour: Int, minute: Int) {
        let exercises = scheduledDay.exerciseNames
        let content = UNMutableNotificationContent()
        if scheduledDay.hasTestDay {
            content.title = "Test day"
            content.body = exercises.count == 1
                ? "\(exercises[0]) — max reps today"
                : "Max rep tests: \(exercises.joined(separator: ", "))"
        } else {
            content.title = "Time to train"
            content.body = exercises.count == 1
                ? exercises[0]
                : "\(exercises.count) exercises today — \(exercises.joined(separator: ", "))"
        }
        content.sound = .default
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = "daily-reminder-\(date.timeIntervalSince1970)"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func scheduleStreakProtection(
        for date: Date,
        exerciseCount: Int,
        streak: Int,
        hour: Int,
        minute: Int
    ) {
        let content = UNMutableNotificationContent()
        if streak > 1 {
            content.title = "Don't break your streak"
            content.body = "\(streak)-day streak — \(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s") still waiting"
        } else {
            content.title = "Start building your streak"
            content.body = "\(exerciseCount) exercise\(exerciseCount == 1 ? "" : "s") due today"
        }
        content.sound = .default
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id = "streak-protection-\(date.timeIntervalSince1970)"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private func fetchActiveEnrolments(context: ModelContext) -> [ExerciseEnrolment] {
        (try? context.fetch(FetchDescriptor<ExerciseEnrolment>(predicate: #Predicate { $0.isActive }))) ?? []
    }

    private func fetchStreakState(context: ModelContext) -> StreakState? {
        (try? context.fetch(FetchDescriptor<StreakState>()))?.first
    }
}
