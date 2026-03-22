import Foundation
import HealthKit

@Observable
final class HealthKitService {
    private let healthStore = HKHealthStore()
    private(set) var isAuthorized: Bool = false

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        ]

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            isAuthorized = healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
        } catch {
            // Authorization failed — app continues without HealthKit
        }
    }

    func saveWorkout(
        startDate: Date,
        endDate: Date,
        totalEnergyBurned: Double?,
        metadata: [String: Any]
    ) async {
        guard HKHealthStore.isHealthDataAvailable(), isAuthorized else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining

        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())

        do {
            try await builder.beginCollection(at: startDate)

            if let calories = totalEnergyBurned {
                let energySample = HKQuantitySample(
                    type: HKQuantityType(.activeEnergyBurned),
                    quantity: HKQuantity(unit: .kilocalorie(), doubleValue: calories),
                    start: startDate,
                    end: endDate
                )
                try await builder.addSamples([energySample])
            }

            if !metadata.isEmpty {
                try await builder.addMetadata(metadata)
            }

            try await builder.endCollection(at: endDate)
            try await builder.finishWorkout()
        } catch {
            // Save failed silently — workout data is already in SwiftData
        }
    }
}
