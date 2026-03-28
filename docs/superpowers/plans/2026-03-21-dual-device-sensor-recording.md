# Dual-Device Sensor Recording Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Associate iPhone and Apple Watch sensor recordings from the same workout session using a shared `sessionId`, add device labels to filenames, enable optional Watch recording trigger from iPhone, and add UX hints for watch-less users on movement-dependent exercises.

**Architecture:** `WorkoutSessionView` generates a UUID `sessionId` when a workout loads. This id is passed to `MotionRecordingService.startRecording` and sent to the Watch via `WCSession.sendMessage`. Both devices embed the `sessionId` and a `_iphone`/`_watch` device suffix in their filenames, so paired files can be identified offline by matching `sessionId + exerciseId + setNumber`. The Upload payload includes `sessionId` for Supabase-side pairing.

**Tech Stack:** Swift 6.2, SwiftData, WatchConnectivity, InchShared shared package, Supabase (SQL migration via MCP tool)

---

## Chunk 1: Model + metadata changes

### Task 1: Add `sessionId` to `SensorRecording` and `dualDeviceRecordingEnabled` to `UserSettings`

**Files:**
- Modify: `Shared/Sources/InchShared/Models/SensorRecording.swift`
- Modify: `Shared/Sources/InchShared/Models/UserSettings.swift`

SwiftData handles new `String` / `Bool` properties with defaults as lightweight migrations automatically — no schema version bump needed.

- [ ] **Step 1: Add `sessionId` to `SensorRecording`**

In `SensorRecording.swift`, add the property after `fileSizeBytes`:

```swift
public var sessionId: String = ""
```

Add the parameter to `init` (after `fileSizeBytes`):
```swift
sessionId: String = "",
```
And in the body:
```swift
self.sessionId = sessionId
```

- [ ] **Step 2: Add `dualDeviceRecordingEnabled` to `UserSettings`**

In `UserSettings.swift`, add after `showConflictWarnings`:

```swift
public var dualDeviceRecordingEnabled: Bool = true
```

Add the parameter to `init`:
```swift
dualDeviceRecordingEnabled: Bool = true,
```
And in the body:
```swift
self.dualDeviceRecordingEnabled = dualDeviceRecordingEnabled
```

- [ ] **Step 3: Build the Shared package to confirm no errors**

```bash
cd /Users/curtismartin/Work/inch-project
xcodebuild -workspace inch/inch.xcworkspace -scheme "InchShared" -destination "platform=iOS Simulator,name=iPhone 16 Pro" build | tail -5
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add Shared/Sources/InchShared/Models/SensorRecording.swift \
        Shared/Sources/InchShared/Models/UserSettings.swift
git commit -m "feat: add sessionId to SensorRecording and dualDeviceRecordingEnabled to UserSettings"
```

---

### Task 2: Add `sessionId` to `WatchSensorMetadata`

**Files:**
- Modify: `inch/inch/Services/WatchSensorMetadata.swift`

`WatchSensorMetadata` is a typed `Sendable` struct used to carry Watch file transfer metadata to the main actor. It needs `sessionId` to propagate it into the `SensorRecording` created on iPhone from Watch files.

- [ ] **Step 1: Add `sessionId` to `WatchSensorMetadata`**

In `WatchSensorMetadata.swift`, add after `recordedAt`:

```swift
let sessionId: String
```

- [ ] **Step 2: Build to confirm compile errors**

The `WatchSensorMetadata` init is called in two places: `WatchConnectivityService.session(_:didReceive:)`. The build will fail because `sessionId` has no default. That is intentional — find and fix all callers in the next steps.

- [ ] **Step 3: Commit**

```bash
git add inch/inch/Services/WatchSensorMetadata.swift
git commit -m "feat: add sessionId to WatchSensorMetadata"
```

---

## Chunk 2: iPhone recording — sessionId + device label in filename

### Task 3: Update `MotionRecordingService` to accept and embed `sessionId`

**Files:**
- Modify: `inch/inch/Services/MotionRecordingService.swift`

