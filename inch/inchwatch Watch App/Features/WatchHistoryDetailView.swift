// inch/inchwatch Watch App/Features/WatchHistoryDetailView.swift
import SwiftUI

struct WatchHistoryDetailView: View {
    let entry: WatchHistoryEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(entry.exerciseName)
                    .font(.headline)
                Text("Level \(entry.level) · Day \(entry.dayNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Divider()
                HStack {
                    Text("Total reps").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(entry.totalReps)").font(.caption).fontWeight(.semibold)
                }
                HStack {
                    Text("Sets").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(entry.setCount)").font(.caption).fontWeight(.semibold)
                }
                Divider()
                Text(entry.completedAt.formatted(.dateTime.month().day().hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
    }
}
