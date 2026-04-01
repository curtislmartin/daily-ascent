# Rest Day Content — Design Spec

**Date:** 2026-03-31
**Status:** Draft
**App:** Daily Ascent (iOS + watchOS bodyweight training)

---

## Problem

The current `RestDayView` shows a moon icon, "Rest Day" heading, next-session count, and a streak card. Users who open the app on rest days see effectively nothing and leave. Research shows that consistent daily app opens — even for 30 seconds of passive content — are a stronger predictor of long-term program completion than workout quality. The rest day screen is the highest-leverage retention surface in the app.

---

## Goals

- Make rest days feel purposeful and part of the program, not a gap in it
- Give users a reason to open the app daily, even when not training
- Reinforce the streak safety message to reduce streak-break anxiety
- Require no new data models, no new services, and no network calls in Phase 1

## Non-Goals

- Guided video content (too heavyweight for Phase 1)
- Nutrition or sleep tracking
- Social comparison or community features
- Generic motivational quotes (research shows these erode trust over time)

---

## Design

### Phase 1 — Immediate Improvements (no new infrastructure)

These changes are purely presentation-layer and require no new data models or services.

#### 1. Rename "Rest Day" → "Recovery Day"

Change the screen title and all references. "Recovery Day" is active and purposeful — your muscles are doing something. "Rest Day" is passive and suggests nothing is happening. This is the single lowest-effort, highest-impact change.

#### 2. Upcoming Session Card (specific, not generic)

Replace the current "Next training: tomorrow — 4 exercises" with a card that shows:

```
Tomorrow
Push-Ups · L2 Day 8
Squats · L2 Day 12
```

Show exercise names, level, and day number — not just a count. This makes the next training day feel concrete and close rather than abstract.

**Data shape change required:** The current `TodayViewModel` exposes only `nextTrainingDate: Date?` and `nextTrainingCount: Int`. The Upcoming Session card requires a new computed property:

```swift
var nextTrainingDayExercises: [(exerciseName: String, level: Int, dayNumber: Int)] = []
```

This is populated in `loadToday()` by finding the nearest upcoming `nextTrainingDate` across all active enrolments, then returning all enrolments due on that date with their names, levels, and day numbers.

**Empty state:** If `nextTrainingDayExercises` is empty (all exercises completed or no active enrolments), the card shows: "All exercises complete — you've finished the program!" or "No exercises enrolled — add one in Settings."

**"Push Day" label:** The example header label is removed. The card header shows the date only: "Tomorrow", "In 2 days", or the formatted date for further dates. No muscle-group-derived label (this would require additional grouping logic not worth the complexity).

#### 3. Explicit Streak Safety Message

The current caption ("rest days are part of the program") is correct but visually weak and easy to miss. Replace with a dedicated message block:

> **Your \(streak)-day streak is safe.**
> Scheduled rest days protect your streak. You're on track.

Show the streak count prominently so the user doesn't have to scroll to verify it. This directly addresses the most common rest-day anxiety: "am I losing my streak right now?"

**Zero-streak state:** When `streak == 0` (user has never trained or streak was just reset), replace the streak safety message with:
> **Start your first streak today.**
> *(or "Your streak resets here — start again tomorrow." if training has occurred before)*

The streak card is never hidden — it always occupies this space. The message adapts to whether `streak == 0` and whether any `CompletedSet` records exist.

#### 4. Contextual Recovery Tip

One sentence, shown below the streak card, rotated daily from a curated set of ~10 science-grounded tips. No tap required — purely passive content.

The tip rotates based on `(Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 1) % tips.count` so it changes daily without any server call or randomisation that would differ between app opens on the same day. (`Calendar.current.dayOfYear` does not exist in Swift — `ordinality(of:in:for:)` is the correct API, returning `Int?`.)

Example tips:
- "Muscle protein synthesis peaks 24–48 hours after your last session. Your rest day is doing real work."
- "Light movement like a walk improves blood flow to recovering muscles without adding training stress."
- "Sleep is when most muscle repair happens. Prioritise 7–9 hours tonight."
- "Your nervous system recovers on rest days too — pushing through fatigue accumulates neural debt."
- "Consistent rest is what makes progressive overload work. The gains happen during recovery, not training."

Tips are stored as a static array in `RestDayView` — no new data model, no network call.

---

### Phase 2 — Enhanced Rest Day Content (requires new components)

These additions go beyond Phase 1 but require no new data models — only new view components.

#### 5. Level Progress Teaser

