import SwiftUI
import SwiftData
import InchShared

struct HistoryView: View {
    @Environment(AnalyticsService.self) private var analytics

    @Query(sort: \CompletedSet.completedAt, order: .reverse)
    private var allSets: [CompletedSet]
    @Query private var allEnrolments: [ExerciseEnrolment]
    @Query private var streakStates: [StreakState]
    @Query private var allSettings: [UserSettings]

    @State private var viewModel = HistoryViewModel()
    @State private var selectedSegment: Segment = .stats
    @State private var showingSettings = false

    private var showSettingsBadge: Bool {
        guard let s = allSettings.first else { return false }
        return !s.hasDemographics
    }

    enum Segment: String, CaseIterable {
        case stats = "Stats"
        case log = "Log"
        case achievements = "Achievements"
    }

    private var streakState: StreakState? { streakStates.first }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedSegment) {
                ForEach(Segment.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            switch selectedSegment {
            case .log:
                HistoryLogView(
                    weekGroups: viewModel.weekGroups(from: allSets)
                )
            case .stats:
                HistoryStatsView(
                    stats: viewModel.stats(from: allSets, enrolments: allEnrolments),
                    streakState: streakState
                )
            case .achievements:
                TrophyShelfView()
            }
        }
        .onAppear {
            analytics.record(AnalyticsEvent(
                name: "progress_viewed",
                properties: .progressViewed
            ))
        }
        .navigationTitle("Me")
        .navigationBarTitleDisplayMode(.large)
        .withHistoryDestinations()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .overlay(alignment: .topTrailing) {
                            if showSettingsBadge {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 7, height: 7)
                                    .offset(x: 4, y: -3)
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
            }
        }
    }
}
