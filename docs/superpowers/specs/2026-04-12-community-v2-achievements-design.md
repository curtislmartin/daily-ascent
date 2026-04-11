# Community v1.1 — Achievements, Lifetime Sync & Local Awards

Date: 2026-04-12

## Summary

Extend the community benchmarks feature with ~25 new achievements across four categories (time-of-day, seasonal, holiday, playful), add lifetime benchmark uploads, and wire up lifetime distribution percentile achievements. Most achievements are computed entirely client-side from local `CompletedSet` history.

## Design Principles

- **Easter eggs over pressure.** Seasonal, holiday, and playful achievements are hidden until earned — no ghost badges. They surface as delightful surprises.
- **Time-of-day badges are visible.** They hint at behaviour changes the user can pursue ("oh, Early Bird means before 6am").
- **All local-only achievements are deterministic.** No server round-trip needed. Evaluated after every workout completion.
- **Threshold of 10.** Time-of-day achievements require 10+ qualifying workouts, not just one accidental early session.

---

## New Achievement Categories

### Achievement Style Mapping

New entries in `achievementStyle(for:)`:

| Category key | SF Symbol | Colour |
|---|---|---|
| `time` | `clock.fill` | `.indigo` |
| `seasonal` | `leaf.fill` | `.mint` |
| `holiday` | `gift.fill` | `.red` |
| `fun` | `party.popper.fill` | `.pink` |

### Section Order in TrophyShelfView

Append after "Community":

```
("time", "Time of Day"),
("seasonal", "Seasonal"),
("holiday", "Holidays"),
("fun", "Fun"),
```

### Hidden Badge Behaviour

`BadgeDefinition` gains `hidden: Bool = false`.

In `TrophyShelfView.buildBadges()`, hidden badges are only included when the user has earned them. This means seasonal, holiday, and fun sections only appear once the user earns their first badge in that category.

---

## Time-of-Day Achievements

Computed from `CompletedSet.completedAt` hour component. Require 10+ distinct session dates matching the hour criteria.

| ID | Label | Trigger | Description |
|---|---|---|---|
| `time_early_bird` | Early Bird | 10+ sessions started before 6am | "The world is still sleeping" |
| `time_dawn_patrol` | Dawn Patrol | 10+ sessions started before 7am | "First light, first rep" |
| `time_5am_club` | 5am Club | 10+ sessions started before 5am | "Discipline has an alarm clock" |
| `time_lunch_legend` | Lunch Break Legend | 10+ sessions between 12pm-1pm | "Gains between meetings" |
| `time_night_owl` | Night Owl | 10+ sessions started after 9pm | "The gym never closes" |
| `time_all_hours` | Sunrise to Sunset | Sessions in all six 4-hour blocks | "Any hour is workout hour" |

**Counting rule:** Count distinct `Calendar.startOfDay(for: completedAt)` dates where at least one set falls in the qualifying hour range. This prevents a single long workout from counting multiple times.

**Sunrise to Sunset blocks:** 0-3, 4-7, 8-11, 12-15, 16-19, 20-23. Must have at least 1 workout in each block.

---

## Holiday Achievements

Computed client-side from `CompletedSet.sessionDate`. Detected by checking the session date against a fixed holiday calendar.

| ID | Label | Date(s) | Description |
|---|---|---|---|
| `holiday_new_year` | New Year, New You | Jan 1 | "Starting the year right" |
| `holiday_valentine` | Valentine's Flex | Feb 14 | "Self-love is the best love" |
| `holiday_leap_day` | Leap Day Legend | Feb 29 | "Once every four years — you showed up" |
| `holiday_st_patrick` | St. Patrick's Strength | Mar 17 | "Lucky? No, disciplined" |
| `holiday_easter` | Easter Riser | Easter Sunday (computed) | "Risen and repping" |
| `holiday_independence` | Independence Rep | Jul 4 | "Freedom to push harder" |
| `holiday_halloween` | Halloween Grind | Oct 31 | "No rest for the wicked" |
| `holiday_thanksgiving` | Turkey Burner | US Thanksgiving (computed) | "Earning the second plate" |
| `holiday_christmas` | Christmas Gains | Dec 25 | "Unwrapping potential" |
| `holiday_nye` | New Year's Eve Send-Off | Dec 31 | "Finishing strong" |
| `holiday_friday_13` | Friday the 13th | Any Friday the 13th | "Superstition? Never heard of it." |

