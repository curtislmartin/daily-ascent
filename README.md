# Daily Ascent — Bodyweight Training App

iOS + watchOS app that guides users through structured bodyweight training programs. Six exercises, three progressive levels each. Users enrol in exercises, follow a prescribed set/rep scheme per day, and advance through levels by passing a max-rep test.

---

## Exercises

| Exercise | Exercise ID | Muscle Group | Levels | Test Targets |
|---|---|---|---|---|
| Push-Ups | `push_ups` | Upper (push) | 3 | 20 → 50 → 100 |
| Squats | `squats` | Lower | 3 | 20 → 100 → 150 |
| Sit-Ups | `sit_ups` | Core (flexion) | 3 | 20 → 60 → 100 |
| Pull-Ups | `pull_ups` | Upper (pull) | 3 | 10 → 20 → 30 |
| Glute Bridges | `glute_bridges` | Lower (posterior) | 3 | 30 → 100 → 150 |
| Dead Bugs | `dead_bugs` | Core (anti-extension) | 3 | 20 → 50 → 80 |

---

## Tech Stack

| | |
|---|---|
| **Platform** | iOS 18.0 + watchOS 10.6 |
| **Language** | Swift 6.2, strict concurrency |
| **UI** | SwiftUI only (no UIKit except where Apple requires it) |
| **Data** | SwiftData (CloudKit-ready schema) |
| **Concurrency** | Swift concurrency only — no GCD, no Combine |
| **Third-party deps** | None |
| **Xcode** | 16.0+ |

---

## Repo Structure

```
inch-project/
├── inch/                          # Xcode project
│   ├── inch/                      # iOS app target
│   │   ├── Features/
│   │   │   ├── Onboarding/        # Enrolment, data consent
│   │   │   ├── Today/             # Daily dashboard + view model
│   │   │   ├── Workout/           # Session, counting modes, rest timer
│   │   │   ├── Program/           # Progress, exercise detail
│   │   │   ├── History/           # Completed workout log, streaks
│   │   │   └── Settings/          # Rest timers, counting mode, privacy
│   │   └── Services/
│   │       ├── WatchConnectivityService.swift
│   │       ├── MotionRecordingService.swift   # Core Motion sensor capture
│   │       ├── HealthKitService.swift
│   │       ├── DataUploadService.swift        # BGProcessingTask + Supabase
│   │       └── NotificationService.swift
│   └── inchwatch Watch App/       # watchOS app target
│       ├── Features/              # Watch Today, Workout, rest timer
│       └── Services/
│           ├── WatchConnectivityService.swift
│           ├── WatchMotionRecordingService.swift
│           └── WatchHealthService.swift
├── Shared/                        # Swift package shared by both targets
│   └── Sources/InchShared/
│       ├── Models/                # SwiftData @Model classes + Enums
│       ├── Engine/                # Pure business logic (no SwiftData dependency)
│       │   ├── SchedulingEngine.swift
│       │   ├── ConflictDetector.swift
│       │   ├── ConflictResolver.swift
│       │   ├── StreakCalculator.swift
│       │   ├── DailyLoadAdvisor.swift
│       │   └── ExerciseDataLoader.swift
│       └── Transfer/              # WatchConnectivity DTOs
└── files/                         # Spec documents (read-only reference)
    ├── bodyweight-ux-design-v2.md # Full UX spec: screens, flows, scheduling rules
    ├── exercise-data.json         # All progressions: 6 exercises, 18 levels, ~300 days
    ├── data-model.md              # SwiftData schema: entities, relationships, enums
    ├── scheduling-engine.md       # Scheduling algorithms + 12 test cases
    ├── architecture.md            # Project structure, state management, navigation
    ├── framework-guidance.md      # WatchConnectivity, Core Motion, HealthKit patterns
    ├── backend-api.md             # Supabase schema, upload endpoints
    └── v1-1-features.md           # History, stats, notifications, complications
```

---

## Architecture Decisions

**Shared package** holds all business logic and models. Both app targets import it. The package does NOT use main-actor default isolation (it's a library). Both app targets do, so most view and service code is implicitly `@MainActor`.

**State management** uses `@Observable` view models — no `@StateObject`, `@ObservedObject`, `@EnvironmentObject`, or `@Published`.

**Navigation** uses `NavigationStack` with `navigationDestination(for:)` throughout. No `NavigationLink(destination:)`, no `NavigationView`.

**Sensor data** — Core Motion captures accelerometer/gyroscope during every set on both iPhone and Apple Watch. Files are binary, transferred from watch to phone via WatchConnectivity file transfer, then batch-uploaded to Supabase via `BGProcessingTask`. Used for future ML-based automatic rep counting.

**Scheduling** is injury-aware: exercises are grouped by muscle group, and the engine prevents scheduling same-group exercises on consecutive days. Each exercise has its own rest-day pattern that determines gaps between sessions.

**Rep counting** has two modes: real-time (motion-based, user taps to count) and manual (user enters reps after the set). Both are selectable per exercise in Settings.

---

## Key Models

| Model | Purpose |
|---|---|
| `ExerciseDefinition` | Static exercise data (name, muscle group, levels) |
| `LevelDefinition` | Level config (target, sets, rest pattern) |
| `DayPrescription` | Per-day rep targets for one level |
| `ExerciseEnrolment` | User's enrolment state: current level, day, next scheduled date |
| `CompletedSet` | Record of one completed set (reps, duration, recording reference) |
| `SensorRecording` | Metadata for a captured motion file |
| `UserSettings` | App-wide preferences (counting mode, rest timers, consent, notifications) |
| `StreakState` | Current streak count and last-updated date |
| `Achievement` | Unlocked achievement record (streak, level, rep milestones) |
| `UserEntitlement` | In-app purchase / subscription record |

---

## Build & Run

```bash
# Open project
open inch/inch.xcodeproj

# Simulators
# iPhone: iPhone 16 Pro
# Watch: Apple Watch Series 10
```

Signing is automatic. Before building, create `inch/inch/Secrets.plist` (gitignored):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>SupabaseURL</key>
    <string>https://your-project.supabase.co</string>
    <key>SupabaseAnonKey</key>
    <string>your-publishable-key</string>
</dict>
</plist>
```

Without this file the app builds and runs normally — analytics and sensor uploads are simply skipped. Supabase upload only activates when the user has granted data consent in onboarding.

---

## Spec Documents

All product and technical decisions live in `files/`. These are read-only reference documents.

| File | Read when |
|---|---|
| `bodyweight-ux-design-v2.md` | Any UI or product question |
| `exercise-data.json` | Anything involving sets/reps/levels |
| `data-model.md` | Any SwiftData or model question |
| `scheduling-engine.md` | Scheduling, conflict detection, streak logic |
| `architecture.md` | Project structure or patterns |
| `framework-guidance.md` | WatchConnectivity, Core Motion, HealthKit |
| `backend-api.md` | Supabase upload pipeline |
| `v1-1-features.md` | History, stats, notifications, complications |
