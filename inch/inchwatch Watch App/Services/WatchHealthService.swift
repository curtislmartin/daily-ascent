import Foundation
import HealthKit

@Observable @MainActor final class WatchHealthService: NSObject {
    private(set) var currentBPM: Int? = nil
    private(set) var isAuthorized: Bool = false

    private var healthStore: HKHealthStore?
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    override init() {
        super.init()
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard let healthStore else { return }
        let read: Set<HKObjectType> = [HKQuantityType(.heartRate)]
        let write: Set<HKSampleType> = [HKObjectType.workoutType()]
        do {
            try await healthStore.requestAuthorization(toShare: write, read: read)
            isAuthorized = true
        } catch {
            isAuthorized = false
        }
    }

    // MARK: - Workout Session

    func startWorkout() async {
        guard session == nil else { return }
        if !isAuthorized { await requestAuthorization() }
        guard isAuthorized, let healthStore else { return }

        let config = HKWorkoutConfiguration()
        config.activityType = .functionalStrengthTraining
        config.locationType = .indoor

        do {
            let newSession = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            let newBuilder = newSession.associatedWorkoutBuilder()
            newBuilder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
            newBuilder.delegate = self

            self.session = newSession
            self.builder = newBuilder

            newSession.startActivity(with: .now)
            try await newBuilder.beginCollection(at: .now)
        } catch {
            // HealthKit unavailable or denied — HR display stays hidden
        }
    }

    func endWorkout() async {
        guard let session, let builder else { return }
        session.end()
        do {
            try await builder.endCollection(at: .now)
            try await builder.finishWorkout()
        } catch {
            // Best-effort — dismiss proceeds regardless
        }
        self.session = nil
        self.builder = nil
        self.currentBPM = nil
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WatchHealthService: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        guard collectedTypes.contains(HKQuantityType(.heartRate)),
              let stats = workoutBuilder.statistics(for: HKQuantityType(.heartRate)),
              let bpm = stats.mostRecentQuantity()?.doubleValue(for: bpmUnit)
        else { return }
        let rounded = Int(bpm.rounded())
        Task { @MainActor in
            self.currentBPM = rounded
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}
}
