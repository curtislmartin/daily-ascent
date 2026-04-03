# Resume Workout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When iOS terminates the app mid-workout, let the user resume from the set they left off rather than starting over.

**Architecture:** `WorkoutViewModel.load()` detects today's partial `CompletedSet` records and sets a `shouldOfferResume` flag; `WorkoutSessionView` reads this flag in `.task` and shows a `confirmationDialog`; `TodayViewModel` exposes `inProgressTodayIds` so `ExerciseCard` can show a subtle "In progress" badge. No new data models.

**Tech Stack:** Swift 6.2, SwiftUI, SwiftData, `@Observable` ViewModels.

---

## File Map

- **Modify:** `inch/inch/Services/AnalyticsService.swift` — add `.workoutResumed` case to `AnalyticsProperties`
- **Modify:** `inch/inch/Features/Today/TodayViewModel.swift` — add `inProgressTodayIds: Set<String>`
- **Modify:** `inch/inch/Features/Today/ExerciseCard.swift` — add `isInProgress: Bool` parameter and badge
- **Modify:** `inch/inch/Features/Today/TodayView.swift` — pass `isInProgress` to `ExerciseCard`
- **Modify:** `inch/inch/Features/Workout/WorkoutViewModel.swift` — detection in `load()`, new properties, `resumeSession()`, `restartSession()`
- **Modify:** `inch/inch/Features/Workout/WorkoutSessionView.swift` — `confirmationDialog`, `.onChange`, updated quit alert message

---

### Task 1: Add `workoutResumed` analytics case

> No unit test — `AnalyticsService` is in the app target with no test infrastructure. Verify by build.

**Files:**
- Modify: `inch/inch/Services/AnalyticsService.swift`

**Context:** `AnalyticsProperties` is an `enum` in `AnalyticsService.swift`. It uses a manual `Encodable` implementation with a `CodingKeys` enum. A new `workoutResumed` case needs: a new enum case, a new coding key, and an encode branch.

- [ ] **Step 1: Add the enum case**

  In `AnalyticsProperties`, after the `workoutStarted` case (line 24), add:

  ```swift
  case workoutResumed(exerciseId: String, level: Int, dayNumber: Int, resumedFromSet: Int)
  ```

- [ ] **Step 2: Add the coding key**

  In `CodingKeys`, after `day_number`, add:

  ```swift
  case resumed_from_set
  ```

- [ ] **Step 3: Add the encode branch**

  In the `encode(to:)` switch, after the `.workoutStarted` case, add:

  ```swift
  case .workoutResumed(let id, let lv, let day, let set):
      try c.encode(id, forKey: .exercise_id)
      try c.encode(lv, forKey: .level)
      try c.encode(day, forKey: .day_number)
      try c.encode(set, forKey: .resumed_from_set)
  ```

- [ ] **Step 4: Build to confirm no compiler errors**

  In Xcode, press ⌘B. Expected: Build Succeeded.

- [ ] **Step 5: Commit**

  ```bash
  git add inch/inch/Services/AnalyticsService.swift
  git commit -m "feat: add workoutResumed analytics event"
  ```

---

### Task 2: Today view indicator

> No unit test — `TodayViewModel` is in the app target with no test infrastructure. Verify by build and manual inspection.

**Files:**
- Modify: `inch/inch/Features/Today/TodayViewModel.swift:7-8` (property) and `~84` (computation in `loadToday`)
- Modify: `inch/inch/Features/Today/ExerciseCard.swift:9` (property) and `~64-68` (badge in `cardContent`)
- Modify: `inch/inch/Features/Today/TodayView.swift:~124-129` (pass parameter)

**Context:** `TodayViewModel.completedTodayIds` is a `Set<String>` computed from `setsByExercise` in `loadToday()`. The new `inProgressTodayIds` uses the same dictionary with different conditions: `completedCount > 0 && completedCount < prescribedCount`.

`ExerciseCard` already has `var isCompleted: Bool = false` with a default. Add `isInProgress` the same way.

- [ ] **Step 1: Add `inProgressTodayIds` property to `TodayViewModel`**

  After `var completedTodayIds: Set<String> = []` (line 8), add:

  ```swift
  var inProgressTodayIds: Set<String> = []
  ```

