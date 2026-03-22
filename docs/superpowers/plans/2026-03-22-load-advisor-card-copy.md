# Load Advisor Card Copy Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hardcoded one-liner below the Today session progress bar with advisory-driven copy that reflects taper, overloaded muscle groups, lookback penalty, and remaining budget headroom.

**Architecture:** Copy derivation lives in a new `LoadAdvisoryCopy` type in the Shared package (pure, testable, no SwiftUI dependency). `TodaySessionBanner` gains an `advisory: LoadAdvisory?` parameter and calls `LoadAdvisoryCopy.copy(completedCount:advisory:)`. `TodayView` passes `viewModel.advisory` through. Nothing else changes.

> **Spec deviation:** The spec says "This mapping lives inline in `TodaySessionBanner` — no new type needed." This plan intentionally departs from that: there is no iOS test target, so keeping the logic in the view makes it untestable. Extracting to `LoadAdvisoryCopy` in the Shared package is the minimal change that preserves testability without introducing a test host target.

**Tech Stack:** Swift 6.2, Swift Testing, InchShared package

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `Shared/Sources/InchShared/Engine/LoadAdvisoryCopy.swift` | **Create** | Pure copy derivation — priority logic, all copy strings |
| `Shared/Tests/InchSharedTests/Engine/LoadAdvisoryCopyTests.swift` | **Create** | All copy cases: nil fallback, taper (×3), overload (×6), lookback, count defaults (×3) |
| `inch/inch/Features/Today/TodaySessionBanner.swift` | **Modify** | Add `advisory` param, call `LoadAdvisoryCopy.copy`, update accessibility label, update preview |
| `inch/inch/Features/Today/TodayView.swift` | **Modify** | Pass `advisory: viewModel.advisory` to `TodaySessionBanner` |

---

## Task 1: LoadAdvisoryCopy — pure copy logic in Shared

**Files:**
- Create: `Shared/Sources/InchShared/Engine/LoadAdvisoryCopy.swift`
- Create: `Shared/Tests/InchSharedTests/Engine/LoadAdvisoryCopyTests.swift`

The copy derivation is pure: given `completedCount: Int` and `advisory: LoadAdvisory?`, return a `String`. It has no SwiftUI dependency and belongs in the Shared package where it can be tested with `swift test`.

### Copy priority (from spec)

1. **advisory is nil** → hardcoded fallback (switch on completedCount)
2. **preTestTaperActive** → taper message (3 sub-cases on `recommendedCount - completedCount`)
3. **overloadedGroups non-empty** → first group's muscle copy
4. **lookbackPenaltyActive** → lookback message
5. **count-based default** → remaining headroom (3 sub-cases)

- [ ] **Step 1: Write the failing tests**

Create `Shared/Tests/InchSharedTests/Engine/LoadAdvisoryCopyTests.swift`:

