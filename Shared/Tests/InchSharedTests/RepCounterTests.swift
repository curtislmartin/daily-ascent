import Testing
@testable import InchShared

struct RepCounterTests {

    // MARK: - Config

    @Test func configExistsForSupportedExercises() {
        for id in ["push_ups", "pull_ups", "squats", "hip_hinge"] {
            #expect(RepCountingConfig.config(for: id) != nil, "Missing config for \(id)")
        }
    }

    @Test func configAbsentForDeadBugs() {
        #expect(RepCountingConfig.config(for: "dead_bugs") == nil)
    }

    @Test func configAbsentForUnknownExercise() {
        #expect(RepCountingConfig.config(for: "unknown") == nil)
    }

    // MARK: - Peak detection

    @Test func countsRepOnClearPeak() async {
        let config = RepCountingConfig(threshold: 0.3, minIntervalSeconds: 0.5, smoothingAlpha: 1.0)
        let counter = RepCounter(config: config)

        // Feed a sample above threshold — smoothingAlpha=1 means no smoothing, direct pass-through
        counter.processSample(ax: 0.4, ay: 0.0, az: 0.0)
        // Feed a lower sample so the "rising" condition resets
        counter.processSample(ax: 0.1, ay: 0.0, az: 0.0)

        await Task.yield() // let main-queue dispatch run
        #expect(counter.count == 1)
    }

    @Test func doesNotCountBelowThreshold() async {
        let config = RepCountingConfig(threshold: 0.3, minIntervalSeconds: 0.5, smoothingAlpha: 1.0)
        let counter = RepCounter(config: config)

        counter.processSample(ax: 0.1, ay: 0.0, az: 0.0)
        counter.processSample(ax: 0.2, ay: 0.0, az: 0.0)

        await Task.yield()
        #expect(counter.count == 0)
    }

    @Test func debouncesRapidPeaks() async {
        // Two peaks within minInterval — only first should count
        let config = RepCountingConfig(threshold: 0.3, minIntervalSeconds: 60.0, smoothingAlpha: 1.0)
        let counter = RepCounter(config: config)

        counter.processSample(ax: 0.5, ay: 0.0, az: 0.0)
        counter.processSample(ax: 0.1, ay: 0.0, az: 0.0) // valley
        counter.processSample(ax: 0.5, ay: 0.0, az: 0.0) // second peak — should be blocked

        await Task.yield()
        #expect(counter.count == 1)
    }

    @Test func resetClearsCount() async {
        let config = RepCountingConfig(threshold: 0.3, minIntervalSeconds: 0.0, smoothingAlpha: 1.0)
        let counter = RepCounter(config: config)

        counter.processSample(ax: 0.5, ay: 0.0, az: 0.0)
        counter.processSample(ax: 0.1, ay: 0.0, az: 0.0)
        await Task.yield()
        #expect(counter.count == 1)

        counter.reset()
        #expect(counter.count == 0)
    }

    @Test func requiresDropBelowThresholdBetweenReps() async {
        // Simulates squat double-counting: two peaks without the signal dropping below threshold
        let config = RepCountingConfig(threshold: 0.3, minIntervalSeconds: 0.0, smoothingAlpha: 1.0)
        let counter = RepCounter(config: config)

        // First peak — should count
        counter.processSample(ax: 0.5, ay: 0.0, az: 0.0)
        // Dips but stays above threshold
        counter.processSample(ax: 0.35, ay: 0.0, az: 0.0)
        // Second peak without crossing below — should NOT count
        counter.processSample(ax: 0.6, ay: 0.0, az: 0.0)

        await Task.yield()
        #expect(counter.count == 1)

        // Now drop below threshold and produce another peak — should count
        counter.processSample(ax: 0.1, ay: 0.0, az: 0.0)
        counter.processSample(ax: 0.5, ay: 0.0, az: 0.0)

        await Task.yield()
        #expect(counter.count == 2)
    }

