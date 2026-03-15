# Framework-Specific Guidance

Guidance for Apple frameworks that don't have community agent skills. These patterns are current as of iOS 18 / watchOS 11 / Swift 6.2.

---

## WatchConnectivity

### Activation

Both sides must activate `WCSession` early in the app lifecycle. On iOS, do this in the app's `init()` or first scene appear. On watchOS, do this in `ExtensionDelegate` or the app's `init()`.

```swift
func activate() {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    session.delegate = self
    session.activate()
}
```

iOS requires implementing all three delegate methods even if unused:
- `session(_:activationDidCompleteWith:error:)`
- `sessionDidBecomeInactive(_:)` — iOS only, called when user switches Watch
- `sessionDidDeactivate(_:)` — iOS only, call `session.activate()` here to reactivate

### Which Transfer Method to Use

| Method | Use For | Delivery | Queued? |
|---|---|---|---|
| `sendMessage(_:replyHandler:errorHandler:)` | Real-time data when both apps are reachable | Immediate | No — fails if counterpart unreachable |
| `transferUserInfo(_:)` | Completion reports, schedule updates | Guaranteed, FIFO | Yes — survives app termination |
| `transferFile(_:metadata:)` | Sensor data files (>64KB) | Guaranteed, background | Yes |
| `updateApplicationContext(_:)` | Latest state snapshot (only latest kept) | Latest-wins | Replaced on each call |

**For this app:**
- Schedule pushes (iPhone→Watch): `transferUserInfo` — must arrive in order, queued
- Completion reports (Watch→iPhone): `transferUserInfo` — must be guaranteed
- Sensor data files (Watch→iPhone): `transferFile` — binary data, potentially large
- Quick sync check (either direction): `sendMessage` when reachable, with `transferUserInfo` fallback

### Bridging to AsyncStream

WCSessionDelegate methods are called on a non-main serial queue. Bridge multi-value delegates to `AsyncStream`:

```swift
// In the service class
private let (completionStream, completionContinuation) = AsyncStream<WatchCompletionReport>.makeStream()
var completionReports: AsyncStream<WatchCompletionReport> { completionStream }

// In delegate callback (nonisolated)
nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
    // Decode and yield
    guard let report = decode(userInfo) else { return }
    completionContinuation.yield(report)
}
```

Set `onTermination` on the continuation if cleanup is needed when the consumer stops listening.

### File Transfer Handling

```swift
nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
    // file.fileURL is a temporary location — must copy before this method returns
    let destination = permanentStoragePath(for: file.metadata)
    try? FileManager.default.moveItem(at: file.fileURL, to: destination)
    // Create SensorRecording metadata on the main actor
}
```

The file at `file.fileURL` is deleted after the delegate method returns. Always move/copy it synchronously.

### Background Delivery

Both `transferUserInfo` and `transferFile` are delivered even if the receiving app is suspended. The system wakes the app briefly to deliver pending transfers. Ensure delegate handling is lightweight — do minimal work, persist data, and let the app go back to sleep.

---

## Core Motion (CMMotionManager)

### Setup and Recording

```swift
import CoreMotion

let motionManager = CMMotionManager()

// Check availability
guard motionManager.isAccelerometerAvailable,
      motionManager.isGyroAvailable else { return }

// Set sampling rate (100Hz)
motionManager.accelerometerUpdateInterval = 1.0 / 100.0
motionManager.gyroUpdateInterval = 1.0 / 100.0

// Create a dedicated OperationQueue for sensor callbacks
let sensorQueue = OperationQueue()
sensorQueue.name = "sensor-recording"
sensorQueue.maxConcurrentOperationCount = 1
sensorQueue.qualityOfService = .userInitiated

// Start recording
motionManager.startAccelerometerUpdates(to: sensorQueue) { data, error in
    guard let data else { return }
    // data.acceleration.x, .y, .z
    // data.timestamp (TimeInterval since boot)
}

motionManager.startGyroUpdates(to: sensorQueue) { data, error in
    guard let data else { return }
    // data.rotationRate.x, .y, .z
    // data.timestamp
}

// Stop recording
motionManager.stopAccelerometerUpdates()
motionManager.stopGyroUpdates()
```

### Important Notes

- **Only one `CMMotionManager` per app.** Creating multiple instances degrades performance. Store it as a singleton or in the service class.
- **OperationQueue is correct here.** Core Motion's callback API predates Swift concurrency. Using an OperationQueue is the approved pattern — don't try to wrap this in an actor or async stream for the raw data path. The callback writes directly to a file handle for performance.
- **Timestamps are relative to boot time**, not wall clock. To correlate with wall clock time, capture `Date.now` at recording start and compute offsets.
- **Battery impact.** 100Hz dual-sensor recording has moderate battery cost. Only record during active sets (start on "Start Set", stop on "End Set" / "Done"). Never record during rest timers.
- **watchOS differences.** On watchOS, use `CMMotionManager` the same way. The Watch has accelerometer and gyroscope. Sampling rates may be lower — the Watch may cap at 50Hz. Check `motionManager.accelerometerUpdateInterval` after setting it to see the actual rate.

### File Format for Sensor Data

Write binary for efficiency. Simple format:

```
Header (fixed):
  - magic bytes: "INCH" (4 bytes)
  - version: UInt8 (1 byte)
  - sample_rate_hz: UInt16 (2 bytes)
  - sensor_type: UInt8 (1 byte) — 0=accel, 1=gyro

Samples (repeated):
  - timestamp: Float64 (8 bytes) — seconds since recording start
  - x: Float32 (4 bytes)
  - y: Float32 (4 bytes)
  - z: Float32 (4 bytes)
```

