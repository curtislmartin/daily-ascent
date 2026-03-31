# Exercise Form Guidance — Design Spec

**Date:** 2026-03-31
**Status:** Draft
**App:** Daily Ascent (iOS + watchOS bodyweight training)

---

## Problem

The app has no exercise education. New users encounter exercise names like "Dead Bug" and "Glute Bridge" with no explanation of what they are or how to perform them correctly. The first 72 hours are the highest-risk retention window; a user who can't start their first workout confidently is likely to quit.

---

## Goals

- Give every user the information they need to perform each exercise safely and correctly
- Surface education without blocking or delaying the first workout
- Work entirely offline with no third-party SDK dependencies

## Non-Goals

- Real-time form feedback (camera/ML — future v2 feature)
- Full instructional videos with narration (too heavyweight for in-workout use)
- Education for exercises not in the app's catalogue

---

## Design

### Three-Tier Progressive Disclosure

Education is layered so users who know the exercises are never slowed down, and users who don't always have a clear path to help.

#### Tier 1 — Exercise Detail Sheet (always available)

An `ExerciseInfoSheet` is accessible by tapping an info button (ⓘ) next to any exercise name — from `ExerciseCard` on the Today tab, from `WorkoutSessionView`, and from `ExerciseDetailView` in the Program tab.

Sheet contents:
1. Looping MP4 demo (3–8 seconds, muted, autoplays, loops)
2. Exercise name + target muscle tags (e.g. "Chest · Triceps · Core")
3. **How to do it** — 3 bullet points: setup position, the movement, key focus cue
4. **Common mistake** — 1 bullet
5. **Level tip** — context-sensitive note for the user's current level (e.g. "At Level 2 you'll be performing wider sets — focus on a full range of motion")

This sheet is non-blocking. The user can dismiss it at any time and return to their workout.

#### Tier 2 — First-Occurrence Nudge

The first time a user encounters an exercise in a workout session, a subtle inline prompt appears below the exercise name on `WorkoutSessionView` (the pre-set ready screen, before the first set begins):

> "First time doing Dead Bug? Tap ⓘ to see how."

**Dismissal:** The nudge is dismissed — and permanently hidden for that exercise — when any of the following occurs:
- The user taps the ⓘ button
- The user taps a dedicated ✕ on the nudge banner
- The user taps "Start Set" (the nudge disappears and is not shown again for this exercise)

The `exerciseId` is written to `seenExerciseInfo` on any of these events. The nudge is not shown once a set is in progress.

**Re-enrolment:** If a user unenrols and re-enrols an exercise, `seenExerciseInfo` is NOT automatically cleared for that exercise. The assumption is the user has already seen the guidance. If re-enrolment occurs after an extended gap (months), the user can always access the sheet via the ⓘ button — the permanent suppression only affects the unsolicited nudge prompt.

#### Tier 3 — Pre-Session Intro (first session only, priority exercises)

For **Dead Bug** and **Glute Bridge** only — exercises whose names are genuinely unfamiliar to most users — a brief dismissable sheet is shown before the user's very first session with that exercise.

The sheet contains:
- The looping demo
- Two coaching cues (setup + movement)
- A single "Got it" button

This is shown once per exercise, ever. It is tracked the same way as Tier 2 (in `UserSettings`). For Push-Ups, Squats, Sit-Ups, and Pull-Ups, this tier is skipped — those names are self-explanatory.

**Relationship to onboarding:** The onboarding enrolment card shows a brief exercise illustration and description. The Tier 3 intro still fires on the first workout session, because (a) onboarding happens days before the first session, (b) the enrolment card content is different from technique guidance, and (c) seeing an illustration in a low-stakes selection flow does not prepare the user for the physical movement. The intro is not redundant.

---

## Media

### Format

3D-rendered looping animations (MP4, H.265, 720p, 3–8 seconds, muted). Not real-human video — 3D animation provides visual consistency across all 18 exercise-level combinations, requires no re-shoot if branding changes, and can optionally highlight the target muscle group.

### Source

Purchase from **gym-animations.com** or **exerciseanimatic.com**:
- Perpetual commercial royalty-free license
- Plain MP4 files — no SDK, no runtime dependency
- Covers all 6 exercises in the catalogue

### Library size

One clip per exercise (6 clips). The same clip is reused across all 3 levels; the written content (coaching cues, level tip) is level-specific. At H.265, 6 × 8-second 720p clips ≈ 15–30 MB total — comfortably within App Store limits.

If budget allows, purchase distinct clips per level for exercises where form changes significantly between levels (Push-Ups: standard → wide → diamond grip).

### Delivery

Bundle clips in the app under a `Resources/ExerciseMedia/` folder. No streaming infrastructure needed. Ensures offline availability during workouts.

### Playback