The filename changes from `{exerciseId}_set{setNumber}_{timestamp}.bin` to `{exerciseId}_set{setNumber}_{sessionId}_iphone.bin`. The `sessionId` is provided by the caller (`WorkoutSessionView`).

- [ ] **Step 1: Update `startRecording` signature**

Change:
```swift
func startRecording(exerciseId: String, setNumber: Int, context: ModelContext) {
```
To:
```swift
func startRecording(exerciseId: String, setNumber: Int, sessionId: String, context: ModelContext) {
```

- [ ] **Step 2: Update the filename**

Change:
```swift
let fileName = "\(exerciseId)_set\(setNumber)_\(Int(Date.now.timeIntervalSince1970)).bin"
```
To:
```swift
let fileName = "\(exerciseId)_set\(setNumber)_\(sessionId)_iphone.bin"
```

- [ ] **Step 3: Store `sessionId` on `currentRecordingSessionId` for use in stopRecording**

Add a stored property after `currentRecordingURL`:
```swift
private(set) var currentSessionId: String = ""
```

In `startRecording`, after `currentRecordingURL = fileURL`:
```swift
currentSessionId = sessionId
```

In `stopRecording`, after `let url = currentRecordingURL`:
```swift
currentSessionId = ""
```

- [ ] **Step 4: Build — expect compile errors in callers**

```bash
xcodebuild -workspace inch/inch.xcworkspace -scheme "inch" -destination "platform=iOS Simulator,name=iPhone 16 Pro" build 2>&1 | grep "error:" | head -20
```

`WorkoutSessionView.swift` will error (missing `sessionId` argument). Fix in Task 5.

- [ ] **Step 5: Commit**

```bash
git add inch/inch/Services/MotionRecordingService.swift
git commit -m "feat: embed sessionId and _iphone device label in motion recording filename"
```

---

## Chunk 3: Watch recording — sessionId + device label in filename

### Task 4: Update `WatchMotionRecordingService` to accept and embed `sessionId`

**Files:**
- Modify: `inch/inchwatch Watch App/Services/WatchMotionRecordingService.swift`

The Watch filename changes from `{exerciseId}_watch_set{setNumber}_{timestamp}.bin` to `{exerciseId}_set{setNumber}_{sessionId}_watch.bin`. Format is now consistent with iPhone (`exerciseId_set{N}_{sessionId}_{device}.bin`).

- [ ] **Step 1: Update `startRecording` signature**

Change:
```swift
func startRecording(exerciseId: String, setNumber: Int) {
```
To:
```swift
func startRecording(exerciseId: String, setNumber: Int, sessionId: String) {
```

- [ ] **Step 2: Update the filename**

Change:
```swift
let fileName = "\(exerciseId)_watch_set\(setNumber)_\(Int(Date.now.timeIntervalSince1970)).bin"
```
To:
```swift
let fileName = "\(exerciseId)_set\(setNumber)_\(sessionId)_watch.bin"
```

- [ ] **Step 3: Thread `sessionId` through `stopAndTransfer`**

Change:
```swift
func stopAndTransfer(
    exerciseId: String,
    setNumber: Int,
    level: Int,
    dayNumber: Int,
    confirmedReps: Int,
    durationSeconds: Double,
    countingMode: String
) -> URL? {
```
To:
```swift
func stopAndTransfer(
    exerciseId: String,
    setNumber: Int,
    sessionId: String,
    level: Int,
    dayNumber: Int,
    confirmedReps: Int,
    durationSeconds: Double,
    countingMode: String
) -> URL? {
```

In the `metadata` dict, add:
```swift
"sessionId": sessionId,
```

- [ ] **Step 4: Add `currentSessionId` property (mirrors iPhone service)**

```swift
private(set) var currentSessionId: String = ""
```

After `currentRecordingURL = fileURL` in `startRecording`:
```swift
currentSessionId = sessionId
```

After `let url = currentRecordingURL` in `stopAndTransfer`:
```swift
currentSessionId = ""
```

- [ ] **Step 5: Commit**

```bash
git add "inch/inchwatch Watch App/Services/WatchMotionRecordingService.swift"
git commit -m "feat: embed sessionId and _watch device label in Watch motion recording filename"
```

