import SwiftUI

struct UpcomingSessionCard: View {
    let nextDate: Date
    let exercises: [(exerciseName: String, level: Int, dayNumber: Int)]

    private var dateLabel: String {
        if Calendar.current.isDateInTomorrow(nextDate) {
            return "Tomorrow"
        }
        let days = Calendar.current.dateComponents([.day], from: .now, to: nextDate).day ?? 0
        if days <= 6 {
            return "In \(days) days"
        }
        return nextDate.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(dateLabel)
                .font(.headline)

            if exercises.isEmpty {
                Text("No exercises enrolled — add one in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(exercises, id: \.exerciseName) { item in
                    HStack {
                        Text(item.exerciseName)
                            .font(.subheadline)
                        Spacer()
                        Text("L\(item.level) Day \(item.dayNumber)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
