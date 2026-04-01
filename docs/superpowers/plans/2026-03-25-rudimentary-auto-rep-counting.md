# Rudimentary Auto-Rep Counting Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add accelerometer-based rep counting to real-time workout mode on both iPhone and Apple Watch, using peak detection on acceleration magnitude as a placeholder until ML-based counting is trained.

**Architecture:** A pure `RepCounter` class in the Shared package runs a low-pass filter + peak detection algorithm on raw accelerometer samples. Both `MotionRecordingService` (iPhone) and `WatchMotionRecordingService` (Watch) gain an `onSample` callback that is called inside their existing `CMDeviceMotionHandler`, feeding samples to a `RepCounter` without requiring a second `CMMotionManager` instance. The counter's `count` property drives updated `RealTimeCountingView` and `WatchRealTimeCountingView` UIs that show automatic counts with manual adjustment fallback.

**Tech Stack:** Swift 6.2, CoreMotion (existing), `@Observable`, SwiftUI, Swift Testing

---

## Supported exercises

| Exercise | Device | Auto count |
|---|---|---|
| push_ups | iPhone (pocket) | ✓ |
| pull_ups | iPhone (pocket) | ✓ |
| glute_bridges | iPhone (pocket) | ✓ |
| squats | iPhone (pocket) | ✓ |
| sit_ups | Apple Watch (wrist) | ✓ |
| dead_bugs | — | ✗ (manual only) |

---

## File Map

**Create:**
- `Shared/Sources/InchShared/Engine/RepCounter.swift` — pure algorithm, no CoreMotion, `@Observable`
- `Shared/Tests/InchSharedTests/RepCounterTests.swift` — algorithm tests

**Modify:**
- `inch/inch/Services/MotionRecordingService.swift` — add `onSample` callback, call it in existing CMDeviceMotionHandler
- `inch/inchwatch Watch App/Services/WatchMotionRecordingService.swift` — same
- `inch/inch/Features/Workout/RealTimeCountingView.swift` — accept optional `RepCounter`, show auto count + manual adjust
- `inch/inch/Features/Workout/WorkoutSessionView.swift` — create `RepCounter` for supported exercises, wire to recording service
- `inch/inchwatch Watch App/Features/WatchRealTimeCountingView.swift` — accept optional `RepCounter`, show auto count + manual adjust
- `inch/inchwatch Watch App/Features/WatchWorkoutView.swift` — create `RepCounter` for sit_ups, wire to watch recording service

---

## Chunk 1: RepCounter algorithm

### Task 1: RepCounter in Shared

**Files:**
- Create: `Shared/Sources/InchShared/Engine/RepCounter.swift`
- Create: `Shared/Tests/InchSharedTests/RepCounterTests.swift`

The algorithm:
1. Compute acceleration magnitude: `√(ax² + ay² + az²)`
2. Apply low-pass filter: `smoothed = α × mag + (1−α) × smoothed`
3. Detect rising peaks above threshold with minimum inter-rep interval
4. Each qualifying peak increments `count` on the main queue

`RepCountingConfig` encodes per-exercise parameters. `config(for:)` returns `nil` for unsupported exercises — the caller uses this to decide whether to enable auto-counting at all.

- [ ] **Step 1: Write the failing tests**

Create `Shared/Tests/InchSharedTests/RepCounterTests.swift`:

```swift
import Testing
@testable import InchShared

struct RepCounterTests {

    // MARK: - Config

    @Test func configExistsForSupportedExercises() {
        for id in ["push_ups", "pull_ups", "squats", "glute_bridges", "sit_ups"] {
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

        // Each component is 0.2, magnitude = √(3×0.04) ≈ 0.346 > 0.3
        counter.processSample(ax: 0.2, ay: 0.2, az: 0.2)
        counter.processSample(ax: 0.0, ay: 0.0, az: 0.0) // valley

        await Task.yield()
        #expect(counter.count == 1)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/curtismartin/Work/inch-project
xcodebuild test \
  -scheme InchShared \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  2>&1 | grep -E "(PASSED|FAILED|error:)" | tail -20
```

Expected: build error — `RepCounter` and `RepCountingConfig` don't exist yet.