- [ ] **Step 2: Compute `inProgressTodayIds` in `loadToday()`**

  In `loadToday()`, find this block (around line 84):
  ```swift
  completedTodayIds = fullyCompletedIds
  ```

  Immediately after it, add:
  ```swift
  inProgressTodayIds = Set(all.compactMap { enrolment -> String? in
      guard let id = enrolment.exerciseDefinition?.exerciseId else { return nil }
      let completedCount = setsByExercise[id]?.count ?? 0
      let prescribedCount = currentPrescription(for: enrolment)?.sets.count ?? 0
      guard prescribedCount > 0, completedCount > 0, completedCount < prescribedCount else { return nil }
      return id
  })
  ```

- [ ] **Step 3: Add `isInProgress` parameter to `ExerciseCard`**

  After `var isCompleted: Bool = false` (line 9), add:

  ```swift
  var isInProgress: Bool = false
  ```

- [ ] **Step 4: Add the "In progress" badge to `ExerciseCard`**

  Find the `Text("Day \(enrolment.currentDay)")` line (around line 65). Replace it with:

  ```swift
  HStack(spacing: 6) {
      Text("Day \(enrolment.currentDay)")
          .font(.caption)
          .foregroundStyle(.tertiary)
      if isInProgress {
          Text("In progress")
              .font(.caption2)
              .fontWeight(.medium)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(.blue.opacity(0.1), in: Capsule())
              .foregroundStyle(.blue)
      }
  }
  ```

- [ ] **Step 5: Update `cardAccessibilityLabel` in `ExerciseCard`**

  Find the `if isCompleted { parts.append("Completed") }` line (around line 152). After it, add:

  ```swift
  if isInProgress { parts.append("In progress") }
  ```

- [ ] **Step 6: Pass `isInProgress` in `TodayView`**

  Find the `ExerciseCard(...)` call in `TodayView.exerciseList` (around line 124). It currently ends with `isCompleted: viewModel.completedTodayIds.contains(exerciseId)`. Add the new parameter:

  ```swift
  ExerciseCard(
      enrolment: enrolment,
      prescription: viewModel.currentPrescription(for: enrolment),
      conflictWarning: viewModel.conflictWarnings[exerciseId],
      isCompleted: viewModel.completedTodayIds.contains(exerciseId),
      isInProgress: viewModel.inProgressTodayIds.contains(exerciseId)
  )
  ```

- [ ] **Step 7: Build to confirm no compiler errors**

  Press ⌘B. Expected: Build Succeeded.

- [ ] **Step 8: Commit**

  ```bash
  git add inch/inch/Features/Today/TodayViewModel.swift \
          inch/inch/Features/Today/ExerciseCard.swift \
          inch/inch/Features/Today/TodayView.swift
  git commit -m "feat: show 'In progress' badge on exercise card for interrupted workouts"
  ```

---

### Task 3: WorkoutViewModel — resume detection and methods

