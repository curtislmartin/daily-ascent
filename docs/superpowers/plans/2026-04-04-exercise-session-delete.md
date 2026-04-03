# Exercise Session Delete Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to drill into a single exercise's session from History and optionally delete it, with enrolment rollback for completed sessions.

**Architecture:** Four targeted changes — add a navigation destination case, add a delete method to `HistoryViewModel`, create `ExerciseSessionDetailView`, and wire `DayGroupRow` to push the new view. No new services or shared-package changes required.

**Tech Stack:** SwiftUI, SwiftData (`@Query`, `ModelContext`, `FetchDescriptor`), `SchedulingEngine.computeNextDate`, Swift 6.2 strict concurrency.

**Spec:** `docs/superpowers/specs/2026-04-04-exercise-session-delete-design.md`

---

## File Map

| File | Change |
|---|---|
| `inch/inch/Navigation/NavigationDestinations.swift` | Add `.exerciseSession` case to `HistoryDestination`; add case to `withHistoryDestinations()` |
| `inch/inch/Features/History/ExerciseSessionDetailView.swift` | **New** — session drill-down and delete UI |
| `inch/inch/Features/History/SetRow.swift` | **New** — set row subview used by `ExerciseSessionDetailView` |
| `inch/inch/Features/History/HistoryViewModel.swift` | Add `deleteSession(exerciseId:date:context:)` |
| `inch/inch/Features/History/DayGroupRow.swift` | Wrap `ExerciseSummaryRow` items in `NavigationLink(value:)` |

---

### Task 1: Navigation destination + ExerciseSessionDetailView shell

**Files:**
- Modify: `inch/inch/Navigation/NavigationDestinations.swift`
- Create: `inch/inch/Features/History/ExerciseSessionDetailView.swift`

This task makes the project compile with the new destination. The view is a placeholder — full implementation comes in Task 3.

- [ ] **Step 1: Add the new case to `HistoryDestination`**

In `NavigationDestinations.swift`, change:

```swift
enum HistoryDestination: Hashable {
    case exerciseDetail(PersistentIdentifier)
}
```

to:

```swift
enum HistoryDestination: Hashable {
    case exerciseDetail(PersistentIdentifier)
    case exerciseSession(exerciseId: String, sessionDate: Date)
}
```

- [ ] **Step 2: Add the case to `withHistoryDestinations()`**

```swift
func withHistoryDestinations() -> some View {
    navigationDestination(for: HistoryDestination.self) { destination in
        switch destination {
        case .exerciseDetail(let id):
            ExerciseDetailView(enrolmentId: id)
        case .exerciseSession(let exerciseId, let sessionDate):
            ExerciseSessionDetailView(exerciseId: exerciseId, sessionDate: sessionDate)
        }
    }
}
```

- [ ] **Step 3: Create the shell view**

Create `inch/inch/Features/History/ExerciseSessionDetailView.swift`:

```swift
import SwiftUI
import SwiftData
import InchShared

struct ExerciseSessionDetailView: View {
    let exerciseId: String
    let sessionDate: Date

    var body: some View {
        Text("Session detail")
            .navigationTitle("Session")
    }
}
```

- [ ] **Step 4: Build and confirm it compiles**

Open Xcode and build the `inch` scheme (⌘B). Expect no errors.

- [ ] **Step 5: Commit**

```bash
git add inch/inch/Navigation/NavigationDestinations.swift \
        inch/inch/Features/History/ExerciseSessionDetailView.swift
git commit -m "feat: add exerciseSession navigation destination and shell view"
```

---

### Task 2: deleteSession in HistoryViewModel

**Files:**
- Modify: `inch/inch/Features/History/HistoryViewModel.swift`

`deleteSession` is in the app target — no test infrastructure. The spec documents manual verification steps at the end of this task.

- [ ] **Step 1: Add the method signature**

At the bottom of `HistoryViewModel`, before the closing brace, add:

```swift
// MARK: - Delete

func deleteSession(exerciseId: String, date: Date, context: ModelContext) throws {
    // implementation follows
}
```

Build to confirm no syntax errors.

- [ ] **Step 2: Fetch the session's CompletedSet records**

