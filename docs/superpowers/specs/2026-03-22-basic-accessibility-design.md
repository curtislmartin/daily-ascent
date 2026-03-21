# Basic Accessibility Pass — Design

**Date:** 2026-03-22
**Scope:** Basic VoiceOver support across main flows for App Store submission. No new features; decorative cleanup + labels + grouping only.

---

## Goals

- Pass Apple review without accessibility rejections
- VoiceOver users can navigate Today, Workout, Program, and History without encountering unlabelled or confusing elements
- No structural changes to views — modifiers only

## Not In Scope

- Custom VoiceOver actions
- Full rotor support
- Notifications settings accessibility
- Watch app accessibility

---

## Changes By File

### ExerciseCard.swift
- Color bar: `.accessibilityHidden(true)` (decorative)
- Muscle group tag: `.accessibilityHidden(true)` (decorative, redundant with card label)
- Chevron: `.accessibilityHidden(true)` (decorative)
- TEST DAY badge: `.accessibilityLabel("Test day")`
- Level badge: `.accessibilityLabel("Level \(enrolment.currentLevel)")`
- The NavigationLink as a whole: `.accessibilityLabel` combining exercise name, level, day, set summary, and conflict warning if present
- Checkmark icon: `.accessibilityLabel("Completed")`

### TodaySessionBanner.swift
- Group as single element with label like "3 of 5 exercises done, 18-day streak"
- Hide internal subviews from accessibility

### TodayDemographicsNudge.swift
- X/dismiss button: `.accessibilityLabel("Dismiss")`

### WorkoutSessionView.swift
- "Start Set N" button: already has text, fine
- "Done with Set" button: already has text, fine
- "Quit Workout" button: already has text, fine
- Set progress header: group as `.accessibilityElement(children: .combine)`

### RestTimerView.swift
- Circular countdown: `.accessibilityLabel("Rest timer, \(remaining) seconds remaining")`
- Hide decorative ring from accessibility

### RealTimeCountingView.swift
- Tap area / rep counter: `.accessibilityLabel("\(count) reps")`

### WeeklyVolumeChart.swift
- Chart: `.accessibilityLabel("Weekly volume chart showing reps per week for the last 8 weeks")`
- Individual bar marks: `.accessibilityHidden(true)` (Swift Charts marks are not individually navigable in a useful way)

### SessionHistoryChart.swift
- Chart: `.accessibilityLabel("Session history chart for \(exerciseName)")`
- Individual marks: `.accessibilityHidden(true)`

### DayGroupRow.swift
- Collapsed row: group as single element, label "Thursday April 17, 498 reps, 6 exercises"
- Expand/collapse: `.accessibilityHint("Double-tap to \(isExpanded ? "collapse" : "expand")")`

### ProgramView.swift (or ProgramViewModel-driven views)
- Progress bars: `.accessibilityLabel("Level \(level), day \(current) of \(total)")`

### ExerciseCompleteView.swift
- Trophy/result area: group as single element with summary label

---

## Approach

- Pure modifier additions — no structural changes
- Each file is independent; changes can be applied in parallel
- Test with VoiceOver on simulator: Settings → Accessibility → VoiceOver

---

## Success Criteria

- All tappable elements have a meaningful label when focused by VoiceOver
- Decorative elements are hidden from VoiceOver
- Charts have summary labels
- No "button" or "image" VoiceOver reads without context