**Variable-date holidays:**
- **Easter Sunday:** Computus algorithm (Anonymous Gregorian). Pure arithmetic, no lookup table needed.
- **US Thanksgiving:** Fourth Thursday of November. `Calendar` date arithmetic.
- **Friday the 13th:** Check `weekday == 6 && day == 13`.

**Uniqueness:** Holiday achievements are one-time unlocks (e.g., "Christmas Gains" unlocks on the first Christmas workout ever, not annually). The `Achievement.sessionDate` records which specific date triggered it.

---

## Seasonal Achievements

Computed client-side from `CompletedSet.sessionDate`. Count distinct workout dates in calendar ranges.

| ID | Label | Trigger | Description |
|---|---|---|---|
| `seasonal_january` | January Persistence | 20+ workouts in any January | "Most resolutions don't survive January. Yours did." |
| `seasonal_summer` | Summer Shape-Up | 50+ workouts in Jun-Aug of any year | "Summer body, built by summer" |
| `seasonal_winter` | Winter Warrior | 40+ workouts in Dec-Feb of any year span | "Cold outside, fire inside" |
| `seasonal_year_round` | Year-Round | 1+ workout in every calendar month of a single year | "No off-season" |

**Winter Warrior edge case:** Dec-Feb spans two calendar years. Check Dec of year N + Jan-Feb of year N+1 for each possible year.

---

## Playful / Fun Achievements

Computed client-side from local models. All hidden until earned.

| ID | Label | Trigger | Description |
|---|---|---|---|
| `fun_century_club` | Century Club | 100 total workouts (distinct session dates) | "Triple digits" |
| `fun_thousand_repper` | Thousand Repper | 1,000 lifetime reps of any single exercise | "A thousand times, and counting" |
| `fun_ten_thousand` | Ten Thousand | 10,000 total lifetime reps (all exercises) | "Dedication has a number" |
| `fun_full_roster` | Full Roster | Enrolled in all 9 exercises simultaneously | "No muscle left behind" |
| `fun_perfect_week` | Perfect Week | Every scheduled workout completed in a 7-day span | "Seven for seven" |
| `fun_triple_threat` | Triple Threat | 3 different exercises completed in one day | "Variety is strength" |
| `fun_five_a_day` | Five-a-Day | 5 different exercises in one day | "Overachiever (complimentary)" |
| `fun_plank_minutes` | Plank Minutes | 10 cumulative minutes of plank holds | "600 seconds of character" |
| `fun_metronome_master` | Metronome Master | 100 metronome-guided sets completed | "Rhythm and reps" |
| `fun_test_day_ace` | Test Day Ace | Passed 3 max-rep tests in a row (no failures between) | "Clutch performer" |
| `fun_level_up_trifecta` | Level Up Trifecta | Reached Level 2 in 3 different exercises | "Broad-based strength" |
| `fun_maxed_out` | Maxed Out | Reached Level 3 in any exercise | "Peak progression" |
| `fun_grand_master` | Grand Master | Reached Level 3 in all 9 exercises | "The summit of summits" |
| `fun_groundhog_day` | Groundhog Day | Same exercise, same reps, two days in a row | "Didn't he do this yesterday?" |

### Detection Notes

- **Century Club / Thousand Repper / Ten Thousand:** Count from `CompletedSet` aggregations.
- **Full Roster:** Check `ExerciseEnrolment` count where `isActive == true`. Triggered on `.workoutCompleted` (user just enrolled and completed their first session) and also when the checker runs.
- **Perfect Week:** For each 7-day window ending on the session date, check that all active enrolments with `nextScheduledDate` in that window were completed. Simplified: all active enrolments had at least one completed set that week.
- **Triple Threat / Five-a-Day:** Count distinct `exerciseId` values in `CompletedSet` where `sessionDate` matches today.
- **Plank Minutes:** Sum `setDurationSeconds` from `CompletedSet` where `exerciseId == "plank"`.
- **Metronome Master:** Count `CompletedSet` where `countingMode == .metronome`.
- **Test Day Ace:** Check last 3 test sets (`isTest == true`) are all `testPassed == true` with no `testPassed == false` between them.
- **Level Up Trifecta:** Count `ExerciseEnrolment` where `currentLevel >= 2`.
- **Maxed Out:** Any `ExerciseEnrolment` where `currentLevel >= 3`.
- **Grand Master:** All 9 exercises have `currentLevel >= 3` (or `currentLevel > 3` / completed).
- **Groundhog Day:** Find two consecutive calendar days where the same exercise was completed with the same `actualReps` total. Compare yesterday's session to today's.

