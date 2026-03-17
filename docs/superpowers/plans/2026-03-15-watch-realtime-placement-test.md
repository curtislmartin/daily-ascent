# WatchRealTimeCountingView + PlacementTestView Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add tap-to-count rep tracking on the Watch for real-time-mode exercises, and add a level placement screen to onboarding so experienced users can start at the right level.

**Architecture:** The Watch feature branches in `WatchWorkoutView` on `session.countingMode`; for `real_time`, shows `WatchRealTimeCountingView` during `.inSet` and stores the count in the view model before transitioning to the existing `WatchPostSetView`. The onboarding feature inserts a `PlacementTestView` step between exercise selection and data consent, driven by new `levelChoices` state on `EnrolmentViewModel`.

**Tech Stack:** Swift 6.2, SwiftUI, SwiftData, watchOS 10+, `sensoryFeedback`, `digitalCrownRotation`

**Skills:** @swiftui-pro for all views, @swiftdata-pro for EnrolmentViewModel/saveEnrolments, @swift-testing-pro for any tests

---

## File Map

### Chunk 1 — WatchRealTimeCountingView

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `inch/inchwatch Watch App/Features/WatchRealTimeCountingView.swift` | Tap-to-count UI, Digital Crown adjustment, haptics, Done callback |
| Modify | `inch/inchwatch Watch App/Features/WatchWorkoutViewModel.swift` | Add `pendingRealTimeCount: Int?`, add `endSetRealTime(count:)` |
| Modify | `inch/inchwatch Watch App/Features/WatchWorkoutView.swift` | Branch on countingMode in `.inSet`; pass `pendingRealTimeCount` to WatchPostSetView |
| Modify | `inch/inchwatch Watch App/Features/WatchPostSetView.swift` | Accept `initialReps: Int` parameter instead of always defaulting to `targetReps` |

### Chunk 2 — PlacementTestView

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `inch/inch/Features/Onboarding/EnrolmentViewModel.swift` | Add `levelChoices: [String: Int]`, update `saveEnrolments()`, add `recommendLevel(score:testTargets:)` |
| Create | `inch/inch/Features/Onboarding/PlacementTestView.swift` | Scrollable screen listing one card per selected exercise, Continue button |
| Create | `inch/inch/Features/Onboarding/PlacementExerciseCard.swift` | Expandable card: Level 1 default, self-select picker, inline placement test |
| Modify | `inch/inch/Features/Onboarding/OnboardingCoordinatorView.swift` | Add `.placement` step between `.enrolment` and `.consent` |

---

## Chunk 1: WatchRealTimeCountingView

### Task 1: Update WatchPostSetView to accept `initialReps`

**Files:**
- Modify: `inch/inchwatch Watch App/Features/WatchPostSetView.swift`

WatchPostSetView currently always seeds `actualReps` from `targetReps`. Real-time counting needs to pre-fill the known count. Add an `initialReps` parameter; default it to `targetReps` so all existing call sites still compile.

- [ ] **Step 1: Update WatchPostSetView**

Replace the init with:

```swift
init(targetReps: Int, initialReps: Int? = nil, onConfirm: @escaping (Int) -> Void) {
    self.targetReps = targetReps
    self.onConfirm = onConfirm
    _actualReps = State(initialValue: initialReps ?? targetReps)
}
```

Add the stored property `let initialReps: Int?` is not needed — the `_actualReps` State init above captures it. The public interface stays:

```swift
struct WatchPostSetView: View {
    let targetReps: Int
    let onConfirm: (Int) -> Void

    @State private var actualReps: Int

    init(targetReps: Int, initialReps: Int? = nil, onConfirm: @escaping (Int) -> Void) {
        self.targetReps = targetReps
        self.onConfirm = onConfirm
        _actualReps = State(initialValue: initialReps ?? targetReps)
    }
    // ... body unchanged
}
```

- [ ] **Step 2: Verify existing call site still compiles**

The existing call in WatchWorkoutView is:
```swift
WatchPostSetView(targetReps: targetReps) { actual in ... }
```
This still works because `initialReps` has a default.

- [ ] **Step 3: Commit**
```bash
git add "inch/inchwatch Watch App/Features/WatchPostSetView.swift"
git commit -m "feat: add initialReps parameter to WatchPostSetView"
```

---

### Task 2: Update WatchWorkoutViewModel

**Files:**
- Modify: `inch/inchwatch Watch App/Features/WatchWorkoutViewModel.swift`

Add `pendingRealTimeCount` so WatchWorkoutView can pass the live count into WatchPostSetView after calling `endSet()`.

