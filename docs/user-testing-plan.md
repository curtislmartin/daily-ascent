# Daily Ascent — User Testing Plan

> **Build:** TestFlight build 30+
> **Last updated:** 2026-03-22
> **Tester setup:** Fresh install preferred. Use the Debug Panel (Settings → bottom) to set up specific states quickly.

---

## Before You Start

- Install via TestFlight
- Use a real device (iPhone + Apple Watch if available)
- Go through onboarding fresh — don't skip it
- Note anything that feels confusing, slow, or wrong — not just bugs

---

## 1. Onboarding

- [ ] Exercise selection screen shows all 6 exercises grouped by muscle group
- [ ] Can select multiple exercises (try 1, try all 6)
- [ ] Cannot continue with 0 exercises selected
- [ ] Placement test works per exercise (or skip)
- [ ] Start date picker works
- [ ] Data consent screen appears — toggle defaults to OFF
- [ ] Demographic tags only appear if data consent is ON
- [ ] All demographic fields are optional
- [ ] Completing onboarding lands on Today tab with exercises scheduled

---

## 2. Today Dashboard

- [ ] Due exercises appear as cards
- [ ] Cards show exercise name, level, day, sets × reps
- [ ] Tapping a card starts a workout session
- [ ] Completing all exercises transitions to a rest/done state
- [ ] Rest day shows correct message ("Next training: tomorrow" or similar)
- [ ] Streak badge shows when streak > 0

**Use debug panel to test these states:**
- [ ] Set exercises due today → cards appear
- [ ] Force rest day → rest day view shows
- [ ] Set streak to 7 → flame badge appears
- [ ] Show demographics nudge → nudge card appears on Today

---

## 3. Workout Session — Manual Counting (Post-Set)

*Best exercises to test: Push-Ups, Pull-Ups, Sit-Ups*

- [ ] "Start Set" screen appears with set number and target reps
- [ ] Timer runs during set
- [ ] "End Set" prompts for rep count entry, pre-filled with target
- [ ] Adjusting count up/down works
- [ ] Rest timer counts down between sets
- [ ] Completing all sets marks exercise as done, returns to Today
- [ ] Completed exercise is checked off on Today dashboard

---

## 4. Workout Session — Real-Time Counting

*Best exercises to test: Squats, Glute Bridges, Dead Bugs*

- [ ] Tap to count reps in real time
- [ ] +/− buttons allow correction
- [ ] Count is accurate
- [ ] Rest timer starts after confirming rep count
- [ ] Completing all sets marks exercise as done

---

## 5. Test Day

*Use debug: "Set exercise to test day" to trigger*

- [ ] Test day card on Today looks visually distinct
- [ ] Single-set session with target shown prominently
- [ ] Ring/progress fills as rep count approaches target
- [ ] **Pass** (≥ target): celebration shown, level unlock message
- [ ] **Fail** (< target): "Retry next session" message shown
- [ ] After passing, Program tab shows new level

---

## 6. Conflict Warnings

*Use debug: "Trigger double-test conflict" and "Trigger same-group conflict"*

- [ ] Double-test conflict: warning banner appears on Today
- [ ] Same-group conflict: warning banner appears on Today
- [ ] Banners are readable and explain the issue
- [ ] Exercises still completable despite warnings

---

## 7. Program Tab

- [ ] All enrolled exercises listed with level progress
- [ ] Progress bars reflect actual progress
- [ ] Next scheduled date shown per exercise
- [ ] Tap exercise → Exercise Detail opens
- [ ] Detail shows: level progression, session history chart, upcoming schedule
- [ ] Level browser shows all days in a level (completed with dates, future with prescriptions)

---

## 8. History Tab

- [ ] Completed sessions appear grouped by week
- [ ] Day entries expand to show per-exercise breakdown
- [ ] Test day passes show trophy icon 🏆
- [ ] Stats section shows: total reps, streak, session count
- [ ] Weekly volume chart renders correctly

*Use debug: "Seed 4 weeks of history" and "Seed 12 weeks of history" to populate data*

- [ ] Week grouping correct with 4 weeks of data
- [ ] Chart scrolls with 12 weeks of data
- [ ] Test day pass row renders correctly (debug: "Add test day pass to history")
- [ ] Test day fail row renders correctly (debug: "Add test day fail to history")

---

## 9. Settings

- [ ] Rest timer sliders work per exercise
- [ ] Counting mode toggle works per exercise
- [ ] Notifications settings show correct toggles and time pickers
- [ ] Data & Privacy: consent toggle works
- [ ] Data & Privacy: Privacy Policy link opens

---

## 10. Notifications

*Use debug panel: Notifications section*

- [ ] Daily reminder fires with correct title and body (single exercise)
- [ ] Daily reminder (multi) lists exercise names
- [ ] Test day reminder has correct messaging
- [ ] Streak protection (streak 0): "Start building your streak"
- [ ] Streak protection (streak 7): "Don't break your streak"
- [ ] Level unlock notification fires after debug pass
- [ ] Schedule adjustment notification fires
- [ ] List pending notifications shows correct count

---

## 11. Apple Watch (if available)

- [ ] Watch app opens and shows today's due exercises
- [ ] Tapping exercise starts a session on Watch
- [ ] Rep counting works (tap to count, Crown to adjust)
- [ ] Rest timer runs and gives haptic feedback
- [ ] Completing a session on Watch syncs back to iPhone
- [ ] iPhone Today dashboard reflects Watch completion
- [ ] Complications show (if set up)

---

## 12. Debug Panel Smoke Test

*Settings → scroll to bottom → debug sections*

- [ ] All scheduling actions execute without crashing
- [ ] All notification actions fire a notification
- [ ] History seeding works and data appears in History tab
- [ ] Danger zone actions show confirmation dialog before executing
- [ ] "Reset done ✓" clears all checkmarks

---

## 13. Edge Cases

- [ ] Complete only some due exercises (not all) — streak maintained
- [ ] Miss a day — exercises stay due, schedule drifts correctly
- [ ] Add a new exercise from Settings — appears on Today on correct date
- [ ] Remove an exercise from Settings — disappears from Today
- [ ] Decline data consent during onboarding — no upload prompt ever appears
- [ ] Opt in to data sharing, then disable — toggle works, no further uploads

---

## What to Note

For every issue found, capture:
1. What you were doing
2. What you expected
3. What actually happened
4. Screenshot or screen recording if possible

Report issues in the GitHub repo: https://github.com/curtislmartin/daily-ascent/issues