```swift
import Testing
import Foundation
@testable import InchShared

struct LoadAdvisoryCopyTests {

    // MARK: - Nil fallback

    @Test(.tags(.loadAdvisor))
    func nilAdvisoryCompletedOneReturnsFallback() {
        let copy = LoadAdvisoryCopy.copy(completedCount: 1, advisory: nil)
        #expect(copy == "Good start — keep going if you feel up to it.")
    }

    @Test(.tags(.loadAdvisor))
    func nilAdvisoryCompletedTwoReturnsFallback() {
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: nil)
        #expect(copy == "Building momentum — listen to your body.")
    }

    @Test(.tags(.loadAdvisor))
    func nilAdvisoryCompletedThreeOrMoreReturnsFallback() {
        let copy = LoadAdvisoryCopy.copy(completedCount: 3, advisory: nil)
        #expect(copy == "Solid session — the rest are optional.")
    }

    // MARK: - Taper

    @Test(.tags(.loadAdvisor))
    func taperWithNoRemainingReturnsGoodPlaceToStop() throws {
        let advisory = makeAdvisory(recommendedCount: 2, preTestTaperActive: true)
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == "Test day tomorrow — good place to stop.")
    }

    @Test(.tags(.loadAdvisor))
    func taperWithNegativeRemainingReturnsGoodPlaceToStop() throws {
        // completedCount exceeded recommendedCount
        let advisory = makeAdvisory(recommendedCount: 2, preTestTaperActive: true)
        let copy = LoadAdvisoryCopy.copy(completedCount: 3, advisory: advisory)
        #expect(copy == "Test day tomorrow — good place to stop.")
    }

    @Test(.tags(.loadAdvisor))
    func taperWithOneRemainingReturnsOnMoreIsFine() throws {
        let advisory = makeAdvisory(recommendedCount: 3, preTestTaperActive: true)
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == "One more is fine — test day tomorrow.")
    }

    @Test(.tags(.loadAdvisor))
    func taperWithTwoOrMoreRemainingReturnsKeepLight() throws {
        let advisory = makeAdvisory(recommendedCount: 4, preTestTaperActive: true)
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == "Test day tomorrow — keep today light.")
    }

    // MARK: - Taper takes priority over overload and lookback

    @Test(.tags(.loadAdvisor))
    func taperTakesPriorityOverOverloadedGroups() throws {
        let advisory = makeAdvisory(
            recommendedCount: 2,
            overloadedGroups: [.lower],
            preTestTaperActive: true
        )
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == "Test day tomorrow — good place to stop.")
    }

    @Test(.tags(.loadAdvisor))
    func taperTakesPriorityOverLookback() throws {
        let advisory = makeAdvisory(
            recommendedCount: 2,
            preTestTaperActive: true,
            lookbackPenaltyActive: true
        )
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == "Test day tomorrow — good place to stop.")
    }

    // MARK: - Overloaded groups (all six MuscleGroup cases)

    @Test(.tags(.loadAdvisor), arguments: [
        (MuscleGroup.lower,          "Your lower body is carrying a lot today."),
        (MuscleGroup.lowerPosterior, "Your posterior chain is carrying a lot today."),
        (MuscleGroup.upperPush,      "Your pushing muscles are carrying a lot today."),
        (MuscleGroup.upperPull,      "Your pulling muscles are carrying a lot today."),
        (MuscleGroup.coreFlexion,    "Your core is carrying a lot today."),
        (MuscleGroup.coreStability,  "Your core is carrying a lot today."),
    ])
    func overloadedGroupCopy(group: MuscleGroup, expected: String) throws {
        let advisory = makeAdvisory(recommendedCount: 1, overloadedGroups: [group])
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == expected)
    }

    // MARK: - Overloaded takes priority over lookback

    @Test(.tags(.loadAdvisor))
    func overloadedTakesPriorityOverLookback() throws {
        let advisory = makeAdvisory(
            recommendedCount: 1,
            overloadedGroups: [.lower],
            lookbackPenaltyActive: true
        )
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == "Your lower body is carrying a lot today.")
    }

    // MARK: - Lookback

    @Test(.tags(.loadAdvisor))
    func lookbackPenaltyReturnsHeavySessionCopy() throws {
        let advisory = makeAdvisory(recommendedCount: 3, lookbackPenaltyActive: true)
        let copy = LoadAdvisoryCopy.copy(completedCount: 1, advisory: advisory)
        #expect(copy == "Heavy session yesterday — take it easy today.")
    }

    // MARK: - Count-based defaults

    @Test(.tags(.loadAdvisor))
    func countDefaultHitRecommendedLoad() throws {
        let advisory = makeAdvisory(recommendedCount: 2)
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == "You've hit today's recommended load.")
    }

    @Test(.tags(.loadAdvisor))
    func countDefaultOneMoreWithinBudget() throws {
        let advisory = makeAdvisory(recommendedCount: 3)
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == "One more is within your budget.")
    }

    @Test(.tags(.loadAdvisor))
    func countDefaultPlentyOfRoom() throws {
        let advisory = makeAdvisory(recommendedCount: 4)
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: advisory)
        #expect(copy == "Plenty of room to keep going.")
    }

    // MARK: - Sort order: first rawValue-sorted group wins
    // The advisor returns overloadedGroups sorted by rawValue string (e.g. "core_flexion" < "lower").
    // LoadAdvisoryCopy relies on this contract and uses .first without re-sorting.

    @Test(.tags(.loadAdvisor))
    func firstRawValueSortedGroupWinsWhenMultipleOverloaded() throws {
        // Advisor sorts by rawValue: "core_flexion" < "lower", so coreFlexion is first
        let advisory = makeAdvisory(
            recommendedCount: 1,
            overloadedGroups: [.lower, .coreFlexion] // would be [.coreFlexion, .lower] after advisor sort
        )
        // Pass already-sorted order as the advisor would produce it
        let sortedAdvisory = makeAdvisory(
            recommendedCount: 1,
            overloadedGroups: [.coreFlexion, .lower]
        )
        let copy = LoadAdvisoryCopy.copy(completedCount: 2, advisory: sortedAdvisory)
        #expect(copy == "Your core is carrying a lot today.")
    }

    // MARK: - Helpers

    private func makeAdvisory(
        recommendedCount: Int,
        overloadedGroups: [MuscleGroup] = [],
        cautionGroups: [MuscleGroup] = [],
        preTestTaperActive: Bool = false,
        lookbackPenaltyActive: Bool = false,
        budgetFraction: Double = 0.5
    ) -> LoadAdvisory {
        LoadAdvisory(
            recommendedCount: recommendedCount,
            overloadedGroups: overloadedGroups,
            cautionGroups: cautionGroups,
            preTestTaperActive: preTestTaperActive,
            lookbackPenaltyActive: lookbackPenaltyActive,
            budgetFraction: budgetFraction
        )
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd Shared && swift test --filter LoadAdvisoryCopyTests 2>&1 | tail -5
```

