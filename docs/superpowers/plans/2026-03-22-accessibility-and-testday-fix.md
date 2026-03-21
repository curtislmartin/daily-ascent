# Basic Accessibility + TestDayView Notification Fix — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add basic VoiceOver accessibility labels/grouping across the main iOS flows, and fix TestDayView to fire notification service calls on test completion (currently skipped).

**Architecture:** Pure SwiftUI modifier additions — no structural changes to any view. Each file is independent and can be applied in any order. TestDayView fix adds environment injection + a `.onChange(of:)` handler mirroring the existing WorkoutSessionView pattern.

**Tech Stack:** SwiftUI, Swift 6.2, UserNotifications, SwiftData. No new files created.

---

## Chunk 1: TestDayView Notification Fix + Today Tab

### Task 1: Fix TestDayView — trigger notifications after test completion

`TestDayView` saves the test result and advances the schedule but never calls `NotificationService`. A passed test should fire a level-unlock notification and refresh the upcoming schedule.

**Files:**
- Modify: `inch/inch/Features/Workout/TestDayView.swift`

- [ ] **Add `NotificationService` environment and `UserSettings` query to `TestDayView`**

  At the top of the struct, after `private let scheduler = SchedulingEngine()`, add:

  ```swift
  @Environment(NotificationService.self) private var notifications
  @Query private var allSettings: [UserSettings]
  private var settings: UserSettings? { allSettings.first }
  ```

- [ ] **Add `.onChange(of: phase)` modifier to the view body**

  After the existing `.task { load() }` modifier, add:

  ```swift
  .onChange(of: phase) { _, newPhase in
      guard case .result(_, let passed, _) = newPhase,
            let settings else { return }
      Task {
          await notifications.requestPermission()
          await notifications.refresh(context: modelContext, settings: settings)
          if passed, settings.levelUnlockNotificationEnabled,
             let enrolment {
              notifications.postLevelUnlock(
                  exerciseName: enrolment.exerciseDefinition?.name ?? "",
                  newLevel: enrolment.currentLevel,
                  startsIn: SchedulingEngine.interLevelGapDays
              )
          }
      }
  }
  ```

- [ ] **Build to verify no errors**

  ```bash
  cd /Users/curtismartin/Work/inch-project/inch
  xcodebuild -scheme inch -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | grep -E "error:|Build succeeded"
  ```
  Expected: `Build succeeded`

- [ ] **Commit**

  ```bash
  cd /Users/curtismartin/Work/inch-project
  git add inch/inch/Features/Workout/TestDayView.swift
  git commit -m "fix: fire notification service after test day completion"
  ```

---

### Task 2: ExerciseCard accessibility

Color bar, chevron, and muscle-group tag are decorative. The card as a whole should read as a single tappable element with a meaningful label. Badges need readable labels.

**Files:**
- Modify: `inch/inch/Features/Today/ExerciseCard.swift`

- [ ] **Hide the color bar from VoiceOver**

  On the `colorBar` computed property's `RoundedRectangle`, add `.accessibilityHidden(true)`:

  ```swift
  private var colorBar: some View {
      RoundedRectangle(cornerRadius: 3)
          .fill(accentColor)
          .frame(width: 4)
          .frame(height: 52)
          .accessibilityHidden(true)
  }
  ```

- [ ] **Fix the test day badge label**

  Replace the `testDayBadge` modifier chain — add `.accessibilityLabel("Test day")` after `.foregroundStyle(.orange)`:

  ```swift
  private var testDayBadge: some View {
      Text("TEST DAY")
          .font(.caption2)
          .fontWeight(.bold)
          .padding(.horizontal, 6)
          .padding(.vertical, 3)
          .background(.orange.opacity(0.15), in: Capsule())
          .foregroundStyle(.orange)
          .accessibilityLabel("Test day")
  }
  ```