---

## Chunk 4: WatchConnectivity — session coordination messages

### Task 5: iPhone `WatchConnectivityService` — send session coordination

**Files:**
- Modify: `inch/inch/Services/WatchConnectivityService.swift`

iPhone sends two types of messages to Watch:
- `sessionStart`: carries `exerciseId` + `sessionId` so the Watch can use the same id in its filenames
- `recordingStart` / `recordingStop`: triggers Watch to start/stop recording for the set (only works when Watch app is in foreground)

All sends are guarded by `wcSession.isReachable`.

- [ ] **Step 1: Add `isWatchReachable` computed property**

After the `activate()` method:
```swift
var isWatchReachable: Bool {
    wcSession?.isReachable ?? false
}
```

- [ ] **Step 2: Add `sendRecordingStart` and `sendRecordingStop`**

```swift
func sendRecordingStart(exerciseId: String, setNumber: Int, sessionId: String) {
    guard let wcSession, wcSession.isReachable else { return }
    wcSession.sendMessage(
        ["type": "recordingStart", "exerciseId": exerciseId, "setNumber": setNumber, "sessionId": sessionId],
        replyHandler: nil,
        errorHandler: nil
    )
}

func sendRecordingStop(exerciseId: String, setNumber: Int) {
    guard let wcSession, wcSession.isReachable else { return }
    wcSession.sendMessage(
        ["type": "recordingStop", "exerciseId": exerciseId, "setNumber": setNumber],
        replyHandler: nil,
        errorHandler: nil
    )
}
```

- [ ] **Step 3: Commit**

```bash
git add inch/inch/Services/WatchConnectivityService.swift
git commit -m "feat: add sendRecordingStart/Stop to iPhone WatchConnectivityService"
```

---

### Task 6: Watch `WatchConnectivityService` — receive coordination messages

**Files:**
- Modify: `inch/inchwatch Watch App/Services/WatchConnectivityService.swift`

The Watch delegate adds `didReceiveMessage` to handle incoming `recordingStart` and `recordingStop` messages. These are yielded to a typed `AsyncStream` that `WatchWorkoutView` consumes.

- [ ] **Step 1: Define `WatchRecordingTrigger` enum**

Add a new file `inch/inchwatch Watch App/Models/WatchRecordingTrigger.swift`:

```swift
import Foundation

enum WatchRecordingTrigger: Sendable {
    case start(exerciseId: String, setNumber: Int, sessionId: String)
    case stop(exerciseId: String, setNumber: Int)
}
```

- [ ] **Step 2: Add `recordingTriggers` stream to Watch `WatchConnectivityService`**

In `WatchConnectivityService`, add after the existing stream properties:

```swift
private let _recordingTriggers: AsyncStream<WatchRecordingTrigger>.Continuation
let recordingTriggers: AsyncStream<WatchRecordingTrigger>
```

In `init()`, before `super.init()`:
```swift
let (triggerStream, triggerContinuation) = AsyncStream<WatchRecordingTrigger>.makeStream()
recordingTriggers = triggerStream
_recordingTriggers = triggerContinuation
```

- [ ] **Step 3: Add `didReceiveMessage` delegate method**

Add after `sessionDidBecomeInactive` / at end of WCSessionDelegate section:

```swift
nonisolated func session(
    _ session: WCSession,
    didReceiveMessage message: [String: Any]
) {
    guard let type = message["type"] as? String else { return }
    switch type {
    case "recordingStart":
        guard let exerciseId = message["exerciseId"] as? String,
              let setNumber = message["setNumber"] as? Int,
              let sessionId = message["sessionId"] as? String
        else { return }
        _recordingTriggers.yield(.start(exerciseId: exerciseId, setNumber: setNumber, sessionId: sessionId))
    case "recordingStop":
        guard let exerciseId = message["exerciseId"] as? String,
              let setNumber = message["setNumber"] as? Int
        else { return }
        _recordingTriggers.yield(.stop(exerciseId: exerciseId, setNumber: setNumber))
    default:
        break
    }
}
```