Expected: compile error — `LoadAdvisoryCopy` does not exist yet.

- [ ] **Step 3: Create LoadAdvisoryCopy.swift**

Create `Shared/Sources/InchShared/Engine/LoadAdvisoryCopy.swift`:

```swift
import Foundation

/// Derives the one-line copy string for the Today session card based on advisory signals.
/// Priority: taper → overloaded group → lookback → count-based default → nil fallback.
public enum LoadAdvisoryCopy {

    /// Returns the advisory copy string for display below the session progress bar.
    /// - Parameters:
    ///   - completedCount: Number of fully-completed exercises today (from the banner's own param).
    ///   - advisory: The load advisor output. Nil until the first exercise is completed.
    public static func copy(completedCount: Int, advisory: LoadAdvisory?) -> String {
        guard let advisory else {
            return fallbackCopy(completedCount: completedCount)
        }

        let remaining = advisory.recommendedCount - completedCount

        // 1. Test day taper — most time-sensitive signal
        if advisory.preTestTaperActive {
            if remaining <= 0 {
                return "Test day tomorrow — good place to stop."
            } else if remaining == 1 {
                return "One more is fine — test day tomorrow."
            } else {
                return "Test day tomorrow — keep today light."
            }
        }

        // 2. Overloaded muscle group — specific recovery call-out
        if let group = advisory.overloadedGroups.first {
            return overloadCopy(for: group)
        }

        // 3. Lookback penalty — yesterday was heavy
        if advisory.lookbackPenaltyActive {
            return "Heavy session yesterday — take it easy today."
        }

        // 4. Count-based default — neutral headroom guidance
        if remaining <= 0 {
            return "You've hit today's recommended load."
        } else if remaining == 1 {
            return "One more is within your budget."
        } else {
            return "Plenty of room to keep going."
        }
    }

    // MARK: - Private

    private static func fallbackCopy(completedCount: Int) -> String {
        switch completedCount {
        case 1:  return "Good start — keep going if you feel up to it."
        case 2:  return "Building momentum — listen to your body."
        default: return "Solid session — the rest are optional."
        }
    }

    private static func overloadCopy(for group: MuscleGroup) -> String {
        switch group {
        case .lower:          return "Your lower body is carrying a lot today."
        case .lowerPosterior: return "Your posterior chain is carrying a lot today."
        case .upperPush:      return "Your pushing muscles are carrying a lot today."
        case .upperPull:      return "Your pulling muscles are carrying a lot today."
        case .coreFlexion:    return "Your core is carrying a lot today."
        case .coreStability:  return "Your core is carrying a lot today."
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd Shared && swift test --filter LoadAdvisoryCopyTests 2>&1 | tail -5
```