- [ ] **Fix the level badge label**

  Add `.accessibilityLabel("Level \(enrolment.currentLevel)")` to `levelBadge`:

  ```swift
  private var levelBadge: some View {
      Text("L\(enrolment.currentLevel)")
          .font(.caption)
          .fontWeight(.medium)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(.secondary.opacity(0.12), in: Capsule())
          .foregroundStyle(.secondary)
          .accessibilityLabel("Level \(enrolment.currentLevel)")
  }
  ```

- [ ] **Hide the muscle group tag and chevron from VoiceOver**

  In `muscleGroupTag(_:)`, add `.accessibilityHidden(true)` at the end:

  ```swift
  private func muscleGroupTag(_ group: MuscleGroup) -> some View {
      Text(group.displayName)
          .font(.caption2)
          .fontWeight(.medium)
          .padding(.horizontal, 6)
          .padding(.vertical, 3)
          .background(accentColor.opacity(0.1), in: Capsule())
          .foregroundStyle(accentColor)
          .accessibilityHidden(true)
  }
  ```

  In `cardContent`, find the chevron `Image` and add `.accessibilityHidden(true)`:

  ```swift
  Image(systemName: "chevron.right")
      .font(.caption)
      .foregroundStyle(.tertiary)
      .accessibilityHidden(true)
  ```

- [ ] **Label the completed checkmark**

  In `cardContent`, find the checkmark `Image` and add `.accessibilityLabel("Completed")`:

  ```swift
  Image(systemName: "checkmark.circle.fill")
      .font(.title3)
      .foregroundStyle(.green)
      .accessibilityLabel("Completed")
  ```

- [ ] **Give the NavigationLink a composite accessibility label**

  Add an `.accessibilityLabel` to the `NavigationLink` in `body` that combines the key info. Add it after `.buttonStyle(.plain)`:

  ```swift
  .buttonStyle(.plain)
  .accessibilityLabel(cardAccessibilityLabel)
  ```

  Add the computed property to the struct:

  ```swift
  private var cardAccessibilityLabel: String {
      var parts: [String] = []
      parts.append(definition?.name ?? "Exercise")
      if isTestDay { parts.append("Test day") }
      parts.append("Level \(enrolment.currentLevel), day \(enrolment.currentDay)")
      if let summary = setSummary { parts.append(summary) }
      if let warning = conflictWarning { parts.append("Warning: \(warning)") }
      if isCompleted { parts.append("Completed") }
      return parts.joined(separator: ", ")
  }
  ```

- [ ] **Build to verify no errors**

  ```bash
  cd /Users/curtismartin/Work/inch-project/inch
  xcodebuild -scheme inch -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | grep -E "error:|Build succeeded"
  ```
  Expected: `Build succeeded`

- [ ] **Commit**

  ```bash
  cd /Users/curtismartin/Work/inch-project
  git add inch/inch/Features/Today/ExerciseCard.swift
  git commit -m "feat(a11y): ExerciseCard composite label, hide decorative elements"
  ```

---

### Task 3: TodaySessionBanner accessibility

The banner has two states. Both should read as a single grouped element.

**Files:**
- Modify: `inch/inch/Features/Today/TodaySessionBanner.swift`

- [ ] **Group the streak/availability banner**

  On `streakAvailabilityBanner`, add grouping after `.padding(.top, 4)`:

  ```swift
  .frame(maxWidth: .infinity, alignment: .leading)
  .padding(.top, 4)
  .accessibilityElement(children: .combine)
  .accessibilityLabel("\(streak)-day streak. \(totalCount) exercise\(totalCount == 1 ? "" : "s") available today.")
  ```

- [ ] **Group the session progress card**

  On `sessionProgressCard`'s outer `VStack`, add after the final `.background(...)`:

  ```swift
  .accessibilityElement(children: .ignore)
  .accessibilityLabel("Today's session: \(completedCount) of \(totalCount) done. \(progressCopy)")
  ```

