import Foundation
import InchShared

@Observable
final class WatchWorkoutViewModel {
    private(set) var session: WatchSession
    private(set) var completedSets: [WatchSetResult] = []
    private(set) var currentSetIndex: Int = 0
    private(set) var pendingRealTimeCount: Int? = nil
    private(set) var phase: WorkoutPhase = .ready

    enum WorkoutPhase: Equatable {
        case ready
        case inSet(startedAt: Date)
        case confirming(targetReps: Int, duration: Double)
        case resting(seconds: Int)
        case complete
    }

    init(session: WatchSession) {
        self.session = session
    }

    var currentSet: Int { currentSetIndex + 1 }
    var totalSets: Int { session.sets.count }
    var targetReps: Int { session.sets[safe: currentSetIndex] ?? 0 }
    var isLastSet: Bool { currentSetIndex >= session.sets.count - 1 }
    var totalReps: Int { completedSets.reduce(0) { $0 + $1.actualReps } }

    var completionReport: WatchCompletionReport {
        WatchCompletionReport(
            exerciseId: session.exerciseId,
            level: session.level,
            dayNumber: session.dayNumber,
            completedSets: completedSets,
            completedAt: .now
        )
    }

    func startSet() {
        phase = .inSet(startedAt: .now)
    }

    func endSet() {
        guard case .inSet(let startedAt) = phase else { return }
        let duration = Date.now.timeIntervalSince(startedAt)
        phase = .confirming(targetReps: targetReps, duration: duration)
    }

    func endSetRealTime(count: Int) {
        pendingRealTimeCount = count
        endSet()
    }

    func clearPendingRealTimeCount() {
        pendingRealTimeCount = nil
    }

    func confirmSet(actual: Int) {
        guard case .confirming(_, let duration) = phase else { return }

        completedSets.append(WatchSetResult(
            setNumber: currentSet,
            targetReps: session.sets[safe: currentSetIndex] ?? actual,
            actualReps: actual,
            durationSeconds: duration
        ))

        if isLastSet {
            phase = .complete
        } else {
            currentSetIndex += 1
            phase = .resting(seconds: session.restSeconds)
        }
    }

    func finishRest() {
        phase = .ready
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
