import SwiftUI
import InchShared

struct UpcomingScheduleList: View {
    let schedule: [ProjectedDay]

    var body: some View {
        ForEach(schedule) { day in
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Day \(day.dayNumber)")
                            .font(.subheadline)
                            .fontWeight(day.isTest ? .bold : .medium)
                        if day.isTest {
                            Image(systemName: "trophy.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    if day.isTest {
                        Text("Test — hit \(day.testTarget) reps")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if !day.sets.isEmpty {
                        Text(day.sets.map(String.init).joined(separator: "-") + " reps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(day.scheduledDate, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        }
    }
}