Replace the body placeholder:

```swift
func deleteSession(exerciseId: String, date: Date, context: ModelContext) throws {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: date)
    guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return }

    let descriptor = FetchDescriptor<CompletedSet>(
        predicate: #Predicate { set in
            set.exerciseId == exerciseId &&
            set.sessionDate >= start &&
            set.sessionDate < end
        },
        sortBy: [SortDescriptor(\.setNumber)]
    )
    let sessionSets = try context.fetch(descriptor)
    guard !sessionSets.isEmpty else { return }
```

- [ ] **Step 3: Determine whether the session was complete**

Append inside the function, before any deletions:

```swift
    let firstSet = sessionSets[0]
    // DayPrescription.sets is [Int] (array of target rep counts per set — not optional).
    // LevelDefinition.days is [DayPrescription]? (optional relationship).
    let levelDef = firstSet.enrolment?.exerciseDefinition?.levels?
        .first { $0.level == firstSet.level }
    let dayPrescription = levelDef?.days?
        .first { $0.dayNumber == firstSet.dayNumber }
    let prescribedCount = dayPrescription?.sets.count ?? 0
    let wasComplete = prescribedCount > 0 && sessionSets.count >= prescribedCount
    let enrolment = firstSet.enrolment
```

- [ ] **Step 4: Delete the records**

```swift
    for set in sessionSets {
        context.delete(set)
    }
    try context.save()
```

- [ ] **Step 5: Handle partial sessions (early return)**

```swift
    guard wasComplete, let enrolment else { return }
```

- [ ] **Step 6: Fetch remaining sets for rollback**

```swift
    let remainingDescriptor = FetchDescriptor<CompletedSet>(
        predicate: #Predicate { set in set.exerciseId == exerciseId },
        sortBy: [SortDescriptor(\.sessionDate, order: .reverse)]
    )
    let remaining = try context.fetch(remainingDescriptor)
```

- [ ] **Step 7: No remaining sets — reset enrolment to L1D1**

```swift
    if remaining.isEmpty {
        enrolment.currentLevel = 1
        enrolment.currentDay = 1
        enrolment.lastCompletedDate = nil
        enrolment.nextScheduledDate = nil
        enrolment.restPatternIndex = 0
    } else {
```

- [ ] **Step 8: Remaining sets — reconstruct enrolment from most recent**

```swift
        let lastSet = remaining[0]

        let newLevel: Int
        let newDay: Int
        if lastSet.isTest && lastSet.testPassed == true {
            if lastSet.level < 3 {
                newLevel = lastSet.level + 1
                newDay = 1
            } else {
                // Level 3 test passed = programme complete
                newLevel = lastSet.level
                newDay = lastSet.dayNumber + 1
            }
        } else if lastSet.isTest {
            // Test failed — retry the same day
            newLevel = lastSet.level
            newDay = lastSet.dayNumber
        } else {
            // Normal day — advance to next day
            newLevel = lastSet.level
            newDay = lastSet.dayNumber + 1
        }

        enrolment.currentLevel = newLevel
        enrolment.currentDay = newDay
        enrolment.lastCompletedDate = lastSet.sessionDate

        let newLevelDef = enrolment.exerciseDefinition?.levels?.first { $0.level == newLevel }
        let patternCount = newLevelDef?.restDayPattern.count ?? 1
        enrolment.restPatternIndex = (newDay - 1) % patternCount

        if let newLevelDef {
            let snapshot = EnrolmentSnapshot(
                currentLevel: newLevel,
                currentDay: newDay,
                lastCompletedDate: lastSet.sessionDate,
                restPatternIndex: enrolment.restPatternIndex,
                enrolledAt: enrolment.enrolledAt,
                isActive: enrolment.isActive
            )
            enrolment.nextScheduledDate = SchedulingEngine().computeNextDate(
                enrolment: snapshot,
                level: LevelSnapshot(newLevelDef)
            )
        }
    }

    try context.save()
}
```

- [ ] **Step 9: Build and confirm it compiles**

Build the `inch` scheme (⌘B). Expect no errors. `SchedulingEngine` and `EnrolmentSnapshot` are from the `InchShared` module, already imported via the existing `import InchShared` at the top of the file — confirm that import is present; add it if missing.

