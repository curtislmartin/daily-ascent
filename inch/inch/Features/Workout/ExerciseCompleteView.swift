import SwiftUI
import InchShared

struct ExerciseCompleteView: View {
    let exerciseName: String
    let totalReps: Int
    let previousSessionReps: Int?
    let nextDate: Date?
    let onDone: () -> Void
    var achievements: [Achievement] = []
    var adaptationMessage: String? = nil
    var showMoveOnAnyway: Bool = false
    var onRatingSubmitted: ((DifficultyRating) -> Void)? = nil
    var onMoveOnAnyway: (() -> Void)? = nil

    @State private var showBanner = false
    @State private var showSheet = false
    @State private var showCelebration = false
    @State private var ratingSubmitted = false

    var body: some View {
        ZStack(alignment: .bottom) {
            mainContent
            if showBanner, let achievement = achievements.first(where: { isTier1($0) }) {
                AchievementBanner(achievement: achievement) {
                    withAnimation { showBanner = false }
                }
                .padding(.bottom, 80)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showSheet) {
            if let achievement = achievements.first(where: { isTier2($0) }) {
                AchievementSheet(achievement: achievement) {
                    showSheet = false
                }
            }
        }
        .fullScreenCover(isPresented: $showCelebration) {
            if let achievement = achievements.first(where: { isTier3($0) }) {
                AchievementCelebrationView(achievement: achievement) {
                    showCelebration = false
                }
            }
        }
        .onAppear {
            triggerCelebrations()
        }
    }

    private var mainContent: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)

                Text("Done!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(exerciseName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(exerciseName) complete. \(totalReps) total reps.")

            VStack(spacing: 8) {
                if totalReps > 0 {
                    Text("\(totalReps) total reps")
                        .font(.headline)
                }
                if let prev = previousSessionReps, prev > 0 {
                    let delta = totalReps - prev
                    Text("\(delta >= 0 ? "+" : "")\(delta) vs last session")
                        .font(.subheadline)
                        .foregroundStyle(delta >= 0 ? .green : .secondary)
                }
                if let next = nextDate {
                    Text("Next session \(next.formatted(.relative(presentation: .named)))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let onRating = onRatingSubmitted, !ratingSubmitted {
                VStack(spacing: 12) {
                    Text("How did that feel?")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        ForEach(DifficultyRating.allCases, id: \.self) { rating in
                            Button(ratingLabel(rating)) {
                                ratingSubmitted = true
                                onRating(rating)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            if let message = adaptationMessage {
                Text(message)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
            }

            if showMoveOnAnyway, let onMoveOn = onMoveOnAnyway {
                Button("Move on anyway") { onMoveOn() }
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            }

            Spacer()

            Button("Done") {
                onDone()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .navigationBarBackButtonHidden()
    }

    private func triggerCelebrations() {
        let tier3 = achievements.filter { isTier3($0) }
        let tier2 = achievements.filter { isTier2($0) }
        let tier1 = achievements.filter { isTier1($0) }
        if !tier3.isEmpty { showCelebration = true }
        else if !tier2.isEmpty { showSheet = true }
        else if !tier1.isEmpty { withAnimation { showBanner = true } }
    }

    private func isTier1(_ a: Achievement) -> Bool {
        let ids = ["first_workout", "first_test", "streak_3", "sessions_5", "sessions_10"]
        return ids.contains(a.id) || a.id.hasPrefix("personal_best_")
    }

    private func isTier2(_ a: Achievement) -> Bool {
        let ids = ["streak_7", "streak_14", "sessions_25", "sessions_50", "the_full_set"]
        return ids.contains(a.id)
    }

    private func ratingLabel(_ rating: DifficultyRating) -> String {
        switch rating {
        case .tooEasy: return "Too easy"
        case .justRight: return "Just right"
        case .tooHard: return "Too hard"
        }
    }

    private func isTier3(_ a: Achievement) -> Bool {
        let ids = ["streak_30", "streak_60", "streak_100", "sessions_100", "program_complete", "test_gauntlet"]
        return ids.contains(a.id) || a.id.hasPrefix("level_complete_")
    }
}
