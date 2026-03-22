import SwiftUI
import SwiftData
import InchShared

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WatchConnectivityService.self) private var watchConnectivity
    @Query private var streakStates: [StreakState]
    @Query private var allSettings: [UserSettings]

    @State private var viewModel = TodayViewModel()
    @State private var nudgeDismissed = false

    private var settings: UserSettings? { allSettings.first }

    private var showDemographicsNudge: Bool {
        guard let s = allSettings.first else { return false }
        return !nudgeDismissed && !s.hasDemographics
    }

    private var showConflictWarnings: Bool { allSettings.first?.showConflictWarnings ?? true }

    private var streak: Int { streakStates.first?.currentStreak ?? 0 }

    private var completedTodayCount: Int {
        viewModel.dueExercises.filter {
            viewModel.completedTodayIds.contains($0.exerciseDefinition?.exerciseId ?? "")
        }.count
    }

    var body: some View {
        Group {
            if viewModel.isRestDay {
                RestDayView(
                    streak: streak,
                    nextTrainingDate: viewModel.nextTrainingDate,
                    nextTrainingCount: viewModel.nextTrainingCount
                )
            } else {
                exerciseList
            }
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if completedTodayCount >= 1 && streak > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Label("\(streak)", systemImage: "flame.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                        .labelStyle(.titleAndIcon)
                }
            }
        }
        .withWorkoutDestinations()
        .withTodayDestinations()
        .task {
            viewModel.loadToday(context: modelContext, showWarnings: showConflictWarnings)
            watchConnectivity.sendTodaySchedule(
                enrolments: viewModel.dueExercises,
                settings: settings
            )
        }
        .onAppear {
            viewModel.loadToday(context: modelContext, showWarnings: showConflictWarnings)
        }
    }

    private var exerciseList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                TodaySessionBanner(
                    streak: streak,
                    completedCount: completedTodayCount,
                    totalCount: viewModel.dueExercises.count,
                    advisory: viewModel.advisory
                )
                if showDemographicsNudge {
                    TodayDemographicsNudge {
                        nudgeDismissed = true
                    }
                }
                ForEach(viewModel.dueExercises, id: \.persistentModelID) { enrolment in
                    let exerciseId = enrolment.exerciseDefinition?.exerciseId ?? ""
                    ExerciseCard(
                        enrolment: enrolment,
                        prescription: viewModel.currentPrescription(for: enrolment),
                        conflictWarning: viewModel.conflictWarnings[exerciseId],
                        isCompleted: viewModel.completedTodayIds.contains(exerciseId)
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }
}