- [ ] **Step 1: Add the property and method**

```swift
// Add to WatchWorkoutViewModel:
private(set) var pendingRealTimeCount: Int? = nil

func endSetRealTime(count: Int) {
    pendingRealTimeCount = count
    endSet()
}

func clearPendingRealTimeCount() {
    pendingRealTimeCount = nil
}
```

- [ ] **Step 2: Commit**
```bash
git add "inch/inchwatch Watch App/Features/WatchWorkoutViewModel.swift"
git commit -m "feat: add endSetRealTime to WatchWorkoutViewModel"
```

---

### Task 3: Create WatchRealTimeCountingView

**Files:**
- Create: `inch/inchwatch Watch App/Features/WatchRealTimeCountingView.swift`

UI: set progress header (caption), large rep count, small target, tap button, Done button. Digital Crown adjusts count. Haptic on each rep tap.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

struct WatchRealTimeCountingView: View {
    let targetReps: Int
    let setNumber: Int
    let totalSets: Int
    let onComplete: (Int) -> Void

    @State private var count: Int = 0
    @State private var crownValue: Double = 0

    var body: some View {
        VStack(spacing: 6) {
            Text("Set \(setNumber) of \(totalSets)")
                .font(.caption)
                .foregroundStyle(.secondary)

            progressDots

            Spacer()

            Text("\(count)")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            Text("/ \(targetReps) target")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                tapRep()
            } label: {
                Text("Tap to Count")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            if count > 0 {
                Button("Done — \(count) reps") {
                    onComplete(count)
                }
                .buttonStyle(.bordered)
                .font(.caption)
            }
        }
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
            if clamped != count { count = clamped }
        }
    }

    private func tapRep() {
        count += 1
        crownValue = Double(count)
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

- [ ] **Step 2: Commit**
```bash
git add "inch/inchwatch Watch App/Features/WatchRealTimeCountingView.swift"
git commit -m "feat: add WatchRealTimeCountingView with tap counting and Crown adjustment"
```

---

### Task 4: Wire WatchRealTimeCountingView into WatchWorkoutView

**Files:**
- Modify: `inch/inchwatch Watch App/Features/WatchWorkoutView.swift`

In the `.inSet` case, check `session.countingMode`. For `"real_time"`, show `WatchRealTimeCountingView`; otherwise keep the existing timer view. Update the `.confirming` case to pass `viewModel.pendingRealTimeCount` and clear it after confirm.

- [ ] **Step 1: Replace the .inSet and .confirming cases**

Current `.inSet` branch:
```swift
case .inSet:
    inSetView
```

Replace with:
```swift
case .inSet:
    if session.countingMode == "real_time" {
        WatchRealTimeCountingView(
            targetReps: viewModel.targetReps,
            setNumber: viewModel.currentSet,
            totalSets: viewModel.totalSets
        ) { count in
            viewModel.endSetRealTime(count: count)
        }
    } else {
        inSetView
    }
```

Current `.confirming` case:
```swift
case .confirming(let targetReps, _):
    WatchPostSetView(targetReps: targetReps) { actual in
        viewModel.confirmSet(actual: actual)
    }
```

Replace with:
```swift
case .confirming(let targetReps, _):
    WatchPostSetView(
        targetReps: targetReps,
        initialReps: viewModel.pendingRealTimeCount
    ) { actual in
        viewModel.clearPendingRealTimeCount()
        viewModel.confirmSet(actual: actual)
    }
```

- [ ] **Step 2: Build the watch target and verify it compiles**

```bash
xcodebuild -project inch/inch.xcodeproj \
  -scheme "inchwatch Watch App" \
  -destination "platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)" \
  -configuration Debug build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**
```bash
git add "inch/inchwatch Watch App/Features/WatchWorkoutView.swift"
git commit -m "feat: show WatchRealTimeCountingView for real_time exercises on Watch"
```

---

## Chunk 2: PlacementTestView

### Task 5: Update EnrolmentViewModel

**Files:**
- Modify: `inch/inch/Features/Onboarding/EnrolmentViewModel.swift`

Add `levelChoices`, the recommendation function, and update `saveEnrolments()` to apply choices.

- [ ] **Step 1: Add levelChoices and recommendLevel**

```swift
// Add to EnrolmentViewModel:
var levelChoices: [String: Int] = [:]

/// Pure function — given sorted test targets [L1target, L2target] and a score,
/// returns recommended level 1, 2, or 3.
/// testTargets must have at least 2 entries (targets for L1 and L2).
static func recommendLevel(score: Int, testTargets: [Int]) -> Int {
    guard testTargets.count >= 2 else { return 1 }
    if score < testTargets[0] { return 1 }
    if score < testTargets[1] { return 2 }
    return 3
}
```

- [ ] **Step 2: Update saveEnrolments() to apply level choices**

Current `saveEnrolments()`:
```swift
let enrolment = ExerciseEnrolment(enrolledAt: startDate)
enrolment.exerciseDefinition = definition
enrolment.nextScheduledDate = startDate
context.insert(enrolment)
```

Replace with:
```swift
let chosenLevel = levelChoices[definition.exerciseId] ?? 1
let enrolment = ExerciseEnrolment(enrolledAt: startDate, currentLevel: chosenLevel)
enrolment.exerciseDefinition = definition
enrolment.nextScheduledDate = startDate
context.insert(enrolment)
```

- [ ] **Step 3: Commit**
```bash
git add inch/inch/Features/Onboarding/EnrolmentViewModel.swift
git commit -m "feat: add levelChoices and recommendLevel to EnrolmentViewModel"
```

---

### Task 6: Create PlacementExerciseCard

**Files:**
- Create: `inch/inch/Features/Onboarding/PlacementExerciseCard.swift`

Self-contained expandable card. Owns its expansion state locally. Writes back to `viewModel.levelChoices` on any level change.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI
import InchShared

struct PlacementExerciseCard: View {
    let definition: ExerciseDefinition
    @Bindable var viewModel: EnrolmentViewModel

    @State private var isExpanded = false
    @State private var testRepCount: Int = 0
    @State private var showingTestResult = false

    private var chosenLevel: Int {
        viewModel.levelChoices[definition.exerciseId] ?? 1
    }

    private var sortedLevels: [LevelDefinition] {
        (definition.levels ?? []).sorted { $0.level < $1.level }
    }

    private var accentColor: Color {
        Color(hex: definition.color) ?? .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row — always visible
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 10, height: 10)
                    Text(definition.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(chosenLevel == 1 ? "Level 1" : "Level \(chosenLevel)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding()

            if isExpanded {
                Divider()
                VStack(alignment: .leading, spacing: 16) {
                    levelPicker
                    Divider()
                    placementTestSection
                }
                .padding()
            }
        }
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Self-select level picker

    private var levelPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose a starting level")
                .font(.subheadline)
                .fontWeight(.medium)
            ForEach(sortedLevels, id: \.level) { levelDef in
                levelRow(for: levelDef)
            }
        }
    }

    private func levelRow(for levelDef: LevelDefinition) -> some View {
        let day1Sets = (levelDef.days ?? [])
            .sorted { $0.dayNumber < $1.dayNumber }
            .first?.sets ?? []
        let setsFormatted = day1Sets.map { "\($0)" }.joined(separator: ", ")
        let isChosen = chosenLevel == levelDef.level

        return Button {
            viewModel.levelChoices[definition.exerciseId] = levelDef.level
        } label: {
            HStack(alignment: .top) {
                Image(systemName: isChosen ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChosen ? accentColor : .secondary)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Level \(levelDef.level)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    if !setsFormatted.isEmpty {
                        Text("Day 1: \(setsFormatted) reps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("Test target: \(levelDef.testTarget) reps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }

    // MARK: - Placement test

    private var placementTestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Or take a placement test")
                .font(.subheadline)
                .fontWeight(.medium)

            Text("Do as many \(definition.name) as you can in one set, then enter your count below.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Text("Reps completed:")
                    .font(.subheadline)
                Spacer()
                Stepper("\(testRepCount)", value: $testRepCount, in: 0...999)
                    .labelsHidden()
                    .frame(width: 120)
                Text("\(testRepCount)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .frame(width: 36, alignment: .trailing)
            }

            if testRepCount > 0 {
                recommendationView
            }
        }
    }

    private var recommendationView: some View {
        let targets = sortedLevels.map { $0.testTarget }
        let recommended = EnrolmentViewModel.recommendLevel(score: testRepCount, testTargets: targets)
        let isApplied = chosenLevel == recommended

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                Text("We recommend Level \(recommended)")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            if !isApplied {
                Button("Start at Level \(recommended)") {
                    viewModel.levelChoices[definition.exerciseId] = recommended
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Text("Applied ✓")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
```

- [ ] **Step 2: Commit**
```bash
git add inch/inch/Features/Onboarding/PlacementExerciseCard.swift
git commit -m "feat: add PlacementExerciseCard with self-select and placement test"
```

---

### Task 7: Create PlacementTestView

**Files:**
- Create: `inch/inch/Features/Onboarding/PlacementTestView.swift`

Top-level screen. Receives the full list of `ExerciseDefinition`s and filters to selected ones. "Continue" always enabled.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI
import SwiftData
import InchShared

struct PlacementTestView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var definitions: [ExerciseDefinition]

    @Bindable var viewModel: EnrolmentViewModel
    var onContinue: () -> Void

    private var selectedDefinitions: [ExerciseDefinition] {
        definitions
            .filter { viewModel.selectedExerciseIds.contains($0.exerciseId) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("For each exercise, choose where to begin. You can adjust this any time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)

                    ForEach(selectedDefinitions, id: \.exerciseId) { definition in
                        PlacementExerciseCard(
                            definition: definition,
                            viewModel: viewModel
                        )
                    }

                    continueButton
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Starting Level")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var continueButton: some View {
        Button {
            onContinue()
        } label: {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 8)
    }
}
```

- [ ] **Step 2: Commit**
```bash
git add inch/inch/Features/Onboarding/PlacementTestView.swift
git commit -m "feat: add PlacementTestView onboarding screen"
```

---

### Task 8: Wire PlacementTestView into OnboardingCoordinatorView

**Files:**
- Modify: `inch/inch/Features/Onboarding/OnboardingCoordinatorView.swift`

Add `.placement` between `.enrolment` and `.consent`. Pass the `viewModel` through so level choices survive the step transition.

- [ ] **Step 1: Update OnboardingCoordinatorView**

```swift
import SwiftUI
import SwiftData
import InchShared

struct OnboardingCoordinatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var definitions: [ExerciseDefinition]

    @State private var step: Step = .enrolment
    @State private var viewModel = EnrolmentViewModel()

    private enum Step {
        case enrolment
        case placement
        case consent
    }

    var body: some View {
        Group {
            switch step {
            case .enrolment:
                EnrolmentView(viewModel: viewModel) {
                    step = .placement
                }
            case .placement:
                PlacementTestView(viewModel: viewModel) {
                    try? viewModel.saveEnrolments(from: definitions, context: modelContext)
                    step = .consent
                }
            case .consent:
                DataConsentView()
            }
        }
        .task {
            if definitions.isEmpty {
                let loader = ExerciseDataLoader()
                try? loader.seedIfNeeded(context: modelContext)
            }
        }
    }
}
```

Note: `saveEnrolments` moved from `EnrolmentView.saveAndContinue()` to `OnboardingCoordinatorView`. Update `EnrolmentView` so its button calls `onEnrolmentSaved()` directly (not `saveEnrolments` — remove the call to `viewModel.saveEnrolments` from `EnrolmentView.saveAndContinue()`).

- [ ] **Step 2: Update EnrolmentView.saveAndContinue()**

The existing `saveAndContinue()` in `EnrolmentView`:
```swift
private func saveAndContinue() {
    do {
        try viewModel.saveEnrolments(from: definitions, context: modelContext)
        onEnrolmentSaved()
    } catch {
        // Enrolment failure is non-recoverable in onboarding context
    }
}
```

Replace with:
```swift
private func saveAndContinue() {
    onEnrolmentSaved()
}
```

Also remove the `@Environment(\.modelContext)` and `@Query private var definitions` from `EnrolmentView` if they are no longer needed there (check — `definitions` is still needed for the exercise selection display via `viewModel.sections(from:)`, but `modelContext` is no longer needed for saving).

Check: `EnrolmentView` still needs `@Query private var definitions` for the exercise list — keep it. Remove only `@Environment(\.modelContext)`.

- [ ] **Step 3: Build iOS target and verify compiles**
```bash
xcodebuild -project inch/inch.xcodeproj \
  -scheme inch \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -configuration Debug build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**
```bash
git add inch/inch/Features/Onboarding/OnboardingCoordinatorView.swift \
        inch/inch/Features/Onboarding/EnrolmentView.swift
git commit -m "feat: wire PlacementTestView into onboarding flow"
```

---

### Task 9: Final build verification — both targets

- [ ] **Step 1: Build iOS**
```bash
xcodebuild -project inch/inch.xcodeproj \
  -scheme inch \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -configuration Debug build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 2: Build Watch**
```bash
xcodebuild -project inch/inch.xcodeproj \
  -scheme "inchwatch Watch App" \
  -destination "platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)" \
  -configuration Debug build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)"
```
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Final commit**
```bash
git add -A
git commit -m "feat: WatchRealTimeCountingView and PlacementTestView complete"
```
