# Bodyweight Training App — UX & Interaction Design (v2)

## The Core Design Challenge

The original Runtastic apps were single-exercise, single-purpose. Each app had one job: guide you through today's push-ups, count your reps, and send you on your way.

This app consolidates six exercises into one experience, but the user chooses which programs to enrol in. On a given training day they might have anywhere from 1–6 exercises due depending on enrolment and schedule drift. The UX needs to handle this variability gracefully — from a single quick set of dead bugs to a full six-exercise session — while keeping injury prevention at the centre of scheduling decisions.

---

## Data Shape Summary

| Exercise | Muscle Group | Sets/Day | Levels | Days per Level | Test Targets |
|---|---|---|---|---|---|
| Push-Ups | Upper (push) | 5 | 3 | 10 / 19 / 25 | 20 → 50 → 100 |
| Squats | Lower | 4 | 3 | 9 / 19 / 19 | 20 → 100 → 150 |
| Sit-Ups | Core (flexion) | 6 | 3 | 9 / 18 / 18 | 20 → 60 → 100 |
| Pull-Ups | Upper (pull) | 4 | 3 | 19 / 19 / 19 | 10 → 20 → 30 |
| Glute Bridges | Lower (posterior) | 4 | 3 | 9 / 19 / 19 | 30 → 100 → 150 |
| Dead Bugs | Core (anti-extension) | 4 | 3 | 9 / 18 / 18 | 20 → 50 → 80 |

Muscle group classification matters for the scheduling engine (see Injury-Aware Scheduling).

Key scheduling facts:
- Each exercise has its own rest day pattern (L1 often 1-2-1-3; L2/L3 typically 2-2-3)
- Some exercises add an extra rest day before the test (push-ups L2/L3, sit-ups L2/L3, dead bugs L2/L3)
- Each level chains sequentially — complete L1, 2-day gap, start L2, etc.
- The full program runs roughly 18–19 weeks if all six are enrolled and no days are missed

---

## Program Enrolment (First Launch)

The first thing the user does is **choose which exercises to train.** This is a one-time setup (editable later in settings).

**Enrolment screen:**
- All six exercises presented as selectable cards
- Each card shows: exercise name, illustration/animation, brief description, program length estimate, muscle group tag
- Cards grouped or tagged by muscle group so the user can see coverage:
  - Upper Push: Push-Ups
  - Upper Pull: Pull-Ups
  - Lower: Squats, Glute Bridges
  - Core: Sit-Ups, Dead Bugs
- A recommendation nudge: "For balanced training, choose at least one from each group" — but no enforcement, the user picks what they want
- Minimum selection: 1 exercise
- Start date picker (default: today)
- "Start Program" button

After enrolment, the app generates a schedule for each selected exercise from the start date, applying the rest day patterns from the spreadsheet data. The user lands on the Today dashboard.

**Editing enrolment later:**
- Settings → Programs → Add/remove exercises
- Adding a new exercise starts it from L1 Day 1 on the next available date
- Removing an exercise archives its progress (can be re-enrolled later, resuming where they left off)

---

## Information Architecture

### Three-Level Hierarchy

```
Today (Dashboard)          →  what's scheduled, what do I want to do?
Program Overview           →  how am I progressing across all exercises?
Workout Session (active)   →  I'm doing reps, count them, time my rest
```

### Navigation Model (iPhone)

**Tab bar with three tabs:**

1. **Today** — daily dashboard, the primary landing screen
2. **Program** — overview of enrolled exercises, levels, and progress
3. **History** — completed workout log, stats, streaks

---

## Screen-by-Screen Design

### 1. Today (iPhone — Daily Dashboard)

This is where 90% of sessions start. It answers: **"What's due today, and what do I want to do?"**

**When there are exercises scheduled:**

Vertical list of today's due exercises as cards. Each card shows:
- Exercise name and icon (colour-coded by exercise)
- Level indicator (L1 / L2 / L3)
- Day within level (e.g. "Day 7 of 19")
- Set preview (e.g. "5 sets — 34, 24, 22, 20, 18")
- Total reps for the session
- Muscle group tag (subtle, e.g. "Upper Push")
- Status: due / in progress / completed ✓ / skipped (pushed to tomorrow)

**The user picks what to start.** They tap an exercise card to begin that exercise. When they finish, the dashboard updates — the completed exercise is checked off and the remaining due exercises are shown. They can:
- Tap another exercise to continue
- Stop for the day — remaining exercises stay as "due" on the dashboard

**If the user doesn't complete an exercise today:**
That exercise gets pushed to tomorrow (+1 day). The rest of that exercise's schedule shifts forward by one day to preserve rest gaps. Other exercises are unaffected — they remain on their own independent timelines.

**When it's a rest day (for all enrolled exercises):**
Show a rest day message with context — "Rest day. Next training: tomorrow — 4 exercises" and a motivational stat.

**Test day cards look distinct:**
Bolder border, with the target number prominent. "Push-Up Test — Hit 50 to unlock Level 3." Visually elevated to signal this is an event.

