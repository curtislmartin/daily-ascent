import SwiftUI

struct RestDayView: View {
    let streak: Int
    let nextTrainingDate: Date?
    let nextTrainingDayExercises: [(exerciseName: String, level: Int, dayNumber: Int)]
    let hasTrainedBefore: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.indigo)
                    Text("Recovery Day")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.top)

                // Streak safety card
                streakCard

                // Upcoming session card
                if let nextDate = nextTrainingDate {
                    UpcomingSessionCard(
                        nextDate: nextDate,
                        exercises: nextTrainingDayExercises
                    )
                }

                // Recovery tip
                RecoveryTipView()

                Spacer(minLength: 40)
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if streak > 0 {
                HStack {
                    Text("\(streak)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading) {
                        Text("day streak")
                            .font(.headline)
                        Text("is safe.")
                            .font(.headline)
                    }
                }
                Text("Scheduled rest days protect your streak. You're on track.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if hasTrainedBefore {
                Text("Your streak resets here — start again tomorrow.")
                    .font(.headline)
                Text("Complete your next workout to begin a new streak.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Start your first streak today.")
                    .font(.headline)
                Text("Complete a workout to begin building your streak.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
