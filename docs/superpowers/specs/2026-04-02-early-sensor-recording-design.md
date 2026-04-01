# Early Sensor Recording Design

## Goal

Start iPhone sensor recording when the "Start Set" screen appears, rather than when the "Start Set" button is tapped. This ensures motion data is captured even if the user begins exercising before interacting with the button.

## Background

Recording currently starts when `WorkoutViewModel.phase` transitions to `.inSet`, `.inRealTimeSet`, or `.inTimedSet` — i.e., at the moment the user taps "Start Set". If the user never taps the button, no recording is started and all sensor data for that set is lost.

## Architecture

Single file change: `inch/inch/Features/Workout/WorkoutSessionView.swift`.

No changes to `MotionRecordingService`, `WorkoutViewModel`, data models, or Watch connectivity.

## Behaviour Changes

### Recording start

Recording moves from phase transitions `.inSet` / `.inRealTimeSet` / `.inTimedSet` to phase transition `.ready`.

| Scenario | Before | After |
|---|---|---|
| User taps "Start Set" | Recording starts | Recording already running |
| User arrives at "Start Set" screen | No recording | Recording starts |
| Rest timer ends | No recording | Recording starts |

### First set

`.onChange(of: viewModel.phase)` does not fire for the initial `.ready` value assigned by `viewModel.load()` in `.task`. The `.task` handler must be restructured to the following order:

1. Call `viewModel.load(context: modelContext)`
2. Derive `let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""`
3. Move `repCounter` creation (currently after the `await` in the existing code) to here, before the `await`
4. If `sensorConsented`:
   - Call `motionRecording.startRecording(exerciseId: exerciseId, setNumber: viewModel.currentSetIndex + 1, sessionId: sessionId, context: modelContext)`
   - Assign `motionRecording.onSample = { [repCounter] ax, ay, az in repCounter?.processSample(ax: ax, ay: ay, az: az) }`
   - Call `repCounter?.reset()`
5. Then call `await healthKit.requestAuthorization()`

Steps 3 and 4 must happen before the `await` in step 5. `startRecording` begins delivering samples immediately on a background queue; `onSample` must be assigned and `repCounter` must exist before `await` to avoid silently dropping pre-authorization samples.

Both steps 3 and 4 must be guarded to be idempotent in case SwiftUI re-runs `.task`: only create `repCounter` if `repCounter == nil`, and only call `startRecording` if `motionRecording.isRecording == false`.

Do not send `watchConnectivity.sendRecordingStart` from `.task` — Watch recording for set 1 fires normally when the user taps "Start Set" and the phase transitions to `.inSet` / `.inRealTimeSet` / `.inTimedSet`.

### Subsequent sets

Phase transitions `.resting` → `.ready` via `viewModel.finishRest()`. `.onChange` fires and starts recording. Recording begins at the end of the rest timer — a few seconds before the user starts moving, which is acceptable.

The `.ready` handler in `.onChange` must (when `sensorConsented`):
- Call `motionRecording.startRecording(exerciseId: exerciseId, setNumber: viewModel.currentSetIndex + 1, sessionId: sessionId, context: modelContext)`
- Assign `motionRecording.onSample = { [repCounter] ax, ay, az in repCounter?.processSample(ax: ax, ay: ay, az: az) }`
- Call `repCounter?.reset()`

This matches the `.task` first-set path exactly.

### Timed exercise path

For timed exercises, the phase sequence is `.ready` → `.preparingTimedSet` (countdown) → `.inTimedSet` (hold). Recording starts at `.ready` and runs continuously through the countdown and into the hold without interruption. `SensorRecording.durationSeconds` is set to `actualDuration` (the hold duration only), so the file will be slightly longer than `durationSeconds` — the same "file longer than reported duration" behaviour as the real-time path. This is acceptable.

### Real-time counting and `onSample`

