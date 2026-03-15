import Foundation
import InchShared

@Observable
final class ProgramViewModel {

    func levelProgress(for enrolment: ExerciseEnrolment) -> Double {
        guard let totalDays = levelTotalDays(for: enrolment), totalDays > 0 else { return 0 }
        return Double(enrolment.currentDay - 1) / Double(totalDays)
    }

    func levelTotalDays(for enrolment: ExerciseEnrolment) -> Int? {
        enrolment.exerciseDefinition?
            .levels?
            .first(where: { $0.level == enrolment.currentLevel })?
            .totalDays
    }

    func estimatedCompletion(for enrolment: ExerciseEnrolment) -> Date? {
        guard let totalDays = levelTotalDays(for: enrolment),
              let nextDate = enrolment.nextScheduledDate
        else { return nil }
        let remaining = totalDays - enrolment.currentDay
        guard remaining > 0 else { return nextDate }
        // Average gap of 2.3 days based on typical rest pattern [2,2,3]
        let estimatedDays = Int(Double(remaining) * 2.3)
        return Calendar.current.date(byAdding: .day, value: estimatedDays, to: nextDate)
    }
}