- [ ] **Step 3: Implement RepCounter**

Create `Shared/Sources/InchShared/Engine/RepCounter.swift`:

```swift
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

    public private(set) var count: Int = 0

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

        if smoothed > config.threshold && smoothed > previous && elapsed >= config.minIntervalSeconds {
            lastRepTime = now
            DispatchQueue.main.async { self.count += 1 }
        }
        previous = smoothed
    }

    /// Resets all state. Call on the main actor before starting a new set.
    public func reset() {
        smoothed = 0
        previous = 0
        lastRepTime = .distantPast
        count = 0
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd /Users/curtismartin/Work/inch-project
xcodebuild test \
  -scheme InchShared \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  2>&1 | grep -E "(PASSED|FAILED|error:)" | tail -20
```

Expected: all RepCounterTests PASSED.

- [ ] **Step 5: Commit**

```bash
git add Shared/Sources/InchShared/Engine/RepCounter.swift \
        Shared/Tests/InchSharedTests/RepCounterTests.swift
git commit -m "feat: add RepCounter algorithm with per-exercise config"
```

---

## Chunk 2: Wire RepCounter into iPhone recording service and workout UI

### Task 2: Add onSample callback to MotionRecordingService

**Files:**
- Modify: `inch/inch/Services/MotionRecordingService.swift`

Add a single `nonisolated(unsafe)` callback property. The existing `CMDeviceMotionHandler` calls it on every sample — after writing to file — so recording and counting share one stream with zero duplication.

- [ ] **Step 1: Add the callback property**

In `MotionRecordingService`, add after the `flushAndClose` declaration:

```swift
// Called on the sensor OperationQueue for every sample while recording.
// Set before calling startRecording; cleared in stopRecording.
// nonisolated(unsafe) — only ever mutated/read on the serial sensor OperationQueue
// or on @MainActor (when nil, between sets).
nonisolated(unsafe) var onSample: ((Double, Double, Double) -> Void)?
```

- [ ] **Step 2: Call the callback in the CMDeviceMotionHandler**

Inside `startDeviceMotionUpdates`, in the `CMDeviceMotionHandler` closure, add one line after reading the acceleration values and before writing to the buffer:

```swift
// Existing reads:
let ax = Float32(data.userAcceleration.x)
let ay = Float32(data.userAcceleration.y)
let az = Float32(data.userAcceleration.z)

// Add:
onSample?(Double(data.userAcceleration.x),
          Double(data.userAcceleration.y),
          Double(data.userAcceleration.z))

// Existing buffer write follows...
```

- [ ] **Step 3: Clear callback in stopRecording**

In `stopRecording()`, add after `flushAndClose?()`:

```swift
onSample = nil
```

- [ ] **Step 4: Build to confirm no errors**

```bash
cd /Users/curtismartin/Work/inch-project/inch
xcodebuild build \
  -scheme inch \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add inch/inch/Services/MotionRecordingService.swift
git commit -m "feat: add onSample callback to MotionRecordingService for rep counting"
```

---

### Task 3: Update RealTimeCountingView to show auto count

**Files:**
- Modify: `inch/inch/Features/Workout/RealTimeCountingView.swift`

The view receives an optional `RepCounter`. When non-nil, the count display is driven by the counter's `count` property. A `+1 / −1` adjustment row lets the user correct misses or double-counts. The "Tap Each Rep" button remains but is labelled "Add Rep" for clarity, acting as a manual override. When `repCounter` is nil (dead_bugs or unrecognised exercise), the view behaves exactly as before.

- [ ] **Step 1: Update RealTimeCountingView**

Replace the entire file content:

