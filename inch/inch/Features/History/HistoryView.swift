import SwiftUI
import SwiftData
import InchShared

struct HistoryView: View {
    @Query(sort: \CompletedSet.completedAt, order: .reverse)
    private var allSets: [CompletedSet]

    @State private var viewModel = HistoryViewModel()
    @State private var showingSettings = false

    private var sessions: [SessionGroup] { viewModel.grouped(sets: allSets) }

    var body: some View {
        Group {
            if sessions.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(sessions) { session in
                        Section(header: Text(session.id.formatted(date: .complete, time: .omitted))) {
                            ForEach(session.exercises) { summary in
                                NavigationLink(value: session.id) {
                                    ExerciseSummaryRow(summary: summary)
                                }
                            }
                            HStack {
                                Spacer()
                                Text("\(session.totalReps) total reps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .navigationDestination(for: Date.self) { date in
            SessionDetailView(sessionDate: date)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No workouts yet")
                .font(.headline)
            Text("Complete your first session to see it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

private struct ExerciseSummaryRow: View {
    let summary: ExerciseSummary

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(hex: summary.color) ?? .accentColor)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                Text(summary.name)
                    .font(.body)
                Text("\(summary.setCount) sets · \(summary.totalReps) reps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private extension Color {
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
