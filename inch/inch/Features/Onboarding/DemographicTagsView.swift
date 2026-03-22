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
    private let activityOptions: [(label: String, subtitle: String)] = [
        ("Beginner",     "New to training"),
        ("Intermediate", "2–3× per week"),
        ("Advanced",     "Training 2+ years"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                section(title: "Age") {
                    ForEach(ageOptions, id: \.self) { option in
                        DemographicOptionCard(
                            label: option,
                            subtitle: nil,
                            isSelected: ageRange == option
                        ) {
                            ageRange = ageRange == option ? nil : option
                        }
                    }
                }

                section(title: "Height") {
                    ForEach(heightOptions, id: \.self) { option in
                        DemographicOptionCard(
                            label: option,
                            subtitle: nil,
                            isSelected: heightRange == option
                        ) {
                            heightRange = heightRange == option ? nil : option
                        }
                    }
                }

                section(title: "Biological sex") {
                    ForEach(sexOptions, id: \.self) { option in
                        DemographicOptionCard(
                            label: option,
                            subtitle: nil,
                            isSelected: biologicalSex == option
                        ) {
                            biologicalSex = biologicalSex == option ? nil : option
                        }
                    }
                }

                section(title: "Activity level") {
                    ForEach(activityOptions, id: \.label) { option in
                        DemographicOptionCard(
                            label: option.label,
                            subtitle: option.subtitle,
                            isSelected: activityLevel == option.label
                        ) {
                            activityLevel = activityLevel == option.label ? nil : option.label
                        }
                    }
                }

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
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tell us about yourself")
                .font(.headline)
            Text("All optional — tap Continue to skip.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder cards: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
            cards()
        }
    }
}


// MARK: - Option Card

struct DemographicOptionCard: View {
    let label: String
    let subtitle: String?
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(isSelected ? Color.accentColor.opacity(0.08) : Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    NavigationStack {
        DemographicTagsView { _, _, _, _ in }
    }
}
