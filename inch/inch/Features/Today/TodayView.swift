import SwiftUI
import SwiftData
import InchShared

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(WatchConnectivityService.self) private var watchConnectivity
    @Environment(AnalyticsService.self) private var analytics
    @Query private var streakStates: [StreakState]
    @Query private var allSettings: [UserSettings]

    @State private var viewModel = TodayViewModel()
    @State private var nudgeDismissed = false
    @Environment(NotificationService.self) private var notifications
    @State private var streakRecoveryDismissed = false

    private var settings: UserSettings? { allSettings.first }

    private var showDemographicsNudge: Bool {
        guard let s = allSettings.first else { return false }
        return !nudgeDismissed && !s.hasDemographics
    }

    private var showConflictWarnings: Bool { allSettings.first?.showConflictWarnings ?? true }

    private var streak: Int { streakStates.first?.currentStreak ?? 0 }
    private var longestStreak: Int { streakStates.first?.longestStreak ?? 0 }

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
                    nextTrainingDayExercises: viewModel.nextTrainingDayExercises,
                    hasTrainedBefore: viewModel.hasTrainedBefore
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
            viewModel.configure(analytics: analytics)
            viewModel.loadToday(context: modelContext, showWarnings: showConflictWarnings)
            watchConnectivity.sendTodaySchedule(
                enrolments: viewModel.dueExercises,
                settings: settings
            )
        }
        .onAppear {
            viewModel.configure(analytics: analytics)
            viewModel.loadToday(context: modelContext, showWarnings: showConflictWarnings)
            if viewModel.streakWasJustReset, let nextDate = viewModel.nextTrainingDate {
                notifications.scheduleStreakRecovery(nextTrainingDate: nextDate)
            }
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
                if streak == 0 && longestStreak > 0 && !viewModel.isRestDay && !streakRecoveryDismissed {
                    StreakRecoveryBanner {
                        streakRecoveryDismissed = true
                    }
                }
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
