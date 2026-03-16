// inch/inchwatch Watch App/Features/WatchHistoryView.swift
import SwiftUI

struct WatchHistoryView: View {
    @Environment(WatchHistoryStore.self) private var historyStore
    @State private var selectedEntry: WatchHistoryEntry?

    var body: some View {
        if historyStore.entries.isEmpty {
            emptyState
        } else {
            List {
                ForEach(groupedEntries, id: \.0) { sectionTitle, entries in
                    Section(sectionTitle) {
                        ForEach(entries) { entry in
                            Button {
                                selectedEntry = entry
                            } label: {
                                historyRow(entry)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .sheet(item: $selectedEntry) { entry in
                WatchHistoryDetailView(entry: entry)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No workouts yet")
                .font(.headline)
            Text("Complete one from the Today tab.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private func historyRow(_ entry: WatchHistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.exerciseName)
                .font(.headline)
            Text("\(entry.totalReps) reps · \(entry.setCount) sets")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.completedAt.formatted(.relative(presentation: .named)))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var groupedEntries: [(String, [WatchHistoryEntry])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return [] }

        var groups: [(String, [WatchHistoryEntry])] = []
        var remaining = historyStore.entries

        let todayEntries = remaining.filter { calendar.startOfDay(for: $0.completedAt) == today }
        remaining.removeAll { calendar.startOfDay(for: $0.completedAt) == today }
        if !todayEntries.isEmpty { groups.append(("Today", todayEntries)) }

        let yesterdayEntries = remaining.filter { calendar.startOfDay(for: $0.completedAt) == yesterday }
        remaining.removeAll { calendar.startOfDay(for: $0.completedAt) == yesterday }
        if !yesterdayEntries.isEmpty { groups.append(("Yesterday", yesterdayEntries)) }

        var byDay: [Date: [WatchHistoryEntry]] = [:]
        for entry in remaining {
            let day = calendar.startOfDay(for: entry.completedAt)
            byDay[day, default: []].append(entry)
        }
        for day in byDay.keys.sorted(by: >) {
            let title = day.formatted(.dateTime.month(.abbreviated).day())
            if let dayEntries = byDay[day] {
                groups.append((title, dayEntries))
            }
        }

        return groups
    }
}
