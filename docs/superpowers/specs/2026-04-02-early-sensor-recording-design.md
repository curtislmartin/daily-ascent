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

`.onChange(of: viewModel.phase)` does not fire for the initial `.ready` value assigned by `viewModel.load()` in `.task`. Recording must be started explicitly in the `.task` handler, after `viewModel.load()` returns, when `sensorConsented` is true.

### Subsequent sets

Phase transitions `.resting` → `.ready` via `viewModel.finishRest()`. `.onChange` fires and starts recording. Recording begins at the end of the rest timer — a few seconds before the user starts moving, which is acceptable.

### Set completes normally

Recording is already running. The existing stop-and-save logic is unchanged:
- Post-set confirmation: `motionRecording.stopRecording()` called before `confirmSet`
- Real-time set: `motionRecording.stopRecording()` called in `completeRealTimeSet`
- Timed set: `motionRecording.stopRecording()` called in the timed set completion handler

### User quits workout

The "Quit Workout" destructive button action currently calls `dismiss()` only. Add `motionRecording.stopRecording()` before dismiss, and delete the returned file URL (no `CompletedSet` was saved, so the file is orphaned and should be removed immediately rather than waiting for storage pruning).

### User navigates back (set 1, no quit button)

`shouldWarnOnBack` returns `false` for set 1 in `.ready` phase, so the quit confirmation is not shown and the user can navigate back freely. Add `.onDisappear` to `WorkoutSessionView` that calls `motionRecording.stopRecording()` and deletes the returned file URL if recording is in progress.

## Watch dual recording

No change. `watchConnectivity.sendRecordingStart` remains in the `.inSet` / `.inRealTimeSet` / `.inTimedSet` handlers. The iPhone file will have a slightly earlier start time than the Watch file, but correlation uses `sessionId` + `setNumber`, not timestamps.

## Removed code

Remove `motionRecording.startRecording(...)` and `watchConnectivity.sendRecordingStart(...)` calls from the `.inSet`, `.inRealTimeSet`, and `.inTimedSet` cases in `.onChange(of: viewModel.phase)`. The Watch start calls move back to those handlers unchanged; only the iPhone `startRecording` call moves to `.ready`.

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
3. Tap "Quit Workout" during a set — verify recording is stopped and orphaned file is deleted
4. Navigate back from set 1 before tapping "Start Set" — verify recording is stopped and file deleted
5. Complete rest timer, arrive at next set's "Start Set" screen — verify new recording starts
