import Foundation
import SwiftData

@Model
public final class UserSettings {
    public var createdAt: Date = Date.now

    public var restOverrides: [String: Int] = [:]
    public var countingModeOverrides: [String: String] = [:]

    public var interExerciseRestEnabled: Bool = false
    public var interExerciseRestSeconds: Int = 120

    public var dailyReminderEnabled: Bool = true
    public var dailyReminderHour: Int = 8
    public var dailyReminderMinute: Int = 0
    public var streakProtectionEnabled: Bool = true
    public var testDayNotificationEnabled: Bool = true
    public var levelUnlockNotificationEnabled: Bool = true
    public var streakProtectionHour: Int = 19
    public var streakProtectionMinute: Int = 0
    public var showConflictWarnings: Bool = true

    public var motionDataUploadConsented: Bool = false
    public var consentDate: Date? = nil
    public var contributorId: String = ""

    public var ageRange: String? = nil
    public var heightRange: String? = nil
    public var biologicalSex: String? = nil
    public var activityLevel: String? = nil

    public init(
        createdAt: Date = Date.now,
        restOverrides: [String: Int] = [:],
        countingModeOverrides: [String: String] = [:],
        interExerciseRestEnabled: Bool = false,
        interExerciseRestSeconds: Int = 120,
        dailyReminderEnabled: Bool = true,
        dailyReminderHour: Int = 8,
        dailyReminderMinute: Int = 0,
        streakProtectionEnabled: Bool = true,
        testDayNotificationEnabled: Bool = true,
        levelUnlockNotificationEnabled: Bool = true,
        streakProtectionHour: Int = 19,
        streakProtectionMinute: Int = 0,
        showConflictWarnings: Bool = true,
        motionDataUploadConsented: Bool = false,
        consentDate: Date? = nil,
        contributorId: String = "",
        ageRange: String? = nil,
        heightRange: String? = nil,
        biologicalSex: String? = nil,
        activityLevel: String? = nil
    ) {
        self.createdAt = createdAt
        self.restOverrides = restOverrides
        self.countingModeOverrides = countingModeOverrides
        self.interExerciseRestEnabled = interExerciseRestEnabled
        self.interExerciseRestSeconds = interExerciseRestSeconds
        self.dailyReminderEnabled = dailyReminderEnabled
        self.dailyReminderHour = dailyReminderHour
        self.dailyReminderMinute = dailyReminderMinute
        self.streakProtectionEnabled = streakProtectionEnabled
        self.testDayNotificationEnabled = testDayNotificationEnabled
        self.levelUnlockNotificationEnabled = levelUnlockNotificationEnabled
        self.streakProtectionHour = streakProtectionHour
        self.streakProtectionMinute = streakProtectionMinute
        self.showConflictWarnings = showConflictWarnings
        self.motionDataUploadConsented = motionDataUploadConsented
        self.consentDate = consentDate
        self.contributorId = contributorId
        self.ageRange = ageRange
        self.heightRange = heightRange
        self.biologicalSex = biologicalSex
        self.activityLevel = activityLevel
    }
}
