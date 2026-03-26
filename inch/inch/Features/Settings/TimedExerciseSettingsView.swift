import SwiftUI
import SwiftData
import InchShared

struct TimedExerciseSettingsView: View {
    @Bindable var settings: UserSettings
    @Environment(\.modelContext) private var modelContext

    private let options = [3, 5, 10]

    var body: some View {
        List {
            Section {
                Picker("Prep countdown", selection: $settings.timedPrepCountdownSeconds) {
                    ForEach(options, id: \.self) { seconds in
                        Text("\(seconds) seconds").tag(seconds)
                    }
                }
                .onChange(of: settings.timedPrepCountdownSeconds) {
                    try? modelContext.save()
                }
            } footer: {
                Text("Countdown shown before each timed hold so you can get into position.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Timed Exercises")
        .navigationBarTitleDisplayMode(.inline)
    }
}
