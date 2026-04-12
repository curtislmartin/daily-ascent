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
        case "hip_hinge":
            return RepCountingConfig(threshold: 0.25, minIntervalSeconds: 1.0, smoothingAlpha: 0.2)
        default:
            return nil
        }
    }
}

/// Counts reps from a live accelerometer stream using low-pass filtering and peak detection.
///
/// `processSample` must be called exclusively from a single serial `OperationQueue` (the same
/// queue used by `CMMotionManager`). All internal mutable state is only ever written from that
/// queue. `count` is written on the same queue; callers reading `count` on the main actor will
/// always see a consistent value since `Int` writes are atomic on supported platforms and the
/// serial queue prevents concurrent writes.
@Observable
public final class RepCounter {
    // Mutated only from the serial sensor OperationQueue.
    private var smoothed: Double = 0
    private var previous: Double = 0
    private var lastRepTime: Date = .distantPast
    private var wasBelow: Bool = true

    public var count: Int = 0

    private let config: RepCountingConfig

    public init(config: RepCountingConfig) {
        self.config = config
    }

    /// Call once per `CMDeviceMotion` sample from the sensor OperationQueue.
    /// Uses `userAcceleration` components (gravity already removed by Core Motion).
    nonisolated public func processSample(ax: Double, ay: Double, az: Double) {
        let mag = (ax * ax + ay * ay + az * az).squareRoot()
        smoothed = config.smoothingAlpha * mag + (1.0 - config.smoothingAlpha) * smoothed

        let now = Date.now
        let elapsed = now.timeIntervalSince(lastRepTime)

        if smoothed <= config.threshold {
            wasBelow = true
        }

        if wasBelow && smoothed > config.threshold && smoothed > previous && elapsed >= config.minIntervalSeconds {
            lastRepTime = now
            count += 1
            wasBelow = false
        }
        previous = smoothed
    }

    /// Resets all state. Call before starting a new set.
    public func reset() {
        smoothed = 0
        previous = 0
        lastRepTime = .distantPast
        wasBelow = true
        count = 0
    }
}
