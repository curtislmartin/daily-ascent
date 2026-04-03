# Early Sensor Recording Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Start iPhone sensor recording when the "Start Set" screen appears rather than when the button is tapped, so motion data is captured even if the user begins exercising before interacting with the button.

**Architecture:** Single file change to `WorkoutSessionView.swift`. Move `startRecording` (plus `onSample` wiring and `repCounter.reset`) from the `.inSet`/`.inRealTimeSet`/`.inTimedSet` phase handlers to the `.ready` phase handler and to `.task` for the first set. Add `.onDisappear` cleanup and update the quit handler to stop and delete any in-progress recording.

**Tech Stack:** Swift 6.2, SwiftUI, `@Observable`, `MotionRecordingService` (Core Motion wrapper), `CMMotionManager`.

---

## File Map

- **Modify:** `inch/inch/Features/Workout/WorkoutSessionView.swift`
  - Restructure `.task` block (lines 191–209)
  - Add `.ready` case to `.onChange` (lines 210–323)
  - Remove `startRecording` / `onSample` / `repCounter.reset` from `.inSet`, `.inRealTimeSet`, `.inTimedSet`
  - Update quit alert action (lines 160–172)
  - Add `.onDisappear` modifier

---

### Task 1: Move `repCounter` creation before the `await` in `.task`

> No unit test possible — sensor recording requires real hardware. Manual verification in Task 4.

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutSessionView.swift:191-209`

**Context:** The current `.task` block creates `repCounter` on line 206, after `await healthKit.requestAuthorization()` on line 208. In the next task we will assign `motionRecording.onSample` before the `await`; `repCounter` must already exist at that point.

- [ ] **Step 1: Locate the `.task` block**

  Open `inch/inch/Features/Workout/WorkoutSessionView.swift`. Find the `.task` modifier — it starts at line 191 and ends at line 209. The relevant section is:

  ```swift
  .task {
      sessionId = UUID().uuidString
      viewModel.configure(analytics: analytics)
      viewModel.load(context: modelContext)
      let tier3Exercises = ["dead_bugs", "glute_bridges"]
      if tier3Exercises.contains(exerciseId),
         let s = settings,
         !s.seenExerciseInfo.contains(exerciseId) {
          showTier3Intro = true
      } else if let s = settings, !s.seenExerciseInfo.contains(exerciseId) {
          showNudge = true
      }
      let id = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
      if Self.phoneAutoCountedExercises.contains(id),
         let config = RepCountingConfig.config(for: id) {
          repCounter = RepCounter(config: config)
      }
      await healthKit.requestAuthorization()
  }
  ```

- [ ] **Step 2: Move `repCounter` creation before the `await`**

  The `repCounter` creation block is already above the `await` — confirm this in the file. (In the original code it was on lines 203–207, before line 208's `await`.) If it is already before the `await`, no change is needed for this step. Proceed to Task 2.

  > Note: If you find `repCounter` creation is somehow after the `await`, move it above `await healthKit.requestAuthorization()`.

---

### Task 2: Add recording start to `.task` (first set)

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutSessionView.swift:191-209`

**Context:** `.onChange` does not fire for the initial `.ready` value. Recording for the first set must be started in `.task` after `viewModel.load()` returns. The start must happen before `await healthKit.requestAuthorization()` to avoid dropping early samples.

- [ ] **Step 1: Add recording start block to `.task`**

  After the `repCounter` creation block and before `await healthKit.requestAuthorization()`, add:

  ```swift
  if sensorConsented, !motionRecording.isRecording {
      let id = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
      motionRecording.startRecording(
          exerciseId: id,
          setNumber: viewModel.currentSetIndex + 1,
          sessionId: sessionId,
          context: modelContext
      )
      motionRecording.onSample = { [repCounter] ax, ay, az in
          repCounter?.processSample(ax: ax, ay: ay, az: az)
      }
      repCounter?.reset()
  }
  ```

  The `!motionRecording.isRecording` guard makes the block idempotent if `.task` re-fires.

  The resulting `.task` block should look like:

  ```swift
  .task {
      sessionId = UUID().uuidString
      viewModel.configure(analytics: analytics)
      viewModel.load(context: modelContext)
      let tier3Exercises = ["dead_bugs", "glute_bridges"]
      if tier3Exercises.contains(exerciseId),
         let s = settings,
         !s.seenExerciseInfo.contains(exerciseId) {
          showTier3Intro = true
      } else if let s = settings, !s.seenExerciseInfo.contains(exerciseId) {
          showNudge = true
      }
      let id = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
      if repCounter == nil, Self.phoneAutoCountedExercises.contains(id),
         let config = RepCountingConfig.config(for: id) {
          repCounter = RepCounter(config: config)
      }
      if sensorConsented, !motionRecording.isRecording {
          motionRecording.startRecording(
              exerciseId: id,
              setNumber: viewModel.currentSetIndex + 1,
              sessionId: sessionId,
              context: modelContext
          )
          motionRecording.onSample = { [repCounter] ax, ay, az in
              repCounter?.processSample(ax: ax, ay: ay, az: az)
          }
          repCounter?.reset()
      }
      await healthKit.requestAuthorization()
  }
  ```

  Note: `id` is already declared above (for the `repCounter` check) — reuse it, do not declare it again.