    @Test func usesMagnitudeNotSingleAxis() async {
        // Below threshold on each axis individually, but magnitude is above
        let threshold = 0.3
        let config = RepCountingConfig(threshold: threshold, minIntervalSeconds: 0.0, smoothingAlpha: 1.0)
        let counter = RepCounter(config: config)

        // Each component is 0.2, magnitude = sqrt(3x0.04) ~= 0.346 > 0.3
        counter.processSample(ax: 0.2, ay: 0.2, az: 0.2)
        counter.processSample(ax: 0.0, ay: 0.0, az: 0.0) // valley

        await Task.yield()
        #expect(counter.count == 1)
    }

    // MARK: - Vertical projection

    @Test func verticalProjectionCountsUpwardAcceleration() async {
        // gravity pointing down along -y (phone upright in pocket)
        let config = RepCountingConfig(threshold: 0.3, minIntervalSeconds: 0.0, smoothingAlpha: 1.0, verticalProjection: true)
        let counter = RepCounter(config: config)

        // Upward acceleration: userAcceleration.y is positive (opposing gravity.y = -1)
        // signal = -(0.5 * -1.0) / 1.0 = +0.5 → above threshold → counts
        counter.processSample(ax: 0, ay: 0.5, az: 0, gx: 0, gy: -1.0, gz: 0)
        counter.processSample(ax: 0, ay: 0, az: 0, gx: 0, gy: -1.0, gz: 0) // valley

        await Task.yield()
        #expect(counter.count == 1)
    }

    @Test func verticalProjectionIgnoresDownwardAcceleration() async {
        // gravity pointing down along -y
        let config = RepCountingConfig(threshold: 0.3, minIntervalSeconds: 0.0, smoothingAlpha: 1.0, verticalProjection: true)
        let counter = RepCounter(config: config)

        // Downward acceleration: userAcceleration.y is negative (same direction as gravity.y = -1)
        // signal = -(-0.5 * -1.0) / 1.0 = -0.5 → negative → stays below threshold
        counter.processSample(ax: 0, ay: -0.5, az: 0, gx: 0, gy: -1.0, gz: 0)
        counter.processSample(ax: 0, ay: 0, az: 0, gx: 0, gy: -1.0, gz: 0)

        await Task.yield()
        #expect(counter.count == 0)
    }

    @Test func verticalProjectionRejectsSquatDoubleCounting() async {
        // Simulates a squat: descent acceleration (downward) then ascent acceleration (upward).
        // Only the upward (concentric) phase should count.
        let config = RepCountingConfig(threshold: 0.3, minIntervalSeconds: 0.0, smoothingAlpha: 1.0, verticalProjection: true)
        let counter = RepCounter(config: config)
        let g = (x: 0.0, y: -1.0, z: 0.0) // gravity pointing down

        // Descent: userAccel.y = -0.5 (downward) → signal = -0.5 → no count
        counter.processSample(ax: 0, ay: -0.5, az: 0, gx: g.x, gy: g.y, gz: g.z)
        counter.processSample(ax: 0, ay: 0, az: 0, gx: g.x, gy: g.y, gz: g.z) // pause at bottom

        // Ascent: userAccel.y = +0.5 (upward) → signal = +0.5 → should count
        counter.processSample(ax: 0, ay: 0.5, az: 0, gx: g.x, gy: g.y, gz: g.z)
        counter.processSample(ax: 0, ay: 0, az: 0, gx: g.x, gy: g.y, gz: g.z) // standing

        await Task.yield()
        #expect(counter.count == 1)
    }

    @Test func squatConfigUsesVerticalProjection() {
        let config = RepCountingConfig.config(for: "squats")
        #expect(config != nil)
        #expect(config?.verticalProjection == true)
    }

    @Test func nonSquatConfigsDoNotUseVerticalProjection() {
        for id in ["push_ups", "pull_ups", "hip_hinge"] {
            let config = RepCountingConfig.config(for: id)
            #expect(config?.verticalProjection == false, "\(id) should not use vertical projection")
        }
    }
}