Use `AVPlayer` with `AVPlayerLayer` via `UIViewRepresentable`. Set `actionAtItemEnd = .none` and loop using `NotificationCenter` observer for `AVPlayerItemDidPlayToEndTime`. No third-party player, no visible playback controls. The clip loops silently and automatically.

`UIViewRepresentable` is a UIKit bridge type. This is an approved exception to the no-UIKit rule — `AVPlayerLayer` is a QuartzCore type and has no native SwiftUI equivalent for looping muted video. The wrapper is contained entirely in `LoopingVideoView` and does not expose UIKit types to callers.

**Audio session:** Configure `AVAudioSession.sharedInstance()` with category `.ambient` and option `.mixWithOthers` before playing. This prevents the muted clip from interrupting the user's music playback.

**Error state:** If `Bundle.main.url(forResource:withExtension:)` returns `nil` or `AVPlayer` fails to load the item, `LoopingVideoView` falls back to displaying the exercise's static illustration from the asset catalogue (the same image used on the enrolment card). This must never crash.

**Memory lifecycle:** `LoopingVideoView` calls `player.pause()` and removes the `NotificationCenter` observer in `dismantleUIView`. Each sheet presentation creates one `AVPlayer`; it is torn down on dismiss. Do not cache `AVPlayer` instances across sheet presentations.

---

## Data Model

No new `@Model` entities required. One property added to the existing `UserSettings` model.

Add to `UserSettings`:
```swift
var seenExerciseInfo: [String] = []  // exerciseId values, treated as a set (uniqueness enforced on write)
```

**Schema migration required.** Adding a property to an existing `@Model` class requires a `VersionedSchema` bump. Since `seenExerciseInfo` has a sensible default (`[]`), this is a lightweight migration — no data transformation needed, just a `BodyweightSchemaV2` with `MigrationStage.lightweight`.

The first-occurrence nudge and pre-session intro both check and write this array. Before appending, always check `contains(exerciseId)` to prevent duplicates (SwiftData does not support `Set<String>` as a stored property type).

---

## SwiftUI Components

| Component | Description |
|---|---|
| `ExerciseInfoSheet` | Full sheet with looping video, cues, level tip. Presented via `.sheet` modifier. |
| `ExerciseInfoButton` | Small ⓘ button that presents `ExerciseInfoSheet`. Reused wherever an exercise name appears. |
| `ExerciseNudgeBanner` | Inline prompt shown below exercise name on first occurrence. Dismissable. |
| `LoopingVideoView` | `UIViewRepresentable` wrapping `AVPlayerLayer` for muted looping MP4. |

`ExerciseInfoSheet` receives an `exerciseId: String`, `level: Int`, and `mediaURL: URL`. It derives all content from a static lookup (matching the existing `exercise-data.json` pattern — no new network call).

Coaching cues, common mistakes, and level tips are stored as a Swift enum or static struct keyed by `exerciseId`, collocated with the sheet component.

---

## Accessibility

- `LoopingVideoView` respects `UIAccessibility.isReduceMotionEnabled`. When reduce motion is on, show a static still image (first frame) instead of the looping animation.
- All coaching cue text is readable by VoiceOver.
- The "Got it" and dismiss buttons have minimum 44×44pt tap targets.

---

## Scope Boundaries

- **iPhone only** in v1. The Watch workout UI is too constrained for an info sheet; the nudge on first occurrence is omitted from Watch.
- No audio narration — users are often in public spaces without headphones.
- No interactive form checks (camera, accelerometer).

---

## Content Dependency

Coaching cues, common mistakes, and level tips for all 6 exercises across all 3 levels must be written before `ExerciseInfoSheet` can be built. This content does not exist in `exercise-data.json` or any other spec. It must be authored as a static Swift lookup (enum or struct) keyed by `exerciseId` and `level`.

**Content structure per entry:**
- `muscles: [String]` — 1–2 target muscle names
- `setup: String` — starting position (≤ 20 words)
- `movement: String` — the action (≤ 20 words)
- `focus: String` — key coaching cue (≤ 15 words)
- `commonMistake: String` — one mistake (≤ 20 words)
- `levelTip: String` — level-specific note (≤ 25 words; for Level 3, describe what makes this the advanced form)

This content must be authored and approved before implementation begins. It is a blocking dependency.

## Level Derivation

`ExerciseInfoSheet` always shows the user's **current level** for that exercise. When opened from the History tab (if implemented), it shows the user's current level, not the historical level at the time of the session. This is a deliberate simplification — historical level context is available from the History row itself.

## Open Questions

1. Should the ⓘ button appear on the Watch `WatchReadyView` (pre-set screen)? Deferred to v2 — Watch screen is too small.
2. Should the detail sheet be navigable from the History tab's `ExerciseSummaryRow`? Deferred — low priority for v1.