```swift
import SwiftUI
import InchShared

struct RealTimeCountingView: View {
    let targetReps: Int
    var autoCompleteAtTarget: Bool = true
    var repCounter: RepCounter? = nil
    let onComplete: (Int) -> Void

    @State private var manualCount: Int = 0
    @State private var showingCompletion: Bool = false
    @State private var targetReached: Bool = false

    private var count: Int {
        repCounter?.count ?? manualCount
    }

    private var progress: Double {
        targetReps > 0 ? min(Double(count) / Double(targetReps), 1) : 0
    }

    private var ringColor: Color {
        targetReached ? .green : .accentColor
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(.secondary.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.2), value: count)

                VStack(spacing: 2) {
                    Text("\(count)")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if repCounter != nil {
                        Text("auto")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 200, height: 200)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(count) reps\(repCounter != nil ? ", auto counted" : "")")

            if targetReached {
                Text("Target reached! Keep going.")
                    .font(.subheadline)
                    .foregroundStyle(.green)
                    .transition(.opacity.combined(with: .scale))
            } else {
                Text("target: \(targetReps)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if repCounter != nil {
                // Auto mode: adjustment row + done button
                HStack(spacing: 20) {
                    Button {
                        adjustCount(by: -1)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove rep")

                    Button {
                        adjustCount(by: 1)
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundStyle(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add rep")
                }

                Button("Done — \(count) reps") {
                    finish(reps: count)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(count == 0 || showingCompletion)
            } else {
                // Manual mode: tap button
                Button {
                    tapRep()
                } label: {
                    Text("Tap Each Rep")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(showingCompletion)
                .accessibilityHint("Double-tap to count one rep")

                if count > 0 {
                    Button("Done — \(count) reps") {
                        finish(reps: count)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
            }
        }
        .animation(.spring(duration: 0.2), value: count)
        .animation(.easeInOut(duration: 0.3), value: targetReached)
        .onChange(of: count) { _, newValue in
            if newValue >= targetReps && !targetReached {
                targetReached = true
                if autoCompleteAtTarget && repCounter == nil {
                    showingCompletion = true
                    finish(reps: newValue)
                }
            }
        }
    }

    // MARK: - Private

    private func tapRep() {
        manualCount += 1
    }

    private func adjustCount(by delta: Int) {
        guard let counter = repCounter else { return }
        let adjusted = max(0, counter.count + delta)
        counter.count = adjusted
    }

    private func finish(reps: Int) {
        onComplete(reps)
    }
}
```

> **Note:** `adjustCount` sets `counter.count` directly — `RepCounter.count` needs to be settable. In Task 1, `count` was declared `public private(set) var`. Change the declaration to `public var count: Int = 0` in `RepCounter.swift` to allow external adjustment by the view.

- [ ] **Step 2: Make RepCounter.count publicly settable**

In `Shared/Sources/InchShared/Engine/RepCounter.swift`, change:

```swift
public private(set) var count: Int = 0
```

to:

```swift
public var count: Int = 0
```

- [ ] **Step 3: Build to confirm no errors**

```bash
cd /Users/curtismartin/Work/inch-project/inch
xcodebuild build \
  -scheme inch \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add inch/inch/Features/Workout/RealTimeCountingView.swift \
        Shared/Sources/InchShared/Engine/RepCounter.swift
git commit -m "feat: update RealTimeCountingView to display auto rep count with manual adjustment"
```

---

### Task 4: Wire RepCounter into WorkoutSessionView (iPhone)

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutSessionView.swift`

`WorkoutSessionView` creates a `RepCounter` if the exercise supports it (i.e., `RepCountingConfig.config(for: exerciseId)` returns non-nil AND the phone is the expected device — i.e., not sit_ups, which uses the watch). When recording starts for a real-time set, it sets `motionRecording.onSample` to route samples to the counter. When the set ends, it clears the callback and resets the counter for the next set.

The watch handles sit_ups auto-counting independently (Task 5/6), so the iPhone explicitly skips it.

- [ ] **Step 1: Add repCounter state and phone-supported set**

Add to `WorkoutSessionView`, after the existing `@State` declarations:

```swift
@State private var repCounter: RepCounter? = nil