- [ ] **Step 2: Build the project to confirm no compiler errors**

  In Xcode, press ⌘B. Expected: Build Succeeded with no errors.

---

### Task 3: Add `.ready` case to `.onChange` and remove `startRecording` from set-start handlers

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutSessionView.swift:210-323`

**Context:** The `.onChange(of: viewModel.phase)` switch currently starts recording in `.inSet`, `.inRealTimeSet`, and `.inTimedSet`. We move that to `.ready`. Watch `sendRecordingStart` calls, `showHoldPhoneHint = false` assignments, and `realTimeSetStartDate = .now` all stay where they are.

- [ ] **Step 1: Add `.ready` case to the `switch` in `.onChange`**

  Inside the `switch newPhase {` block, add a `.ready` case before the existing cases:

  ```swift
  case .ready:
      if sensorConsented, !motionRecording.isRecording {
          let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
          motionRecording.startRecording(
              exerciseId: exerciseId,
              setNumber: viewModel.currentSetIndex + 1,
              sessionId: sessionId,
              context: modelContext
          )
          motionRecording.onSample = { [repCounter] ax, ay, az in
              repCounter?.processSample(ax: ax, ay: ay, az: az)
          }
          repCounter?.reset()
      }
  ```

- [ ] **Step 2: Remove `startRecording` from `.inRealTimeSet`**

  In the `.inRealTimeSet` case, delete:
  ```swift
  motionRecording.startRecording(
      exerciseId: exerciseId,
      setNumber: viewModel.currentSetIndex + 1,
      sessionId: sessionId,
      context: modelContext
  )
  repCounter?.reset()
  motionRecording.onSample = { [repCounter] ax, ay, az in
      repCounter?.processSample(ax: ax, ay: ay, az: az)
  }
  ```

  Keep `showHoldPhoneHint = false`, `realTimeSetStartDate = .now`, and the `watchConnectivity.sendRecordingStart` block unchanged.

  After the removal, `.inRealTimeSet` should look like:

  ```swift
  case .inRealTimeSet:
      showHoldPhoneHint = false
      realTimeSetStartDate = .now
      if sensorConsented {
          let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
          if dualRecordingEnabled {
              watchConnectivity.sendRecordingStart(
                  exerciseId: exerciseId,
                  setNumber: viewModel.currentSetIndex + 1,
                  sessionId: sessionId
              )
          }
      }
  ```

- [ ] **Step 3: Remove `startRecording` from `.inSet`**

  In the `.inSet` case, delete the `motionRecording.startRecording(...)` call. Keep `showHoldPhoneHint = false` and the `watchConnectivity.sendRecordingStart` block unchanged.

  After the removal, `.inSet` should look like:

  ```swift
  case .inSet:
      showHoldPhoneHint = false
      if sensorConsented {
          let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
          if dualRecordingEnabled {
              watchConnectivity.sendRecordingStart(
                  exerciseId: exerciseId,
                  setNumber: viewModel.currentSetIndex + 1,
                  sessionId: sessionId
              )
          }
      }
  ```

- [ ] **Step 4: Remove `startRecording` from `.inTimedSet`**

  In the `.inTimedSet` case, delete the `motionRecording.startRecording(...)` call. Keep `showHoldPhoneHint = false` and the `watchConnectivity.sendRecordingStart` block unchanged.

  After the removal, `.inTimedSet` should look like:

  ```swift
  case .inTimedSet:
      showHoldPhoneHint = false
      if sensorConsented {
          let exerciseId = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
          if dualRecordingEnabled {
              watchConnectivity.sendRecordingStart(
                  exerciseId: exerciseId,
                  setNumber: viewModel.currentSetIndex + 1,
                  sessionId: sessionId
              )
          }
      }
  ```

- [ ] **Step 5: Build to confirm no compiler errors**

  Press ⌘B. Expected: Build Succeeded.

---

### Task 4: Update quit handler and add `.onDisappear` cleanup

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutSessionView.swift:159-209`

- [ ] **Step 1: Update the "Quit Workout" alert action**

  Find the `.alert("Quit workout?", ...)` modifier. In the destructive button action, add the following two lines immediately before `dismiss()`:

  ```swift
  let url = motionRecording.stopRecording()
  if let url { try? FileManager.default.removeItem(at: url) }
  ```

  The full button action should become:

  ```swift
  Button("Quit Workout", role: .destructive) {
      analytics.record(AnalyticsEvent(
          name: "workout_abandoned",
          properties: .workoutAbandoned(
              exerciseId: viewModel.enrolment?.exerciseDefinition?.exerciseId ?? "",
              level: viewModel.enrolment?.currentLevel ?? 0,
              dayNumber: viewModel.enrolment?.currentDay ?? 0,
              setsCompleted: viewModel.currentSetIndex,
              setsTotal: viewModel.totalSets
          )
      ))
      let url = motionRecording.stopRecording()
      if let url { try? FileManager.default.removeItem(at: url) }
      dismiss()
  }
  ```

  > `stopRecording()` is safe to call when not recording — all operations are nil-guarded or idempotent. No `isRecording` guard needed here.

- [ ] **Step 2: Add `.onDisappear` modifier**

  After the `.onChange` modifier (the large switch block that ends around line 323), add:

  ```swift
  .onDisappear {
      if motionRecording.isRecording {
          let url = motionRecording.stopRecording()
          if let url { try? FileManager.default.removeItem(at: url) }
      }
  }
  ```

  This handles back-navigation from set 1 (no quit button shown). For sets 2+, `stopRecording()` was already called in the quit handler before `dismiss()`, so `isRecording` is `false` and this is a no-op.

- [ ] **Step 3: Build to confirm no compiler errors**

  Press ⌘B. Expected: Build Succeeded.

- [ ] **Step 4: Commit**

  ```bash
  git add inch/inch/Features/Workout/WorkoutSessionView.swift
  git commit -m "feat: start sensor recording when 'Start Set' screen appears"
  ```

---

### Task 5: Manual verification on device

> Sensor recording requires a real device. Use iPhone with motion consent granted in Settings.

- [ ] **Step 1: Install on device**

  ```bash
  ./scripts/build-device.sh
  ```

- [ ] **Check 1 — Recording starts on arrival at "Start Set" screen**

  Open a workout. Before tapping "Start Set", add a breakpoint or log on `motionRecording.isRecording`. Confirm it is `true` immediately when the "Start Set" screen appears.

- [ ] **Check 2 — Normal set completion saves a SensorRecording**

  Complete a full set. Navigate to the debug panel or check SwiftData to confirm a `SensorRecording` entry exists with the correct `exerciseId`, `setNumber`, and a non-empty `filePath`.

- [ ] **Check 3 — Quit workout deletes the orphaned file**

  Start a workout, tap "Quit Workout" before completing any set. Confirm no orphaned `.bin` file in the `sensor_data` directory and no `SensorRecording` entry was created.

- [ ] **Check 4 — Back navigation (set 1) deletes the orphaned file**

  Start a workout, navigate back using the system back gesture before tapping "Start Set". Confirm the recording file is deleted.

- [ ] **Check 5 — Subsequent sets start recording after rest timer**

  Complete set 1, wait through the rest timer, arrive at the "Start Set 2" screen. Confirm `isRecording` is `true`.

- [ ] **Check 6 — Real-time set rep count is correct**

  Complete a real-time counting exercise (e.g. Push-Ups). Confirm the rep count shown at completion is correct. (Rep counter receives samples from `.ready` onwards.)

- [ ] **Check 7 — Timed hold exercise works correctly**

  Complete a timed hold exercise (e.g. Dead Bugs). Confirm `SensorRecording.durationSeconds` reflects the hold duration, not the longer recording window.
