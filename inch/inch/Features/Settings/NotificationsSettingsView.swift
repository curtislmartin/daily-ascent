import SwiftUI
import InchShared

struct NotificationsSettingsView: View {
    @Bindable var settings: UserSettings
    @Environment(\.openURL) private var openURL
    @Environment(NotificationService.self) private var notifications

    var body: some View {
        List {
            if notifications.isAuthorized {
                Section {
                    Toggle("Daily Reminder", isOn: $settings.dailyReminderEnabled)
                    if settings.dailyReminderEnabled {
                        DatePicker(
                            "Reminder time",
                            selection: dailyReminderBinding,
                            displayedComponents: .hourAndMinute
                        )
                    }
                    Toggle("Streak Protection", isOn: $settings.streakProtectionEnabled)
                    if settings.streakProtectionEnabled {
                        DatePicker(
                            "Reminder time",
                            selection: streakProtectionBinding,
                            displayedComponents: .hourAndMinute
                        )
                    }
                    Toggle("Level Unlock Alerts", isOn: $settings.levelUnlockNotificationEnabled)
                }
            } else if notifications.authorizationStatus == .notDetermined {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Allow notifications to get workout reminders and streak alerts.")
                            .font(.subheadline)
                        Button("Enable Notifications") {
                            Task { await notifications.requestPermission() }
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notifications are disabled")
                            .font(.subheadline)
                        Text("Enable in Settings → Notifications → Inch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Open Settings") {
                            // "App-Prefs:NOTIFICATIONS" is the iOS 16+ deep-link to the app's
                            // notification settings. UIApplication.openNotificationSettingsURLString
                            // is UIKit (banned) so we use the string literal directly.
                            if let url = URL(string: "App-Prefs:NOTIFICATIONS") {
                                openURL(url)
                            }
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await notifications.checkAuthorizationStatus() }
    }

    // MARK: - Private

    private var dailyReminderBinding: Binding<Date> {
        timeBinding(hour: $settings.dailyReminderHour, minute: $settings.dailyReminderMinute)
    }

    private var streakProtectionBinding: Binding<Date> {
        timeBinding(hour: $settings.streakProtectionHour, minute: $settings.streakProtectionMinute)
    }

    private func timeBinding(hour: Binding<Int>, minute: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: hour.wrappedValue,
                    minute: minute.wrappedValue,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                hour.wrappedValue = c.hour ?? hour.wrappedValue
                minute.wrappedValue = c.minute ?? minute.wrappedValue
            }
        )
    }
}