Expected: `Test run with 21 tests passed`

- [ ] **Step 5: Run full suite to confirm no regressions**

```bash
cd Shared && swift test 2>&1 | tail -5
```

Expected: all tests pass (60 + 21 = 81 tests)

- [ ] **Step 6: Commit**

```bash
git add Shared/Sources/InchShared/Engine/LoadAdvisoryCopy.swift \
        Shared/Tests/InchSharedTests/Engine/LoadAdvisoryCopyTests.swift
git commit -m "feat: add LoadAdvisoryCopy — advisory-driven session card copy"
```

---

## Task 2: Wire advisory into TodaySessionBanner and TodayView

**Files:**
- Modify: `inch/inch/Features/Today/TodaySessionBanner.swift`
- Modify: `inch/inch/Features/Today/TodayView.swift`

### What changes in TodaySessionBanner

1. Add `let advisory: LoadAdvisory?` parameter (add after `totalCount`, default to `nil` so existing callers compile without changes during the edit)
2. Replace `progressCopy` computed var with a call to `LoadAdvisoryCopy.copy(completedCount:advisory:)`
3. In `sessionProgressCard`, rename the usage from `progressCopy` → `advisoryCopy` (two spots: the `Text` and the `.accessibilityLabel`)
4. Add `import InchShared` at the top of the file — the current file only imports SwiftUI, so this line must be added
5. Update the `#Preview` to exercise one advisory state

### What changes in TodayView

Pass `advisory: viewModel.advisory` to `TodaySessionBanner`.

- [ ] **Step 1: Update TodaySessionBanner**

Open `inch/inch/Features/Today/TodaySessionBanner.swift`. The current file is 81 lines. Apply these changes:

**a) Add the advisory parameter** (after `totalCount: Int`):
```swift
let advisory: LoadAdvisory?
```

**b) Replace `progressCopy`** with `advisoryCopy`:
```swift
private var advisoryCopy: String {
    LoadAdvisoryCopy.copy(completedCount: completedCount, advisory: advisory)
}
```

Delete the entire old `progressCopy` computed var.

**c) In `sessionProgressCard`, replace both uses of `progressCopy` with `advisoryCopy`:**

Line 61: `Text(progressCopy)` → `Text(advisoryCopy)`
Line 68: `.accessibilityLabel("Today's session: \(completedCount) of \(totalCount) done. \(progressCopy)")` → `.accessibilityLabel("Today's session: \(completedCount) of \(totalCount) done. \(advisoryCopy)")`

**d) Update the `#Preview`** to show advisory state. Replace the existing preview with:

```swift
#Preview("No advisory") {
    TodaySessionBanner(streak: 3, completedCount: 1, totalCount: 4, advisory: nil)
        .padding()
}

#Preview("Taper — stop here") {
    TodaySessionBanner(
        streak: 3,
        completedCount: 2,
        totalCount: 4,
        advisory: LoadAdvisory(
            recommendedCount: 2,
            overloadedGroups: [],
            cautionGroups: [],
            preTestTaperActive: true,
            lookbackPenaltyActive: false,
            budgetFraction: 0.7
        )
    )
    .padding()
}

#Preview("Lower body overloaded") {
    TodaySessionBanner(
        streak: 3,
        completedCount: 2,
        totalCount: 4,
        advisory: LoadAdvisory(
            recommendedCount: 3,
            overloadedGroups: [.lower],
            cautionGroups: [.lowerPosterior],
            preTestTaperActive: false,
            lookbackPenaltyActive: false,
            budgetFraction: 0.85
        )
    )
    .padding()
}
```