- [ ] **Step 4: Build Watch target**

```bash
xcodebuild -workspace inch/inch.xcworkspace -scheme "inchwatch Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)" build 2>&1 | tail -5
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add "inch/inchwatch Watch App/Models/WatchRecordingTrigger.swift" \
        "inch/inchwatch Watch App/Services/WatchConnectivityService.swift"
git commit -m "feat: add recordingTriggers stream to Watch WatchConnectivityService"
```

---

### Task 7: Watch `WatchConnectivityService` — propagate `sessionId` from file transfer metadata

**Files:**
- Modify: `inch/inch/Services/WatchConnectivityService.swift` (iPhone side)

When the Watch calls `transferFile`, it includes `sessionId` in the metadata dict. The iPhone `didReceive file` delegate reads it and passes it to `WatchSensorMetadata`, which is then used when creating `SensorRecording`.

- [ ] **Step 1: Extract `sessionId` in `didReceive file`**

In `WatchConnectivityService.swift` (iPhone), in `nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile)`, update the `WatchSensorMetadata` init to add `sessionId`:

```swift
let meta = WatchSensorMetadata(
    exerciseId: exerciseId,
    setNumber: raw["setNumber"] as? Int ?? 0,
    device: raw["device"] as? String ?? SensorDevice.appleWatch.rawValue,
    level: raw["level"] as? Int ?? 0,
    dayNumber: raw["dayNumber"] as? Int ?? 0,
    confirmedReps: raw["confirmedReps"] as? Int ?? 0,
    durationSeconds: raw["durationSeconds"] as? Double ?? 0,
    countingMode: raw["countingMode"] as? String ?? "",
    sampleRateHz: raw["sampleRateHz"] as? Int ?? 50,
    recordedAt: raw["recordedAt"] as? Double ?? Date.now.timeIntervalSince1970,
    sessionId: raw["sessionId"] as? String ?? ""
)
```

- [ ] **Step 2: Pass `sessionId` when creating `SensorRecording` from Watch files**

In `handleReceivedFiles`, update the `SensorRecording` init:
```swift
let recording = SensorRecording(
    recordedAt: Date(timeIntervalSince1970: meta.recordedAt),
    device: .appleWatch,
    exerciseId: meta.exerciseId,
    level: meta.level,
    dayNumber: meta.dayNumber,
    setNumber: meta.setNumber,
    confirmedReps: meta.confirmedReps,
    sampleRateHz: meta.sampleRateHz,
    durationSeconds: meta.durationSeconds,
    countingMode: meta.countingMode,
    filePath: received.fileURL.path,
    fileSizeBytes: received.fileSizeBytes,
    sessionId: meta.sessionId
)
```

- [ ] **Step 3: Commit**

```bash
git add inch/inch/Services/WatchConnectivityService.swift \
        inch/inch/Services/WatchSensorMetadata.swift
git commit -m "feat: propagate sessionId from Watch file transfer metadata to SensorRecording"
```

---

## Chunk 5: WorkoutSessionView — integrate sessionId + send triggers

### Task 8: `WorkoutSessionView` — generate sessionId, pass to recording, send triggers

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutSessionView.swift`

`WorkoutSessionView` generates a `sessionId` UUID once per exercise session. It passes this to `MotionRecordingService.startRecording` and sends `recordingStart`/`recordingStop` messages to Watch when `dualDeviceRecordingEnabled` is true.

- [ ] **Step 1: Add `@Environment(WatchConnectivityService.self)` and state for sessionId**

Add after the existing `@Environment` declarations:
```swift
@Environment(WatchConnectivityService.self) private var watchConnectivity
```

Add new `@State`:
```swift
@State private var sessionId: String = ""
```

Add computed property after `sensorConsented`:
```swift
private var dualRecordingEnabled: Bool {
    allSettings.first?.dualDeviceRecordingEnabled ?? true
}
```

- [ ] **Step 2: Generate `sessionId` in `.task`**

In `.task`:
```swift
.task {
    sessionId = UUID().uuidString
    viewModel.load(context: modelContext)
    await healthKit.requestAuthorization()
}
```

- [ ] **Step 3: Update `startRecording` call sites — pass `sessionId`**

There are two call sites. Update both:

In `.onChange(of: viewModel.phase)` → `.inSet`:
```swift
case .inSet:
    if sensorConsented {
        let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
        motionRecording.startRecording(
            exerciseId: exerciseId,
            setNumber: viewModel.currentSetIndex + 1,
            sessionId: sessionId,
            context: modelContext
        )
        if dualRecordingEnabled {
            watchConnectivity.sendRecordingStart(
                exerciseId: exerciseId,
                setNumber: viewModel.currentSetIndex + 1,
                sessionId: sessionId
            )
        }
    }
