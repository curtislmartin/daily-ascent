import SwiftUI
import InchShared

struct WatchReadyView: View {
    let session: WatchSession
    let viewModel: WatchWorkoutViewModel

    @Environment(WatchHealthService.self) private var healthService

    @ScaledMetric private var repsFontSize: CGFloat = 28

    var body: some View {
        VStack(spacing: 4) {
            if let variation = session.variationName {
                Text(variation)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text(session.exerciseName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text("Set \(viewModel.currentSet) of \(viewModel.totalSets)")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(viewModel.targetReps)")
                    .font(.system(size: repsFontSize, weight: .bold, design: .rounded))
                Text("reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Start") {
                if viewModel.completedSets.isEmpty {
                    Task { await healthService.startWorkout() }
                }
                viewModel.startSet()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