> No unit test — `WorkoutViewModel` is in the app target with no test infrastructure. Verify by build and manual testing in Task 5.

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutViewModel.swift`

**Context:** `WorkoutViewModel.load(context:)` currently always fires `workout_started` analytics. After this change it only fires `workout_started` when no resume is offered — otherwise `restartSession()` or `resumeSession()` fires the appropriate event.

The detection query uses `sessionDate >= todayStart` (not `completedAt`) to match the date-filtering convention used in `TodayViewModel`.

`WorkoutViewModel.saveTimedSet` stores `actualReps: 0` for timed exercises, so `resumeSessionReps` will be `0` for resumed timed workouts. This is acceptable — see spec for rationale.

- [ ] **Step 1: Add the three new properties**

  After `var phase: WorkoutPhase = .loading` (line 23), add:

  ```swift
  var shouldOfferResume: Bool = false
  private(set) var resumeSetCount: Int = 0
  private(set) var resumeSessionReps: Int = 0
  ```

- [ ] **Step 2: Add resume detection to `load()`**

  In `load(context:)`, find these two consecutive lines (around line 81–82):
  ```swift
  sessionDate = .now
  phase = .ready
  ```

  Between them, insert the detection block:

  ```swift
  sessionDate = .now

  if let exerciseId = enrolment.exerciseDefinition?.exerciseId, let prescription {
      let todayStart = Calendar.current.startOfDay(for: .now)
      let allSets = (try? context.fetch(FetchDescriptor<CompletedSet>())) ?? []
      let todaySets = allSets.filter { $0.exerciseId == exerciseId && $0.sessionDate >= todayStart }
      let completedCount = todaySets.count
      if completedCount > 0, completedCount < prescription.sets.count {
          shouldOfferResume = true
          resumeSetCount = completedCount
          resumeSessionReps = todaySets.reduce(0) { $0 + $1.actualReps }
      }
  }

  phase = .ready
  ```

- [ ] **Step 3: Make `workout_started` conditional in `load()`**

  Still in `load(context:)`, find the `analytics?.record(...)` call for `workout_started` (around line 85–92). Wrap it in a guard:

  ```swift
  if !shouldOfferResume {
      analytics?.record(AnalyticsEvent(
          name: "workout_started",
          properties: .workoutStarted(
              exerciseId: def.exerciseId,
              level: enrolment.currentLevel,
              dayNumber: enrolment.currentDay
          )
      ))
  }
  ```

- [ ] **Step 4: Add `resumeSession()` and `restartSession()`**

  After the `finishRest()` method (around line 136), add:

  ```swift
  func resumeSession() {
      currentSetIndex = resumeSetCount
      sessionTotalReps = resumeSessionReps
      shouldOfferResume = false
      guard let enrolment, let def = enrolment.exerciseDefinition else { return }
      analytics?.record(AnalyticsEvent(
          name: "workout_resumed",
          properties: .workoutResumed(
              exerciseId: def.exerciseId,
              level: enrolment.currentLevel,
              dayNumber: enrolment.currentDay,
              resumedFromSet: resumeSetCount + 1
          )
      ))
  }

  func restartSession() {
      shouldOfferResume = false
      guard let enrolment, let def = enrolment.exerciseDefinition else { return }
      analytics?.record(AnalyticsEvent(
          name: "workout_started",
          properties: .workoutStarted(
              exerciseId: def.exerciseId,
              level: enrolment.currentLevel,
              dayNumber: enrolment.currentDay
          )
      ))
  }
  ```

- [ ] **Step 5: Build to confirm no compiler errors**

  Press ⌘B. Expected: Build Succeeded.

- [ ] **Step 6: Commit**

  ```bash
  git add inch/inch/Features/Workout/WorkoutViewModel.swift
  git commit -m "feat: detect interrupted workout session and add resume/restart methods"
  ```

---

### Task 4: WorkoutSessionView — confirmation dialog and quit alert

> No unit test — view-level change. Verify by build and manual testing in Task 5.

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutSessionView.swift`

**Context:** `WorkoutSessionView` has `@State private var viewModel: WorkoutViewModel`. Because `viewModel` is a `@State`-held `@Observable` object, the dialog is driven by a local `@State private var showResumePrompt` rather than binding directly to `viewModel.shouldOfferResume`. This avoids ambiguity around `Bindable` initialisation.

The `.onChange(of: showResumePrompt)` handler catches outside-tap dismissal (iOS sets the binding to `false` without calling any button). The guard `viewModel.shouldOfferResume` prevents a spurious `restartSession()` call after a button has already cleared the flag.

- [ ] **Step 1: Add `@State private var showResumePrompt`**

  Find the `@State private var showingQuitConfirm = false` line (around line 52). After it, add:

  ```swift
  @State private var showResumePrompt = false
  ```

- [ ] **Step 2: Set `showResumePrompt` in `.task`**

  In the `.task` block, find `viewModel.load(context: modelContext)` (line 196). After it, add:

  ```swift
  if viewModel.shouldOfferResume {
      showResumePrompt = true
  }
  ```