**Scheduling conflict indicators:**
If the scheduling engine has flagged a concern (see Injury-Aware Scheduling), show a subtle warning on the affected card — e.g. a small shield icon with "Consider resting squats today — test day tomorrow." The user can override this, but the app should surface the recommendation.

---

### 2. Workout Session (iPhone — Active Exercise)

When the user taps an exercise, they enter a focused full-screen session for that single exercise.

**Session flow for a regular training day:**

```
[Set 1: do reps]  →  [Rest timer]  →  [Set 2: do reps]  →  ...  →  [Exercise complete]  →  [Return to Today]
```

No inter-exercise navigation within the session. Each exercise is its own atomic session. When it finishes, the user returns to the Today dashboard and picks the next one (or stops). This is simpler than a guided multi-exercise flow and matches the "choose what to do" model.

**Active set screen:**
- Giant rep counter, centre screen
- Target reps for this set shown above or below
- Set progress indicator (dots: set 2 of 5)
- "Done" button to complete the set (manual counting)
- +/− adjustment buttons for correcting the count

**Rest timer screen (between sets):**
- Countdown timer, large and central
- Default rest varies by exercise (see Rest Timer Defaults below)
- "Skip" button to end rest early
- Preview of next set: "Next: Set 3 — 22 reps"
- Progress: "2 of 5 sets complete"

**Exercise complete screen:**
- Celebration: "Push-Ups done! 118 reps ✓"
- Session time for this exercise
- "Back to Today" button — returns to the dashboard showing remaining exercises
- Quick stat: how this session compares to previous (e.g. "+12 reps vs last session")

**Test day session flow:**
- Target displayed prominently: "Hit 50 to unlock Level 3"
- Single set — no rest timers
- Ring/progress visualisation filling toward the target
- Rep counter with manual +/−
- If target hit: celebration animation, level unlock, confetti
- If target missed: "Almost — 43 of 50. You can retry next session."
  - Failed test blocks progression. The test day stays on the schedule. The user retries on their next scheduled training day (respecting the rest gap). No immediate retry — the rest day before the test exists for a reason, and attempting again fatigued defeats the purpose.

---

### 3. Apple Watch — Companion App

The Watch is a **companion device**, not a standalone app. The iPhone holds the program database, scheduling engine, and is the source of truth for all progress data. The Watch downloads upcoming sessions and provides a convenient wrist-based interface for the workout itself.

**What gets synced to the Watch:**

Via WatchConnectivity `transferUserInfo` (queued, reliable delivery):
- Upcoming sessions: next 2–4 weeks of scheduled workouts per enrolled exercise
- Per session: exercise name, exercise colour, level, day number, set count, rep targets per set, whether it's a test day, test target
- This is a few KB total — storage is not a concern
- Sync triggers: on schedule change (completion, pushback, enrolment change), and on Watch app launch if stale

**What the Watch sends back to the iPhone:**

- Completed session data: exercise, sets performed, reps per set, timestamps, pass/fail for tests
- Raw motion data recordings (see ML Data Collection section)
- Synced via `transferUserInfo` for results, `transferFile` for larger sensor data payloads

**Sync strategy:**
- iPhone pushes schedule updates proactively whenever the schedule changes
- Watch pushes results back immediately if phone is reachable (`sendMessage`), otherwise queues via `transferUserInfo`
- On conflict (both devices show different state), iPhone wins — it's the source of truth
- The Watch should show a "last synced" indicator if data is more than 24 hours stale

**Watch workout flow:**

**Active set screen:**
- Rep count — enormous, fills the display
- Target reps — smaller, above
- Set indicator — dots at top
- Tap screen to increment (manual counting)
- Digital Crown scrolls to adjust count up/down
- Haptic tap on each count increment

**Rest timer:**
- Countdown fills the screen
- Haptic tap at 10 seconds remaining
- Three quick haptics when rest ends
- Crown scroll to adjust remaining time
- Tap to skip rest

**Exercise complete:**
- "✓ Push-Ups — 118 reps" with a strong haptic
- Shows remaining exercises due today
- Tap an exercise to start it, or dismiss to end the Watch session

**Starting a Watch workout:**
- Open Watch app → shows today's due exercises (synced from iPhone)
- Tap any exercise to start it
- Or use the complication to go straight to today's view

**Complications:**
- Small: "4/6" (exercises done today) or "REST" on rest days
- Medium: exercise icons for what's due today with completion indicators

---

### 4. Injury-Aware Scheduling Engine

This is the most important piece of logic in the app. Each exercise runs on its own independent timeline, but the app needs to be smart about what lands on the same day — especially around test days, which represent peak effort.

**Muscle group classification:**

```
Upper Push:     Push-Ups
Upper Pull:     Pull-Ups
Lower:          Squats, Glute Bridges
Core Flexion:   Sit-Ups
Core Stability: Dead Bugs
```