If any enrolled exercise is within 3 sessions of its max-rep test, show a teaser card:

> **Push-Up test in 3 sessions**
> Target: 50 reps · Keep going 💪

Derived from the existing `ExerciseEnrolment.currentDay` and level data. Motivates the user to return for the next training day without being pushy.

#### 6. Week-in-Review Card

Shown on rest days that fall on Saturday or Sunday (or the final rest day of a training week). Shows:

> **This week: 4 of 5 sessions complete**
> 312 reps across Push-Ups, Squats, Sit-Ups, Dead Bugs

Derived from existing `CompletedSet` data. Requires no new storage — just a query scoped to the current calendar week.

#### 7. Optional 5-Minute Mobility Flow

A structured on-screen mobility sequence (no video — text + static illustrations + timer) tailored to the last muscle group trained. The app knows which exercises were completed in the most recent training session and can surface a relevant sequence:

- After upper-body session (Push-Ups, Pull-Ups): chest opener, thoracic rotation, shoulder circles
- After lower-body session (Squats, Glute Bridges): hip flexor stretch, pigeon pose, quad stretch
- After core session (Sit-Ups, Dead Bugs): cat-cow, spinal twist, cobra

The flow is a new `MobilityFlowView` — a simple step-through sequence with a timer per pose. No external content, no video. Steps and durations are hardcoded per muscle group category.

This is shown as an optional CTA card ("Optional: 5-min recovery · Upper body") — never auto-started, never pushed as a notification.

---

## View Structure

### Updated `RestDayView`

```
RestDayView
├── Header: "Recovery Day" + moon icon
├── StreakCard (existing, updated copy)
│   └── Streak count (prominent)
│   └── "Your X-day streak is safe." message
├── UpcomingSessionCard (new — Phase 1)
│   └── Next training date + exercise list
├── RecoveryTipView (new — Phase 1)
│   └── Single rotating tip
├── LevelProgressTeaserCard (new — Phase 2, conditional)
├── WeekInReviewCard (new — Phase 2, conditional on weekend)
└── MobilityFlowCTACard (new — Phase 2, optional)
```

---

## Tone Guidelines

All rest day copy follows these rules:
- **Scientific framing over cheerleading.** "Muscle protein synthesis peaks 24–48 hours post-training" > "You're crushing it!"
- **Purposeful, not passive.** "Your recovery day is doing real work" > "Nothing scheduled today."
- **Low-key.** No exclamation points in recovery tips. No urgency.
- **Brief.** Body copy is 1–2 sentences maximum.
- **Never punish.** Nothing on this screen should create anxiety about rest or streaks.

---

## Watch Scope (Phase 1)

`WatchRestDayView` receives the updated streak safety message and next session exercise list. The streak value is already synced from iPhone — add the next-training-day exercise list to the `WatchConnectivity` payload. `WatchTodayView` calls `sendTodaySchedule()` on the iPhone side; extend the payload to include `nextTrainingDayExercises: [(exerciseName: String, level: Int, dayNumber: Int)]` alongside the existing session data. The Watch displays this list on the rest day screen.

## Phase 2 Clarifications

**Level Progress Teaser threshold:** "Within 3 sessions of test" means `testDayNumber - currentDay <= 3`. The test day is counted as one of the three (so the teaser appears on the rest day before day N-2, N-1, and N-3 relative to the test). Shown only once per level test — hidden after the test day passes.

**Week-in-Review rep count:** Sum `CompletedSet.actualReps` (not prescribed) for the week. For test days where users may exceed the prescription, actual reps is the correct value.

**Mobility Flow muscle group mapping:**
- Upper: Push-Ups, Pull-Ups → chest opener, thoracic rotation, shoulder circles
- Lower: Squats, Glute Bridges → hip flexor stretch, pigeon pose, quad stretch
- Core: Sit-Ups, Dead Bugs → cat-cow, spinal twist, cobra
- Mixed session (exercises from 2+ groups): show both sequences sequentially, or let the user pick. Default: show the group with the most exercises completed that session.

**Mobility Flow illustrations:** Text descriptions with timer only in v1. Illustrations (static images) are deferred to v2 — too much production work relative to the value at launch.

## Scope Boundaries

- Phase 1: no new `@Model` entities; `TodayViewModel` gains `nextTrainingDayExercises` computed property; WatchConnectivity payload extended for next-session list
- Phase 2 mobility flow: text + timer only, no illustrations, no video
- No push notifications specifically for rest day content
