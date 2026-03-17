import SwiftUI
import SwiftData
import InchShared

struct PrivacySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    var viewModel: SettingsViewModel

    @State private var showingDeleteHistoryConfirm = false
    @State private var showingResetConfirm = false
    @State private var showingDeleteContributedDataConfirm = false

    private enum DemographicField: Identifiable {
        case age, height, sex, activity
        var id: Self { self }
    }

    @State private var activeDemographicField: DemographicField?

    private var settings: UserSettings? { viewModel.settings }

    var body: some View {
        List {
            consentSection
            if settings?.motionDataUploadConsented == true {
                demographicsSection
            }
            dataSection
            Section("Legal") {
                Link("Privacy Policy", destination: URL(string: "https://curtislmartin.github.io/inch/privacy")!)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Data & Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .task { viewModel.load(context: modelContext) }
        .sheet(item: $activeDemographicField) { field in
            switch field {
            case .age:
                DemographicPickerSheet(
                    title: "Age Range",
                    options: ["Under 18", "18–29", "30–39", "40–49", "50–59", "60+"],
                    selection: Binding(
                        get: { settings?.ageRange },
                        set: { settings?.ageRange = $0; try? modelContext.save() }
                    )
                )
            case .height:
                DemographicPickerSheet(
                    title: "Height",
                    options: ["Under 160cm", "160–170cm", "171–180cm", "181–190cm", "Over 190cm"],
                    selection: Binding(
                        get: { settings?.heightRange },
                        set: { settings?.heightRange = $0; try? modelContext.save() }
                    )
                )
            case .sex:
                DemographicPickerSheet(
                    title: "Biological Sex",
                    options: ["Male", "Female", "Prefer not to say"],
                    selection: Binding(
                        get: { settings?.biologicalSex },
                        set: { settings?.biologicalSex = $0; try? modelContext.save() }
                    )
                )
            case .activity:
                DemographicPickerSheet(
                    title: "Activity Level",
                    options: ["Beginner", "Intermediate", "Advanced"],
                    selection: Binding(
                        get: { settings?.activityLevel },
                        set: { settings?.activityLevel = $0; try? modelContext.save() }
                    )
                )
            }
        }
        .alert(
            "Delete all workout history?",
            isPresented: $showingDeleteHistoryConfirm
        ) {
            Button("Delete History", role: .destructive) {
                viewModel.deleteHistory(context: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All completed sets and session records will be permanently deleted. Your programme progress is kept.")
        }
        .alert(
            "Reset app to onboarding?",
            isPresented: $showingResetConfirm
        ) {
            Button("Reset Everything", role: .destructive) {
                viewModel.resetToOnboarding(context: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All progress, history, and settings will be permanently deleted. You'll go through onboarding again.")
        }
        .alert(
            "Delete contributed data?",
            isPresented: $showingDeleteContributedDataConfirm
        ) {
            Button("Delete My Contributed Data", role: .destructive) {
                viewModel.deleteContributedData(context: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes all motion sensor data you've contributed from our servers. Your local workout history is kept.")
        }
    }

    private var demographicsSection: some View {
        Section {
            demographicRow(title: "Age range",      value: settings?.ageRange,      field: .age)
            demographicRow(title: "Height",          value: settings?.heightRange,   field: .height)
            demographicRow(title: "Biological sex",  value: settings?.biologicalSex, field: .sex)
            demographicRow(title: "Activity level",  value: settings?.activityLevel, field: .activity)
        } header: {
            Text("Profile")
        } footer: {
            Text("Optional. Used only to improve rep-counting accuracy for different body types.")
        }
    }

    private func demographicRow(title: String, value: String?, field: DemographicField) -> some View {
        Button {
            activeDemographicField = field
        } label: {
            LabeledContent(title) {
                Text(value ?? "Not set")
                    .foregroundStyle(value == nil ? .secondary : .primary)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }

    private var consentSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings?.motionDataUploadConsented ?? false },
                set: { newValue in
                    settings?.motionDataUploadConsented = newValue
                    settings?.consentDate = newValue ? .now : nil
                    if newValue && (settings?.contributorId.isEmpty ?? true) {
                        settings?.contributorId = UUID().uuidString.lowercased()
                    }
                    try? modelContext.save()
                }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Share motion data anonymously")
                    Text("Helps improve automatic rep counting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("Motion sensor data is always recorded locally during workouts. Enabling sharing sends anonymised accelerometer and gyroscope data to help train rep-counting models for this app.")
        }
    }

    private var dataSection: some View {
        Section("Data") {
            if settings?.motionDataUploadConsented == true {
                Button("Delete My Contributed Data", role: .destructive) {
                    showingDeleteContributedDataConfirm = true
                }
            }
            Button("Delete Workout History", role: .destructive) {
                showingDeleteHistoryConfirm = true
            }
            Button("Reset App", role: .destructive) {
                showingResetConfirm = true
            }
        }
    }

}