---

## Lifetime Benchmark Upload

### New Method in CommunityBenchmarkService

`uploadLifetimeBenchmark(totalWorkouts:totalLifetimeReps:enrolledExerciseCount:)` — same fire-and-forget pattern as exercise/streak uploads.

### Trigger

On app foreground, check if 24h since last lifetime sync. Compute counts from local `CompletedSet` and `ExerciseEnrolment`, then upload.

**Implementation:** Add a `lastLifetimeSyncDate` to `CommunityDistributionCache` (or a separate `@AppStorage` key). Check in `inchApp.swift` via `scenePhase == .active`.

### Lifetime Percentile Achievements

Added to the existing `community` category (already visible in TrophyShelfView):

| ID | Label | Trigger | Description |
|---|---|---|---|
| `community_volume_machine` | Volume Machine | Lifetime reps ≥ P90 | "Top 10% by total volume" |
| `community_dedicated` | Dedicated | Total workouts ≥ P75 | "More dedicated than 75% of users" |
| `community_veteran` | Veteran | Total workouts ≥ P90 | "Top 10% by total workouts" |

These require fetched lifetime distributions. Checked when distributions are refreshed, same as existing community percentile achievements.

---

## AchievementChecker Changes

### Approach

All new local achievements are checked within the existing `.workoutCompleted` event handler. This is the natural trigger point — the user just finished an exercise, and we have access to `ModelContext` with all `CompletedSet` history.

No new event types are needed. The checker already fetches all `CompletedSet` records for other checks (session counts, PB). The new checks add queries to the same data.

### New Private Helper Methods

```
checkTimeOfDay(existingIds:sessionDate:context:into:)
checkHoliday(existingIds:sessionDate:context:into:)
checkSeasonal(existingIds:context:into:)
checkPlayful(existingIds:exerciseId:sessionDate:context:into:)
```

Each follows the existing pattern of `checkFullSet` and `checkTestGauntlet` — guard on existing IDs, query context, append to results.

### Lifetime Percentile Events

Add a new event case:
```swift
case communityLifetimePercentileUpdated(metricType: String, percentile: Int)
```

Checked when lifetime distributions are fetched. Awards `community_volume_machine`, `community_dedicated`, `community_veteran`.

---

## BadgeDefinition Changes

### New Property

```swift
let hidden: Bool  // default false
```

### New Static Badges

All time-of-day badges added to `staticBadges` with `hidden: false`.
All seasonal, holiday, and fun badges added with `hidden: true`.
Community lifetime badges (Volume Machine, Dedicated, Veteran) added with `hidden: false`.

---

## TrophyShelfView Changes

### Section Order

Add new entries:
```swift
("time", "Time of Day"),
("seasonal", "Seasonal"),
("holiday", "Holidays"),
("fun", "Fun"),
```

### Hidden Badge Filtering

In `buildBadges()`, after building the full list, the view already cross-references with earned achievements. For the grid display, filter: include badge if `!badge.hidden` OR the achievement exists in the earned set. Hidden sections that have zero earned badges don't appear at all (the existing `compactMap` with `guard !matching.isEmpty` handles this).

---

## AchievementBadgeCircle Changes

Add new category styles in `achievementStyle(for:)`.

---

## Files Summary

| Action | File |
|---|---|
| **Modify** | `Shared/Sources/InchShared/Engine/AchievementChecker.swift` — new helper methods, new event case |
| **Modify** | `inch/inch/Components/BadgeDefinition.swift` — `hidden` property, ~25 new badges |
| **Modify** | `inch/inch/Components/AchievementBadgeCircle.swift` — 4 new category styles |
| **Modify** | `inch/inch/Features/History/TrophyShelfView.swift` — new sections, hidden filtering |
| **Modify** | `inch/inch/Services/CommunityBenchmarkService.swift` — lifetime upload method |
| **Modify** | `inch/inch/inchApp.swift` — lifetime sync on foreground |
| **Create** | `Shared/Sources/InchShared/Engine/HolidayCalendar.swift` — Easter/Thanksgiving computation |

## Verification

1. Build succeeds with no errors
2. TrophyShelfView shows Time of Day section with ghost badges, no Seasonal/Holiday/Fun sections visible
3. Complete a workout — new achievement checks run without crash
4. Simulate a holiday date — holiday achievement unlocks and Holiday section appears
5. Simulate enough workout history — playful achievements unlock correctly
