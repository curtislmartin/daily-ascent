# Scheduling Engine Specification

The scheduling engine computes training dates, detects conflicts, and resolves them. It is pure logic with no UI dependencies — it operates on data model state and returns schedule decisions.

> **This is the first code to build and the most important to test.**

---

## Core Concepts

### Rest Day Pattern

Each exercise level has a repeating gap pattern: `[2, 2, 3]` means "train, wait 2 days, train, wait 2 days, train, wait 3 days, repeat."

The `restPatternIndex` tracks position within the cycle. After each completed training day, the index advances: `restPatternIndex = (restPatternIndex + 1) % pattern.count`.

### Extra Rest Before Test

Some exercise levels add extra rest before the final test day. When the next day is a test day AND `extraRestBeforeTest` is set, the gap is `extraRestBeforeTest` days instead of the normal pattern value.

### Inter-Level Gap

After completing a level (passing the test), there is always a 2-day gap before the next level starts. The `restPatternIndex` resets to 0 for the new level.

---

## Algorithm 1: Compute Next Scheduled Date

Given an exercise enrolment's current state, compute when the next training day falls.

```
function computeNextDate(enrolment) -> Date:
    let exercise = enrolment.exerciseDefinition
    let level = exercise.levels[enrolment.currentLevel - 1]
    let pattern = level.restDayPattern
    
    // If no training has been completed yet, the next date is the enrolment date
    if enrolment.lastCompletedDate == nil:
        return enrolment.enrolledAt  // first training day
    
    let lastDate = enrolment.lastCompletedDate
    
    // Check if the user just passed a test (completed the last day of a level)
    if enrolment.currentDay > level.totalDays:
        // Level complete — advance to next level
        if enrolment.currentLevel < 3:
            return lastDate + interLevelGapDays  // 2 days
        else:
            return nil  // program complete for this exercise
    
    // Check if next day is the test day AND extraRestBeforeTest applies
    let nextDay = level.days[enrolment.currentDay - 1]  // 0-indexed array, currentDay is 1-indexed
    if nextDay.isTest AND level.extraRestBeforeTest != nil:
        return lastDate + level.extraRestBeforeTest
    
    // Normal case: use rest pattern
    let gapDays = pattern[enrolment.restPatternIndex % pattern.count]
    return lastDate + gapDays
```

### Edge Cases
- First training day ever: `nextScheduledDate = enrolledAt` (the start date the user chose)
- Program complete (all L3 passed): `nextScheduledDate = nil`
- Level transition: `currentLevel` increments, `currentDay` resets to 1, `restPatternIndex` resets to 0

---

## Algorithm 2: Complete a Training Day

When the user finishes all sets for an exercise on a given day:

```
function completeTrainingDay(enrolment, actualDate, setResults):
    let level = enrolment.exerciseDefinition.levels[enrolment.currentLevel - 1]
    let dayPrescription = level.days[enrolment.currentDay - 1]
    
    // Save completed sets (done by the caller, not this function)
    
    // Check if this was a test day
    if dayPrescription.isTest:
        let totalReps = sum(setResults.actualReps)
        if totalReps >= level.testTarget:
            // TEST PASSED
            if enrolment.currentLevel < 3:
                enrolment.currentLevel += 1
                enrolment.currentDay = 1
                enrolment.restPatternIndex = 0
            else:
                // Program complete for this exercise
                enrolment.isActive = false  // or mark as "completed"
            enrolment.lastCompletedDate = actualDate
        else:
            // TEST FAILED — stay on the same day, schedule retry after rest
            enrolment.lastCompletedDate = actualDate
            // currentLevel and currentDay DO NOT change
            // The test day will be scheduled again after the normal rest gap
    else:
        // Regular training day
        enrolment.currentDay += 1
        enrolment.restPatternIndex += 1
        enrolment.lastCompletedDate = actualDate
    
    // Recompute next scheduled date
    enrolment.nextScheduledDate = computeNextDate(enrolment)
```

### Failed Test Retry Scheduling

