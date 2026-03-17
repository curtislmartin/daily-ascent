import Foundation
import SwiftData
import InchShared

@Observable
final class SettingsViewModel {
    var settings: UserSettings?
    var enrolments: [ExerciseEnrolment] = []

    func load(context: ModelContext) {
        settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first
        let descriptor = FetchDescriptor<ExerciseEnrolment>(
            predicate: #Predicate { $0.isActive }
        )
        enrolments = (try? context.fetch(descriptor)) ?? []
    }

    func restSeconds(for enrolment: ExerciseEnrolment) -> Int {
        guard let exerciseId = enrolment.exerciseDefinition?.exerciseId,
              let override = settings?.restOverrides[exerciseId]
        else {
            return enrolment.exerciseDefinition?.defaultRestSeconds ?? 60
        }
        return override
    }

    func setRestSeconds(_ seconds: Int, for enrolment: ExerciseEnrolment, context: ModelContext) {
        guard let exerciseId = enrolment.exerciseDefinition?.exerciseId else { return }
        settings?.restOverrides[exerciseId] = seconds
        try? context.save()
    }

    func countingMode(for enrolment: ExerciseEnrolment) -> CountingMode {
        guard let exerciseId = enrolment.exerciseDefinition?.exerciseId,
              let raw = settings?.countingModeOverrides[exerciseId],
              let mode = CountingMode(rawValue: raw)
        else {
            return enrolment.exerciseDefinition?.countingMode ?? .postSetConfirmation
        }
        return mode
    }

    func setCountingMode(_ mode: CountingMode, for enrolment: ExerciseEnrolment, context: ModelContext) {
        guard let exerciseId = enrolment.exerciseDefinition?.exerciseId else { return }
        settings?.countingModeOverrides[exerciseId] = mode.rawValue
        try? context.save()
    }

    func resetRestTimers(context: ModelContext) {
        settings?.restOverrides = [:]
        try? context.save()
    }

    func deleteHistory(context: ModelContext) {
        resetStreak(context: context)
        try? context.delete(model: CompletedSet.self)
        try? context.save()
    }

    func resetToOnboarding(context: ModelContext) {
        resetStreak(context: context)
        try? context.delete(model: CompletedSet.self)
        try? context.delete(model: ExerciseEnrolment.self)
        try? context.delete(model: UserSettings.self)
        try? context.save()
    }

    func deleteContributedData(context: ModelContext) {
        guard let settings,
              !settings.contributorId.isEmpty,
              settings.motionDataUploadConsented
        else { return }

        let contributorId = settings.contributorId
        Task {
            do {
                try await DataUploadService().unlinkContributorData(contributorId: contributorId)
                settings.contributorId = UUID().uuidString.lowercased()
                settings.motionDataUploadConsented = false
                settings.consentDate = nil
                try? context.save()
            } catch {
                // Silent failure — user can try again
            }
        }
    }

    private func resetStreak(context: ModelContext) {
        let descriptor = FetchDescriptor<StreakState>()
        guard let state = (try? context.fetch(descriptor))?.first else { return }
        state.currentStreak = 0
        state.longestStreak = 0
        state.lastActiveDate = nil
    }
}