/// Exercises where the iPhone pocket signal is used for auto-counting.
/// sit_ups is excluded — the watch wrist signal is better for that exercise.
private static let phoneAutoCountedExercises: Set<String> = [
    "push_ups", "pull_ups", "squats", "glute_bridges"
]
```

- [ ] **Step 2: Create the counter on view appear**

In the `.task` modifier (after `viewModel.load`), add:

```swift
let id = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
if Self.phoneAutoCountedExercises.contains(id),
   let config = RepCountingConfig.config(for: id) {
    repCounter = RepCounter(config: config)
}
```

- [ ] **Step 3: Wire onSample when real-time recording starts**

In the existing `RealTimeCountingView.onAppear` block (inside `readyView`), after `motionRecording.startRecording(...)`, add:

```swift
repCounter?.reset()
motionRecording.onSample = { [repCounter] ax, ay, az in
    repCounter?.processSample(ax: ax, ay: ay, az: az)
}
```

- [ ] **Step 4: Clear onSample when set completes**

In the `RealTimeCountingView` completion closure (inside `readyView`), before calling `viewModel.completeRealTimeSet`, the recording is already stopped via `motionRecording.stopRecording()` which already clears `onSample`. No additional change needed — `stopRecording` handles cleanup.

- [ ] **Step 5: Pass repCounter to RealTimeCountingView**

Update the `RealTimeCountingView` initialisation in `readyView` to pass the counter:

```swift
RealTimeCountingView(
    targetReps: viewModel.currentTargetReps,
    repCounter: repCounter
) { actual in
    // existing completion closure unchanged
}
```

- [ ] **Step 6: Build to confirm no errors**

```bash
cd /Users/curtismartin/Work/inch-project/inch
xcodebuild build \
  -scheme inch \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 7: Commit**

```bash
git add inch/inch/Features/Workout/WorkoutSessionView.swift
git commit -m "feat: wire RepCounter into iPhone real-time workout for auto rep counting"
```

---

## Chunk 3: Wire RepCounter into Watch recording service and Watch UI

### Task 5: Add onSample callback to WatchMotionRecordingService

**Files:**
- Modify: `inch/inchwatch Watch App/Services/WatchMotionRecordingService.swift`

Identical pattern to Task 2 — add `onSample`, call it in the handler, clear it in stop.

- [ ] **Step 1: Add the callback property**

After the `flushAndClose` declaration in `WatchMotionRecordingService`:

```swift
nonisolated(unsafe) var onSample: ((Double, Double, Double) -> Void)?
```

- [ ] **Step 2: Call the callback in startDeviceMotionUpdates**

Inside the `CMDeviceMotionHandler`, after reading the acceleration values:

```swift
onSample?(Double(data.userAcceleration.x),
          Double(data.userAcceleration.y),
          Double(data.userAcceleration.z))
```

- [ ] **Step 3: Clear callback in stopAndTransfer**

In `stopAndTransfer(...)`, after `flushAndClose?()`:

```swift
onSample = nil
```

- [ ] **Step 4: Build watch target to confirm no errors**

```bash
cd /Users/curtismartin/Work/inch-project/inch
xcodebuild build \
  -scheme inchwatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add "inch/inchwatch Watch App/Services/WatchMotionRecordingService.swift"
git commit -m "feat: add onSample callback to WatchMotionRecordingService for rep counting"
```

---

### Task 6: Update WatchRealTimeCountingView and wire into WatchWorkoutView

**Files:**
- Modify: `inch/inchwatch Watch App/Features/WatchRealTimeCountingView.swift`
- Modify: `inch/inchwatch Watch App/Features/WatchWorkoutView.swift`

The watch shows auto count for `sit_ups` (the exercise where wrist signal is best). Other exercises on watch use manual tap counting as before. The digital crown still adjusts the count in both modes.

- [ ] **Step 1: Update WatchRealTimeCountingView**

Replace the file content:

