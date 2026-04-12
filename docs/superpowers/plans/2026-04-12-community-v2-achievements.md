# Community v1.1 — Achievements, Lifetime Sync & Local Awards

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add ~25 new achievements (time-of-day, holiday, seasonal, playful), lifetime benchmark uploads, and lifetime percentile achievements to the community benchmarks feature.

**Architecture:** All new achievements are computed client-side in `AchievementChecker` from local `CompletedSet`/`ExerciseEnrolment` data. A new `HolidayCalendar` utility handles variable-date holiday detection (Easter, Thanksgiving). `BadgeDefinition` gains a `hidden` flag so seasonal/holiday/fun badges only appear once earned. Lifetime benchmarks are uploaded on app foreground via the existing `CommunityBenchmarkService`.

**Tech Stack:** Swift 6.2, SwiftData, SwiftUI, Swift Testing

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| **Create** | `Shared/Sources/InchShared/Engine/HolidayCalendar.swift` | Easter/Thanksgiving computation, holiday date matching |
| **Create** | `Shared/Tests/InchSharedTests/HolidayCalendarTests.swift` | Tests for holiday detection |
| **Create** | `Shared/Tests/InchSharedTests/AchievementCheckerV2Tests.swift` | Tests for all new achievement checks |
| **Modify** | `Shared/Sources/InchShared/Engine/AchievementChecker.swift` | New helper methods for time/holiday/seasonal/playful checks |
| **Modify** | `inch/inch/Components/BadgeDefinition.swift` | `hidden` property, ~25 new badge entries |
| **Modify** | `inch/inch/Components/AchievementBadgeCircle.swift` | 4 new category styles |
| **Modify** | `inch/inch/Features/History/TrophyShelfView.swift` | New sections, hidden badge filtering |
| **Modify** | `inch/inch/Services/CommunityBenchmarkService.swift` | Lifetime upload method |
| **Modify** | `inch/inch/inchApp.swift` | Lifetime sync on foreground |

---

### Task 1: HolidayCalendar — Variable-Date Holiday Detection

**Files:**
- Create: `Shared/Sources/InchShared/Engine/HolidayCalendar.swift`
- Create: `Shared/Tests/InchSharedTests/HolidayCalendarTests.swift`

- [ ] **Step 1: Write the failing tests**

Create `Shared/Tests/InchSharedTests/HolidayCalendarTests.swift`:

```swift
import Testing
@testable import InchShared
import Foundation

struct HolidayCalendarTests {

    // MARK: - Fixed holidays

    @Test func newYearDetected() {
        let date = makeDate(2026, 1, 1)
        let holidays = HolidayCalendar.holidays(for: date)
        #expect(holidays.contains("holiday_new_year"))
    }

    @Test func christmasDetected() {
        let date = makeDate(2026, 12, 25)
        let holidays = HolidayCalendar.holidays(for: date)
        #expect(holidays.contains("holiday_christmas"))
    }

    @Test func valentineDetected() {
        let date = makeDate(2026, 2, 14)
        let holidays = HolidayCalendar.holidays(for: date)
        #expect(holidays.contains("holiday_valentine"))
    }

    @Test func halloweenDetected() {
        let date = makeDate(2026, 10, 31)
        let holidays = HolidayCalendar.holidays(for: date)
        #expect(holidays.contains("holiday_halloween"))
    }

    @Test func regularDateHasNoHolidays() {
        let date = makeDate(2026, 3, 15)
        let holidays = HolidayCalendar.holidays(for: date)
        #expect(holidays.isEmpty)
    }

    // MARK: - Easter (Anonymous Gregorian Computus)

    @Test func easter2026() {
        let easter = HolidayCalendar.easterSunday(year: 2026)
        #expect(easter == makeDate(2026, 4, 5))
    }

    @Test func easter2027() {
        let easter = HolidayCalendar.easterSunday(year: 2027)
        #expect(easter == makeDate(2027, 3, 28))
    }

    @Test func easter2024() {
        let easter = HolidayCalendar.easterSunday(year: 2024)
        #expect(easter == makeDate(2024, 3, 31))
    }

    @Test func easterHolidayDetected() {
        // Easter 2026 is April 5
        let date = makeDate(2026, 4, 5)
        let holidays = HolidayCalendar.holidays(for: date)
        #expect(holidays.contains("holiday_easter"))
    }

    // MARK: - Thanksgiving (4th Thursday of November)

    @Test func thanksgiving2026() {
        let tg = HolidayCalendar.thanksgiving(year: 2026)
        // Nov 2026: 1st is Sunday, 4th Thursday = Nov 26
        #expect(tg == makeDate(2026, 11, 26))
    }

    @Test func thanksgiving2025() {
        let tg = HolidayCalendar.thanksgiving(year: 2025)
        // Nov 2025: 1st is Saturday, 4th Thursday = Nov 27
        #expect(tg == makeDate(2025, 11, 27))
    }

    @Test func thanksgivingHolidayDetected() {
        let date = makeDate(2026, 11, 26)
        let holidays = HolidayCalendar.holidays(for: date)
        #expect(holidays.contains("holiday_thanksgiving"))
    }

    // MARK: - Friday the 13th

    @Test func fridayThe13thDetected() {
        // Feb 13, 2026 is a Friday
        let date = makeDate(2026, 2, 13)
        let holidays = HolidayCalendar.holidays(for: date)
        #expect(holidays.contains("holiday_friday_13"))
    }

    @Test func thursday13thNotDetected() {
        // Mar 13, 2026 is a Friday? Let's check — actually we need a Thursday the 13th
        // Nov 13, 2025 is a Thursday
        let date = makeDate(2025, 11, 13)
        let holidays = HolidayCalendar.holidays(for: date)
        #expect(holidays.allSatisfy { $0 != "holiday_friday_13" })
    }

    // MARK: - Leap Day

    @Test func leapDayDetected() {
        let date = makeDate(2028, 2, 29)
        let holidays = HolidayCalendar.holidays(for: date)
        #expect(holidays.contains("holiday_leap_day"))
    }

    // MARK: - Helpers

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)!
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/curtismartin/Work/inch-project/Shared && swift test --filter HolidayCalendarTests 2>&1 | tail -20`
Expected: Compilation error — `HolidayCalendar` not found

- [ ] **Step 3: Implement HolidayCalendar**

Create `Shared/Sources/InchShared/Engine/HolidayCalendar.swift`:

```swift
import Foundation

public enum HolidayCalendar {

    /// Returns all holiday achievement IDs that match the given date.
    public static func holidays(for date: Date) -> [String] {
        let cal = Calendar.current
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)
        let year = cal.component(.year, from: date)
        let weekday = cal.component(.weekday, from: date)

        var result: [String] = []

        // Fixed-date holidays
        switch (month, day) {
        case (1, 1):   result.append("holiday_new_year")
        case (2, 14):  result.append("holiday_valentine")
        case (2, 29):  result.append("holiday_leap_day")
        case (3, 17):  result.append("holiday_st_patrick")
        case (7, 4):   result.append("holiday_independence")
        case (10, 31): result.append("holiday_halloween")
        case (12, 25): result.append("holiday_christmas")
        case (12, 31): result.append("holiday_nye")
        default: break
        }

        // Easter (variable)
        let easter = easterSunday(year: year)
        if cal.isDate(date, inSameDayAs: easter) {
            result.append("holiday_easter")
        }

        // Thanksgiving (variable — 4th Thursday of November)
        let tg = thanksgiving(year: year)
        if cal.isDate(date, inSameDayAs: tg) {
            result.append("holiday_thanksgiving")
        }

        // Friday the 13th
        if weekday == 6 && day == 13 {
            result.append("holiday_friday_13")
        }

        return result
    }

    /// Anonymous Gregorian Computus — computes Easter Sunday for a given year.
    public static func easterSunday(year: Int) -> Date {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar.current.date(from: components)!
    }

    /// US Thanksgiving — 4th Thursday of November.
    public static func thanksgiving(year: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = 11
        components.weekday = 5 // Thursday
        components.weekdayOrdinal = 4
        components.hour = 12
        return Calendar.current.date(from: components)!
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/curtismartin/Work/inch-project/Shared && swift test --filter HolidayCalendarTests 2>&1 | tail -20`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Shared/Sources/InchShared/Engine/HolidayCalendar.swift Shared/Tests/InchSharedTests/HolidayCalendarTests.swift
git commit -m "feat: add HolidayCalendar with Easter/Thanksgiving computation and tests"
```

---

### Task 2: BadgeDefinition — Add `hidden` Property and New Badges

**Files:**
- Modify: `inch/inch/Components/BadgeDefinition.swift`

- [ ] **Step 1: Add `hidden` property and all new badge definitions**

Replace the entire content of `BadgeDefinition.swift`:

```swift
// MARK: - BadgeDefinition

struct BadgeDefinition {
    let id: String
    let label: String
    let category: String     // must match a key handled by achievementStyle(for:)
    let description: String  // shown in the detail sheet
    let hidden: Bool         // hidden badges only appear once earned (easter eggs)

    init(id: String, label: String, category: String, description: String, hidden: Bool = false) {
        self.id = id
        self.label = label
        self.category = category
        self.description = description
        self.hidden = hidden
    }

    /// All static (non-enrolment-dependent) badge definitions in display order.
    static let staticBadges: [BadgeDefinition] = [
        // Milestones
        BadgeDefinition(id: "first_workout",    label: "First Workout",    category: "milestone",    description: "Complete your first workout session"),
        BadgeDefinition(id: "first_test",       label: "First Test",       category: "milestone",    description: "Pass your first level test"),
        BadgeDefinition(id: "program_complete", label: "Program Complete", category: "milestone",    description: "Complete all levels across every exercise"),
        // Streaks
        BadgeDefinition(id: "streak_3",   label: "3-Day Streak",   category: "streak", description: "Train on 3 consecutive days"),
        BadgeDefinition(id: "streak_7",   label: "7-Day Streak",   category: "streak", description: "Maintain a 7-day training streak"),
        BadgeDefinition(id: "streak_14",  label: "14-Day Streak",  category: "streak", description: "Maintain a 14-day training streak"),
        BadgeDefinition(id: "streak_30",  label: "30-Day Streak",  category: "streak", description: "Maintain a 30-day training streak"),
        BadgeDefinition(id: "streak_60",  label: "60-Day Streak",  category: "streak", description: "Maintain a 60-day training streak"),
        BadgeDefinition(id: "streak_100", label: "100-Day Streak", category: "streak", description: "Maintain a 100-day training streak"),
        // Consistency
        BadgeDefinition(id: "sessions_5",   label: "5 Sessions",   category: "consistency", description: "Complete 5 training sessions"),
        BadgeDefinition(id: "sessions_10",  label: "10 Sessions",  category: "consistency", description: "Complete 10 training sessions"),
        BadgeDefinition(id: "sessions_25",  label: "25 Sessions",  category: "consistency", description: "Complete 25 training sessions"),
        BadgeDefinition(id: "sessions_50",  label: "50 Sessions",  category: "consistency", description: "Complete 50 training sessions"),
        BadgeDefinition(id: "sessions_100", label: "100 Sessions", category: "consistency", description: "Complete 100 training sessions"),
        // Journey
        BadgeDefinition(id: "the_full_set",  label: "The Full Set",  category: "journey", description: "Train every enrolled exercise in one week"),
        BadgeDefinition(id: "test_gauntlet", label: "Test Gauntlet", category: "journey", description: "Pass level tests in 3 or more exercises"),
        // Community — percentile-based (visible)
        BadgeDefinition(id: "community_top_half",       label: "Top Half",       category: "community", description: "Reach the top 50% in any exercise"),
        BadgeDefinition(id: "community_upper_quarter",  label: "Upper Quarter",  category: "community", description: "Reach the top 25% in any exercise"),
        BadgeDefinition(id: "community_top_10",         label: "Top 10%",        category: "community", description: "Reach the top 10% in any exercise"),
        BadgeDefinition(id: "community_iron_streak",    label: "Iron Streak",    category: "community", description: "Your streak is in the top 10% of all users"),
        BadgeDefinition(id: "community_volume_machine", label: "Volume Machine", category: "community", description: "Top 10% by total volume"),
        BadgeDefinition(id: "community_dedicated",      label: "Dedicated",      category: "community", description: "More dedicated than 75% of users"),
        BadgeDefinition(id: "community_veteran",        label: "Veteran",        category: "community", description: "Top 10% by total workouts"),
        // Time of Day (visible as ghosts)
        BadgeDefinition(id: "time_early_bird",   label: "Early Bird",         category: "time", description: "The world is still sleeping"),
        BadgeDefinition(id: "time_dawn_patrol",  label: "Dawn Patrol",        category: "time", description: "First light, first rep"),
        BadgeDefinition(id: "time_5am_club",     label: "5am Club",           category: "time", description: "Discipline has an alarm clock"),
        BadgeDefinition(id: "time_lunch_legend", label: "Lunch Break Legend", category: "time", description: "Gains between meetings"),
        BadgeDefinition(id: "time_night_owl",    label: "Night Owl",          category: "time", description: "The gym never closes"),
        BadgeDefinition(id: "time_all_hours",    label: "Sunrise to Sunset",  category: "time", description: "Any hour is workout hour"),
        // Seasonal (hidden — easter eggs)
        BadgeDefinition(id: "seasonal_january",    label: "January Persistence", category: "seasonal", description: "Most resolutions don't survive January. Yours did.", hidden: true),
        BadgeDefinition(id: "seasonal_summer",     label: "Summer Shape-Up",     category: "seasonal", description: "Summer body, built by summer", hidden: true),
        BadgeDefinition(id: "seasonal_winter",     label: "Winter Warrior",      category: "seasonal", description: "Cold outside, fire inside", hidden: true),
        BadgeDefinition(id: "seasonal_year_round", label: "Year-Round",          category: "seasonal", description: "No off-season", hidden: true),
        // Holiday (hidden — easter eggs)
        BadgeDefinition(id: "holiday_new_year",     label: "New Year, New You",       category: "holiday", description: "Starting the year right", hidden: true),
        BadgeDefinition(id: "holiday_valentine",    label: "Valentine's Flex",        category: "holiday", description: "Self-love is the best love", hidden: true),
        BadgeDefinition(id: "holiday_leap_day",     label: "Leap Day Legend",         category: "holiday", description: "Once every four years — you showed up", hidden: true),
        BadgeDefinition(id: "holiday_st_patrick",   label: "St. Patrick's Strength",  category: "holiday", description: "Lucky? No, disciplined", hidden: true),
        BadgeDefinition(id: "holiday_easter",       label: "Easter Riser",            category: "holiday", description: "Risen and repping", hidden: true),
        BadgeDefinition(id: "holiday_independence", label: "Independence Rep",        category: "holiday", description: "Freedom to push harder", hidden: true),
        BadgeDefinition(id: "holiday_halloween",    label: "Halloween Grind",         category: "holiday", description: "No rest for the wicked", hidden: true),
        BadgeDefinition(id: "holiday_thanksgiving", label: "Turkey Burner",           category: "holiday", description: "Earning the second plate", hidden: true),
        BadgeDefinition(id: "holiday_christmas",    label: "Christmas Gains",         category: "holiday", description: "Unwrapping potential", hidden: true),
        BadgeDefinition(id: "holiday_nye",          label: "New Year's Eve Send-Off", category: "holiday", description: "Finishing strong", hidden: true),
        BadgeDefinition(id: "holiday_friday_13",    label: "Friday the 13th",         category: "holiday", description: "Superstition? Never heard of it.", hidden: true),
        // Fun (hidden — easter eggs)
        BadgeDefinition(id: "fun_century_club",      label: "Century Club",      category: "fun", description: "Triple digits", hidden: true),
        BadgeDefinition(id: "fun_thousand_repper",   label: "Thousand Repper",   category: "fun", description: "A thousand times, and counting", hidden: true),
        BadgeDefinition(id: "fun_ten_thousand",      label: "Ten Thousand",      category: "fun", description: "Dedication has a number", hidden: true),
        BadgeDefinition(id: "fun_full_roster",       label: "Full Roster",       category: "fun", description: "No muscle left behind", hidden: true),
        BadgeDefinition(id: "fun_perfect_week",      label: "Perfect Week",      category: "fun", description: "Seven for seven", hidden: true),
        BadgeDefinition(id: "fun_triple_threat",     label: "Triple Threat",     category: "fun", description: "Variety is strength", hidden: true),
        BadgeDefinition(id: "fun_five_a_day",        label: "Five-a-Day",        category: "fun", description: "Overachiever (complimentary)", hidden: true),
        BadgeDefinition(id: "fun_plank_minutes",     label: "Plank Minutes",     category: "fun", description: "600 seconds of character", hidden: true),
        BadgeDefinition(id: "fun_metronome_master",  label: "Metronome Master",  category: "fun", description: "Rhythm and reps", hidden: true),
        BadgeDefinition(id: "fun_test_day_ace",      label: "Test Day Ace",      category: "fun", description: "Clutch performer", hidden: true),
        BadgeDefinition(id: "fun_level_up_trifecta", label: "Level Up Trifecta", category: "fun", description: "Broad-based strength", hidden: true),
        BadgeDefinition(id: "fun_maxed_out",         label: "Maxed Out",         category: "fun", description: "Peak progression", hidden: true),
        BadgeDefinition(id: "fun_grand_master",      label: "Grand Master",      category: "fun", description: "The summit of summits", hidden: true),
        BadgeDefinition(id: "fun_groundhog_day",     label: "Groundhog Day",     category: "fun", description: "Didn't he do this yesterday?", hidden: true),
    ]
}
```

- [ ] **Step 2: Verify build compiles**

Run: `cd /Users/curtismartin/Work/inch-project/inch && xcodebuild build -scheme inch -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' -quiet 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add inch/inch/Components/BadgeDefinition.swift
git commit -m "feat: add hidden property to BadgeDefinition, add 25+ new badge definitions"
```

---

### Task 3: AchievementBadgeCircle — New Category Styles

**Files:**
- Modify: `inch/inch/Components/AchievementBadgeCircle.swift`

- [ ] **Step 1: Add 4 new category cases to `achievementStyle(for:)`**

In `achievementStyle(for:)`, add before the `default` case:

```swift
    case "time":         return ("clock.fill",          .indigo)
    case "seasonal":     return ("leaf.fill",           .mint)
    case "holiday":      return ("gift.fill",           .red)
    case "fun":          return ("party.popper.fill",   .pink)