```

In `.confirming`:
```swift
case .confirming:
    if motionRecording.isRecording {
        pendingRecordingURL = motionRecording.stopRecording()
    }
    if dualRecordingEnabled {
        let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
        watchConnectivity.sendRecordingStop(
            exerciseId: exerciseId,
            setNumber: viewModel.currentSetIndex + 1
        )
    }
```

In `readyView` (real-time mode `.onAppear`):
```swift
.onAppear {
    if sensorConsented {
        realTimeSetStartDate = .now
        let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
        motionRecording.startRecording(
            exerciseId: exerciseId,
            setNumber: viewModel.currentSetIndex + 1,
            sessionId: sessionId,
            context: modelContext
        )
        if dualRecordingEnabled {
            watchConnectivity.sendRecordingStart(
                exerciseId: exerciseId,
                setNumber: viewModel.currentSetIndex + 1,
                sessionId: sessionId
            )
        }
    }
}
```

For real-time stop (in `RealTimeCountingView` completion closure):
```swift
let url = sensorConsented ? motionRecording.stopRecording() : nil
if dualRecordingEnabled {
    let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
    watchConnectivity.sendRecordingStop(
        exerciseId: exerciseId,
        setNumber: viewModel.currentSetIndex + 1
    )
}
```

- [ ] **Step 4: Build iPhone target**

```bash
xcodebuild -workspace inch/inch.xcworkspace -scheme "inch" -destination "platform=iOS Simulator,name=iPhone 16 Pro" build 2>&1 | tail -5
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add inch/inch/Features/Workout/WorkoutSessionView.swift
git commit -m "feat: generate sessionId per workout session and send recording triggers to Watch"
```

---

## Chunk 6: Watch workout — handle recording triggers from iPhone

### Task 9: `WatchWorkoutView` — consume recording triggers and start/stop recording

**Files:**
- Modify: `inch/inchwatch Watch App/Features/WatchWorkoutView.swift`

When the user is doing a workout on iPhone with the Watch app also open, the Watch receives `recordingStart`/`recordingStop` messages. `WatchWorkoutView` listens to `watchConnectivity.recordingTriggers` and calls `motionRecording` accordingly. Guard against double-recording: only start if not already recording; only stop if already recording.

- [ ] **Step 1: Add `currentSessionId` state and trigger listener**

Add `@State` in `WatchWorkoutView`:
```swift
@State private var inboundSessionId: String = ""
```

Add a `.task` modifier (alongside the existing ones if any, or as a new one):
```swift
.task {
    for await trigger in watchConnectivity.recordingTriggers {
        switch trigger {
        case .start(let exerciseId, let setNumber, let sessionId):
            // Only respond to triggers for this exercise; don't double-record
            guard exerciseId == session.exerciseId,
                  !motionRecording.isRecording else { break }
            inboundSessionId = sessionId
            motionRecording.startRecording(
                exerciseId: exerciseId,
                setNumber: setNumber,
                sessionId: sessionId
            )
        case .stop(let exerciseId, let setNumber):
            guard exerciseId == session.exerciseId,
                  motionRecording.isRecording else { break }
            _ = motionRecording.stopAndTransfer(
                exerciseId: exerciseId,
                setNumber: setNumber,
                sessionId: inboundSessionId,
                level: session.level,
                dayNumber: session.dayNumber,
                confirmedReps: 0,           // unknown — iPhone holds this
                durationSeconds: 0,         // unknown — iPhone holds this
                countingMode: session.countingMode
            )
            inboundSessionId = ""
        }
    }
}
```

- [ ] **Step 2: Update existing `.onChange(of: viewModel.phase)` to pass sessionId**

The existing Watch-native recording (when user works out on Watch) still uses its own sessionId. Update the `.onChange`:

```swift
case .inSet:
    setStartDate = .now
    elapsed = 0
    // Use an inbound sessionId from iPhone if available, else generate one
    let sid = inboundSessionId.isEmpty ? UUID().uuidString : inboundSessionId
    motionRecording.startRecording(
        exerciseId: session.exerciseId,
        setNumber: viewModel.currentSet,
        sessionId: sid
    )
