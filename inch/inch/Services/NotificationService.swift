import Foundation
import UserNotifications
import SwiftData
import InchShared

@Observable
final class NotificationService {
    var isAuthorized: Bool = false

    // MARK: - Permission

    /// Requests permission if not yet determined. Safe to call on every workout —
    /// UNUserNotificationCenter shows the system prompt only once.
    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        isAuthorized = granted
    }

    func checkAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
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
            .filter { $0.hasPrefix("daily-reminder-") || $0.hasPrefix("streak-protection-") }
        center.removePendingNotificationRequests(withIdentifiers: idsToRemove)

        let enrolments = fetchActiveEnrolments(context: context)
        let streak = fetchStreakState(context: context)?.currentStreak ?? 0
        let schedule = buildSchedule(from: enrolments)

        for (date, exerciseNames) in schedule {
            if settings.dailyReminderEnabled {
                scheduleDailyReminder(
                    for: date,
                    exercises: exerciseNames,
                    hour: settings.dailyReminderHour,
                    minute: settings.dailyReminderMinute
                )
            }
            if settings.streakProtectionEnabled {
                scheduleStreakProtection(
                    for: date,
                    exerciseCount: exerciseNames.count,
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

    private func buildSchedule(from enrolments: [ExerciseEnrolment]) -> [Date: [String]] {
        let today = Calendar.current.startOfDay(for: .now)
        guard let weekOut = Calendar.current.date(byAdding: .day, value: 7, to: today) else { return [:] }
        var schedule: [Date: [String]] = [:]
        for enrolment in enrolments {
            guard let scheduled = enrolment.nextScheduledDate else { continue }
            let day = Calendar.current.startOfDay(for: scheduled)
            guard day >= today, day <= weekOut else { continue }
            let name = enrolment.exerciseDefinition?.name ?? "Exercise"
            schedule[day, default: []].append(name)
        }
        return schedule
    }

    private func scheduleDailyReminder(for date: Date, exercises: [String], hour: Int, minute: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Time to train"
        content.body = exercises.count == 1
            ? exercises[0]
            : "\(exercises.count) exercises today — \(exercises.joined(separator: ", "))"
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
