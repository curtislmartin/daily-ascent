# v1.1 Feature Specification

Builds on the v1 foundation. All features reference the existing data model (`data-model.md`), architecture (`architecture.md`), and agent skill conventions.

---

## 1. History View

### Screen: HistoryView (Tab 3)

Two segments at the top: **Log** and **Stats**. Default to Log.

### 1a. Workout Log

Reverse-chronological list of training days, grouped by calendar week.

**Week header:**
```
Week of 14 Apr — 462 reps across 12 sessions
```

**Day entry (collapsed — default):**
```
┌─────────────────────────────────────────┐
│ Thu 17 Apr                    498 reps  │
│ ●●●●●●  6 exercises · 24 min           │
│         ↳ Squats pushed to tomorrow     │
└─────────────────────────────────────────┘
```

- Coloured dots represent each exercise completed that day (using exercise accent colours)
- Duration = time from first set's `completedAt` to last set's `completedAt` on that `sessionDate`
- "Pushed to tomorrow" shown if any enrolled exercise was due but has no `CompletedSet` for that date

**Day entry (expanded — tap to expand):**
Shows per-exercise breakdown for that day:

```
Push-Ups  L2 Day 8      5 sets    118 / 118 reps  ✓
Squats    L2 Day 10     4 sets    104 / 108 reps
Sit-Ups   L2 Day 6      6 sets    106 / 106 reps  ✓
Pull-Ups  L2 Day 4      4 sets     23 / 23 reps   ✓
Dead Bugs L2 Day 6      4 sets     39 / 39 reps   ✓
```

Format: `exercise name | level & day | set count | actual / target reps | ✓ if all targets hit`

Tapping an individual exercise row navigates to the exercise detail view for that exercise.

**Test day entries look different:**
```
┌─────────────────────────────────────────┐
│ 🏆 Sat 5 Apr — Push-Up Test            │
│ Level 2 Final — 52 / 50 — PASSED       │
└─────────────────────────────────────────┘
```

Or for failures:
```
│ Sat 5 Apr — Push-Up Test                │
│ Level 2 Final — 43 / 50 — Retry next   │
```

**Empty state:** "No workouts yet. Head to the Today tab to start training."

### Data Query

```swift
// Fetch all completed sets grouped by sessionDate, ordered by date descending
let descriptor = FetchDescriptor<CompletedSet>(
    sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
)
let allSets = try modelContext.fetch(descriptor)

// Group by sessionDate (calendar day)
let grouped = Dictionary(grouping: allSets) { set in
    Calendar.current.startOfDay(for: set.sessionDate)
}
```

### HistoryViewModel

```swift
@Observable
final class HistoryViewModel {
    var weekGroups: [WeekGroup] = []
    
    struct WeekGroup: Identifiable {
        let id: Date  // start of week
        let totalReps: Int
        let sessionCount: Int
        let days: [DayGroup]
    }
    
    struct DayGroup: Identifiable {
        let id: Date  // sessionDate
        let exercises: [ExerciseSummary]
        let totalReps: Int
        let duration: TimeInterval?
        let pushedExercises: [String]  // exercise names that were due but not completed
    }
    
    struct ExerciseSummary: Identifiable {
        let id: String  // exerciseId
        let exerciseName: String
        let color: String
        let level: Int
        let dayNumber: Int
        let setCount: Int
        let actualReps: Int
        let targetReps: Int
        let isTest: Bool
        let testPassed: Bool?
    }
}
```

---

### 1b. Stats Dashboard

Shown when the "Stats" segment is selected.

**Summary cards (horizontal scroll or 2×2 grid):**

| Card | Value | Subtitle |
|---|---|---|
| Total Reps | `12,847` | All time |
| Streak | `18 days` | Current |
| Best Streak | `24 days` | Personal best |
| Sessions | `42` | Training days completed |

**Per-exercise stats (vertical list below summary cards):**

Each exercise gets a compact row:

```
💪 Push-Ups    L2 Day 14/19    4,231 reps total
🦵 Squats      L2 Day 10/19    3,108 reps total
...
```

Tapping navigates to exercise detail view.

**Weekly Volume Chart (Swift Charts):**

Stacked bar chart showing total reps per week, broken down by exercise colour. Last 8 weeks visible, horizontally scrollable for older data.

```swift
import Charts

Chart(weeklyData) { week in
    ForEach(week.exerciseBreakdown) { exercise in
        BarMark(
            x: .value("Week", week.startDate, unit: .weekOfYear),
            y: .value("Reps", exercise.totalReps)
        )
        .foregroundStyle(by: .value("Exercise", exercise.name))
    }
}
.chartForegroundStyleScale(exerciseColorMapping)
```

The chart should use the exercise accent colours for each segment.

**Level Progress Timeline:**

A horizontal visual showing each enrolled exercise's progress through L1 → L2 → L3. Similar to the Program view's progress bars but combined into one view for comparison.

### Stats Queries

```swift
// Total reps all time
let totalReps = try modelContext.fetch(FetchDescriptor<CompletedSet>())
    .reduce(0) { $0 + $1.actualReps }

// Total reps per exercise
// Group CompletedSet by exerciseId, sum actualReps

// Weekly volume (last 8 weeks)
// Group CompletedSet by Calendar.current.dateInterval(of: .weekOfYear, for: sessionDate)
// Then group within each week by exerciseId

// Session count
// Count distinct sessionDate values across all CompletedSet
```

Note: For performance, consider caching aggregate stats and updating on each completion rather than recomputing from all CompletedSet records every time the view appears. A `StatsCache` entity or computed values on `ExerciseEnrolment` could help as the dataset grows.

---

## 2. Exercise Detail View

### Screen: ExerciseDetailView

Navigated to from Program tab (tap exercise card) or from History (tap exercise row).

**Header:**
- Exercise name, icon, colour
- Current level badge: "Level 2"
- Progress: "Day 14 of 19"
- Next scheduled date: "Next: Thursday 17 Apr"

### 2a. Level Progression Visual

Three-segment horizontal bar (L1 | L2 | L3):
- Completed levels: filled with exercise colour
- Current level: partially filled based on day/totalDays
- Future levels: grey/empty
- Tap a level segment to browse that level's prescription (see 2c)

Below the bar, test results for completed levels:
```
L1 Test: 25 reps (target 20) — Passed 5 Apr
L2 Test: upcoming — target 50
```

### 2b. Session History Chart (Swift Charts)

Line chart showing total reps per session for this exercise over time.

```swift
Chart(sessionHistory) { session in
    LineMark(
        x: .value("Date", session.date),
        y: .value("Reps", session.totalReps)
    )
    .foregroundStyle(Color(hex: exercise.color))
    
    PointMark(
        x: .value("Date", session.date),
        y: .value("Reps", session.totalReps)
    )
    .foregroundStyle(session.isTest ? .white : Color(hex: exercise.color))
    .symbolSize(session.isTest ? 80 : 30)
}
.chartYAxisLabel("Total Reps")
```

Test days are highlighted with a larger marker. Show a horizontal reference line at the current test target if there's an upcoming test.

### 2c. Upcoming Schedule

Calendar-style list of the next 7-10 training days for this exercise:

```
Day 15 — Thu 17 Apr — 5 sets: 38, 28, 26, 24, 22
Day 16 — Sat 19 Apr — 5 sets: 40, 28, 28, 24, 24
Day 17 — Tue 22 Apr — 5 sets: 42, 32, 28, 26, 24
...
Day 19 — 🏆 TEST DAY — Hit 50 reps
```

This requires projecting the schedule forward using `SchedulingEngine.projectSchedule()`.

### 2d. Level Browser

Tapping a level in the progression bar shows all days for that level:

```
Level 2 — Push-Ups
19 training days · Rest pattern: 2-2-3

Day 1:  16, 12, 14, 10, 10  (62 reps)  ✓ completed 7 Apr
Day 2:  16, 16, 12, 11, 10  (65 reps)  ✓ completed 9 Apr
...
Day 14: current ← you are here
Day 15: 38, 28, 26, 24, 22  (138 reps)
...
Day 19: TEST — hit 50 reps
```

Completed days show a checkmark and the completion date. The current day is highlighted. Future days show the prescribed sets.

### 2e. Actions

- **Reset Level:** "Start Level 2 over from Day 1" — confirmation dialog, resets `currentDay` to 1, `restPatternIndex` to 0, and clears `nextScheduledDate` for recalculation. Does NOT delete history.
- **Jump to Day:** For experienced users — browse any day in any level, tap to set it as current. Confirmation: "Set Push-Ups to Level 3, Day 5? Your current progress in Level 2 will be saved in history."

### Data Query

```swift
// Session history for this exercise
let descriptor = FetchDescriptor<CompletedSet>(
    predicate: #Predicate { $0.exerciseId == exerciseId },
    sortBy: [SortDescriptor(\.sessionDate)]
)

// Group by sessionDate, sum actualReps per date for the chart
```

---

## 3. Notifications

### Permission Request