The complete updated file should look like:

```swift
import SwiftUI
import InchShared

/// Shown at the top of the Today exercise list.
/// - Before any exercise is done: a compact streak + availability line (D-style).
/// - After the first exercise: a segmented progress card (E-style).
struct TodaySessionBanner: View {
    let streak: Int
    let completedCount: Int
    let totalCount: Int
    let advisory: LoadAdvisory?

    var body: some View {
        if completedCount == 0 {
            if streak > 0 {
                streakAvailabilityBanner
            }
            // streak == 0 && completedCount == 0 → show nothing
        } else {
            sessionProgressCard
        }
    }

    // MARK: - D-style

    private var streakAvailabilityBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            Text("\(streak)-day streak · \(totalCount) exercise\(totalCount == 1 ? "" : "s") available")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(streak)-day streak. \(totalCount) exercise\(totalCount == 1 ? "" : "s") available today.")
    }

    // MARK: - E-style

    private var sessionProgressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today's session")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(completedCount) of \(totalCount) done")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                ForEach(0..<totalCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index < completedCount ? Color.accentColor : Color(.systemFill))
                        .frame(height: 5)
                }
            }

            Text(advisoryCopy)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's session: \(completedCount) of \(totalCount) done. \(advisoryCopy)")
    }

    private var advisoryCopy: String {
        LoadAdvisoryCopy.copy(completedCount: completedCount, advisory: advisory)
    }
}

#Preview("No advisory") {
    TodaySessionBanner(streak: 3, completedCount: 1, totalCount: 4, advisory: nil)
        .padding()
}

#Preview("Taper — stop here") {
    TodaySessionBanner(
        streak: 3,
        completedCount: 2,
        totalCount: 4,
        advisory: LoadAdvisory(
            recommendedCount: 2,
            overloadedGroups: [],
            cautionGroups: [],
            preTestTaperActive: true,
            lookbackPenaltyActive: false,
            budgetFraction: 0.7
        )
    )
    .padding()
}

#Preview("Lower body overloaded") {
    TodaySessionBanner(
        streak: 3,
        completedCount: 2,
        totalCount: 4,
        advisory: LoadAdvisory(
            recommendedCount: 3,
            overloadedGroups: [.lower],
            cautionGroups: [.lowerPosterior],
            preTestTaperActive: false,
            lookbackPenaltyActive: false,
            budgetFraction: 0.85
        )
    )
    .padding()
}
```

- [ ] **Step 2: Update TodayView**

In `inch/inch/Features/Today/TodayView.swift`, find the `TodaySessionBanner(...)` call (around line 73) and add the advisory parameter:

```swift
TodaySessionBanner(
    streak: streak,
    completedCount: completedTodayCount,
    totalCount: viewModel.dueExercises.count,
    advisory: viewModel.advisory
)
```

- [ ] **Step 3: Build to verify it compiles**

Run from the worktree root (the directory containing the `inch/` folder):

```bash
xcodebuild \
  -project inch/inch.xcodeproj \
  -scheme inch \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Alternatively, open Xcode and do Product → Build (⌘B). Expected: BUILD SUCCEEDED with no errors.

- [ ] **Step 4: Run Shared tests to confirm no regressions**

```bash
cd Shared && swift test 2>&1 | tail -5
```

Expected: all 81 tests pass.

- [ ] **Step 5: Commit**

```bash
git add inch/inch/Features/Today/TodaySessionBanner.swift \
        inch/inch/Features/Today/TodayView.swift
git commit -m "feat: wire LoadAdvisory into TodaySessionBanner copy"
```