- [ ] **Step 3: Add the `.confirmationDialog` modifier**

  The view has a chain of modifiers after the `Group { ... }` body. Add the dialog modifier after the existing `.alert("Quit workout?", ...)` block (which ends around line 178):

  ```swift
  .confirmationDialog(
      "Resume workout?",
      isPresented: $showResumePrompt
  ) {
      Button("Resume from set \(viewModel.resumeSetCount + 1)") {
          // A recording for set 1 was started before the dialog appeared.
          // Discard it — the user is resuming from a later set.
          if motionRecording.isRecording {
              let url = motionRecording.stopRecording()
              if let url { try? FileManager.default.removeItem(at: url) }
          }
          viewModel.resumeSession()
          // Start a fresh recording for the correct set number.
          if sensorConsented {
              let id = viewModel.enrolment?.exerciseDefinition?.exerciseId ?? ""
              repCounter?.reset()
              motionRecording.onSample = { [repCounter] ax, ay, az in
                  repCounter?.processSample(ax: ax, ay: ay, az: az)
              }
              motionRecording.startRecording(
                  exerciseId: id,
                  setNumber: viewModel.currentSetIndex + 1,
                  sessionId: sessionId,
                  context: modelContext
              )
          }
      }
      Button("Start over", role: .destructive) {
          // Recording for set 1 is already running and correct — no action needed.
          viewModel.restartSession()
      }
  }
  ```

  **Why Resume needs explicit recording restart:** `viewModel.load()` triggers `phase = .ready`, which causes the `.task` block and `.onChange(.ready)` handler to start recording for set 1 before the dialog appears. When the user resumes from set N, that set-1 recording is orphaned. Stopping it and starting a fresh recording for the correct set ensures sensor data is captured for the actual set being performed.

  **Why Start Over does not:** the recording already running is for set 1, which is exactly what's needed.

- [ ] **Step 4: Add `.onChange` to handle outside-tap dismissal**

  Immediately after the `.confirmationDialog` block, add:

  ```swift
  .onChange(of: showResumePrompt) { old, new in
      if old, !new, viewModel.shouldOfferResume {
          viewModel.restartSession()
      }
  }
  ```

- [ ] **Step 5: Update the quit alert message**

  Find the `.alert("Quit workout?", ...)` block. Inside it, find:

  ```swift
  Text("Your progress so far won't be saved.")
  ```

  Replace with:

  ```swift
  Text("Any sets in progress won't be saved.")
  ```

- [ ] **Step 6: Build to confirm no compiler errors**

  Press ⌘B. Expected: Build Succeeded.

- [ ] **Step 7: Commit**

  ```bash
  git add inch/inch/Features/Workout/WorkoutSessionView.swift
  git commit -m "feat: add resume workout confirmation dialog"
  ```

---

### Task 5: Manual verification on device

> Install using `./scripts/build-device.sh` (or `upload-testflight.sh` for TestFlight). Use an exercise with 3+ sets.

- [ ] **Check 1 — No indicator shown for fresh exercise**

  Open Today view. An exercise with no completed sets today should show no "In progress" badge.

- [ ] **Check 2 — Indicator appears after partial completion**

  Complete 1 set of a 3-set exercise. Force-quit the app. Reopen — the exercise card should show the "In progress" badge.

- [ ] **Check 3 — Resume prompt appears**

  Tap the exercise with the "In progress" badge. The workout screen should immediately show a dialog: "Resume workout?" with "Resume from set 2" and "Start over".

- [ ] **Check 4 — Resume fast-forwards correctly**

  Tap "Resume from set 2". Confirm the ready view shows "Start Set 2 of 3".

- [ ] **Check 5 — Resume completes correctly**

  Resume and complete the remaining sets. Confirm the completion screen shows and the exercise is marked done in Today view.

- [ ] **Check 6 — Start over works**

  Repeat the partial-completion scenario. Tap "Start over" — confirm the workout starts at set 1.

- [ ] **Check 7 — Outside-tap dismiss treated as Start over**

  When the "Resume workout?" dialog appears, tap outside it to dismiss. Confirm the workout starts at set 1 (not set 2).

- [ ] **Check 8 — No indicator after full completion**

  Complete all sets of an exercise. Force-quit and reopen. Confirm no "In progress" badge and no resume dialog.

- [ ] **Check 9 — No resume offered next day**

  (Simulate by temporarily adjusting the date or waiting overnight.) Open an exercise with yesterday's partial sets. Confirm no resume dialog — workout opens at set 1.