When a test is failed:
- `currentDay` stays the same (it's still the test day)
- `lastCompletedDate` updates to today
- The normal rest gap applies from today to the retry date
- The pattern position does NOT advance (since we're repeating the same day)

This means: if the rest pattern says the gap to the test was 4 days (extra rest), the retry is scheduled using the normal pattern gap (2 or 3 days), NOT the extra rest gap. The extra rest was for approaching the test fresh the first time. Retries use standard recovery.

Wait — actually, let's reconsider. The `extraRestBeforeTest` should still apply on retries because the user is still approaching the same max-effort test. The gap before a test day is the gap, regardless of whether it's the first attempt or a retry.

**Decision: Extra rest before test applies on every attempt, including retries.**

```
// In computeNextDate, when nextDay.isTest:
// This correctly handles retries because currentDay hasn't advanced
if nextDay.isTest AND level.extraRestBeforeTest != nil:
    return lastDate + level.extraRestBeforeTest
```

---

## Algorithm 3: Day Pushback (Missed Day)

When a scheduled day passes without the user completing the exercise:

```
function pushbackExercise(enrolment, today):
    // The exercise's nextScheduledDate was in the past
    // It stays "due" — it doesn't auto-advance
    // The schedule recalculates only when the user completes the day
    
    // On the "Today" dashboard:
    // If nextScheduledDate <= today AND not completed today → show as "due"
    // No automatic pushback happens — the exercise just waits
    
    // When the user eventually completes it:
    // completeTrainingDay() uses the actual completion date
    // nextScheduledDate recalculates from that date
    // The rest of the schedule naturally shifts forward
```

**Key insight:** There is no active "push" operation. The schedule is always computed relative to `lastCompletedDate`. If the user doesn't train for a week, the exercise is just "due" for that entire week. When they eventually complete it, the rest gap applies from the completion date, and everything shifts forward automatically.

---

## Algorithm 4: Conflict Detection

Run after any schedule change (completion, enrolment, manual override).

```
function detectConflicts(allEnrolments) -> [Conflict]:
    var conflicts: [Conflict] = []
    
    // Build a schedule map: date -> [(enrolment, dayPrescription)]
    let scheduleMap: [Date: [(ExerciseEnrolment, DayPrescription)]] = [:]
    
    for enrolment in allEnrolments where enrolment.isActive:
        // Project the next N days (e.g. 14 days) of scheduled training
        var projected = projectSchedule(enrolment, daysAhead: 14)
        for (date, dayPrescription) in projected:
            scheduleMap[date].append((enrolment, dayPrescription))
    
    // Check each date for conflicts
    for (date, sessions) in scheduleMap:
        let testSessions = sessions.filter { $0.1.isTest }
        let regularSessions = sessions.filter { !$0.1.isTest }
        
        // Rule 1: No two test days on the same date
        if testSessions.count > 1:
            conflicts.append(.doubleTest(date: date, exercises: testSessions))
        
        // Rule 2: Test day should not coincide with same-muscle-group training
        for testSession in testSessions:
            let testMuscleGroup = testSession.0.exerciseDefinition.muscleGroup
            for regularSession in regularSessions:
                let regularMuscleGroup = regularSession.0.exerciseDefinition.muscleGroup
                if testMuscleGroup.conflictGroups.contains(regularMuscleGroup):
                    conflicts.append(.testWithSameGroupTraining(
                        date: date,
                        testExercise: testSession,
                        trainingExercise: regularSession
                    ))
    
    return conflicts
```

### Schedule Projection

To detect conflicts, we need to project each exercise's schedule forward:

```
function projectSchedule(enrolment, daysAhead: Int) -> [(Date, DayPrescription)]:
    var results: [(Date, DayPrescription)] = []
    
    // Create a temporary copy of enrolment state
    var tempLevel = enrolment.currentLevel
    var tempDay = enrolment.currentDay
    var tempDate = enrolment.nextScheduledDate ?? Date.now
    var tempPatternIndex = enrolment.restPatternIndex
    
    let endDate = Date.now + daysAhead
    
    while tempDate <= endDate:
        let level = enrolment.exerciseDefinition.levels[tempLevel - 1]
        if tempDay <= level.totalDays:
            let prescription = level.days[tempDay - 1]
            results.append((tempDate, prescription))
            
            // Advance simulation
            if prescription.isTest:
                // Assume test passes for projection purposes
                if tempLevel < 3:
                    tempLevel += 1
                    tempDay = 1
                    tempPatternIndex = 0
                    tempDate = tempDate + interLevelGapDays
                else:
                    break  // program ends
            else:
                tempDay += 1
                tempPatternIndex += 1
                let pattern = level.restDayPattern
                
                // Check if next day is test with extra rest
                if tempDay <= level.totalDays:
                    let nextPrescription = level.days[tempDay - 1]
                    if nextPrescription.isTest, let extra = level.extraRestBeforeTest:
                        tempDate = tempDate + extra
                    else:
                        tempDate = tempDate + pattern[tempPatternIndex % pattern.count]
                
        else:
            break
    
    return results
```

---

## Algorithm 5: Conflict Resolution

```
function resolveConflicts(conflicts) -> [ScheduleAdjustment]:
    var adjustments: [ScheduleAdjustment] = []
    
    // Sort conflicts by date (earliest first)
    let sorted = conflicts.sorted(by: { $0.date < $1.date })
    
    for conflict in sorted:
        switch conflict:
        case .doubleTest(date, exercises):
            // The exercise closer to program completion gets priority
            let sorted = exercises.sorted { remainingDays($0) < remainingDays($1) }
            // Push the lower-priority exercise's schedule by 1 day
            let toPush = sorted.last!
            adjustments.append(.pushOneDay(enrolment: toPush.0, reason: "Avoiding test day collision"))
            
        case .testWithSameGroupTraining(date, testExercise, trainingExercise):
            // Regular training always yields to test day
            adjustments.append(.pushOneDay(enrolment: trainingExercise.0, reason: "Resting muscle group for test day"))
    
    return adjustments
```

### Applying Adjustments

A push adjustment adds 1 day to the exercise's `nextScheduledDate`. After applying, re-run conflict detection to check for cascading conflicts (the push might create a new conflict on the next day). Limit to 5 iterations to prevent infinite loops.

```
function applyAndResolve(allEnrolments):
    var iterations = 0
    while iterations < 5:
        let conflicts = detectConflicts(allEnrolments)
        if conflicts.isEmpty: break
        
        let adjustments = resolveConflicts(conflicts)
        for adj in adjustments:
            adj.enrolment.nextScheduledDate += 1 day
        
        iterations += 1
    
    if iterations == 5:
        // Log warning — couldn't fully resolve. Show remaining conflicts as warnings on dashboard.
```

---

## Algorithm 6: Streak Calculation

```
function updateStreak(streakState, today, allEnrolments):
    // Check if today is a training day for any enrolled exercise
    let exercisesDueToday = allEnrolments.filter {
        $0.isActive && $0.nextScheduledDate != nil && Calendar.isSameDay($0.nextScheduledDate, today)
    }
    
    // If no exercises are due today, it's a rest day — streak continues, no update needed
    if exercisesDueToday.isEmpty: return
    
    // Check if at least one exercise was completed today
    let completedToday = /* query CompletedSet where sessionDate == today */
    
    if !completedToday.isEmpty:
        // User trained today
        if streakState.lastActiveDate == nil || Calendar.isYesterdayOrEarlier(streakState.lastActiveDate, relativeTo: today):
            // Check if there are any missed training days between lastActiveDate and today
            // For simplicity: if lastActiveDate was yesterday OR this is the first active day, increment
            if streakState.lastActiveDate != nil && Calendar.isYesterday(streakState.lastActiveDate, relativeTo: today):
                streakState.currentStreak += 1
            else if streakState.lastActiveDate == nil:
                streakState.currentStreak = 1
            else:
                // Gap of >1 day — but was every day in between a rest day?
                // Check each day between lastActiveDate and today
                var allRestDays = true
                for date in daysBetween(streakState.lastActiveDate, today):
                    let dueOnDate = allEnrolments.filter { wasDueOn($0, date) }
                    if !dueOnDate.isEmpty:
                        allRestDays = false
                        break
                if allRestDays:
                    streakState.currentStreak += 1
                else:
                    streakState.currentStreak = 1  // streak broken
        
        streakState.lastActiveDate = today
        streakState.longestStreak = max(streakState.longestStreak, streakState.currentStreak)
```

Note: The "was every day in between a rest day?" check is complex. For v1, a simpler approximation: if the gap between `lastActiveDate` and `today` is exactly 1 calendar day, the streak continues. If the gap is larger, check if any exercises were due on the missed days. This requires historical schedule reconstruction, which is expensive. 

**Pragmatic v1 approach:** Track streak as consecutive calendar days with at least one completion on every day that had exercises due. On app launch and after each completion, run a lightweight check: "was yesterday a training day? If yes, was at least one exercise completed yesterday?" If the answer is "no to both" (yesterday was a rest day), the streak continues. If "yes it was a training day, but nothing was completed," the streak resets.

---

## Test Cases

### Test 1: Basic Date Calculation
```
Given: Push-Ups L1, pattern [2,2,3], enrolled March 15
When: User completes Day 1 on March 15
Then: nextScheduledDate = March 17 (15 + 2)
      restPatternIndex = 1
      currentDay = 2
```

### Test 2: Pattern Cycling
```
Given: Push-Ups L1, pattern [2,2,3], completed Day 1 on March 15 (index=0)
       Completed Day 2 on March 17 (index=1)  
       Completed Day 3 on March 19 (index=2)
When:  Computing next date after Day 3
Then:  gapDays = pattern[3 % 3] = pattern[0] = 2
       nextScheduledDate = March 21 (wrong — should be March 22 = 19 + 3)
```

Wait — the index should be the index *before* the gap, not after. Let me reconsider.

The gap at `restPatternIndex` is the gap *after* completing the day at that index. So:
- Complete Day 1 → gap is pattern[0] = 2 → next date is +2
- Complete Day 2 → gap is pattern[1] = 2 → next date is +2  
- Complete Day 3 → gap is pattern[2] = 3 → next date is +3
- Complete Day 4 → gap is pattern[3 % 3 = 0] = 2 → next date is +2

**Corrected:** `restPatternIndex` is incremented *after* using it to compute the gap.

### Test 2 (corrected): Pattern Cycling
```
Given: Push-Ups L1, pattern [2,2,3]
       Day 1 completed March 15, restPatternIndex was 0 → gap = 2 → next = March 17, index becomes 1
       Day 2 completed March 17, restPatternIndex was 1 → gap = 2 → next = March 19, index becomes 2
       Day 3 completed March 19, restPatternIndex was 2 → gap = 3 → next = March 22, index becomes 3
       Day 4 completed March 22, restPatternIndex was 3 % 3 = 0 → gap = 2 → next = March 24
Then: Matches spreadsheet dates ✓
```

### Test 3: Extra Rest Before Test
```
Given: Push-Ups L2, pattern [2,2,3], extraRestBeforeTest = 4
       Day 18 completed (second-to-last day)
       Next day (Day 19) is the test day
When: Computing next date
Then: gap = 4 (not pattern value), nextScheduledDate = lastCompleted + 4
```

### Test 4: Level Transition
```
Given: Push-Ups L1, test day (Day 10), testTarget = 20
When: User completes test with 25 reps (>= 20)
Then: currentLevel = 2
      currentDay = 1
      restPatternIndex = 0
      nextScheduledDate = testCompletionDate + 2 (inter-level gap)
```

### Test 5: Failed Test
```
Given: Push-Ups L2, test day (Day 19), testTarget = 50
When: User completes test with 43 reps (< 50)
Then: currentLevel = 2 (unchanged)
      currentDay = 19 (unchanged — still the test day)
      lastCompletedDate = today
      nextScheduledDate = today + 4 (extraRestBeforeTest applies for retry)
```

### Test 6: Missed Day Then Completion
```
Given: Squats L2, nextScheduledDate = March 20
When: User doesn't train March 20, 21, 22. Completes on March 23.
Then: lastCompletedDate = March 23
      Normal rest gap applies from March 23
      restPatternIndex advances normally
      All future dates shift forward by 3 days
```

### Test 7: Conflict — Double Test
```
Given: Push-Ups test on April 5, Pull-Ups test on April 5
When: Conflict detection runs
Then: Conflict detected (double test)
      Lower-priority exercise pushed to April 6
      (Priority: the one closer to program end stays)
```

### Test 8: Conflict — Test With Same Group Training
```
Given: Squats test on April 10, Glute Bridges regular day on April 10
When: Conflict detection runs
Then: Conflict detected (test + same muscle group)
      Glute Bridges pushed to April 11
```

### Test 9: Cascade Resolution
```
Given: Squats test on April 10
       Glute Bridges training on April 10 → pushed to April 11
       But Glute Bridges was already scheduled for April 11 (impossible — they'd have rest)
       Actually: Glute Bridges has a DIFFERENT exercise due April 11
When: Push to April 11 creates new conflict
Then: Engine detects and resolves in next iteration
```

### Test 10: Streak — Partial Completion
```
Given: 5 exercises due today, user completes 2
Then: Streak maintained (at least one completed)
```

### Test 11: Streak — Rest Day
```
Given: No exercises due today (rest day for all)
Then: Streak maintained (rest days never break streaks)
```

### Test 12: Streak — Complete Skip
```
Given: 3 exercises due today, user completes 0
Then: Streak breaks (resets to 0)
```
