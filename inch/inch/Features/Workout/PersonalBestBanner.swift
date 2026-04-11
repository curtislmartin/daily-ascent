import SwiftUI

struct PersonalBestBanner: View {
    let reps: Int
    let exerciseName: String
    let percentile: Int?
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("New PB: \(reps) \(exerciseName.lowercased())")
                    .font(.subheadline).fontWeight(.semibold)
                if let percentile {
                    Text("Better than \(percentile)% of users")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .sensoryFeedback(.success, trigger: true)
        .task {
            try? await Task.sleep(for: .seconds(4))
            onDismiss()
        }
        .onTapGesture { onDismiss() }
    }
}