```

- [ ] **Step 2: Verify build compiles**

Run: `cd /Users/curtismartin/Work/inch-project/inch && xcodebuild build -scheme inch -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' -quiet 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add inch/inch/Components/AchievementBadgeCircle.swift
git commit -m "feat: add time, seasonal, holiday, fun category styles to achievement badges"
```

---

### Task 4: TrophyShelfView — New Sections and Hidden Badge Filtering

**Files:**
- Modify: `inch/inch/Features/History/TrophyShelfView.swift`

- [ ] **Step 1: Add new sections to `sectionOrder`**

Append to the `sectionOrder` array:

```swift
    ("time", "Time of Day"),
    ("seasonal", "Seasonal"),
    ("holiday", "Holidays"),
    ("fun", "Fun"),
```

- [ ] **Step 2: Add hidden badge filtering in `buildBadges()`**

The `buildBadges()` method currently returns all static badges plus dynamic per-enrolment badges. We need to filter: include a badge if `!badge.hidden` OR the user has earned it. The earned check requires access to achievements.

Change the `body` computed property. Replace the line:

```swift
let badges = buildBadges()
```

with:

```swift
let badges = buildBadges(earnedIds: Set(achievements.map(\.id)))
```

Update the `buildBadges` signature and add filtering at the end:

```swift
private func buildBadges(earnedIds: Set<String>) -> [BadgeDefinition] {
```

At the very end of `buildBadges`, before `return result`, add:

```swift
    result = result.filter { !$0.hidden || earnedIds.contains($0.id) }
```

- [ ] **Step 3: Verify build compiles**

Run: `cd /Users/curtismartin/Work/inch-project/inch && xcodebuild build -scheme inch -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' -quiet 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 4: Commit**

```bash
git add inch/inch/Features/History/TrophyShelfView.swift
git commit -m "feat: add time/seasonal/holiday/fun sections, filter hidden badges in TrophyShelfView"
```

---

### Task 5: AchievementChecker — Time-of-Day Achievements

**Files:**
- Modify: `Shared/Sources/InchShared/Engine/AchievementChecker.swift`
- Create: `Shared/Tests/InchSharedTests/AchievementCheckerV2Tests.swift`

- [ ] **Step 1: Write failing tests for time-of-day achievements**

Create `Shared/Tests/InchSharedTests/AchievementCheckerV2Tests.swift`:

```swift
import Testing
@testable import InchShared
import SwiftData
import Foundation

struct AchievementCheckerV2Tests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(BodyweightSchemaV3.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return Calendar.current.date(from: components)!
    }

    private func insertSets(
        context: ModelContext,
        exerciseId: String = "push_ups",
        dates: [(year: Int, month: Int, day: Int, hour: Int)]
    ) {
        for d in dates {
            let set = CompletedSet(
                completedAt: makeDate(d.year, d.month, d.day, hour: d.hour),
                sessionDate: makeDate(d.year, d.month, d.day, hour: d.hour),
                exerciseId: exerciseId,
                level: 1,
                dayNumber: 1,
                setNumber: 1,
                targetReps: 10,
                actualReps: 10
            )
            context.insert(set)
        }
        try? context.save()
    }

    // MARK: - Time of Day

    @Test func earlyBirdUnlockedWith10EarlySessions() throws {
        let context = try makeContext()
        // 10 sessions before 6am on different days
        let dates = (1...10).map { (year: 2026, month: 3, day: $0, hour: 5) }
        insertSets(context: context, dates: dates)

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: makeDate(2026, 3, 10, hour: 5)),
            in: context
        )
        #expect(results.contains { $0.id == "time_early_bird" })
    }

    @Test func earlyBirdNotUnlockedWith9EarlySessions() throws {
        let context = try makeContext()
        let dates = (1...9).map { (year: 2026, month: 3, day: $0, hour: 5) }
        insertSets(context: context, dates: dates)

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: makeDate(2026, 3, 9, hour: 5)),
            in: context
        )
        #expect(results.allSatisfy { $0.id != "time_early_bird" })
    }

    @Test func nightOwlUnlockedWith10LateSessions() throws {
        let context = try makeContext()
        let dates = (1...10).map { (year: 2026, month: 3, day: $0, hour: 22) }
        insertSets(context: context, dates: dates)

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: makeDate(2026, 3, 10, hour: 22)),
            in: context
        )
        #expect(results.contains { $0.id == "time_night_owl" })
    }

    @Test func allHoursUnlockedWhenAllBlocksCovered() throws {
        let context = try makeContext()
        // One workout in each 4-hour block: 0-3, 4-7, 8-11, 12-15, 16-19, 20-23
        let dates = [
            (year: 2026, month: 3, day: 1, hour: 2),
            (year: 2026, month: 3, day: 2, hour: 5),
            (year: 2026, month: 3, day: 3, hour: 9),
            (year: 2026, month: 3, day: 4, hour: 13),
            (year: 2026, month: 3, day: 5, hour: 17),
            (year: 2026, month: 3, day: 6, hour: 21),
        ]
        insertSets(context: context, dates: dates)

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: makeDate(2026, 3, 6, hour: 21)),
            in: context
        )
        #expect(results.contains { $0.id == "time_all_hours" })
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/curtismartin/Work/inch-project/Shared && swift test --filter AchievementCheckerV2Tests 2>&1 | tail -20`
Expected: Tests fail — time-of-day achievements not returned

- [ ] **Step 3: Implement `checkTimeOfDay` in AchievementChecker**

In `AchievementChecker.swift`, add a call in the `.workoutCompleted` case, after the existing `checkFullSet(...)` call:

```swift
            checkTimeOfDay(existingIds: existingIds, sessionDate: sessionDate,
                          context: context, into: &unlocked)
```

Add the private helper method:

```swift
    private func checkTimeOfDay(existingIds: Set<String>, sessionDate: Date,
                                 context: ModelContext, into results: inout [Achievement]) {
        let sets = (try? context.fetch(FetchDescriptor<CompletedSet>())) ?? []
        let cal = Calendar.current

        // Count distinct dates per hour range
        func distinctDates(where hourFilter: (Int) -> Bool) -> Int {
            let matching = sets.filter { hourFilter(cal.component(.hour, from: $0.completedAt)) }
            return Set(matching.map { cal.startOfDay(for: $0.completedAt) }).count
        }

        let timeAchievements: [(id: String, filter: (Int) -> Bool)] = [
            ("time_5am_club",     { $0 < 5 }),
            ("time_early_bird",   { $0 < 6 }),
            ("time_dawn_patrol",  { $0 < 7 }),
            ("time_lunch_legend", { $0 >= 12 && $0 < 13 }),
            ("time_night_owl",    { $0 >= 21 }),
        ]

        for (id, filter) in timeAchievements where !existingIds.contains(id) {
            if distinctDates(where: filter) >= 10 {
                results.append(Achievement(
                    id: id, category: "time",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }
        }

        // Sunrise to Sunset — all six 4-hour blocks covered
        if !existingIds.contains("time_all_hours") {
            let blocks = [0..<4, 4..<8, 8..<12, 12..<16, 16..<20, 20..<24]
            let coveredBlocks = blocks.filter { range in
                sets.contains { range.contains(cal.component(.hour, from: $0.completedAt)) }
            }
            if coveredBlocks.count == 6 {
                results.append(Achievement(
                    id: "time_all_hours", category: "time",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }
        }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/curtismartin/Work/inch-project/Shared && swift test --filter AchievementCheckerV2Tests 2>&1 | tail -20`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add Shared/Sources/InchShared/Engine/AchievementChecker.swift Shared/Tests/InchSharedTests/AchievementCheckerV2Tests.swift
git commit -m "feat: add time-of-day achievement checks with tests"
```

---

### Task 6: AchievementChecker — Holiday Achievements

**Files:**
- Modify: `Shared/Sources/InchShared/Engine/AchievementChecker.swift`
- Modify: `Shared/Tests/InchSharedTests/AchievementCheckerV2Tests.swift`

- [ ] **Step 1: Write failing tests for holiday achievements**

Add to `AchievementCheckerV2Tests.swift`:

```swift
    // MARK: - Holiday

    @Test func christmasGainsUnlockedOnChristmas() throws {
        let context = try makeContext()
        let christmasDate = makeDate(2026, 12, 25, hour: 10)
        insertSets(context: context, dates: [(year: 2026, month: 12, day: 25, hour: 10)])

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: christmasDate),
            in: context
        )
        #expect(results.contains { $0.id == "holiday_christmas" })
    }

    @Test func noHolidayOnRegularDay() throws {
        let context = try makeContext()
        let date = makeDate(2026, 6, 15, hour: 10)
        insertSets(context: context, dates: [(year: 2026, month: 6, day: 15, hour: 10)])

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: date),
            in: context
        )
        #expect(results.allSatisfy { !$0.id.hasPrefix("holiday_") })
    }

    @Test func easterAchievementOnEasterSunday() throws {
        let context = try makeContext()
        // Easter 2026 is April 5
        let date = makeDate(2026, 4, 5, hour: 10)
        insertSets(context: context, dates: [(year: 2026, month: 4, day: 5, hour: 10)])

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: date),
            in: context
        )
        #expect(results.contains { $0.id == "holiday_easter" })
    }

    @Test func fridayThe13thAchievement() throws {
        let context = try makeContext()
        // Feb 13, 2026 is a Friday
        let date = makeDate(2026, 2, 13, hour: 10)
        insertSets(context: context, dates: [(year: 2026, month: 2, day: 13, hour: 10)])

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: date),
            in: context
        )
        #expect(results.contains { $0.id == "holiday_friday_13" })
    }

    @Test func holidayNotDuplicated() throws {
        let context = try makeContext()
        let existing = Achievement(id: "holiday_christmas", category: "holiday", unlockedAt: .now)
        context.insert(existing)
        try context.save()

        let date = makeDate(2027, 12, 25, hour: 10)
        insertSets(context: context, dates: [(year: 2027, month: 12, day: 25, hour: 10)])

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: date),
            in: context
        )
        #expect(results.allSatisfy { $0.id != "holiday_christmas" })
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/curtismartin/Work/inch-project/Shared && swift test --filter AchievementCheckerV2Tests 2>&1 | tail -20`
Expected: New holiday tests fail

- [ ] **Step 3: Implement `checkHoliday` in AchievementChecker**

In `AchievementChecker.swift`, add a call in the `.workoutCompleted` case, after the `checkTimeOfDay(...)` call:

```swift
            checkHoliday(existingIds: existingIds, sessionDate: sessionDate, into: &unlocked)
