import SwiftUI

struct ExerciseNudgeBanner: View {
    let exerciseName: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("First time doing \(exerciseName)? Tap ⓘ to see how.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Dismiss hint")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
