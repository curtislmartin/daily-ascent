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
}
