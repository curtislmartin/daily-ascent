import SwiftUI

struct RestDayView: View {
    let streak: Int
    let nextTrainingDate: Date?
    let nextTrainingCount: Int

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)

                Text("Rest Day")
                    .font(.title)
                    .fontWeight(.bold)

                Text(nextTrainingMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if streak > 0 {
                streakView
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }

    private var nextTrainingMessage: String {
        guard let date = nextTrainingDate else {
            return "No upcoming sessions scheduled."
        }
        let formatted = date.formatted(
            .relative(presentation: .named, unitsStyle: .wide)
        ).lowercased()
        if nextTrainingCount == 1 {
            return "Next training \(formatted) — 1 exercise"
        } else {
            return "Next training \(formatted) — \(nextTrainingCount) exercises"
        }
    }

    private var streakView: some View {
        VStack(spacing: 6) {
            Label("\(streak)-day streak", systemImage: "flame.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text("Keep it up — rest days are part of the program.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
}