```

```swift
case .confirming:
    if motionRecording.isRecording,
       case .confirming(let targetReps, let duration) = newPhase {
        _ = motionRecording.stopAndTransfer(
            exerciseId: session.exerciseId,
            setNumber: viewModel.currentSet,
            sessionId: motionRecording.currentSessionId,
            level: session.level,
            dayNumber: session.dayNumber,
            confirmedReps: viewModel.pendingRealTimeCount ?? targetReps,
            durationSeconds: duration,
            countingMode: session.countingMode
        )
    }
```

- [ ] **Step 3: Build Watch target**

```bash
xcodebuild -workspace inch/inch.xcworkspace -scheme "inchwatch Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)" build 2>&1 | tail -5
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add "inch/inchwatch Watch App/Features/WatchWorkoutView.swift"
git commit -m "feat: Watch handles recording triggers from iPhone with shared sessionId"
```

---

## Chunk 7: Upload — sessionId in payload + Supabase migration

### Task 10: `DataUploadService` — include `sessionId` in upload

**Files:**
- Modify: `inch/inch/Services/DataUploadService.swift`

The upload payload gains `sessionId`. The storage filename is updated to include sessionId and device, matching the local filename pattern.

- [ ] **Step 1: Add `sessionId` to `SensorRecordingPayload`**

In `SensorRecordingPayload`:
```swift
let sessionId: String
```

In `CodingKeys`:
```swift
case sessionId = "session_id"
```

- [ ] **Step 2: Update `uploadRecording` to use local filename and pass sessionId**

Change the filename + storagePath to use `recording.exerciseId` and derive from local filename:

```swift
let localName = URL(filePath: recording.filePath).deletingPathExtension().lastPathComponent
let fileName = "\(localName)_\(Int(recording.recordedAt.timeIntervalSince1970)).bin.zlib"
let storagePath = "\(recording.exerciseId)/\(fileName)"
```

> Note: `localName` already includes `sessionId` and `_iphone`/`_watch` from the filename format `{exerciseId}_set{N}_{sessionId}_{device}`.

Update the payload init to include `sessionId`:
```swift
let payload = SensorRecordingPayload(
    exerciseId: recording.exerciseId,
    level: recording.level,
    dayNumber: recording.dayNumber,
    setNumber: recording.setNumber,
    confirmedReps: recording.confirmedReps,
    countingMode: recording.countingMode,
    device: recording.device.rawValue,
    sampleRateHz: recording.sampleRateHz,
    durationSeconds: recording.durationSeconds,
    filePath: storagePath,
    fileSizeBytes: compressedData.count,
    recordedAt: recording.recordedAt,
    ageRange: config.ageRange,
    heightRange: config.heightRange,
    biologicalSex: config.biologicalSex,
    activityLevel: config.activityLevel,
    sessionId: recording.sessionId
)
```

- [ ] **Step 3: Apply Supabase migration to add `session_id` column**

Run via the Supabase MCP tool (`mcp__plugin_supabase_supabase__execute_sql`):

```sql
ALTER TABLE sensor_recordings
ADD COLUMN IF NOT EXISTS session_id TEXT;
```

- [ ] **Step 4: Build iPhone target**

```bash
xcodebuild -workspace inch/inch.xcworkspace -scheme "inch" -destination "platform=iOS Simulator,name=iPhone 16 Pro" build 2>&1 | tail -5
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: Commit**

