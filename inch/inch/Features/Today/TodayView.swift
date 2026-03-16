import SwiftUI
import SwiftData
import InchShared

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WatchConnectivityService.self) private var watchConnectivity
    @Query private var streakStates: [StreakState]
    @Query private var allSettings: [UserSettings]

    @State private var viewModel = TodayViewModel()

    private var settings: UserSettings? { allSettings.first }

    private var showConflictWarnings: Bool { allSettings.first?.showConflictWarnings ?? true }

    private var streak: Int { streakStates.first?.currentStreak ?? 0 }

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
                if streak > 0 {
                    streakBanner
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
                if viewModel.showDemographicsNudge {
                    TodayDemographicsNudge {
                        viewModel.showDemographicsNudge = false
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
    }

    private var streakBanner: some View {
        Label("\(streak)-day training streak", systemImage: "flame.fill")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
    }
}
