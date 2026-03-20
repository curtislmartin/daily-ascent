import SwiftUI
import SwiftData
import InchShared

struct HistoryView: View {
    @Query(sort: \CompletedSet.completedAt, order: .reverse)
    private var allSets: [CompletedSet]
    @Query private var allEnrolments: [ExerciseEnrolment]
    @Query private var streakStates: [StreakState]
    @Query private var allSettings: [UserSettings]

    @State private var viewModel = HistoryViewModel()
    @State private var selectedSegment: Segment = .log
    @State private var showingSettings = false

    private var showSettingsBadge: Bool {
        guard let s = allSettings.first else { return false }
        return s.motionDataUploadConsented && !s.hasDemographics
    }

    enum Segment: String, CaseIterable {
        case log = "Log"
        case stats = "Stats"
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
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.large)
        .withHistoryDestinations()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "gearshape")
                        if showSettingsBadge {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 5, y: -5)
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