- [ ] **Step 10: Commit**

```bash
git add inch/inch/Features/History/HistoryViewModel.swift
git commit -m "feat: add deleteSession with enrolment rollback to HistoryViewModel"
```

---

### Task 3: ExerciseSessionDetailView full implementation

**Files:**
- Modify: `inch/inch/Features/History/ExerciseSessionDetailView.swift`

Replace the shell with the full view.

- [ ] **Step 1: Set up @Query with a predicate built in init**

```swift
import SwiftUI
import SwiftData
import InchShared

struct ExerciseSessionDetailView: View {
    let exerciseId: String
    let sessionDate: Date

    @Query private var sets: [CompletedSet]
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false

    @State private var viewModel = HistoryViewModel()

    init(exerciseId: String, sessionDate: Date) {
        self.exerciseId = exerciseId
        self.sessionDate = sessionDate
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: sessionDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        _sets = Query(
            filter: #Predicate { set in
                set.exerciseId == exerciseId &&
                set.sessionDate >= start &&
                set.sessionDate < end
            },
            sort: \.setNumber
        )
    }
```

- [ ] **Step 2: Add computed helpers**

```swift
    private var exerciseName: String {
        sets.first?.enrolment?.exerciseDefinition?.name ?? exerciseId
    }

    private var prescribedSetCount: Int {
        guard let first = sets.first else { return 0 }
        return first.enrolment?.exerciseDefinition?.levels?
            .first { $0.level == first.level }?
            .days?.first { $0.dayNumber == first.dayNumber }?
            .sets.count ?? 0
    }

    private var isTimed: Bool {
        sets.first?.countingMode == .timed
    }

    private var totalReps: Int {
        sets.reduce(0) { $0 + $1.actualReps }
    }

    private var totalDurationSeconds: Double {
        sets.compactMap(\.setDurationSeconds).reduce(0, +)
    }
```

- [ ] **Step 3: Write the body**

```swift
    var body: some View {
        List {
            setsSection
            summarySection
            deleteSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(exerciseName)
                        .font(.headline)
                    Text(sessionDate.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .confirmationDialog(
            "Delete this session?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Session", role: .destructive) {
                try? viewModel.deleteSession(
                    exerciseId: exerciseId,
                    date: sessionDate,
                    context: context
                )
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone. Progress will be rolled back if the session was fully completed.")
        }
    }
```

- [ ] **Step 4: Write the sets section**

```swift
    @ViewBuilder
    private var setsSection: some View {
        Section("Sets") {
            ForEach(sets) { set in
                SetRow(set: set, isTimed: isTimed)
            }
            // Greyed-out uncompleted sets (partial sessions only)
            if sets.count < prescribedSetCount {
                ForEach((sets.count + 1)...prescribedSetCount, id: \.self) { number in
                    HStack {
                        Text("Set \(number)")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("—")
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
```

- [ ] **Step 5: Write the summary section**

```swift
    @ViewBuilder
    private var summarySection: some View {
        Section("Summary") {
            if isTimed {
                LabeledContent("Completed") {
                    Text("\(sets.count) of \(prescribedSetCount) sets")
                }
                LabeledContent("Total hold") {
                    Text(String(format: "%.0fs", totalDurationSeconds))
                }
            } else {
                LabeledContent("Completed") {
                    Text("\(sets.count) of \(prescribedSetCount) sets")
                }
                LabeledContent("Total reps") {
                    Text("\(totalReps)")
                }
            }
        }
    }
```

- [ ] **Step 6: Write the delete section**

```swift
    @ViewBuilder
    private var deleteSection: some View {
        Section {
            Button("Delete Session", role: .destructive) {
                showDeleteConfirmation = true
            }
        }
    }
}
```

- [ ] **Step 7: Create SetRow in its own file**

Create `inch/inch/Features/History/SetRow.swift` (one type per file — CLAUDE.md convention):

