import SwiftUI
import SwiftData
import InchShared

struct AboutMeView: View {
    @Environment(\.modelContext) private var modelContext
    var viewModel: SettingsViewModel

    private enum DemographicField: Identifiable {
        case age, height, sex, activity
        var id: Self { self }
    }

    @State private var activeDemographicField: DemographicField?

    private var settings: UserSettings? { viewModel.settings }

    var body: some View {
        List {
            Section {
                demographicRow(title: "Age range",      value: settings?.ageRange,      field: .age)
                demographicRow(title: "Height",         value: settings?.heightRange,   field: .height)
                demographicRow(title: "Biological sex", value: settings?.biologicalSex, field: .sex)
                demographicRow(title: "Activity level", value: settings?.activityLevel, field: .activity)
            } footer: {
                Text("Optional. Used only to improve rep-counting accuracy for different body types.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("About Me")
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
}
