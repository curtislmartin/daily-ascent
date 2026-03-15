# Handoff Preparation Checklist

## What Claude Code Needs to Build This App

The UX design doc describes what the app does and why. Claude Code needs documents that describe **how** to build it — exact data shapes, precise algorithms, project structure, and framework-specific guidance for areas without community agent skills.

---

## Documents to Create

### 1. ✅ UX & Interaction Design (DONE)
`bodyweight-ux-design-v2.md`
- Screen flows, counting modes, scheduling logic, privacy, monetisation
- Serves as the product spec — Claude Code references this for "what should happen"

### 2. Exercise Progression Data (JSON)
`exercise-data.json`

Convert the spreadsheet into a machine-readable JSON file that ships as a bundled resource in the app. This is the source of truth for all exercise progressions.

Structure needed:
```json
{
  "exercises": [
    {
      "id": "push_ups",
      "name": "Push-Ups",
      "muscleGroup": "upper_push",
      "color": "#E8722A",
      "countingMode": "post_set_confirmation",
      "defaultRestSeconds": 60,
      "levels": [
        {
          "level": 1,
          "restDayPattern": [1, 2, 1, 3],
          "extraRestBeforeTest": false,
          "testTarget": 20,
          "days": [
            { "day": 1, "sets": [2, 3, 4, 3, 2] },
            { "day": 2, "sets": [3, 4, 4, 3, 2] },
            ...
            { "day": 10, "sets": [20] }  // test day
          ]
        },
        { "level": 2, ... },
        { "level": 3, ... }
      ]
    },
    ...
  ]
}
```

Why this matters: Claude Code can read this file and generate the seed data loading, the scheduling engine, and all the UI that displays set prescriptions — without having to interpret a spreadsheet.

### 3. SwiftData Schema Document
`data-model.md`

Exact entity definitions with all properties, relationships, and indexes. This is the single source of truth for the data layer.

Entities needed:
- **ExerciseDefinition** — static exercise data (loaded from JSON)
- **LevelDefinition** — level config per exercise
- **DayPrescription** — what sets/reps are prescribed for each day
- **UserExerciseEnrolment** — which exercises the user has enrolled in
- **ExerciseProgress** — current state per exercise (level, day, last completed, next scheduled)
- **CompletedSession** — a finished workout session (date, duration, exercises done)
- **CompletedSet** — individual set within a session (exercise, set number, target reps, actual reps, timestamp)
- **SensorRecording** — metadata for a motion data recording (exercise, set, rep count, file path, upload status)
- **UserSettings** — rest timer overrides, counting mode overrides, notification preferences
- **DataConsent** — ML upload opt-in status, contributor UUID, demographic tags
- **StreakState** — current streak count, last active date
- **UserEntitlement** — StoreKit purchase records (future)
- **FeatureFlag** — premium feature gates (future)

Relationships, cascade rules, indexes, and computed properties all specified.

### 4. Technical Architecture Document
`architecture.md`

Project structure, target configuration, and framework responsibilities.

Contents:
- **Xcode project structure**: iOS app target, watchOS app target, shared framework (for models and business logic), widget extension (future)
- **Shared framework**: SwiftData models, scheduling engine, exercise data loader — shared between iOS and watchOS targets
- **Framework dependencies per target**: which frameworks each target imports
- **File organisation**: folder structure, naming conventions, where things live
- **Navigation architecture**: iOS uses NavigationStack with path-based routing; watchOS uses NavigationStack with simpler hierarchy
- **State management**: how @Observable view models coordinate with SwiftData, how workout session state flows
- **WatchConnectivity architecture**: which messages go which direction, activation flow, session delegation
- **Background task registration**: BGProcessingTask for ML data upload, how it schedules
- **HealthKit workout session lifecycle**: when HKWorkoutSession starts/stops, how it maps to the exercise-level sessions

### 5. Scheduling Engine Specification
`scheduling-engine.md`

The scheduling engine is the most complex piece of pure logic. It needs a precise spec with pseudocode and test cases.

Contents:
- **Date calculation algorithm**: given last completed date + rest pattern position, compute next scheduled date
- **Rest pattern cycling**: how the 1-2-1-3 and 2-2-3 patterns work, how position tracks across days
- **+1 pushback logic**: when a day is missed, how the rest of the schedule recalculates
- **Conflict detection**: full algorithm with priority rules
- **Conflict resolution**: auto-push logic with cascade handling
- **Test day identification**: how to determine if a day is a test day
- **Level transition**: what happens when a test is passed — gap calculation, next level start
- **Edge cases**: what if all exercises are pushed to the same day? what if a push creates a new conflict? what if the user completes an exercise out of order?
- **Test cases**: specific input/output examples for each algorithm

