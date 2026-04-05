import SwiftUI
import SwiftData
import InchShared

struct DataConsentView: View {
    let onComplete: (Bool) -> Void

    @State private var consented = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                explanationSection
                localRecordingNote
                consentToggle
                continueButton
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .navigationTitle("Sensor Data")
        .navigationBarTitleDisplayMode(.large)
    }

    private var explanationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Help improve automatic rep counting")
                .font(.headline)

            Text("While you work out, Daily Ascent records motion sensor data from your iPhone and Apple Watch. This data captures the movement patterns of each exercise — it's what will allow the app to count reps automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // swiftlint:disable:next line_length
            Text("If you opt in, your sensor data and optional profile details (age range, height, biological sex, and activity level) are uploaded anonymously to help train a rep-counting model. Different body types move differently — this context makes the model more accurate for everyone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("No data is ever linked to your identity.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var localRecordingNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Local data", systemImage: "iphone.circle")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Daily Ascent records sensor data locally on your device during workouts. We will never collect this data without your consent. This keeps your options open to share later and may enable on-device features in the future.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var consentToggle: some View {
        Toggle(isOn: $consented) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Share data anonymously")
                    .font(.body)
                Text("Sensor data and optional profile details, used only to improve rep counting in this app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var continueButton: some View {
        Button {
            onComplete(consented)
        } label: {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
    }
}