Each sample is 20 bytes. At 100Hz, that's 2KB/sec per sensor, 4KB/sec for both. A 60-second set produces ~240KB total.

---

## HealthKit

### Authorization Request

```swift
import HealthKit

let healthStore = HKHealthStore()

let typesToShare: Set<HKSampleType> = [
    HKObjectType.workoutType()
]

let typesToRead: Set<HKObjectType> = [
    HKObjectType.workoutType(),
    HKObjectType.quantityType(forIdentifier: .heartRate)!,
    HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
]

try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
```

Request authorization before the first workout, not at app launch. The system shows the Health access sheet — requesting too early feels intrusive.

### Saving a Workout (iOS)

```swift
let workout = HKWorkout(
    activityType: .functionalStrengthTraining,
    start: sessionStartDate,
    end: sessionEndDate,
    duration: sessionEndDate.timeIntervalSince(sessionStartDate),
    totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: estimatedCalories),
    totalDistance: nil,
    metadata: [
        "ExercisesCompleted": exerciseNames.joined(separator: ","),
        "TotalReps": totalReps
    ]
)

try await healthStore.save(workout)
```

### watchOS Workout Session

On watchOS, use `HKWorkoutSession` and `HKLiveWorkoutBuilder` for live workout tracking with heart rate:

```swift
let configuration = HKWorkoutConfiguration()
configuration.activityType = .functionalStrengthTraining
configuration.locationType = .indoor

let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
let builder = session.associatedWorkoutBuilder()

builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

session.startActivity(with: .now)
try await builder.beginCollection(at: .now)

// ... workout happens ...

session.end()
try await builder.endCollection(at: .now)
try await builder.finishWorkout()
```

The `HKLiveWorkoutBuilder` automatically collects heart rate, active calories, and other metrics during the session.

### Important Notes

- **Don't save one workout per exercise.** Save a single `HKWorkout` spanning the entire training session (first exercise start to last exercise end). Multiple short workouts clutter the Health timeline.
- **Calories are estimates.** Without weight data, use conservative estimates based on MET values for bodyweight exercise (~3.5 MET for moderate calisthenics). If the user provides weight (future feature), use MET × weight × duration.
- **Always check `HKHealthStore.isHealthDataAvailable()`** before any HealthKit operations. It returns false on iPad.

---

## BGProcessingTask

### Registration

In `Info.plist`, add the task identifier to `BGTaskSchedulerPermittedIdentifiers`:

```xml
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.inch.bodyweight.sensor-upload</string>
</array>
```

Register the handler early — in the `App` `init()` or app delegate:

```swift
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.inch.bodyweight.sensor-upload",
    using: nil  // main queue
) { task in
    guard let processingTask = task as? BGProcessingTask else { return }
    Task {
        await handleSensorUpload(task: processingTask)
    }
}
```

### Scheduling

```swift
func scheduleSensorUpload() {
    let request = BGProcessingTaskRequest(identifier: "com.inch.bodyweight.sensor-upload")
    request.requiresNetworkConnectivity = true
    request.requiresExternalPower = true  // charging required
    request.earliestBeginDate = nil       // as soon as conditions are met
    
    do {
        try BGTaskScheduler.shared.submit(request)
    } catch {
        // BGTaskScheduler.Error.unavailable on simulator
        // BGTaskScheduler.Error.tooManyPendingTaskRequests if >10 pending
    }
}
```

### Handler Implementation

```swift
@concurrent
func handleSensorUpload(task: BGProcessingTask) async {
    // Set expiration handler — system may terminate the task
    task.expirationHandler = {
        // Cancel ongoing upload, save progress
    }
    
    // Fetch pending recordings
    // Compress each file (gzip)
    // Upload to Supabase Storage
    // Update SensorRecording.uploadStatus
    // Mark task complete
    
    let success = await performUpload()
    task.setTaskCompleted(success: success)
    
    // Re-schedule for next batch
    scheduleSensorUpload()
}
```

### Important Notes

- **Test on a real device.** `BGTaskScheduler` does not work in the simulator. Use the Xcode debug command `e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"com.inch.bodyweight.sensor-upload"]` to trigger tasks during development.
- **System decides when to run.** Even with `requiresExternalPower = true` and `requiresNetworkConnectivity = true`, the system chooses the exact timing. Typically overnight during charging.
- **Expiration is real.** The system can terminate the task at any time. Always implement `expirationHandler` and save partial progress.
- **Re-schedule after completion.** `BGProcessingTask` is one-shot. After handling, submit a new request for the next run.
- **Maximum 10 pending requests** across all task identifiers. This app only has one, so this isn't a concern.

---

## StoreKit 2 (Stubbed for v1)

v1 is free. StoreKit 2 integration is for v2 when the subscription tier launches. However, the architecture should be ready.

### Minimal v1 Stub

```swift
// EntitlementService.swift
@Observable
final class EntitlementService {
    var isPremium: Bool = false  // always false in v1
    
    func checkEntitlements() async {
        // v1: no-op, everything is free
        // v2: check Transaction.currentEntitlements
        isPremium = false
    }
    
    func isPremiumFeature(_ feature: String) -> Bool {
        // v1: all features are free
        false
    }
}
```

### v2 Implementation Pattern

```swift
func checkEntitlements() async {
    for await result in Transaction.currentEntitlements {
        if case .verified(let transaction) = result {
            // Update isPremium based on active subscription
            if transaction.productID == "com.inch.premium.monthly"
                || transaction.productID == "com.inch.premium.annual" {
                isPremium = transaction.revocationDate == nil
            }
        }
    }
}
```

Listen for transaction updates at app launch to handle renewals, refunds, and family sharing changes.
