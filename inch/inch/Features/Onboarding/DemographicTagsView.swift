import SwiftUI

struct DemographicTagsView: View {
    let onComplete: (String?, String?, String?, String?) -> Void

    @State private var ageRange: String? = nil
    @State private var heightRange: String? = nil
    @State private var biologicalSex: String? = nil
    @State private var activityLevel: String? = nil

    private let ageOptions = ["Under 18", "18–29", "30–39", "40–49", "50–59", "60+"]
    private let heightOptions = ["Under 160cm", "160–170cm", "171–180cm", "181–190cm", "Over 190cm"]
    private let sexOptions = ["Male", "Female", "Prefer not to say"]
    private let activityOptions = ["Beginner", "Intermediate", "Advanced"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                PickerSection(title: "Age", options: ageOptions, selection: $ageRange)
                PickerSection(title: "Height", options: heightOptions, selection: $heightRange)
                PickerSection(title: "Biological sex", options: sexOptions, selection: $biologicalSex)
                PickerSection(title: "Activity level", options: activityOptions, selection: $activityLevel)

                Button {
                    onComplete(ageRange, heightRange, biologicalSex, activityLevel)
                } label: {
                    Text("Continue")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle("Optional Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Skip") {
                    onComplete(nil, nil, nil, nil)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Help us build better models")
                .font(.headline)
            Text("Different body types produce different movement signatures. These optional fields help us train accurate rep counting for everyone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("All fields are optional and anonymous — never linked to your identity.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

private struct PickerSection: View {
    let title: String
    let options: [String]
    @Binding var selection: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            selection = selection == option ? nil : option
                        } label: {
                            Text(option)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    selection == option
                                        ? Color.accentColor
                                        : Color(.secondarySystemFill),
                                    in: Capsule()
                                )
                                .foregroundStyle(selection == option ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