```swift
import SwiftUI
import InchShared

struct SetRow: View {
    let set: CompletedSet
    let isTimed: Bool

    var body: some View {
        HStack {
            Text("Set \(set.setNumber + 1)")
                .foregroundStyle(.primary)
            Spacer()
            if isTimed {
                if let held = set.setDurationSeconds {
                    Text(String(format: "%.0fs hold", held))
                }
                if let target = set.targetDurationSeconds {
                    Text("target \(target)s")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            } else {
                Text("\(set.actualReps) reps")
                if set.targetReps > 0 {
                    Text("target \(set.targetReps)")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
    }
}
```

In `ExerciseSessionDetailView.swift`, `SetRow` is used directly — no `private` modifier needed since it's in a separate file.

- [ ] **Step 8: Add SetRow.swift to the Xcode project**

Open `inch/inch.xcodeproj` in Xcode. Right-click the `History` group → Add Files → select `SetRow.swift`. Confirm it appears under the `inch` target.

- [ ] **Step 9: Build and confirm it compiles**

Build the `inch` scheme (⌘B). Expect no errors.

- [ ] **Step 10: Manual smoke test in Simulator**

Run on iPhone 16 Pro simulator. Navigate to History → expand a day → tap any exercise row. Expect: the shell "Session detail" text appears (navigation works). Full wiring comes in Task 4.

- [ ] **Step 11: Commit**

```bash
git add inch/inch/Features/History/ExerciseSessionDetailView.swift \
        inch/inch/Features/History/SetRow.swift \
        inch/inch.xcodeproj/project.pbxproj
git commit -m "feat: implement ExerciseSessionDetailView with sets list and delete confirmation"
```

---

### Task 4: Wire DayGroupRow to push the session detail view

**Files:**
- Modify: `inch/inch/Features/History/DayGroupRow.swift`

Wrap each `ExerciseSummaryRow` in a `NavigationLink(value:)`. Both `regularDayContent` and `testDayContent` need this treatment.

- [ ] **Step 1: Wrap exercises in regularDayContent**

In `regularDayContent`, the expanded `ForEach` currently reads:

```swift
ForEach(day.exercises) { exercise in
    ExerciseSummaryRow(exercise: exercise)
        .padding(.vertical, 2)
}
```

Change to:

```swift
ForEach(day.exercises) { exercise in
    NavigationLink(value: HistoryDestination.exerciseSession(
        exerciseId: exercise.id,
        sessionDate: day.id
    )) {
        ExerciseSummaryRow(exercise: exercise)
    }
    .padding(.vertical, 2)
}
```

- [ ] **Step 2: Wrap exercises in testDayContent**

In `testDayContent`, the `ForEach` currently reads:

```swift
ForEach(day.exercises.filter(\.isTest)) { exercise in
    VStack(alignment: .leading, spacing: 4) {
        // ... content
    }
    .padding(.vertical, 4)
}
```

Wrap the `VStack` in a `NavigationLink`:

```swift
ForEach(day.exercises.filter(\.isTest)) { exercise in
    NavigationLink(value: HistoryDestination.exerciseSession(
        exerciseId: exercise.id,
        sessionDate: day.id
    )) {
        VStack(alignment: .leading, spacing: 4) {
            // ... existing content unchanged
        }
    }
    .padding(.vertical, 4)
}
```

- [ ] **Step 3: Build and confirm it compiles**

Build the `inch` scheme (⌘B). Expect no errors.

- [ ] **Step 4: Manual end-to-end test in Simulator**

Run on iPhone 16 Pro simulator. The spec provides these verification steps:

1. Complete an exercise fully → open History → tap that session → confirm sets are shown → tap Delete → confirm exercise reappears as due (progress rolled back).
2. Partially complete an exercise (quit mid-session) → open History → tap the partial session → confirm greyed-out incomplete sets are shown → delete → confirm no resume prompt on next open.
3. Delete the only session for an exercise → confirm enrolment resets to Level 1 Day 1.
4. Delete a test-day session that caused a level advance → confirm level reverts.

- [ ] **Step 5: Commit**

```bash
git add inch/inch/Features/History/DayGroupRow.swift
git commit -m "feat: make exercise rows in DayGroupRow navigable to session detail"
```

---

## Done

All four tasks complete. The feature is fully wired: History → expand day → tap exercise → `ExerciseSessionDetailView` → delete with rollback.