- [ ] **Build and commit**

  ```bash
  cd /Users/curtismartin/Work/inch-project/inch
  xcodebuild -scheme inch -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | grep -E "error:|Build succeeded"
  ```

  ```bash
  cd /Users/curtismartin/Work/inch-project
  git add inch/inch/Features/Today/TodaySessionBanner.swift
  git commit -m "feat(a11y): TodaySessionBanner grouped accessibility label"
  ```

---

### Task 4: TodayDemographicsNudge — label the dismiss button

The X button has no visible label — VoiceOver reads "button" with no context.

**Files:**
- Modify: `inch/inch/Features/Today/TodayDemographicsNudge.swift`

- [ ] **Label the dismiss button**

  Add `.accessibilityLabel("Dismiss profile nudge")` to the `Button`:

  ```swift
  Button {
      onDismiss()
  } label: {
      Image(systemName: "xmark")
          .font(.caption)
          .foregroundStyle(.secondary)
  }
  .buttonStyle(.plain)
  .accessibilityLabel("Dismiss profile nudge")
  ```

- [ ] **Build and commit**

  ```bash
  cd /Users/curtismartin/Work/inch-project/inch
  xcodebuild -scheme inch -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | grep -E "error:|Build succeeded"
  ```

  ```bash
  cd /Users/curtismartin/Work/inch-project
  git add inch/inch/Features/Today/TodayDemographicsNudge.swift
  git commit -m "feat(a11y): label dismiss button on demographics nudge"
  ```

---

## Chunk 2: Workout Tab + History Tab + Program Tab

### Task 5: WorkoutSessionView — group the set progress header

