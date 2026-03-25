import Foundation

public struct RepCountingConfig: Sendable {
    public let threshold: Double
    public let minIntervalSeconds: Double
    public let smoothingAlpha: Double

    public init(threshold: Double, minIntervalSeconds: Double, smoothingAlpha: Double) {
        self.threshold = threshold
        self.minIntervalSeconds = minIntervalSeconds
        self.smoothingAlpha = smoothingAlpha
    }

    /// Returns nil for exercises that don't support auto-counting (caller should fall back to manual).
    public static func config(for exerciseId: String) -> RepCountingConfig? {
        switch exerciseId {
        case "push_ups":
            return RepCountingConfig(threshold: 0.30, minIntervalSeconds: 0.8, smoothingAlpha: 0.2)
        case "pull_ups":
            return RepCountingConfig(threshold: 0.30, minIntervalSeconds: 1.0, smoothingAlpha: 0.2)
        case "squats":
            return RepCountingConfig(threshold: 0.40, minIntervalSeconds: 0.8, smoothingAlpha: 0.2)
        case "glute_bridges":
            return RepCountingConfig(threshold: 0.25, minIntervalSeconds: 1.0, smoothingAlpha: 0.2)
        case "sit_ups":
            return RepCountingConfig(threshold: 0.25, minIntervalSeconds: 1.2, smoothingAlpha: 0.15)
        default:
            return nil
        }
    }
}

/// Counts reps from a live accelerometer stream using low-pass filtering and peak detection.
///
/// `processSample` is designed to be called from a serial `OperationQueue` (same queue used by
/// `CMMotionManager`). Internal mutable state is `nonisolated(unsafe)` — safe because it is only
/// ever mutated from that single serial queue. `count` is incremented via a main-queue dispatch so
/// SwiftUI observation works correctly.
@Observable
public final class RepCounter {
    // Accessed only from the serial sensor OperationQueue — not a data race.
    nonisolated(unsafe) private var smoothed: Double = 0
    nonisolated(unsafe) private var previous: Double = 0
    nonisolated(unsafe) private var lastRepTime: Date = .distantPast

    // Written only from the main queue via DispatchQueue.main.async — safe.
    nonisolated(unsafe) public var count: Int = 0

    private let config: RepCountingConfig

    public init(config: RepCountingConfig) {
        self.config = config
    }

    /// Call once per `CMDeviceMotion` sample from the sensor OperationQueue.
    /// Uses `userAcceleration` components (gravity already removed by Core Motion).
    ///
    /// `count` is `nonisolated(unsafe)` and written only from the serial sensor
    /// OperationQueue, so there is no data race. SwiftUI views observing `count`
    /// should read it on the main actor; since the sensor queue is serial and
    /// `count` writes are not concurrent, the value is always consistent when read.
    nonisolated public func processSample(ax: Double, ay: Double, az: Double) {
        let mag = (ax * ax + ay * ay + az * az).squareRoot()
        smoothed = config.smoothingAlpha * mag + (1.0 - config.smoothingAlpha) * smoothed

        let now = Date.now
        let elapsed = now.timeIntervalSince(lastRepTime)

        if smoothed > config.threshold && smoothed > previous && elapsed >= config.minIntervalSeconds {
            lastRepTime = now
            count += 1
        }
        previous = smoothed
    }

    /// Resets all state. Call before starting a new set.
    public func reset() {
        smoothed = 0
        previous = 0
        lastRepTime = .distantPast
        count = 0
    }
}
