// inch/inchwatch Watch App/Features/WatchHistoryView.swift
import SwiftUI

struct WatchHistoryView: View {
    @Environment(WatchHistoryStore.self) private var historyStore
    @State private var selectedEntry: WatchHistoryEntry?

    var body: some View {
        if historyStore.entries.isEmpty {
            ContentUnavailableView(
                "No workouts yet",
                systemImage: "clock.arrow.circlepath",
                description: Text("Complete one from the Today tab.")
            )
        } else {
            List {
                ForEach(groupedEntries, id: \.0) { sectionTitle, entries in
                    Section(sectionTitle) {
                        ForEach(entries) { entry in
                            Button {
                                selectedEntry = entry
                            } label: {
                                WatchHistoryRow(entry: entry)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .sheet(item: $selectedEntry, content: WatchHistoryDetailView.init)
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