**Scheduling rules (v1):**

1. **Test day isolation:** A test day for any exercise should NOT coincide with a training day for another exercise in the same muscle group. If a push-up test lands on the same day as a pull-up training day, that's acceptable (different muscle groups). But if a squat test lands on a glute bridge training day, the glute bridges should be pushed +1 day.

2. **No double-testing:** Two test days should never land on the same day, regardless of muscle group. Tests are max-effort — doing two in one day compromises both. If tests collide, the second one pushes +1 day.

3. **Same-group daily volume awareness:** If squats and glute bridges both land on the same day (they often will), that's fine for regular training days — the volume is prescribed and manageable. But the app should track cumulative lower-body volume and flag days where combined volume is unusually high.

4. **Post-test recovery:** After a test day (pass or fail), ensure at least the standard rest gap before the next training day for that muscle group. A passed push-up test followed immediately by a pull-up session the next day is fine. A passed squat test followed by glute bridges the next day might warrant a warning.

**How conflicts are resolved:**

When the scheduling engine detects a conflict (e.g. test day collision), it resolves automatically:
- The lower-priority exercise's session gets pushed +1 day
- Priority order for tests: the exercise with fewer remaining days in the program gets priority (it's closer to finishing)
- For regular training day conflicts with test days: the regular day always yields
- The push cascades — if pushing day N means day N+1 now violates a rest gap, that shifts too

**User override:** The dashboard shows scheduling recommendations, but the user can always tap any due exercise and do it anyway. The app advises, it doesn't enforce. A small indicator shows "Recommended to rest today" on affected cards.

**Future (v2): Structured interleaving plans**

A more sophisticated version could generate weekly plans that optimally interleave exercises across the week, considering:
- Muscle group recovery (48h between same-group sessions)
- Progressive volume management across the week
- Tapering before test days
- The user's preferred training days per week

---

### 5. Program Overview (iPhone)

**Exercise grid view:**
Cards for each enrolled exercise, each showing:
- Exercise name, icon, colour
- Current level with visual progress bar spanning all 3 levels
- Current position: "L2 — Day 14 of 19"
- Next scheduled training date
- Estimated completion date for current level

Tapping an exercise shows its **detail view:**
- Level progression timeline (L1 → L2 → L3) with current position marked
- Calendar view of upcoming sessions with set prescriptions
- Historical chart: total reps per session over time
- Test day info: upcoming target, or past results
- Option to reset this exercise to start of current level

---

### 6. History (iPhone)

**Workout log (reverse-chronological):**
Each entry shows:
- Date
- Exercises completed (coloured dots/icons)
- Total reps across all exercises
- Session duration
- Pushed exercises noted: "Squats pushed to tomorrow"

**Stats dashboard:**
- Total reps all-time and per exercise
- Current streak
- Longest streak
- Weekly volume chart (stacked bars by exercise)
- Level progression timeline

---

## Rep Counting Strategy

### MVP: Two Counting Modes

Not all exercises allow real-time tap-to-count. During push-ups your hands are on the floor. During pull-ups they're gripping a bar. The app needs two distinct interaction patterns depending on whether the user can interact with the device mid-set.

**Mode 1 — Real-time counting (hands free during exercise):**
Used for: Squats, Glute Bridges, Dead Bugs

The user taps to count each rep as they do it. This is the classic Runtastic-style interaction.
- iPhone: Large tap zone centre screen, +/− buttons for correction, "Done" when finished
- Watch: Tap display to increment, Digital Crown to adjust, tap Done when set complete
- Rep counter updates live with each tap
- "Done" button confirms the set

**Mode 2 — Post-set confirmation (hands occupied during exercise):**
Used for: Push-Ups, Pull-Ups, Sit-Ups

The user performs the full set without interacting with the device, then confirms the count afterward. This is the default for any exercise where holding, gripping, or body positioning prevents device interaction.
- Before set: screen shows target reps and "Start Set" button
- During set: screen shows a timer/elapsed time and the target reps (no counting interface — the user is exercising). Optionally a pulsing animation to indicate the set is active. On Watch, a subtle haptic every 30s as a "still recording" signal.
- After set: user taps "End Set" (or the Watch detects stillness after movement stops). Screen shows the target pre-filled with +/− to adjust to actual reps completed, then "Confirm" to save.
- The target is pre-filled because most users hit or get close to the target — adjusting down from 34 to 30 is faster than counting up from 0.

**Why not count the reps while they move? (e.g. voice counting)**
In testing, voice-counting ("one... two... three...") and audio-based detection add complexity without reliability. The post-set confirmation model is simple and accurate. When v2 ML auto-counting arrives, it replaces the "during set" phase with live detection — the before/after UX stays the same.

**Per-exercise mode assignment (can be changed in settings):**

| Exercise | Default Mode | Reason |
|---|---|---|
| Push-Ups | Post-set confirmation | Hands on floor, can't tap. (Future: nose-tap proximity detection) |
| Squats | Real-time counting | Hands free, phone nearby or Watch on wrist |
| Sit-Ups | Post-set confirmation | Phone on chest or hands behind head — can't tap mid-rep |
| Pull-Ups | Post-set confirmation | Hands gripping bar, phone in pocket |
| Glute Bridges | Real-time counting | Hands free at sides, phone or Watch accessible |
| Dead Bugs | Real-time counting | Hands free between reps, controlled movement allows tapping |

Users can override the default mode per exercise in settings. Some users may prefer post-set confirmation for everything (simpler, less distraction). The mode switch should be discoverable but not in-your-face — a small toggle on the set screen or in exercise settings.

**Watch-specific considerations:**
For post-set confirmation exercises on the Watch, the "End Set" trigger is important. Options:
- Tap the display (requires raising wrist, which is fine post-set)
- Double-press the Digital Crown (quick gesture, hands might be sweaty)
- Auto-detect stillness after 3+ seconds of no movement (use accelerometer data — this data is being recorded anyway for ML). This could be a v1.1 enhancement.

**Test day counting:**
Test days are always post-set confirmation regardless of exercise. The user performs their max-effort set, then enters the count. For tests, the ring visualisation shows progress toward the target as the user adjusts the count — filling up as they +/− to their actual number. This creates a moment of tension: "did I hit 50?"

### Sensor Positioning by Exercise (Future)

| Exercise | Best Sensor Device | Placement | Motion Signal |
|---|---|---|---|
| Push-Ups | iPhone | Face-down on floor under face | Proximity sensor / front camera detects face at bottom of rep |
| Squats | Watch | On wrist (natural arm swing) | Vertical acceleration as arms rise/fall with squat |
| Sit-Ups | Watch or iPhone | Wrist or chest | Wrist travels with torso curl; phone on chest detects incline change |
| Pull-Ups | iPhone | In pocket | Vertical acceleration — body rises to bar height |
| Glute Bridges | iPhone | On hip/pelvis | Hip rises and falls — clear vertical displacement |
| Dead Bugs | Manual only | N/A | Minimal gross movement — form > volume |

### ML Data Collection (built into v1, used in v2+)

The app collects raw sensor data during every set to build a labelled training dataset. Data is collected centrally to train models that ship in v2 — we don't want users to lose their contribution if they delete the app.

**What to record (both devices simultaneously during active sets):**
- Accelerometer (3-axis, 100Hz)
- Gyroscope (3-axis, 100Hz)
- Synchronised timestamps

**Metadata per recording:**
- Exercise type, level, day, set number
- Confirmed rep count (manual count = label)
- Device placement (wrist/floor/pocket/chest/hip)
- Counting mode used (real-time or post-set confirmation)
- Session ID for correlating Watch + iPhone recordings

**Storage math:**
- ~2.4 KB/sec raw data → 60s set ≈ 144 KB → full session ≈ 3 MB → monthly ≈ 90 MB

**On-device pipeline:**
- Watch records to temp file during set → transfers via `transferFile` to iPhone
- iPhone stores locally, indexed in SwiftData, batched for upload

**Central cloud collection:**

Sensor data is uploaded to a central data store for model training. This requires explicit user consent.

*Consent flow (during onboarding, after enrolment):*
- Clear explanation: "Help improve automatic rep counting. We collect anonymised motion data from your workouts to train AI models that will count reps for you in a future update."
- What's collected: "Movement data from your wrist and phone sensors during sets, plus the rep count you confirm. No personal information, health data, or identifiers."
- Opt-in toggle (not opted in by default). Can be changed anytime in Settings → Privacy.
- If the user declines, sensor data is still recorded locally (for potential on-device ML later) but never uploaded.

*Anonymisation:*
- Each device generates a random anonymous contributor ID (UUID, not linked to Apple ID, name, or any account)
- No personal data attached to recordings: no name, no age, no weight, no location
- Contributor ID allows grouping sessions from the same person (useful for training — one person's movement patterns are consistent) without identifying them
- If the user resets their contributor ID in settings, a new UUID is generated — old data can't be linked to new data

*Upload strategy:*
- Batch upload on WiFi + charging only (typically overnight, via `BGProcessingTask`)
- Nightly cadence — queues during the day, uploads when conditions are met
- Data is compressed (gzip) before upload — ~3 MB session compresses to ~500 KB
- If conditions aren't met for several days, uploads batch on next opportunity
- Backend: S3-compatible object storage (e.g. AWS S3 or Supabase Storage), organised by exercise type
- Metadata stored in a lightweight database (Supabase Postgres) for querying the training set

*Data structure per upload:*
```
{
  contributor_id: "uuid-v4",
  exercise: "push_ups",
  level: 2,
  day: 8,
  set_number: 3,
  confirmed_reps: 22,
  counting_mode: "post_set_confirmation",
  device: "watch",  // or "iphone"
  placement: "wrist",
  sample_rate_hz: 100,
  duration_seconds: 45.2,
  sensor_data: <compressed binary>,  // 3-axis accel + 3-axis gyro
  recorded_at: "2026-04-15T08:23:41Z"
}
```

*Model training pipeline (v2 development):*
- Once sufficient data is collected (~500+ sets per exercise from 50+ contributors), train Create ML Activity Classifier models per exercise
- Models detect rep boundaries from accelerometer/gyroscope signal patterns
- Trained models are small (~1–5 MB) and ship with app updates via Core ML
- On-device inference — no cloud dependency at runtime

*Data retention:*
- Central data retained indefinitely for model training and improvement
- Users can request deletion of their contributor ID's data via settings (all recordings with that UUID are purged)
- Privacy policy clearly states data use, retention, and deletion rights

---

## Scheduling Logic — Detailed

### Per-Exercise Independent Timelines

Each enrolled exercise maintains:
- Current level (1, 2, or 3)
- Current day within level
- Last completed date
- Next scheduled date (last_completed + rest_gap)
- Status: on-track / pushed / test-day / program-complete

### Date Calculation

```
next_date = last_completed_date + rest_gap_days
```

If not completed on scheduled date → stays due → on completion, rest gap applies from actual completion date → remaining schedule shifts forward.

### Conflict Resolution

After any schedule change:
```
for each exercise scheduled date:
    if test_day collision → push lower-priority +1
    if test_day + same_muscle_group training → push training +1
    if double high_volume same_group → flag warning
    cascade re-check after any push
```

---

## Rest Timer Defaults

Rest times should reflect the muscular demand and set volume of each exercise. The original Runtastic apps gave squats longer rest than push-ups, which makes sense — lower body compound movements under higher volume need more recovery between sets.

**Recommended defaults (all configurable per exercise in settings):**

| Exercise | Default Rest | Rationale |
|---|---|---|
| Push-Ups | 60s | Upper body, moderate volume. 5 sets means more total rest periods — keeping each shorter maintains session flow. |
| Squats | 90s | Lower body compound, high total volume (100+ reps in L2/L3). Legs need more recovery to maintain form. |
| Sit-Ups | 45s | Core endurance, 6 sets of moderate reps. Shorter rest keeps intensity up — abs recover fast. |
| Pull-Ups | 90s | The hardest exercise here. Low reps but extremely demanding per rep. Full recovery between sets is essential to hit targets. |
| Glute Bridges | 75s | Lower body posterior chain, high volume similar to squats but less overall system fatigue. Slightly less than squats. |
| Dead Bugs | 45s | Core stability, lower volume, form-focused. Like sit-ups, short rest is appropriate — the difficulty is coordination, not exhaustion. |

**Scaling with level and set volume:**
As an optional v1.1 enhancement, rest could scale up slightly with volume. When a set target exceeds a threshold (e.g. 30+ reps for upper body, 40+ reps for lower body), add 15s to the default. This keeps early levels snappy and gives breathing room for the harder L3 sets.

**Between exercises (when returning to dashboard):**
No enforced rest between exercises — the user controls pacing by choosing when to start the next exercise from the dashboard. The time spent reviewing the completion screen and selecting the next exercise provides natural transition time. If users want a formal inter-exercise rest, this could be a settings option (default: off, suggested: 2 minutes when enabled).

---

## Streak Definition

Streaks should incentivise consistent, healthy training — not push users toward injury by making them feel they must complete everything.

**Definition:** A streak is maintained as long as the user completes at least one due exercise on every day that has scheduled training. Specifically:

- **Rest days never break a streak.** If no exercises are scheduled, the streak continues automatically.
- **Partial completion counts.** If 5 exercises are due and the user does 3, the streak is maintained. They chose to train — that's the habit we're reinforcing.
- **Complete skip breaks the streak.** If exercises are due and the user does zero, the streak breaks. This is the only way to break it.
- **Pushed exercises don't count against you.** If the scheduling engine pushes an exercise to tomorrow (conflict resolution), that doesn't affect today's streak.

**Display:** "18-day training streak" — simple, no breakdown of "perfect days" vs "partial days." The goal is showing up, not perfection.

**Why this is the right model:** With a newborn and 4–6 exercises daily, demanding full completion every day would lead to either streak-breaking discouragement or pushing through fatigue to avoid breaking the streak. Both are bad. The "just show up" definition means the user can do their pull-ups and dead bugs, skip the squats because their legs are sore, and still feel good about their consistency.

---

## Starting Level & Placement

Users should not be locked into starting at L1 Day 1 if they're already fit. The original Runtastic apps let users freely browse and start any training day — that flexibility is good UX and avoids boring experienced users with weeks of easy reps.

**Approach: Free level selection with a guided placement option.**

*During enrolment, for each selected exercise:*
- Default: Start at L1 Day 1 (recommended for beginners)
- Option: "I'm experienced — choose my starting level"
  - Tapping this opens a quick placement flow per exercise:
  - **Option A — Self-select:** Browse L1 / L2 / L3, see the day 1 set prescriptions for each level, and pick where to start. Show the test target for the selected level so the user understands what they're working toward.
  - **Option B — Placement test:** "Do as many [exercise] as you can." Based on the result, the app recommends a starting level:
    - Push-Ups: <20 → L1, 20–49 → L2, 50+ → L3
    - Squats: <20 → L1, 20–99 → L2, 100+ → L3
    - Pull-Ups: <10 → L1, 10–19 → L2, 20+ → L3
    - (etc., using each level's test target as the threshold)
  - The recommendation is shown but the user can override it — "We'd suggest Level 2, but you can start wherever you want."

*After starting:*
- Users can always jump to any day/level from the exercise detail screen in the Program tab. No gates or locks for navigation — only the progression system (tests) determines when a level is "officially" completed.
- Skipping ahead means you might hit a test day you can't pass, which naturally pushes you back to appropriate difficulty.

This respects the user's autonomy while providing structure for those who want it.

---

## HealthKit Integration

Single HKWorkout per training session (`.functionalStrengthTraining`). Start = first exercise begun, end = last exercise finished. Metadata includes per-exercise breakdowns. Heart rate captured passively via Watch.

**Future (v2): External workout streak awareness**
If the user did a gym session, a run, or any other workout logged in Apple Health but didn't do their bodyweight training, that shouldn't break their streak. The app could query HealthKit for any `.workout` samples on the current day — if one exists from another source, the streak logic treats the day as "active rest" rather than a skip. This reinforces the philosophy that the streak rewards consistent physical activity, not just compliance with this specific program.

---

## Settings (v1)

Settings is essential for v1 — users need to be able to adjust the experience from day one.

**v1 Settings screen:**

*Program*
- Enrolled exercises (add/remove, shows current progress)
- Start date (reset/reschedule)

*Workout*
- Rest timer per exercise (sliders, showing current defaults: 45s–90s)
- Inter-exercise rest timer (toggle on/off, default off, with duration picker when enabled — this lets us track whether users want it, informing future program design)
- Counting mode per exercise (real-time tap / post-set confirmation — shows default with override toggle)

*Data & Privacy*
- Motion data collection consent (toggle, links to explanation)
- Delete my contributed data (sends deletion request for contributor UUID)
- Reset contributor ID (generates new anonymous UUID)

*General*
- Notifications (toggle per type: daily reminder, streak protection, test day, level unlock)
- Reminder time picker
- Units preference (if we ever add weight tracking)

---

## Privacy, Data Consent & Legal

### Australian Privacy Act Considerations

The Privacy Act 1988 applies to organisations with >$3M annual turnover. A new app will likely fall below this threshold initially, but there are good reasons to comply from day one: it builds user trust, it's required for App Store compliance regardless, and if the app grows past the threshold (or if the threshold is lowered by future reform, which is actively being discussed), you're already compliant.

The Privacy and Other Legislation Amendment Act 2024 also introduced new transparency requirements for automated decision-making that take effect December 2026 — relevant if the ML auto-counting feature ever influences the user experience in significant ways.

### Apple App Store Requirements

The App Store requires a Privacy Nutrition Label for every app. This label must declare:
- What data types the app collects
- Whether data is linked to the user's identity
- Whether data is used for tracking
- The purposes for collection

For this app, the nutrition label would declare:
- **Sensor data** (accelerometer/gyroscope): Collected, not linked to identity, not used for tracking. Purpose: app functionality (future rep counting) and product improvement (model training).
- **Fitness & exercise data** (workout type, reps, sets): Collected, not linked to identity. Purpose: app functionality.
- **Usage data** (basic analytics if added): Collected, not linked to identity. Purpose: analytics.

Data processed only on-device does not need to be disclosed in the nutrition label. So the local sensor recordings that are never uploaded (for users who decline consent) don't need declaration.

### Data Consent Flow

**When it appears:** During onboarding, after exercise enrolment and before the first workout. It's a dedicated screen, not buried in settings.

**What it says:**

*Screen 1: The ask*
> **Help us build smarter rep counting**
>
> We're working on automatic rep detection — AI that counts your reps so you don't have to.
>
> To make it work, we need movement data from real workouts. During your sets, the app records motion from your phone and watch sensors.
>
> If you opt in, this anonymous data is uploaded to help train our models. It's never linked to your name, Apple ID, or any personal information.

*Screen 2: The details (expandable, not forced)*
> **What's collected:** Accelerometer and gyroscope readings during active sets, plus the rep count you confirm.
>
> **What's NOT collected:** No name, no account, no location, no health data, no Apple ID.
>
> **How it's anonymised:** Your device generates a random ID that can't be traced back to you. You can reset it anytime.
>
> **When it uploads:** Only on WiFi while charging. Typically overnight.
>
> **Can I delete it?** Yes. Settings → Privacy → Delete My Data removes all your contributions from our servers.

*Toggle: "Share anonymous motion data to improve rep counting"*
Default: OFF. User explicitly opts in.

*"Continue" button* (works regardless of toggle state)

**Should we tell users about local recording if they decline?**
Yes — transparency is always the right call, and the App Store nutrition label will reflect that sensor data is collected for app functionality regardless. But the framing matters. If they decline the upload, a brief note:

> "No problem. Motion data will still be recorded on your device during sets — this powers features like set timing and future on-device rep detection. It never leaves your phone."

This is honest, non-pressuring, and explains why the sensor recording happens even without consent to upload. Users who are truly uncomfortable could have a separate toggle to disable local recording entirely, but this would disable future on-device ML features for them.

### Apple Privacy Manifest

Include a `PrivacyInfo.xcprivacy` manifest in the Xcode project declaring:
- Required reason APIs used (e.g., `CMMotionManager` for sensor data)
- Data types collected and their purposes
- Tracking domains (none — we don't track)

---

## User Profile & Onboarding Data

### What to collect (and what not to)

The app doesn't need an account system for v1. No login, no email, no name. The user installs, enrols in exercises, and starts training. This is a feature — zero friction to start.

**For the ML training dataset**, some demographic data would genuinely improve model quality (different body types produce different motion signatures). But this needs to be handled carefully.

**Recommended approach: Optional, anonymous demographic tags**

After the data consent screen (only shown if user opted in to sharing), offer an optional profile:

> "This helps us build better models for different body types. All fields are optional and anonymous."

- **Age range** (not exact age): Under 18 / 18–29 / 30–39 / 40–49 / 50–59 / 60+
- **Height range**: Short / Medium / Tall (or cm brackets)
- **Biological sex**: Male / Female / Prefer not to say (relevant because it affects movement biomechanics)
- **Activity level**: Beginner / Intermediate / Advanced

**What NOT to collect:**
- Name (unnecessary — no accounts)
- Exact age or date of birth (age range is sufficient for ML)
- Email (no need without accounts)
- Location (irrelevant)
- Weight (useful for calorie estimates but too personal for v1 — can add later as optional)

**These demographic tags attach to the anonymous contributor ID, not to any personal identity.** They're useful for stratifying the ML training set (e.g., "does the model work well for people over 50?") but can't identify anyone.

**If the user didn't opt into data sharing, skip this screen entirely.** We don't collect demographics for users whose data stays on-device — there's no purpose for it.

---

## Monetisation Considerations

### Model: Free core + subscription for advanced features

All six exercises and the full progression program are free. The core workout experience — enrolment, scheduling, counting, rest timers, test days, level progression, Watch companion — ships free and stays free. This maximises the user base (important for ML data collection) and removes friction from the core value proposition.

**Premium (subscription):**
- Structured interleaving plans (smart weekly programming across exercises)
- Advanced analytics and stats (trends, volume charts, exercise comparisons)
- Future content (new exercises, kettlebell programs, weighted progressions)
- ML auto-counting when available
- Priority access to new features

**Why subscription over one-time IAP:**
- Ongoing costs: server storage for ML data pipeline, potential compute for model training
- Ongoing content: new programs, exercises, and features justify recurring revenue
- Subscription aligns with Apple's ecosystem and App Store economics

**Accounts:**
Accounts are not needed for v1 (no login, no premium tier, no cross-device sync). When the subscription tier launches (v1.1 or v2), accounts become necessary for:
- Verifying subscription status across devices
- Syncing progress via CloudKit (premium feature)
- Restoring purchases on new devices

The account system can use Sign in with Apple (zero friction, privacy-preserving, no password management). The data model should reserve space for an optional user account link, but v1 operates entirely without one.

### What this means for the data model

The SwiftData schema needs to support future monetisation without requiring migration:

```
Entity: UserEntitlement
  - productId: String          // StoreKit product identifier
  - purchaseDate: Date
  - expiresDate: Date?         // nil for lifetime purchases (if ever offered)
  - isActive: Bool             // computed from expiry + grace period

Entity: FeatureFlag
  - featureKey: String         // "interleaving_plans", "advanced_stats", "auto_counting"
  - requiredTier: String       // "free", "premium"

Entity: UserAccount (optional, v2)
  - appleUserId: String?       // Sign in with Apple identifier
  - createdAt: Date
  - contributorId: String      // links to anonymous ML data UUID
```

No exercise-level gating needed — all exercises are free. Feature flags gate premium capabilities only.

### What stays free forever
- All 6 exercises, all 3 levels, full progression
- Manual and post-set confirmation counting
- Rest timers (with per-exercise defaults)
- HealthKit integration
- Streak tracking
- Watch companion app
- Motion data contribution (value exchange — users contribute data, we provide the app)

---

## Visual Design

- Dark background (near-black) default
- Exercise accent colours: Push-Ups `#E8722A`, Squats `#0D9488`, Sit-Ups `#D4A017`, Pull-Ups `#DC2626`, Glute Bridges `#8B5CF6`, Dead Bugs `#16A34A`
- Giant monospaced numerals (tabular figures) for counts/timers
- SF Pro for labels
- Simple exercise silhouettes for icons

---

## Critical Path

### v1 (MVP)
- Program enrolment (choose exercises, start date, optional level placement)
- Today dashboard with independent exercise cards
- Per-exercise atomic workout sessions with two counting modes (real-time tap + post-set confirmation)
- Per-exercise rest timer defaults (45s–90s by exercise type)
- Test day flow with pass/fail and level unlock
- Independent scheduling with +1 day pushback
- Injury-aware conflict detection (test isolation, no double-testing)
- Companion Watch app (synced sessions, both counting modes, results sync)
- Raw sensor data collection (accel + gyro, both devices)
- Data consent flow with anonymous upload opt-in
- Anonymous central data upload (WiFi + charging, nightly batch)
- Optional anonymous demographic tags (for ML contributors only)
- HealthKit workout logging
- SwiftData persistence with monetisation-ready schema (entitlements, feature flags)
- Settings screen (rest timers, counting modes, data privacy, enrolled exercises)
- Basic Program overview with free level/day navigation
- Streak tracking (show-up-based definition)
- Privacy policy and App Store nutrition label

### v1.1
- History and stats
- Notifications
- Watch complications
- Exercise detail views
- Dashboard conflict warnings
- Inter-exercise optional rest timer (with usage tracking for future program design)

### v2+
- ML auto rep counting (trained from centrally collected data)
- Structured interleaving plans (premium feature)
- Advanced analytics (premium feature)
- Subscription tier with Sign in with Apple accounts
- Heart rate rest intelligence
- External workout streak awareness (HealthKit query)
- Post-program maintenance mode
- New exercise programs (kettlebell, weighted progressions — premium content)
- Today widget
- CloudKit sync (premium — cross-device progress)
- Training intensity preference (rest gap scaling)
- Cold storage migration for older ML data

---

## Resolved Decisions

1. **Enrolment at setup** — user chooses exercises
2. **Independent per-exercise scheduling** — +1 pushback, rest gaps preserved
3. **Injury-aware engine** — test isolation, no double-testing, muscle group awareness
4. **Watch as companion** — iPhone is source of truth
5. **Failed tests block progression** — retry after rest gap
6. **Two counting modes for MVP** — real-time tap (hands-free exercises) and post-set confirmation (hands-occupied exercises), with sensor data collection from day one
7. **Atomic exercise sessions** — return to dashboard between exercises
8. **Sync via WatchConnectivity** — `transferUserInfo` for schedule/results, `transferFile` for sensor data
9. **Central ML data collection** — anonymous sensor data uploaded with explicit opt-in consent, stored centrally for model training. Users told about local recording regardless.
10. **Streaks reward showing up** — at least one exercise completed on any scheduled training day maintains the streak; rest days never break it
11. **Per-exercise rest timer defaults** — scaled by muscular demand: 90s for squats/pull-ups, 60s push-ups, 75s glute bridges, 45s sit-ups/dead bugs
12. **Free level selection** — users can start at any level/day, with optional placement test for guidance
13. **Manual set completion only** — no auto-detect stillness for ending sets. Users may rest-pause mid-set and we don't want false triggers.
14. **Training intensity preference deferred** — default scheduling with manual pushback is sufficient for v1. Global rest gap scaling is a v2 feature.
15. **Inter-exercise rest timer** — offered as optional toggle (default off) with usage tracking to inform future program design.
16. **Upload on WiFi + charging, nightly** — minimises battery/bandwidth impact while keeping data reasonably fresh.
17. **No accounts, no PII** — no login, no name, no email. Zero friction to start. Demographics optional and anonymous, only for ML contributors.
18. **Settings in v1** — essential for rest timers, counting modes, data privacy, and exercise management.
19. **Monetisation-ready schema** — entitlements and feature flags in the data model from day one, even though v1 ships free. All exercises free; premium gates features not content.
20. **All exercises free** — premium subscription covers advanced features (interleaving plans, analytics, ML counting, future content). Core workout stays free forever.
21. **Subscription model** — ongoing costs (ML data storage, compute) justify recurring revenue. Accounts via Sign in with Apple added when subscription launches.
22. **Privacy policy scoped to app improvement** — "used to improve automatic rep counting in this app." No broad data licensing language. Re-consent if that changes.

---

## Open Questions

1. **App name?** Unnamed. Needs to work in the App Store, be searchable, convey structured progression (not generic fitness), and not conflict with existing apps.
2. **Subscription pricing?** Need to research comparable fitness app pricing in the AU App Store. Monthly vs annual vs both.
3. **When to introduce the premium tier?** At v1.1 launch (with stats and notifications) or at v2 (with ML counting and interleaving)? Later = more free users = more ML data, but delays revenue.
4. **Cold storage strategy for ML data?** Active data in Supabase/S3 for current training runs, then move to cold storage (S3 Glacier or equivalent) to reduce ongoing costs. Need a data lifecycle policy.