```swift
import SwiftUI
import InchShared

struct WatchRealTimeCountingView: View {
    let targetReps: Int
    let setNumber: Int
    let totalSets: Int
    var repCounter: RepCounter? = nil
    let onComplete: (Int) -> Void

    @State private var manualCount: Int = 0
    @State private var crownValue: Double = 0

    private var count: Int {
        repCounter?.count ?? manualCount
    }

    var body: some View {
        VStack(spacing: 4) {
            Text("Set \(setNumber) of \(totalSets)")
                .font(.caption)
                .foregroundStyle(.secondary)

            progressDots

            Spacer(minLength: 2)

            VStack(spacing: 1) {
                Text("\(count)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if repCounter != nil {
                    Text("auto")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text("/ \(targetReps) target")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer(minLength: 2)

            if repCounter != nil {
                Button("Done (\(count))") {
                    onComplete(count)
                }
                .buttonStyle(.borderedProminent)
                .disabled(count == 0)
            } else {
                Button {
                    tapRep()
                } label: {
                    Text("Tap to Count")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                if count > 0 {
                    Button("Done (\(count))") {
                        onComplete(count)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
        .sensoryFeedback(.impact(flexibility: .rigid), trigger: count)
        .focusable()
        .digitalCrownRotation(
            $crownValue,
            from: 0,
            through: 9999,
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: crownValue) { _, newValue in
            let clamped = max(0, Int(newValue.rounded()))
            if let counter = repCounter {
                if clamped != counter.count { counter.count = clamped }
            } else {
                if clamped != manualCount { manualCount = clamped }
            }
        }
        .onChange(of: count) { _, newValue in
            // Keep crown value in sync when auto count changes
            if abs(crownValue - Double(newValue)) > 0.5 {
                crownValue = Double(newValue)
            }
        }
    }

    private func tapRep() {
        manualCount += 1
        crownValue = Double(manualCount)
    }

    private var progressDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSets, id: \.self) { i in
                Circle()
                    .fill(i < setNumber - 1 ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
    }
}
```

- [ ] **Step 2: Add repCounter state to WatchWorkoutView**

In `WatchWorkoutView`, add after the existing `@State` declarations:

```swift
@State private var repCounter: RepCounter? = nil

/// Only sit_ups uses watch wrist signal for auto-counting.
private static let watchAutoCountedExercises: Set<String> = ["sit_ups"]
```

- [ ] **Step 3: Initialise repCounter on task start**

In the `.task` modifier in `WatchWorkoutView` (before the `for await trigger` loop), add:

```swift
if Self.watchAutoCountedExercises.contains(session.exerciseId),
   let config = RepCountingConfig.config(for: session.exerciseId) {
    repCounter = RepCounter(config: config)
}
```

- [ ] **Step 4: Wire onSample when recording starts for real-time sets**

In the `.onChange(of: viewModel.phase)` handler, in the `.inSet` case, after `motionRecording.startRecording(...)`, add:

```swift
if session.countingMode == "real_time" {
    repCounter?.reset()
    motionRecording.onSample = { [repCounter] ax, ay, az in
        repCounter?.processSample(ax: ax, ay: ay, az: az)
    }
}
```

- [ ] **Step 5: Pass repCounter to WatchRealTimeCountingView**

Update the `WatchRealTimeCountingView` instantiation in the `.inSet` branch of `WatchWorkoutView`:

```swift
WatchRealTimeCountingView(
    targetReps: viewModel.targetReps,
    setNumber: viewModel.currentSet,
    totalSets: viewModel.totalSets,
    repCounter: repCounter
) { count in
    viewModel.endSetRealTime(count: count)
}
```

- [ ] **Step 6: Build both targets**

```bash
cd /Users/curtismartin/Work/inch-project/inch
xcodebuild build \
  -scheme inch \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5

xcodebuild build \
  -scheme inchwatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
  2>&1 | grep -E "(error:|BUILD SUCCEEDED|BUILD FAILED)" | tail -5
```

Expected: both BUILD SUCCEEDED.

- [ ] **Step 7: Run full test suite**

```bash
cd /Users/curtismartin/Work/inch-project
xcodebuild test \
  -scheme InchShared \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  2>&1 | grep -E "(PASSED|FAILED|error:)" | tail -20
```

Expected: all tests PASSED.

- [ ] **Step 8: Upload to TestFlight**

```bash
cd /Users/curtismartin/Work/inch-project
./scripts/upload-testflight.sh
```

- [ ] **Step 9: Final commit**

```bash
git add "inch/inchwatch Watch App/Features/WatchRealTimeCountingView.swift" \
        "inch/inchwatch Watch App/Features/WatchWorkoutView.swift"
git commit -m "feat: wire RepCounter into Watch real-time workout for sit_ups auto counting"
```