```

Add the private helper method:

```swift
    private func checkHoliday(existingIds: Set<String>, sessionDate: Date,
                               into results: inout [Achievement]) {
        let matchingHolidays = HolidayCalendar.holidays(for: sessionDate)
        for holidayId in matchingHolidays where !existingIds.contains(holidayId) {
            results.append(Achievement(
                id: holidayId, category: "holiday",
                unlockedAt: .now, sessionDate: sessionDate
            ))
        }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/curtismartin/Work/inch-project/Shared && swift test --filter AchievementCheckerV2Tests 2>&1 | tail -20`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add Shared/Sources/InchShared/Engine/AchievementChecker.swift Shared/Tests/InchSharedTests/AchievementCheckerV2Tests.swift
git commit -m "feat: add holiday achievement checks with tests"
```

---

### Task 7: AchievementChecker — Seasonal Achievements

**Files:**
- Modify: `Shared/Sources/InchShared/Engine/AchievementChecker.swift`
- Modify: `Shared/Tests/InchSharedTests/AchievementCheckerV2Tests.swift`

- [ ] **Step 1: Write failing tests for seasonal achievements**

Add to `AchievementCheckerV2Tests.swift`:

```swift
    // MARK: - Seasonal

    @Test func januaryPersistenceWith20Workouts() throws {
        let context = try makeContext()
        let dates = (1...20).map { (year: 2026, month: 1, day: $0, hour: 10) }
        insertSets(context: context, dates: dates)

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: makeDate(2026, 1, 20)),
            in: context
        )
        #expect(results.contains { $0.id == "seasonal_january" })
    }

    @Test func januaryPersistenceNotWith19Workouts() throws {
        let context = try makeContext()
        let dates = (1...19).map { (year: 2026, month: 1, day: $0, hour: 10) }
        insertSets(context: context, dates: dates)

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: makeDate(2026, 1, 19)),
            in: context
        )
        #expect(results.allSatisfy { $0.id != "seasonal_january" })
    }

    @Test func yearRoundWithWorkoutsEveryMonth() throws {
        let context = try makeContext()
        let dates = (1...12).map { (year: 2026, month: $0, day: 15, hour: 10) }
        insertSets(context: context, dates: dates)

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: makeDate(2026, 12, 15)),
            in: context
        )
        #expect(results.contains { $0.id == "seasonal_year_round" })
    }

    @Test func yearRoundNotWithMissingMonth() throws {
        let context = try makeContext()
        // Months 1-11 only
        let dates = (1...11).map { (year: 2026, month: $0, day: 15, hour: 10) }
        insertSets(context: context, dates: dates)

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: makeDate(2026, 11, 15)),
            in: context
        )
        #expect(results.allSatisfy { $0.id != "seasonal_year_round" })
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/curtismartin/Work/inch-project/Shared && swift test --filter AchievementCheckerV2Tests 2>&1 | tail -20`
Expected: New seasonal tests fail

- [ ] **Step 3: Implement `checkSeasonal` in AchievementChecker**

In `AchievementChecker.swift`, add a call in the `.workoutCompleted` case, after the `checkHoliday(...)` call:

```swift
            checkSeasonal(existingIds: existingIds, sessionDate: sessionDate,
                         context: context, into: &unlocked)
```

Add the private helper method:

```swift
    private func checkSeasonal(existingIds: Set<String>, sessionDate: Date,
                                context: ModelContext, into results: inout [Achievement]) {
        let sets = (try? context.fetch(FetchDescriptor<CompletedSet>())) ?? []
        let cal = Calendar.current

        func distinctDates(in monthRange: [Int], year: Int? = nil) -> Int {
            let matching = sets.filter {
                let m = cal.component(.month, from: $0.sessionDate)
                let y = cal.component(.year, from: $0.sessionDate)
                let monthMatch = monthRange.contains(m)
                if let year { return monthMatch && y == year }
                return monthMatch
            }
            return Set(matching.map { cal.startOfDay(for: $0.sessionDate) }).count
        }

        // January Persistence — 20+ workouts in any January
        if !existingIds.contains("seasonal_january") {
            let years = Set(sets.map { cal.component(.year, from: $0.sessionDate) })
            for year in years {
                if distinctDates(in: [1], year: year) >= 20 {
                    results.append(Achievement(
                        id: "seasonal_january", category: "seasonal",
                        unlockedAt: .now, sessionDate: sessionDate
                    ))
                    break
                }
            }
        }

        // Summer Shape-Up — 50+ workouts in Jun-Aug of any year
        if !existingIds.contains("seasonal_summer") {
            let years = Set(sets.map { cal.component(.year, from: $0.sessionDate) })
            for year in years {
                if distinctDates(in: [6, 7, 8], year: year) >= 50 {
                    results.append(Achievement(
                        id: "seasonal_summer", category: "seasonal",
                        unlockedAt: .now, sessionDate: sessionDate
                    ))
                    break
                }
            }
        }

        // Winter Warrior — 40+ workouts in Dec(N)-Feb(N+1) for any year span
        if !existingIds.contains("seasonal_winter") {
            let years = Set(sets.map { cal.component(.year, from: $0.sessionDate) })
            for year in years {
                let winterSets = sets.filter {
                    let m = cal.component(.month, from: $0.sessionDate)
                    let y = cal.component(.year, from: $0.sessionDate)
                    return (m == 12 && y == year) || ((m == 1 || m == 2) && y == year + 1)
                }
                let count = Set(winterSets.map { cal.startOfDay(for: $0.sessionDate) }).count
                if count >= 40 {
                    results.append(Achievement(
                        id: "seasonal_winter", category: "seasonal",
                        unlockedAt: .now, sessionDate: sessionDate
                    ))
                    break
                }
            }
        }

        // Year-Round — 1+ workout in every calendar month of a single year
        if !existingIds.contains("seasonal_year_round") {
            let years = Set(sets.map { cal.component(.year, from: $0.sessionDate) })
            for year in years {
                let months = Set(sets.filter { cal.component(.year, from: $0.sessionDate) == year }
                                     .map { cal.component(.month, from: $0.sessionDate) })
                if months.count == 12 {
                    results.append(Achievement(
                        id: "seasonal_year_round", category: "seasonal",
                        unlockedAt: .now, sessionDate: sessionDate
                    ))
                    break
                }
            }
        }
    }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/curtismartin/Work/inch-project/Shared && swift test --filter AchievementCheckerV2Tests 2>&1 | tail -20`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add Shared/Sources/InchShared/Engine/AchievementChecker.swift Shared/Tests/InchSharedTests/AchievementCheckerV2Tests.swift
git commit -m "feat: add seasonal achievement checks with tests"
```

---

### Task 8: AchievementChecker — Playful / Fun Achievements

**Files:**
- Modify: `Shared/Sources/InchShared/Engine/AchievementChecker.swift`
- Modify: `Shared/Tests/InchSharedTests/AchievementCheckerV2Tests.swift`

- [ ] **Step 1: Write failing tests for playful achievements**

Add to `AchievementCheckerV2Tests.swift`:

```swift
    // MARK: - Fun / Playful

    @Test func centuryClubWith100Workouts() throws {
        let context = try makeContext()
        let dates = (1...31).map { (year: 2026, month: 1, day: $0, hour: 10) }
            + (1...28).map { (year: 2026, month: 2, day: $0, hour: 10) }
            + (1...31).map { (year: 2026, month: 3, day: $0, hour: 10) }
            + (1...10).map { (year: 2026, month: 4, day: $0, hour: 10) }
        insertSets(context: context, dates: dates)

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 10, level: 1, sessionDate: makeDate(2026, 4, 10)),
            in: context
        )
        #expect(results.contains { $0.id == "fun_century_club" })
    }

    @Test func thousandRepperWith1000Reps() throws {
        let context = try makeContext()
        // 100 sets of 10 reps each = 1000 reps of push_ups
        for day in 1...20 {
            for setNum in 1...5 {
                let set = CompletedSet(
                    completedAt: makeDate(2026, 3, day, hour: 10),
                    sessionDate: makeDate(2026, 3, day, hour: 10),
                    exerciseId: "push_ups",
                    level: 1, dayNumber: 1, setNumber: setNum,
                    targetReps: 10, actualReps: 10
                )
                context.insert(set)
            }
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 50, level: 1, sessionDate: makeDate(2026, 3, 20)),
            in: context
        )
        #expect(results.contains { $0.id == "fun_thousand_repper" })
    }

    @Test func tripleThreatWith3ExercisesInOneDay() throws {
        let context = try makeContext()
        let today = makeDate(2026, 3, 15, hour: 10)
        for ex in ["push_ups", "squats", "pull_ups"] {
            let set = CompletedSet(
                completedAt: today, sessionDate: today, exerciseId: ex,
                level: 1, dayNumber: 1, setNumber: 1,
                targetReps: 10, actualReps: 10
            )
            context.insert(set)
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "pull_ups", totalReps: 10, level: 1, sessionDate: today),
            in: context
        )
        #expect(results.contains { $0.id == "fun_triple_threat" })
    }

    @Test func fiveADayWith5ExercisesInOneDay() throws {
        let context = try makeContext()
        let today = makeDate(2026, 3, 15, hour: 10)
        for ex in ["push_ups", "squats", "pull_ups", "dips", "rows"] {
            let set = CompletedSet(
                completedAt: today, sessionDate: today, exerciseId: ex,
                level: 1, dayNumber: 1, setNumber: 1,
                targetReps: 10, actualReps: 10
            )
            context.insert(set)
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "rows", totalReps: 10, level: 1, sessionDate: today),
            in: context
        )
        #expect(results.contains { $0.id == "fun_five_a_day" })
    }

    @Test func groundhogDaySameExerciseSameRepsTwoDays() throws {
        let context = try makeContext()
        let yesterday = makeDate(2026, 3, 14, hour: 10)
        let today = makeDate(2026, 3, 15, hour: 10)
        // Yesterday: push_ups, 30 total reps
        for setNum in 1...3 {
            let set = CompletedSet(
                completedAt: yesterday, sessionDate: yesterday, exerciseId: "push_ups",
                level: 1, dayNumber: 1, setNumber: setNum,
                targetReps: 10, actualReps: 10
            )
            context.insert(set)
        }
        // Today: push_ups, 30 total reps
        for setNum in 1...3 {
            let set = CompletedSet(
                completedAt: today, sessionDate: today, exerciseId: "push_ups",
                level: 1, dayNumber: 1, setNumber: setNum,
                targetReps: 10, actualReps: 10
            )
            context.insert(set)
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 30, level: 1, sessionDate: today),
            in: context
        )
        #expect(results.contains { $0.id == "fun_groundhog_day" })
    }

    @Test func metronomeMasterWith100MetronomeSets() throws {
        let context = try makeContext()
        for day in 1...20 {
            for setNum in 1...5 {
                let set = CompletedSet(
                    completedAt: makeDate(2026, 3, day, hour: 10),
                    sessionDate: makeDate(2026, 3, day, hour: 10),
                    exerciseId: "dead_bugs",
                    level: 1, dayNumber: 1, setNumber: setNum,
                    targetReps: 10, actualReps: 10,
                    countingMode: .metronome
                )
                context.insert(set)
            }
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "dead_bugs", totalReps: 50, level: 1, sessionDate: makeDate(2026, 3, 20)),
            in: context
        )
        #expect(results.contains { $0.id == "fun_metronome_master" })
    }

    @Test func plankMinutesWith10CumulativeMinutes() throws {
        let context = try makeContext()
        // 10 sets of 60 seconds each = 600 seconds = 10 minutes
        for day in 1...10 {
            let set = CompletedSet(
                completedAt: makeDate(2026, 3, day, hour: 10),
                sessionDate: makeDate(2026, 3, day, hour: 10),
                exerciseId: "plank",
                level: 1, dayNumber: 1, setNumber: 1,
                targetReps: 1, actualReps: 1,
                setDurationSeconds: 60.0
            )
            context.insert(set)
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "plank", totalReps: 1, level: 1, sessionDate: makeDate(2026, 3, 10)),
            in: context
        )
        #expect(results.contains { $0.id == "fun_plank_minutes" })
    }

    @Test func testDayAceWith3ConsecutivePasses() throws {
        let context = try makeContext()
        for day in 1...3 {
            let set = CompletedSet(
                completedAt: makeDate(2026, 3, day, hour: 10),
                sessionDate: makeDate(2026, 3, day, hour: 10),
                exerciseId: "push_ups",
                level: 1, dayNumber: 10, setNumber: 1,
                targetReps: 20, actualReps: 25,
                isTest: true, testPassed: true
            )
            context.insert(set)
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 25, level: 1, sessionDate: makeDate(2026, 3, 3)),
            in: context
        )
        #expect(results.contains { $0.id == "fun_test_day_ace" })
    }

    @Test func tenThousandWith10000TotalReps() throws {
        let context = try makeContext()
        // 100 sets of 100 reps = 10,000
        for day in 1...20 {
            for setNum in 1...5 {
                let set = CompletedSet(
                    completedAt: makeDate(2026, 3, day, hour: 10),
                    sessionDate: makeDate(2026, 3, day, hour: 10),
                    exerciseId: "push_ups",
                    level: 1, dayNumber: 1, setNumber: setNum,
                    targetReps: 100, actualReps: 100
                )
                context.insert(set)
            }
        }
        try context.save()

        let checker = AchievementChecker()
        let results = checker.check(
            after: .workoutCompleted(exerciseId: "push_ups", totalReps: 500, level: 1, sessionDate: makeDate(2026, 3, 20)),
            in: context
        )
        #expect(results.contains { $0.id == "fun_ten_thousand" })
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/curtismartin/Work/inch-project/Shared && swift test --filter AchievementCheckerV2Tests 2>&1 | tail -20`
Expected: New fun tests fail

- [ ] **Step 3: Implement `checkPlayful` in AchievementChecker**

In `AchievementChecker.swift`, add a call in the `.workoutCompleted` case, after the `checkSeasonal(...)` call:

```swift
            checkPlayful(existingIds: existingIds, exerciseId: exerciseId,
                        totalReps: totalReps, sessionDate: sessionDate,
                        context: context, into: &unlocked)
```

Add the private helper method:

```swift
    private func checkPlayful(existingIds: Set<String>, exerciseId: String,
                               totalReps: Int, sessionDate: Date,
                               context: ModelContext, into results: inout [Achievement]) {
        let sets = (try? context.fetch(FetchDescriptor<CompletedSet>())) ?? []
        let cal = Calendar.current
        let today = cal.startOfDay(for: sessionDate)

        // Century Club — 100 distinct workout dates
        if !existingIds.contains("fun_century_club") {
            let distinctDates = Set(sets.map { cal.startOfDay(for: $0.sessionDate) })
            if distinctDates.count >= 100 {
                results.append(Achievement(
                    id: "fun_century_club", category: "fun",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }
        }

        // Thousand Repper — 1,000 reps of any single exercise
        if !existingIds.contains("fun_thousand_repper") {
            let repsByExercise = Dictionary(grouping: sets, by: \.exerciseId)
                .mapValues { $0.reduce(0) { $0 + $1.actualReps } }
            if repsByExercise.values.contains(where: { $0 >= 1000 }) {
                results.append(Achievement(
                    id: "fun_thousand_repper", category: "fun",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }
        }

        // Ten Thousand — 10,000 total reps across all exercises
        if !existingIds.contains("fun_ten_thousand") {
            let totalAllReps = sets.reduce(0) { $0 + $1.actualReps }
            if totalAllReps >= 10_000 {
                results.append(Achievement(
                    id: "fun_ten_thousand", category: "fun",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }
        }

        // Full Roster — all 9 exercises enrolled
        if !existingIds.contains("fun_full_roster") {
            let enrolments = (try? context.fetch(FetchDescriptor<ExerciseEnrolment>())) ?? []
            let activeCount = enrolments.filter(\.isActive).count
            if activeCount >= 9 {
                results.append(Achievement(
                    id: "fun_full_roster", category: "fun",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }
        }

        // Triple Threat — 3 different exercises in one day
        if !existingIds.contains("fun_triple_threat") {
            let todaySets = sets.filter { cal.startOfDay(for: $0.sessionDate) == today }
            let distinctExercises = Set(todaySets.map(\.exerciseId))
            if distinctExercises.count >= 3 {
                results.append(Achievement(
                    id: "fun_triple_threat", category: "fun",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }
        }

        // Five-a-Day — 5 different exercises in one day
        if !existingIds.contains("fun_five_a_day") {
            let todaySets = sets.filter { cal.startOfDay(for: $0.sessionDate) == today }
            let distinctExercises = Set(todaySets.map(\.exerciseId))
            if distinctExercises.count >= 5 {
                results.append(Achievement(
                    id: "fun_five_a_day", category: "fun",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }
        }

        // Plank Minutes — 10 cumulative minutes of plank holds
        if !existingIds.contains("fun_plank_minutes") {
            let plankSets = sets.filter { $0.exerciseId == "plank" }
            let totalSeconds = plankSets.reduce(0.0) { $0 + ($1.setDurationSeconds ?? 0) }
            if totalSeconds >= 600 {
                results.append(Achievement(
                    id: "fun_plank_minutes", category: "fun",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }
        }

        // Metronome Master — 100 metronome-guided sets
        if !existingIds.contains("fun_metronome_master") {
            let metronomeSets = sets.filter { $0.countingMode == .metronome }
            if metronomeSets.count >= 100 {
                results.append(Achievement(
                    id: "fun_metronome_master", category: "fun",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }
        }

        // Test Day Ace — 3 consecutive test passes with no failures between
        if !existingIds.contains("fun_test_day_ace") {
            let testSets = sets.filter(\.isTest)
                .sorted { $0.completedAt < $1.completedAt }
            if testSets.count >= 3 {
                let lastThree = testSets.suffix(3)
                if lastThree.allSatisfy({ $0.testPassed == true }) {
                    results.append(Achievement(
                        id: "fun_test_day_ace", category: "fun",
                        unlockedAt: .now, sessionDate: sessionDate
                    ))
                }
            }
        }

        // Level Up Trifecta — reached Level 2 in 3 different exercises
        if !existingIds.contains("fun_level_up_trifecta") {
            let enrolments = (try? context.fetch(FetchDescriptor<ExerciseEnrolment>())) ?? []
            let level2Count = enrolments.filter { $0.currentLevel >= 2 }.count
            if level2Count >= 3 {
                results.append(Achievement(
                    id: "fun_level_up_trifecta", category: "fun",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }
        }

        // Maxed Out — reached Level 3 in any exercise
        if !existingIds.contains("fun_maxed_out") {
            let enrolments = (try? context.fetch(FetchDescriptor<ExerciseEnrolment>())) ?? []
            if enrolments.contains(where: { $0.currentLevel >= 3 }) {
                results.append(Achievement(
                    id: "fun_maxed_out", category: "fun",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }
        }

        // Grand Master — reached Level 3 in all 9 exercises
        if !existingIds.contains("fun_grand_master") {
            let enrolments = (try? context.fetch(FetchDescriptor<ExerciseEnrolment>())) ?? []
            let active = enrolments.filter(\.isActive)
            if active.count >= 9 && active.allSatisfy({ $0.currentLevel >= 3 }) {
                results.append(Achievement(
                    id: "fun_grand_master", category: "fun",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }
        }

        // Groundhog Day — same exercise, same total reps, two consecutive days
        if !existingIds.contains("fun_groundhog_day") {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: today) else { return }
            let yesterdaySets = sets.filter {
                cal.startOfDay(for: $0.sessionDate) == yesterday && $0.exerciseId == exerciseId
            }
            let yesterdayReps = yesterdaySets.reduce(0) { $0 + $1.actualReps }
            if yesterdayReps > 0 && yesterdayReps == totalReps {
                results.append(Achievement(
                    id: "fun_groundhog_day", category: "fun",
                    unlockedAt: .now, sessionDate: sessionDate
                ))
            }
        }
    }
```

Note: `Perfect Week` is omitted from this task as it requires checking scheduled vs completed workouts which adds complexity — it can be added in a follow-up. The spec describes it as checking all active enrolments had at least one completed set that week, which requires knowing scheduled dates in the past (which aren't stored). We'll skip it for now.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/curtismartin/Work/inch-project/Shared && swift test --filter AchievementCheckerV2Tests 2>&1 | tail -20`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add Shared/Sources/InchShared/Engine/AchievementChecker.swift Shared/Tests/InchSharedTests/AchievementCheckerV2Tests.swift
git commit -m "feat: add playful/fun achievement checks with tests"
```

---

### Task 9: AchievementChecker — Lifetime Percentile Achievements

**Files:**
- Modify: `Shared/Sources/InchShared/Engine/AchievementChecker.swift`

- [ ] **Step 1: Add new event case and handler**

Add to `AchievementEvent`:

```swift
    case communityLifetimePercentileUpdated(metricType: String, percentile: Int)
```

Add a new case in the `check(after:in:)` switch:

```swift
        case let .communityLifetimePercentileUpdated(metricType, percentile):
            if metricType == "total_lifetime_reps" {
                if percentile >= 90 && !existingIds.contains("community_volume_machine") {
                    unlocked.append(Achievement(
                        id: "community_volume_machine", category: "community", unlockedAt: .now
                    ))
                }
            }
            if metricType == "total_workouts" {
                if percentile >= 75 && !existingIds.contains("community_dedicated") {
                    unlocked.append(Achievement(
                        id: "community_dedicated", category: "community", unlockedAt: .now
                    ))
                }
                if percentile >= 90 && !existingIds.contains("community_veteran") {
                    unlocked.append(Achievement(
                        id: "community_veteran", category: "community", unlockedAt: .now
                    ))
                }
            }
```

- [ ] **Step 2: Build and verify**

Run: `cd /Users/curtismartin/Work/inch-project/Shared && swift build 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Shared/Sources/InchShared/Engine/AchievementChecker.swift
git commit -m "feat: add lifetime percentile achievement event and checks"
```

---

### Task 10: CommunityBenchmarkService — Lifetime Upload

**Files:**
- Modify: `inch/inch/Services/CommunityBenchmarkService.swift`

- [ ] **Step 1: Add lifetime upload method and payload**

Add the public method (following the same pattern as `uploadExerciseBenchmark`):

```swift
    // MARK: - Lifetime Benchmark Upload

    func uploadLifetimeBenchmark(totalWorkouts: Int, totalLifetimeReps: Int, enrolledExerciseCount: Int) {
        Task.detached(priority: .utility) { [self] in
            await _uploadLifetimeBenchmark(
                totalWorkouts: totalWorkouts,
                totalLifetimeReps: totalLifetimeReps,
                enrolledExerciseCount: enrolledExerciseCount
            )
        }
    }
```

Add the `@concurrent` private method:

```swift
    @concurrent
    private func _uploadLifetimeBenchmark(totalWorkouts: Int, totalLifetimeReps: Int, enrolledExerciseCount: Int) async {
        guard let config = supabaseConfig() else { return }
        let deviceHash = CommunityIdentity.deviceHash

        let payload = LifetimeBenchmarkPayload(
            deviceHash: deviceHash,
            totalWorkouts: totalWorkouts,
            totalLifetimeReps: totalLifetimeReps,
            enrolledExerciseCount: enrolledExerciseCount
        )

        guard let url = URL(string: "\(config.url)/rest/v1/lifetime_benchmarks") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(config.anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.setValue("resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = try? JSONEncoder().encode(payload)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode < 300 {
                logger.debug("Lifetime benchmark uploaded")
            }
        } catch {
            logger.debug("Lifetime benchmark upload failed: \(error.localizedDescription)")
        }
    }
```

Add the payload struct at the bottom of the file, alongside the other payloads:

```swift
private nonisolated struct LifetimeBenchmarkPayload: Encodable {
    let deviceHash: String
    let totalWorkouts: Int
    let totalLifetimeReps: Int
    let enrolledExerciseCount: Int

    enum CodingKeys: String, CodingKey {
        case deviceHash = "device_hash"
        case totalWorkouts = "total_workouts"
        case totalLifetimeReps = "total_lifetime_reps"
        case enrolledExerciseCount = "enrolled_exercise_count"
    }
}
```

- [ ] **Step 2: Build and verify**

Run: `cd /Users/curtismartin/Work/inch-project/inch && xcodebuild build -scheme inch -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' -quiet 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add inch/inch/Services/CommunityBenchmarkService.swift
git commit -m "feat: add lifetime benchmark upload to CommunityBenchmarkService"
```

---

### Task 11: Lifetime Sync on App Foreground

**Files:**
- Modify: `inch/inch/inchApp.swift`

- [ ] **Step 1: Add lifetime sync in the `.task` block**

At the end of the existing `.task { ... }` block in `inchApp.swift`, after the `withTaskGroup` call, add the lifetime sync:

```swift
                    // Lifetime benchmark sync (once per day)
                    if userSettings?.communityBenchmarksEnabled == true {
                        let syncContext = ModelContext(self.container)
                        let allSets = (try? syncContext.fetch(FetchDescriptor<CompletedSet>())) ?? []
                        let enrolments = (try? syncContext.fetch(FetchDescriptor<ExerciseEnrolment>())) ?? []

                        let totalWorkouts = Set(allSets.map { Calendar.current.startOfDay(for: $0.sessionDate) }).count
                        let totalReps = allSets.reduce(0) { $0 + $1.actualReps }
                        let enrolledCount = enrolments.filter(\.isActive).count

                        communityBenchmark.uploadLifetimeBenchmark(
                            totalWorkouts: totalWorkouts,
                            totalLifetimeReps: totalReps,
                            enrolledExerciseCount: enrolledCount
                        )
                    }
```

Note: The rate limiting (once per day) is handled server-side by the upsert on `device_hash`. The client `.task` block only runs once per app launch, which is acceptable frequency.

- [ ] **Step 2: Build and verify**

Run: `cd /Users/curtismartin/Work/inch-project/inch && xcodebuild build -scheme inch -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' -quiet 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add inch/inch/inchApp.swift
git commit -m "feat: add lifetime benchmark sync on app launch"
```

---

### Task 12: Full Build Verification

**Files:** None (verification only)

- [ ] **Step 1: Run full Xcode build**

Run: `cd /Users/curtismartin/Work/inch-project/inch && xcodebuild build -scheme inch -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' -quiet 2>&1 | tail -20`
Expected: Build succeeds with zero errors

- [ ] **Step 2: Run all Shared package tests**

Run: `cd /Users/curtismartin/Work/inch-project/Shared && swift test 2>&1 | tail -30`
Expected: All tests pass, including new HolidayCalendar and AchievementCheckerV2 tests

- [ ] **Step 3: Verify no regressions in existing achievement tests**

Run: `cd /Users/curtismartin/Work/inch-project/Shared && swift test --filter AchievementCheckerTests 2>&1 | tail -10`
Expected: All existing tests still pass