```bash
git add inch/inch/Services/DataUploadService.swift
git commit -m "feat: include sessionId in upload payload and storage filename"
```

---

## Chunk 8: Settings toggle + "hold phone" hint

### Task 11: Settings — dual-device recording toggle

**Files:**
- Modify: `inch/inch/Features/Settings/PrivacySettingsView.swift`

Add a toggle for `dualDeviceRecordingEnabled` in the `consentSection`, visible only when Watch is supported on the device. The toggle is below the anonymised sharing toggle.

- [ ] **Step 1: Add dual-device toggle to `consentSection`**

In `PrivacySettingsView`, below the existing anonymised sharing `Toggle`, add:

```swift
if WCSession.isSupported() {
    Toggle(isOn: Binding(
        get: { settings?.dualDeviceRecordingEnabled ?? true },
        set: { newValue in
            settings?.dualDeviceRecordingEnabled = newValue
            try? modelContext.save()
        }
    )) {
        VStack(alignment: .leading, spacing: 4) {
            Text("Record on Apple Watch")
            Text("When your Watch is nearby and the app is open, both devices record simultaneously.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    .disabled(settings?.motionDataUploadConsented == false)
}
```

Add `import WatchConnectivity` at the top of the file.

- [ ] **Step 2: Build and verify**

```bash
xcodebuild -workspace inch/inch.xcworkspace -scheme "inch" -destination "platform=iOS Simulator,name=iPhone 16 Pro" build 2>&1 | tail -5
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add inch/inch/Features/Settings/PrivacySettingsView.swift
git commit -m "feat: add dual-device recording toggle to Privacy settings"
```

---

### Task 12: "Hold your phone" hint for sit-ups and dead bugs

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutSessionView.swift`

For sit-ups and dead bugs, if the Watch is not reachable (or the user has no Watch), the phone in pocket provides the primary sensor signal. Show a one-time, non-blocking hint before the first set asking the user to hold the phone.

- [ ] **Step 1: Add state and computed properties**

In `WorkoutSessionView`:
```swift
@State private var showHoldPhoneHint = true

private var exerciseId: String {
    viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
}

private var isHoldPhoneExercise: Bool {
    exerciseId == "sit_ups" || exerciseId == "dead_bugs"
}

private var shouldShowHoldPhoneHint: Bool {
    showHoldPhoneHint &&
    isHoldPhoneExercise &&
    !watchConnectivity.isWatchReachable &&
    viewModel.currentSetIndex == 0 &&
    viewModel.phase == .ready
}
```

- [ ] **Step 2: Add hint banner to `readyView`**

In `readyView`, above the `setProgressHeader`, add:

```swift
if shouldShowHoldPhoneHint {
    HStack(spacing: 10) {
        Image(systemName: "hand.raised.fill")
            .foregroundStyle(.secondary)
        Text("Hold your phone for better tracking")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        Spacer()
        Button {
            showHoldPhoneHint = false
        } label: {
            Image(systemName: "xmark")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
    }
    .padding(12)
    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
}
```

Dismiss the hint when the first set starts — in `.onChange(of: viewModel.phase)`, in the `.inSet` case, add:
```swift
showHoldPhoneHint = false
```

- [ ] **Step 3: Build**

```bash
xcodebuild -workspace inch/inch.xcworkspace -scheme "inch" -destination "platform=iOS Simulator,name=iPhone 16 Pro" build 2>&1 | tail -5
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add inch/inch/Features/Workout/WorkoutSessionView.swift
git commit -m "feat: show hold-phone hint for sit-ups and dead bugs when Watch not reachable"
```

---

## Final build check

- [ ] **Build both targets clean**

```bash
xcodebuild -workspace inch/inch.xcworkspace -scheme "inch" -destination "platform=iOS Simulator,name=iPhone 16 Pro" clean build 2>&1 | tail -5
xcodebuild -workspace inch/inch.xcworkspace -scheme "inchwatch Watch App" -destination "platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)" clean build 2>&1 | tail -5
```
Both expected: `BUILD SUCCEEDED`
