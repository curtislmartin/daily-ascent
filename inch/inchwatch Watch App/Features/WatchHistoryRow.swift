import SwiftUI

struct WatchHistoryRow: View {
    let entry: WatchHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.exerciseName)
                .font(.headline)
            Text("\(entry.totalReps) reps · \(entry.setCount) sets")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.completedAt.formatted(.relative(presentation: .named)))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
