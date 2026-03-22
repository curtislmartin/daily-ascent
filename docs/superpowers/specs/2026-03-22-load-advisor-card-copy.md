# Load Advisor Card Copy Design

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire `LoadAdvisory` into the `TodaySessionBanner` so the one-liner below the progress bar reflects real advisory signals instead of hardcoded copy.

**Architecture:** `TodaySessionBanner` gains an optional `advisory: LoadAdvisory?` parameter. A new `advisoryCopy` computed var derives the copy string from advisory signals in priority order. `TodayView` passes `viewModel.advisory` through. No other UI changes.

**Tech Stack:** SwiftUI, InchShared (LoadAdvisory, MuscleGroup)

---

## Scope

Only the copy line in the E-style session progress card changes. The card structure, progress bar, segment count, "n of m done" label, and all other layout elements remain exactly as they are.

The advisory is nil until the first exercise is completed, which is also when the E-style card appears — so fallback to the current hardcoded copy only occurs if this assumption ever breaks.

---

## Files

- **Modify:** `inch/inch/Features/Today/TodaySessionBanner.swift`
  - Add `advisory: LoadAdvisory?` parameter (optional, defaults to nil for backward compat)
  - Replace `progressCopy` with `advisoryCopy` that uses advisory when present, falls back to current copy otherwise
- **Modify:** `inch/inch/Features/Today/TodayView.swift`
  - Pass `viewModel.advisory` into `TodaySessionBanner`

---

## Copy Priority

When `advisory` is non-nil, `advisoryCopy` evaluates signals in this order and returns the first matching string:

### 1. Pre-test taper active

`advisory.preTestTaperActive == true`

The sub-message depends on remaining headroom. Use `advisory.recommendedCount - completedCount` to determine how much room is left. `completedCount` here is the same value passed into the banner (fully-completed exercises). The advisor's `recommendedCount` is derived from exercises that have any completed set, so the two counts are expected to agree in practice — both update after the same workout write-back.

| Condition | Copy |
|---|---|
| `advisory.recommendedCount - completedCount <= 0` | "Test day tomorrow — good place to stop." |
| `advisory.recommendedCount - completedCount == 1` | "One more is fine — test day tomorrow." |
| `advisory.recommendedCount - completedCount >= 2` | "Test day tomorrow — keep today light." |

When `completedCount` has already exceeded `recommendedCount` (remainder is negative), the `<= 0` row fires — "good place to stop" remains appropriate.

### 2. Overloaded muscle group

`advisory.overloadedGroups` is non-empty (taper not active)

Use the first group in `overloadedGroups`. The advisor sorts by `rawValue` alphabetically (`core_flexion` < `core_stability` < `lower` < `lower_posterior` < `upper_pull` < `upper_push`) — this is not a severity ordering, just a stable tie-breaker.

All six `MuscleGroup` cases must be covered:

| Group | Copy |
|---|---|
| `.lower` | "Your lower body is carrying a lot today." |
| `.lowerPosterior` | "Your posterior chain is carrying a lot today." |
| `.upperPush` | "Your pushing muscles are carrying a lot today." |
| `.upperPull` | "Your pulling muscles are carrying a lot today." |
| `.coreFlexion` | "Your core is carrying a lot today." |
| `.coreStability` | "Your core is carrying a lot today." |

### 3. Lookback penalty active

`advisory.lookbackPenaltyActive == true` (taper not active, no overloaded groups)

Copy: `"Heavy session yesterday — take it easy today."`

### 4. Count-based default

No warnings active. Use `recommendedCount - completedCount`:

| Remaining | Copy |
|---|---|
| `<= 0` | "You've hit today's recommended load." |
| `== 1` | "One more is within your budget." |
| `>= 2` | "Plenty of room to keep going." |

Note: the `<= 0` count-based message is only reached when no warning signals are active. When taper is active and `remaining <= 0`, the taper branch fires first and returns "Test day tomorrow — good place to stop" instead.

### Fallback (advisory == nil)

Return existing hardcoded copy unchanged:

```swift
switch completedCount {
case 1: "Good start — keep going if you feel up to it."
case 2: "Building momentum — listen to your body."
default: "Solid session — the rest are optional."
}
```

---

## MuscleGroup Display Names

`MuscleGroup` has six cases (raw values are snake_case strings). The copy uses plain English names. This mapping lives inline in `TodaySessionBanner` as a `switch` — no new type needed.

---

## Accessibility

The existing `.accessibilityLabel` on `sessionProgressCard` (line 68 of `TodaySessionBanner.swift`) interpolates `progressCopy` at the end of the string. Replace `\(progressCopy)` with `\(advisoryCopy)` so VoiceOver reads the advisory text.

## Previews and Tests

- Update the existing `#Preview` for `TodaySessionBanner` to exercise at least one advisory state (e.g. taper active) alongside the nil fallback.
- Add unit tests covering: nil advisory fallback, taper sub-messages (all three remaining counts), overloaded group copy for each MuscleGroup case, lookback copy, and count-based defaults.

---

## What Is Not In Scope

- No new UI elements (no chips, no load bar, no icons)
- No changes to the D-style streak banner
- No changes to `TodayViewModel`, `DailyLoadAdvisor`, or `LoadAdvisory`
- No display of `cautionGroups` or `budgetFraction` in this iteration
