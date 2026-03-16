// inch/inchwatch Watch App/Features/WatchSettingsView.swift
import SwiftUI

struct WatchSettingsView: View {
    @Environment(WatchSettings.self) private var settings
    @Environment(WatchHealthService.self) private var healthService

    var body: some View {
        @Bindable var settings = settings
        List {
            if healthService.isAuthorized {
                Section("Heart Rate") {
                    Toggle("Show heart rate", isOn: $settings.showHeartRate)

                    Picker("High HR alert", selection: $settings.heartRateAlertBPM) {
                        Text("Off").tag(0)
                        Text("150 BPM").tag(150)
                        Text("160 BPM").tag(160)
                        Text("170 BPM").tag(170)
                        Text("180 BPM").tag(180)
                    }
                    .pickerStyle(.navigationLink)
                }
            }

            Section {
                Toggle("Auto-start next set", isOn: $settings.autoAdvanceAfterRest)
            } header: {
                Text("Workout")
            } footer: {
                Text("Skips the ready screen and begins the next set automatically after rest ends.")
            }

            // Second section for countdown haptics toggle — separate section needed
            // because SwiftUI Section supports only one footer.
            Section {
                Toggle("Countdown haptics", isOn: $settings.hapticFinalCountdown)
            } footer: {
                Text("Taps your wrist at 3, 2, and 1 seconds remaining in the rest timer.")
            }
        }
        .navigationTitle("Settings")
    }
}
