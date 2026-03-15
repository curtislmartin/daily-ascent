import Foundation
import SwiftData

@Model
final class UserSettings {
    var createdAt: Date = Date.now

    var restOverrides: [String: Int] = [:]
    var countingModeOverrides: [String: String] = [:]

    var interExerciseRestEnabled: Bool = false
    var interExerciseRestSeconds: Int = 120

    var dailyReminderEnabled: Bool = true
    var dailyReminderHour: Int = 8
    var dailyReminderMinute: Int = 0
    var streakProtectionEnabled: Bool = true
    var testDayNotificationEnabled: Bool = true
    var levelUnlockNotificationEnabled: Bool = true

    var motionDataUploadConsented: Bool = false
    var consentDate: Date? = nil
    var contributorId: String = ""

    var ageRange: String? = nil
    var heightRange: String? = nil
    var biologicalSex: String? = nil
    var activityLevel: String? = nil

    init(
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
        self.motionDataUploadConsented = motionDataUploadConsented
        self.consentDate = consentDate
        self.contributorId = contributorId
        self.ageRange = ageRange
        self.heightRange = heightRange
        self.biologicalSex = biologicalSex
        self.activityLevel = activityLevel
    }
}