Request notification permission after the user completes their first workout (not during onboarding — too early, they haven't experienced the value yet).

```swift
import UserNotifications

func requestNotificationPermission() async throws -> Bool {
    let center = UNUserNotificationCenter.current()
    let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
    return granted
}
```

If denied, the notification toggles in Settings show "Notifications disabled" with a link to system Settings.

### Notification Types

#### 3a. Daily Training Reminder

**Trigger:** Scheduled daily at the user's preferred time (default 8:00 AM). Only fires on days where at least one exercise is due.

**Content:**
- Title: "Time to train"
- Body: "4 exercises today — Push-Ups, Squats, Sit-Ups, Dead Bugs" (lists due exercises)
- If only 1 exercise: "Push-Ups — Day 14, 5 sets"
- Sound: default

**Scheduling logic:**
Each evening (or after each workout completion), calculate tomorrow's schedule. If exercises are due, schedule a notification for the reminder time. If it's a rest day, don't schedule.

```swift
func scheduleDailyReminder(for date: Date, exercises: [String], hour: Int, minute: Int) {
    let content = UNMutableNotificationContent()
    content.title = "Time to train"
    content.body = "\(exercises.count) exercises today — \(exercises.joined(separator: ", "))"
    content.sound = .default
    
    var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
    components.hour = hour
    components.minute = minute
    
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    let request = UNNotificationRequest(identifier: "daily-reminder-\(date)", content: content, trigger: trigger)
    
    UNUserNotificationCenter.current().add(request)
}
```

**Refresh strategy:** After each workout completion or at app launch, remove outdated reminders and schedule the next 7 days of reminders. This ensures they're always up to date even if the schedule shifts due to pushbacks.

#### 3b. Streak Protection

**Trigger:** Fires at 7:00 PM (configurable) on training days where no exercises have been completed yet.

**Content:**
- Title: "Don't break your streak"
- Body: "18-day streak — 3 exercises still waiting" (dynamic count)
- If streak is 0 or 1: "Start building your streak — 3 exercises due today"

**Scheduling logic:**
Schedule alongside the daily reminder each evening. The notification checks at delivery time whether exercises were completed — but since local notifications can't check state, schedule it unconditionally and remove it when a workout is completed during the day.

```swift
// After completing any exercise today, cancel the streak protection notification
func cancelStreakProtection(for date: Date) {
    let identifier = "streak-protection-\(date)"
    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
}
```

#### 3c. Test Day Notification

**Trigger:** Morning of a test day, at the daily reminder time.

**Content:**
- Title: "Test day"  
- Body: "Push-Up Test — hit 50 to unlock Level 3"
- Sound: default (same as daily reminder — no custom sounds for v1)

**Scheduling logic:** When projecting the schedule forward, identify test days and schedule a notification for each. Replace the daily reminder on that day with this more specific one.

#### 3d. Level Unlock

**Trigger:** Immediately after passing a test.

**Content:**
- Title: "Level 3 unlocked!"
- Body: "Push-Ups — Level 3 starts in 2 days"
- This is a local notification posted programmatically, not calendar-scheduled

```swift
func postLevelUnlock(exerciseName: String, newLevel: Int, startsIn: Int) {
    let content = UNMutableNotificationContent()
    content.title = "Level \(newLevel) unlocked!"
    content.body = "\(exerciseName) — Level \(newLevel) starts in \(startsIn) days"
    content.sound = .default
    
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request = UNNotificationRequest(identifier: "level-unlock-\(UUID())", content: content, trigger: trigger)
    UNUserNotificationCenter.current().add(request)
}
```

#### 3e. Schedule Adjustment

**Trigger:** When the conflict resolver automatically pushes an exercise.

**Content:**
- Title: "Schedule adjusted"
- Body: "Glute Bridges moved to Thursday — resting before Squat test"

Post immediately when the conflict resolver runs and makes an adjustment. Don't spam — group adjustments that happen in the same resolution pass into a single notification.

### NotificationService

```swift
// NotificationService.swift
@Observable
final class NotificationService {
    var isAuthorized: Bool = false
    
    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }
    
    func refreshScheduledNotifications(dueExercises: [Date: [String]], streak: Int, settings: UserSettings) {
        let center = UNUserNotificationCenter.current()
        // Remove all pending
        center.removeAllPendingNotificationRequests()
        // Re-schedule next 7 days
        for (date, exercises) in dueExercises {
            if settings.dailyReminderEnabled {
                scheduleDailyReminder(for: date, exercises: exercises,
                    hour: settings.dailyReminderHour, minute: settings.dailyReminderMinute)
            }
            if settings.streakProtectionEnabled {
                scheduleStreakProtection(for: date, exerciseCount: exercises.count, streak: streak)
            }
        }
    }
    
    func cancelTodayStreakProtection() {
        let today = Calendar.current.startOfDay(for: .now)
        let identifier = "streak-protection-\(today)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
```

---

## 4. Watch Complications

### Implementation: WidgetKit (watchOS 10+)

watchOS 10+ uses WidgetKit for complications (ClockKit is deprecated). Complications are small widgets on the watch face.

### Supported Families

| Family | Layout | Content |
|---|---|---|
| `accessoryCircular` | Small circle | Exercise count: "4/6" or "REST" |
| `accessoryCorner` | Corner gauge | Progress arc showing exercises done / due |
| `accessoryRectangular` | Medium rectangle | "4 exercises due" with coloured dots per exercise |
| `accessoryInline` | Single-line text | "4 exercises today" or "Rest day" |

### Timeline Provider

```swift
import WidgetKit
import SwiftUI

struct InchComplicationProvider: TimelineProvider {
    typealias Entry = InchComplicationEntry
    
    func placeholder(in context: Context) -> InchComplicationEntry {
        InchComplicationEntry(date: .now, dueCount: 4, completedCount: 0, totalEnrolled: 6, isRestDay: false, exerciseColors: [])
    }
    
    func getSnapshot(in context: Context, completion: @escaping (InchComplicationEntry) -> Void) {
        // Return current state from shared data
        let entry = loadCurrentState()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<InchComplicationEntry>) -> Void) {
        let entry = loadCurrentState()
        // Refresh at midnight (schedule changes) and after each workout
        let midnight = Calendar.current.startOfDay(for: .now).addingTimeInterval(86400)
        let timeline = Timeline(entries: [entry], policy: .after(midnight))
        completion(timeline)
    }
    
    private func loadCurrentState() -> InchComplicationEntry {
        // Read from shared UserDefaults (app group) or WatchConnectivity cache
        // This data is pushed from the iPhone whenever the schedule changes
    }
}

struct InchComplicationEntry: TimelineEntry {
    let date: Date
    let dueCount: Int
    let completedCount: Int
    let totalEnrolled: Int
    let isRestDay: Bool
    let exerciseColors: [String]  // hex colours for due exercises
}
```

### Complication Views

```swift
struct InchCircularComplication: View {
    let entry: InchComplicationEntry
    
    var body: some View {
        if entry.isRestDay {
            VStack(spacing: 2) {
                Text("REST")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
                Text("DAY")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(spacing: 2) {
                Text("DUE")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                Text("\(entry.completedCount)/\(entry.dueCount)")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
            }
        }
    }
}

struct InchRectangularComplication: View {
    let entry: InchComplicationEntry
    
    var body: some View {
        if entry.isRestDay {
            Text("Rest day — next training tomorrow")
                .font(.caption)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(entry.dueCount - entry.completedCount) exercises remaining")
                    .font(.headline)
                HStack(spacing: 4) {
                    ForEach(entry.exerciseColors, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
    }
}
```

### Data Sharing Between App and Widget

Complications run in a separate process and can't access the main app's SwiftData store directly. Use a shared App Group for communication:

1. iPhone pushes complication data to Watch via `transferUserInfo` alongside the schedule sync
2. Watch stores complication state in shared `UserDefaults` (App Group)
3. The complication's `TimelineProvider` reads from shared `UserDefaults`
4. After each workout completion on the Watch, update `UserDefaults` and call `WidgetCenter.shared.reloadAllTimelines()`

```swift
// Shared data key
let complicationData = UserDefaults(suiteName: "group.com.inch.bodyweight")

// After workout completion
complicationData?.set(completedCount, forKey: "complication.completedCount")
complicationData?.set(dueCount, forKey: "complication.dueCount")
WidgetCenter.shared.reloadAllTimelines()
```

---

## 5. Dashboard Conflict Warnings

### UI Treatment

Conflict warnings appear on exercise cards in the Today view. They're non-blocking — the user can still tap to start the exercise.

**Warning banner on the exercise card:**
```
┌─────────────────────────────────────────┐
│ ⚠️ Squat test tomorrow — consider rest  │
│                                         │
│ 🍑 Glute Bridges                        │
│ L2 · Day 6 of 19          104 reps     │
│ ┌────┬────┬────┬────┐                   │
│ │ 42 │ 20 │ 16 │ 26 │                   │
│ └────┴────┴────┴────┘                   │
└─────────────────────────────────────────┘
```

The warning banner sits at the top of the affected card, in a muted amber colour. The card itself remains fully tappable.

### Warning Types

| Conflict Type | Banner Text |
|---|---|
| Same-group test tomorrow | "⚠️ [Exercise] test tomorrow — consider resting [muscle group]" |
| Same-group test today | "⚠️ [Exercise] test also today — consider doing one tomorrow" |
| Double test same day | "⚠️ Two tests today — consider moving one to tomorrow" |
| High volume same group | "💪 High [muscle group] volume today — [X] total reps across [exercise] and [exercise]" |

### Implementation

The `TodayViewModel` runs conflict detection and populates a warning dictionary:

```swift
// In TodayViewModel
var conflictWarnings: [String: ConflictWarning] = [:]  // exerciseId -> warning

struct ConflictWarning {
    let type: ConflictType
    let message: String
    let isAutoResolved: Bool  // true if the engine already pushed something
}

enum ConflictType {
    case testConflict
    case sameGroupHighVolume
    case scheduleAdjusted
}

func loadConflicts() {
    let conflicts = ConflictDetector.detect(allEnrolments: activeEnrolments)
    for conflict in conflicts {
        // Map to user-facing warnings
    }
}
```

The warning is shown as an overlay on the `ExerciseCard` view:

```swift
struct ExerciseCard: View {
    let enrolment: ExerciseEnrolment
    let warning: ConflictWarning?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let warning {
                ConflictWarningBanner(warning: warning)
            }
            // ... rest of card content
        }
    }
}
```

---

## 6. Settings Enhancements (v1.1)

v1 has a basic settings screen. v1.1 adds notification controls and surfaces conflict warning preferences.

### New Settings Sections

**Notifications section:**
```
Notifications
  ├── Daily Reminder        [toggle]    8:00 AM  [time picker]
  ├── Streak Protection     [toggle]    7:00 PM  [time picker]  
  ├── Test Day Alerts       [toggle]
  └── Level Unlock Alerts   [toggle]
```

If notification permission is denied, show:
```
Notifications are disabled. Enable in Settings → Notifications → Inch
[Open Settings]  // links to UIApplication.openSettingsURLString
```

**Schedule section (new):**
```
Schedule
  └── Show Conflict Warnings  [toggle]   default ON
```

When OFF, the conflict detector still runs (to resolve double-tests) but the advisory warnings are hidden from the dashboard.

---

## Files to Create / Modify

### New Files
```
InchApp/Features/History/
  ├── HistoryView.swift           // Tab 3 with Log/Stats segments
  ├── HistoryLogView.swift        // Workout log list
  ├── HistoryStatsView.swift      // Stats dashboard
  ├── WeeklyVolumeChart.swift     // Swift Charts stacked bar
  ├── DayGroupRow.swift           // Expandable day entry
  ├── ExerciseSummaryRow.swift    // Per-exercise row in expanded day
  └── HistoryViewModel.swift      // Data loading and aggregation

InchApp/Features/Program/
  ├── ExerciseDetailView.swift    // Full exercise detail screen
  ├── LevelProgressionBar.swift   // L1-L2-L3 visual
  ├── SessionHistoryChart.swift   // Swift Charts line chart
  ├── UpcomingScheduleList.swift  // Next N training days
  ├── LevelBrowserView.swift     // Browse all days in a level
  └── ExerciseDetailViewModel.swift

InchApp/Features/Today/
  └── ConflictWarningBanner.swift // Warning overlay on exercise cards

InchApp/Services/
  └── NotificationService.swift   // UNUserNotificationCenter wrapper

InchWatch/
  ├── Complications/
  │   ├── InchComplicationProvider.swift
  │   ├── InchComplicationEntry.swift
  │   ├── InchCircularComplication.swift
  │   ├── InchRectangularComplication.swift
  │   └── InchInlineComplication.swift
  └── (modify WatchConnectivityService to push complication data)
```

### Modified Files
```
InchApp/Features/Today/ExerciseCard.swift     — add conflict warning banner
InchApp/Features/Today/TodayViewModel.swift   — add conflict detection
InchApp/Features/Settings/SettingsView.swift   — add notification and schedule sections
InchApp/Features/Settings/SettingsViewModel.swift — notification permission handling
InchApp/InchApp.swift                          — register notification service
InchWatch/InchWatchApp.swift                   — register widget extension
```

---

## Build Order (v1.1)

1. **HistoryViewModel** — data loading and aggregation logic, testable
2. **HistoryLogView + DayGroupRow** — the workout log UI
3. **HistoryStatsView + WeeklyVolumeChart** — stats dashboard with Swift Charts
4. **ExerciseDetailViewModel** — schedule projection, history queries
5. **ExerciseDetailView + subviews** — the full detail screen
6. **ConflictWarningBanner + TodayViewModel updates** — wire up conflict display
7. **NotificationService** — permission, scheduling, cancellation
8. **Settings notification section** — toggles and time pickers
9. **Watch complications** — timeline provider, views, App Group data sharing
10. **Integration testing** — verify notification scheduling after completions, complication updates after sync

---

## Dependencies on v1

These features require v1 to be working:
- `CompletedSet` records exist (from completing workouts)
- `SchedulingEngine.projectSchedule()` works (for upcoming schedule in exercise detail)
- `ConflictDetector` works (for dashboard warnings)
- `StreakState` is maintained (for stats dashboard)
- WatchConnectivity sync is functional (for complication data)

If any v1 component isn't fully working, build v1.1 features bottom-up starting with HistoryViewModel (which only needs CompletedSet data to function).