### 6. Framework-Specific Guidance (no community skills available)
`framework-guidance.md`

For frameworks not covered by Swift Agent Skills, we need to write our own guidance documents so Claude Code doesn't hallucinate APIs or use deprecated patterns.

Sections needed:
- **WatchConnectivity**: activation flow, transferUserInfo vs sendMessage vs transferFile, error handling, when to use which, session delegate setup, handling background delivery
- **Core Motion**: CMMotionManager setup, starting/stopping accelerometer+gyroscope updates, sampling rate configuration, recording to file during a workout set, battery considerations
- **HealthKit**: HKWorkoutSession and HKLiveWorkoutBuilder setup on watchOS, HKWorkout creation on iOS, requesting authorizations, metadata attachment
- **BGProcessingTask**: registration in Info.plist, scheduling, handling expiration, WiFi + charging requirements check
- **StoreKit 2**: basic Transaction listener setup, entitlement checking (stubbed for v1, implemented in v2)

### 7. CLAUDE.md File
`CLAUDE.md` (placed in project root)

The project-level instructions file that Claude Code reads on every invocation. This ties everything together.

Contents:
- Project overview (one paragraph)
- Links to all spec documents
- Build instructions (Xcode version, deployment targets, signing)
- Testing instructions (which tests to run, what coverage is expected)
- Code style rules (Swift conventions, naming, file organization)
- What NOT to do (no UIKit, no Combine unless necessary, no third-party dependencies except those explicitly listed)
- Current development phase and priorities

### 8. Backend API Specification (lightweight)
`backend-api.md`

The Supabase backend for ML data collection. Simple enough to spec in one document.

Contents:
- **Supabase project setup**: tables, storage buckets, RLS policies
- **Upload endpoint**: POST to Supabase Storage with metadata insert to Postgres
- **Data schema**: the sensor recording metadata table
- **Authentication**: anonymous — no user accounts, just the contributor UUID in the request
- **Rate limiting**: basic protection against abuse
- **Data deletion endpoint**: DELETE by contributor UUID

---

## Document Creation Order

Priority order for creating these (each builds on the previous):

1. **Exercise Data JSON** — extract from spreadsheet, everything else references this
2. **SwiftData Schema** — defines the data layer that all features build on
3. **Scheduling Engine Spec** — the most complex logic, needs thorough test cases
4. **Technical Architecture** — project structure and framework integration
5. **Framework Guidance** — fills the gaps where no agent skills exist
6. **Backend API Spec** — lightweight, needed for the upload feature
7. **CLAUDE.md** — written last, references everything above

---

## Agent Skills to Install

### Essential (install before starting)
1. **SwiftUI Pro** — github.com/twostraws/SwiftUI-Agent-Skill
2. **SwiftData Pro** — github.com/twostraws/SwiftData-Agent-Skill
3. **Swift Concurrency Pro** — github.com/twostraws/Swift-Concurrency-Agent-Skill
4. **Swift Testing Pro** — github.com/twostraws/Swift-Testing-Agent-Skill

### Recommended
5. **iOS Accessibility** — github.com/dadederk/iOS-Accessibility-Agent-Skill
6. **Writing for Interfaces** — github.com/andrewgleave/skills/tree/main/writing-for-interfaces

### Not needed (covered by our own docs or not relevant for v1)
- Core Data skills (we're using SwiftData, not Core Data)
- App Store skills (not submitting yet)
- Performance audit (premature for v1)
- SwiftUI Design Principles (SwiftUI Pro covers this)

---

## What I Don't Need Uploaded to Me

You don't need to upload the agent skill files to this conversation. Those skills are installed into Claude Code's environment directly (via the claude code CLI or project config). They work at the Claude Code level, not the planning level.

What you SHOULD upload to Claude Code's context (or place in the project directory):
- All the documents listed above
- The original spreadsheet (as reference, though the JSON extraction replaces it for code generation)
- The wireframe JSX file (as visual reference for UI implementation)

---

## Handoff Workflow

1. Create all documents in this checklist (we do this together here)
2. Set up the Xcode project skeleton (targets, signing, deployment targets)
3. Install the 4-6 agent skills into Claude Code
4. Place all spec documents in the project directory
5. Write the CLAUDE.md referencing everything
6. Start Claude Code with: "Read CLAUDE.md and all referenced spec documents. Begin with the shared framework: SwiftData models and the scheduling engine, with full test coverage."

The scheduling engine + data model should be built and tested first because everything else depends on them. Then the iOS UI, then the Watch companion, then HealthKit, then sensor recording, then the upload pipeline.