`motionRecording.onSample` and `repCounter?.reset()` move from the `.inRealTimeSet` handler to the `.ready` handler (and to `.task` for set 1 — see above). The rep counter receives samples from the moment recording begins, including any pre-button-tap window. `realTimeSetStartDate` stays in the `.inRealTimeSet` handler — it records when the user tapped "Start Set", which is used to compute the active-set duration stored in `SensorRecording.durationSeconds`. The recording file will be slightly longer than `durationSeconds`; this is intentional.

### Set completes normally

Recording is already running. The existing stop-and-save logic is unchanged:
- Post-set confirmation: `motionRecording.stopRecording()` called before `confirmSet`
- Real-time set: `motionRecording.stopRecording()` called in `completeRealTimeSet`
- Timed set: `let url = sensorConsented ? motionRecording.stopRecording() : nil` in the timed set completion handler

The existing stop paths use slightly different guards (`sensorConsented` vs `isRecording`). Do not change these.

### `showHoldPhoneHint`

`showHoldPhoneHint = false` currently lives in the `.inSet`, `.inRealTimeSet`, and `.inTimedSet` handlers. It does not move — leave it in those handlers unchanged.

### User quits workout

The "Quit Workout" destructive button action is inside an `.alert` modifier and currently calls `dismiss()` only. Add the following before `dismiss()` (no `isRecording` guard needed — `MotionRecordingService.stopRecording` is safe to call when not recording; all its operations are nil-guarded or idempotent):

```swift
let url = motionRecording.stopRecording()
if let url { try? FileManager.default.removeItem(at: url) }
``` After `stopRecording()` returns, `isRecording` is `false`, so the subsequent `.onDisappear` (triggered by `dismiss()`) is a no-op.

### User navigates back (`.onDisappear` guard)

Add `.onDisappear` to `WorkoutSessionView`. In the handler, if `motionRecording.isRecording` is `true`, call `stopRecording()` and call `try? FileManager.default.removeItem(at: url)` on the returned URL if non-nil.

This guard applies to all sets. For set 1 (no quit button), it handles back-navigation. For sets 2+ (quit button shown), the quit alert path already calls `stopRecording()` before `dismiss()`, so `isRecording` is `false` by the time `.onDisappear` fires — making it a no-op. When the session completes normally (`.complete` phase), recording has already been stopped; the guard is again a no-op.

## Watch dual recording

No change. `watchConnectivity.sendRecordingStart` remains in the `.inSet` / `.inRealTimeSet` / `.inTimedSet` handlers unchanged. Do not move or copy it to the `.ready` handler or `.task`. The iPhone file will have a slightly earlier start time than the Watch file, but correlation uses `sessionId` + `setNumber`, not timestamps.

## Removed code

Remove only `motionRecording.startRecording(...)` from the `.inSet`, `.inRealTimeSet`, and `.inTimedSet` cases in `.onChange(of: viewModel.phase)`. Leave `watchConnectivity.sendRecordingStart(...)` in those handlers unchanged. Also remove `repCounter?.reset()` and the `motionRecording.onSample` assignment from `.inRealTimeSet`; they move to the `.ready` handler (and to `.task` for set 1).

## Error handling

`MotionRecordingService.startRecording` already guards against:
- Device motion unavailable
- Insufficient device storage
- Folder over 50 MB cap

No additional error handling required. If `startRecording` silently no-ops, the existing behaviour is preserved (no recording saved).

## Testing

Manual testing on device (sensor recording requires real hardware):
1. Open a workout, arrive at "Start Set" screen — verify `motionRecording.isRecording` is `true`
2. Complete a set normally — verify `SensorRecording` is saved with correct file
3. Tap "Quit Workout" — verify recording is stopped and orphaned file is deleted
4. Navigate back from set 1 before tapping "Start Set" — verify recording is stopped and file deleted
5. Complete rest timer, arrive at next set's "Start Set" screen — verify new recording starts
6. Complete a real-time set — verify rep count is correct (counter received samples from `.ready` phase onwards)
7. Complete a timed (hold) exercise — verify recording ran through countdown into hold, `SensorRecording.durationSeconds` reflects hold duration only