The header shows "Set 2 of 5 / Day 14 · Level 2 / Next: 28 reps" as separate elements. Combine into one.

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutSessionView.swift`

- [ ] **Combine the set progress header into one element**

  On `setProgressHeader`, add after the outer `HStack`'s closing brace (before the final `}` of the `var`):

  ```swift
  .accessibilityElement(children: .combine)
  ```

- [ ] **Build and commit**

  ```bash
  cd /Users/curtismartin/Work/inch-project/inch
  xcodebuild -scheme inch -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | grep -E "error:|Build succeeded"
  ```

  ```bash
  cd /Users/curtismartin/Work/inch-project
  git add inch/inch/Features/Workout/WorkoutSessionView.swift
  git commit -m "feat(a11y): combine set progress header into single element"
  ```

---

### Task 6: RealTimeCountingView — label the rep counter and tap button

The large counter shows a number. VoiceOver should say "12 reps" not "12". The progress ring is decorative.

**Files:**
- Modify: `inch/inch/Features/Workout/RealTimeCountingView.swift`

- [ ] **Label the counter ZStack and hide the ring**

  The outer `ZStack` (circle + counter) should be a single element. Add modifiers after `.frame(width: 200, height: 200)`:

  ```swift
  .frame(width: 200, height: 200)
  .accessibilityElement(children: .ignore)
  .accessibilityLabel("\(count) reps")
  ```

- [ ] **Add an accessibility hint to the tap button**

  Find the "Tap Each Rep" `Button` and add `.accessibilityHint("Double-tap to count one rep")`:

  ```swift
  .buttonStyle(.borderedProminent)
  .controlSize(.large)
  .disabled(showingCompletion)
  .accessibilityHint("Double-tap to count one rep")
  ```

- [ ] **Build and commit**

  ```bash
  cd /Users/curtismartin/Work/inch-project/inch
  xcodebuild -scheme inch -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | grep -E "error:|Build succeeded"
  ```

  ```bash
  cd /Users/curtismartin/Work/inch-project
  git add inch/inch/Features/Workout/RealTimeCountingView.swift
  git commit -m "feat(a11y): rep counter label and tap button hint"
  ```

---

### Task 7: RestTimerView — label the circular countdown

The circular progress ring + countdown number should read as "Rest timer, 45 seconds remaining".

**Files:**
- Modify: `inch/inch/Features/Workout/RestTimerView.swift`

- [ ] **Group the ZStack and give it a dynamic label**

  Add modifiers after the `ZStack`'s `.frame(width: 200, height: 200)`:

  ```swift
  .frame(width: 200, height: 200)
  .accessibilityElement(children: .ignore)
  .accessibilityLabel("Rest timer, \(remaining) second\(remaining == 1 ? "" : "s") remaining")
  ```

- [ ] **Build and commit**

  ```bash
  cd /Users/curtismartin/Work/inch-project/inch
  xcodebuild -scheme inch -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | grep -E "error:|Build succeeded"
  ```

  ```bash
  cd /Users/curtismartin/Work/inch-project
  git add inch/inch/Features/Workout/RestTimerView.swift
  git commit -m "feat(a11y): rest timer countdown label"
  ```

---

### Task 8: ExerciseCompleteView — group the result area

The trophy, "Done!", exercise name, rep count, and next date are separate elements. Group as one summary.

**Files:**
- Modify: `inch/inch/Features/Workout/ExerciseCompleteView.swift`

- [ ] **Group the result VStack into a single accessibility element**

  Add modifiers to the inner `VStack(spacing: 16)` (the one containing the checkmark, "Done!", and exercise name):

  ```swift
  VStack(spacing: 16) {
      Image(systemName: "checkmark.circle.fill")
          ...
      Text("Done!")
          ...
      Text(exerciseName)
          ...
  }
  .accessibilityElement(children: .ignore)
  .accessibilityLabel("\(exerciseName) complete. \(totalReps) total reps.")
  ```

- [ ] **Build and commit**

  ```bash
  cd /Users/curtismartin/Work/inch-project/inch
  xcodebuild -scheme inch -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | grep -E "error:|Build succeeded"
  ```

  ```bash
  cd /Users/curtismartin/Work/inch-project
  git add inch/inch/Features/Workout/ExerciseCompleteView.swift
  git commit -m "feat(a11y): exercise complete summary label"
  ```

---

### Task 9: DayGroupRow — label collapsed row and hide decorative dots

The exercise colour dots are decorative. The collapsed button row should read as a single summary.

**Files:**
- Modify: `inch/inch/Features/History/DayGroupRow.swift`

- [ ] **Hide the exercise dots**

  On `exerciseDots`, add `.accessibilityHidden(true)` after the closing brace of the `HStack`:

  ```swift
  private var exerciseDots: some View {
      HStack(spacing: 3) {
          ForEach(day.exercises) { exercise in
              Circle()
                  .fill(Color(hex: exercise.color) ?? .accentColor)
                  .frame(width: 8, height: 8)
          }
      }
      .accessibilityHidden(true)
  }
  ```

- [ ] **Give the collapsed button a combined accessibility label and expand/collapse hint**

  In `regularDayContent`, the `Button`'s label `HStack` contains all the info. Add modifiers after `.buttonStyle(.plain)`:

  ```swift
  .buttonStyle(.plain)
  .accessibilityLabel(collapsedLabel)
  .accessibilityHint(isExpanded ? "Double-tap to collapse" : "Double-tap to expand")
  ```

  Add the computed property:

  ```swift
  private var collapsedLabel: String {
      var parts = [dayLabel, "\(day.totalReps) reps", "\(day.exercises.count) exercises"]
      if let dur = durationLabel { parts.append(dur) }
      return parts.joined(separator: ", ")
  }
  ```

- [ ] **Build and commit**

  ```bash
  cd /Users/curtismartin/Work/inch-project/inch
  xcodebuild -scheme inch -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | grep -E "error:|Build succeeded"
  ```

  ```bash
  cd /Users/curtismartin/Work/inch-project
  git add inch/inch/Features/History/DayGroupRow.swift
  git commit -m "feat(a11y): DayGroupRow label, hide decorative dots, expand hint"
  ```

---

### Task 10: WeeklyVolumeChart — chart summary label

Swift Charts individual marks are not meaningfully navigable. Give the chart a summary label.

**Files:**
- Modify: `inch/inch/Features/History/WeeklyVolumeChart.swift`

- [ ] **Add a summary accessibility label to the chart**

  Add modifiers after `.frame(height: 180)`:

  ```swift
  .frame(height: 180)
  .accessibilityLabel("Weekly volume chart. Shows total reps per week for the last \(weeklyData.count) weeks.")
  .accessibilityHidden(weeklyData.isEmpty)
  ```

- [ ] **Build and commit**

  ```bash
  cd /Users/curtismartin/Work/inch-project/inch
  xcodebuild -scheme inch -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | grep -E "error:|Build succeeded"
  ```

  ```bash
  cd /Users/curtismartin/Work/inch-project
  git add inch/inch/Features/History/WeeklyVolumeChart.swift
  git commit -m "feat(a11y): weekly volume chart summary label"
  ```

---

### Task 11: SessionHistoryChart — chart summary label

**Files:**
- Modify: `inch/inch/Features/Program/SessionHistoryChart.swift`

- [ ] **Add a summary accessibility label**

  Add modifiers after `.frame(height: 180)`:

  ```swift
  .frame(height: 180)
  .accessibilityLabel("Session history chart. Shows reps per session across \(history.count) session\(history.count == 1 ? "" : "s").\(testTarget > 0 ? " Target to pass: \(testTarget) reps." : "")")
  .accessibilityHidden(history.isEmpty)
  ```

- [ ] **Build and commit**

  ```bash
  cd /Users/curtismartin/Work/inch-project/inch
  xcodebuild -scheme inch -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | grep -E "error:|Build succeeded"
  ```

  ```bash
  cd /Users/curtismartin/Work/inch-project
  git add inch/inch/Features/Program/SessionHistoryChart.swift
  git commit -m "feat(a11y): session history chart summary label"
  ```

---

### Task 12: ProgramView (EnrolmentRow) — progress bar label

The custom progress bar has no text that VoiceOver can read. The row's NavigationLink should get a composite label.

**Files:**
- Modify: `inch/inch/Features/Program/ProgramView.swift`

- [ ] **Label the progress bar and hide it from VoiceOver's element list**

  The `GeometryReader` block renders a visual-only progress bar. Add `.accessibilityHidden(true)` after `.frame(height: 6)`:

  ```swift
  .frame(height: 6)
  .accessibilityHidden(true)
  ```

- [ ] **Give the NavigationLink a composite label**

  The `NavigationLink` in `ProgramView.body` wraps `EnrolmentRow`. Add `.accessibilityLabel` to the row's outer `VStack` — add it after `.padding(.vertical, 4)`:

  ```swift
  .padding(.vertical, 4)
  .accessibilityElement(children: .ignore)
  .accessibilityLabel(rowAccessibilityLabel)
  ```

  Add the computed property to `EnrolmentRow`:

  ```swift
  private var rowAccessibilityLabel: String {
      var parts: [String] = []
      parts.append(def?.name ?? "Exercise")
      parts.append("Level \(enrolment.currentLevel), day \(enrolment.currentDay) of \(totalDays)")
      let pct = Int(progress * 100)
      parts.append("\(pct)% complete")
      if let next = enrolment.nextScheduledDate {
          parts.append("Next session \(next.formatted(.relative(presentation: .named)))")
      }
      return parts.joined(separator: ", ")
  }
  ```

- [ ] **Build to verify no errors**

  ```bash
  cd /Users/curtismartin/Work/inch-project/inch
  xcodebuild -scheme inch -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | grep -E "error:|Build succeeded"
  ```
  Expected: `Build succeeded`

- [ ] **Commit**

  ```bash
  cd /Users/curtismartin/Work/inch-project
  git add inch/inch/Features/Program/ProgramView.swift
  git commit -m "feat(a11y): ProgramView row label, hide progress bar from VoiceOver"
  ```
