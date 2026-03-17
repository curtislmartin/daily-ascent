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

            Text("While you work out, Inch records motion sensor data from your iPhone and Apple Watch. This data captures the patterns of each exercise — it's what lets the app learn to count reps automatically.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("If you opt in, this sensor data is uploaded anonymously to help train a rep-counting model. Your data never includes any personal information — only accelerometer and gyroscope readings during exercises.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var localRecordingNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Local recording always happens", systemImage: "iphone.circle")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Even if you don't opt in to sharing, Inch records sensor data locally on your device. This keeps your option open to share later, and may enable on-device ML features in the future. You can disable local recording in Settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var consentToggle: some View {
        Toggle(isOn: $consented) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Share sensor data anonymously")
                    .font(.body)
                Text("Used only to improve automatic rep counting in this app.")
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
