# Retention Analytics — Design Spec

**Date:** 2026-03-31
**Status:** Draft
**App:** Daily Ascent (iOS + watchOS bodyweight training)

---

## Problem

The app has no instrumentation. When users stop using the app, there is no data to explain why — whether they dropped off at onboarding, abandoned their first workout, stalled at a specific program day, or simply lost the habit after a streak break. Without this signal, product decisions are guesswork.

---

## Goals

- Understand where in the user journey drop-off occurs
- Identify which exercises have the highest abandonment rate
- Measure onboarding → first workout conversion
- Surface level test calibration issues (pass/fail rates)
- Achieve all of this with zero personal data and no new SDK dependencies

## Non-Goals

- User-level cohort analysis or Day 7 / Day 30 retention (requires a persistent identifier — deliberately excluded)
- A/B testing infrastructure
- Real-time dashboards (batch upload on BGProcessingTask is sufficient)
- Watch-specific events (add in a future phase once iPhone baseline is established)

---

## Privacy Design

### True Anonymity

No persistent identifier is used. Each event is a standalone record with no link to any other session, device, or user.

A **session-scoped ephemeral UUID** is generated in memory on each app launch and discarded when the app is terminated or backgrounded past the OS threshold. This UUID:
- Is never written to disk or Keychain
- Resets to a new random value on every launch
- Cannot be used to identify, single out, or link records across sessions

**GDPR status:** Not personal data. EDPB anonymisation guidance tests three criteria: singling out, linking, inference. A per-session UUID that resets on every launch fails the "linking" test by design. No consent banner, no privacy nutrition label update beyond "Diagnostics / Usage Data" (first-party, not linked to identity).

**ATT (App Tracking Transparency):** Does not apply. ATT governs cross-app and cross-website tracking. These are first-party events within a single app, sent to the developer's own backend.

### Server-Side Requirements

- Supabase project must be configured to **not log or retain client IP addresses** (disable request logging in Supabase dashboard, or use Supabase EU region with a Data Processing Agreement)
- No IP-based rate limiting or session correlation on the server side

### Privacy Policy

Add one sentence: "We collect anonymous session analytics to improve the app. These events cannot be linked to you across sessions or to any personal information."

---

## Event Schema

### Supabase Table

```sql
CREATE TABLE app_events (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id   UUID NOT NULL,          -- ephemeral, per-launch only
    event_name   TEXT NOT NULL,
    occurred_at  TIMESTAMPTZ NOT NULL,   -- device-side timestamp
    uploaded_at  TIMESTAMPTZ DEFAULT now(),
    app_version  TEXT NOT NULL,
    os_version   TEXT NOT NULL,
    properties   JSONB
);

CREATE INDEX idx_events_session   ON app_events(session_id);
CREATE INDEX idx_events_name      ON app_events(event_name);
CREATE INDEX idx_events_occurred  ON app_events(occurred_at);
CREATE INDEX idx_events_props     ON app_events USING gin(properties);

ALTER TABLE app_events ENABLE ROW LEVEL SECURITY;

-- Anonymous inserts only; no client-side reads
CREATE POLICY "Allow anonymous insert" ON app_events
    FOR INSERT WITH CHECK (true);
```

### The 12 Events

#### Lifecycle

| Event | Trigger | Key Properties |
|---|---|---|
| `app_installed` | First launch after install | `app_version`, `os_version` |
| `app_opened` | Each foreground launch | `app_version` |
| `onboarding_completed` | User finishes enrolment flow | `exercises_enrolled: [String]`, `data_consent_given: Bool` |

#### Workout Funnel

| Event | Trigger | Key Properties |
|---|---|---|
| `workout_started` | User taps to begin a session | `exercise_id`, `level`, `day_number` |
| `workout_completed` | All sets saved | `exercise_id`, `level`, `day_number`, `total_sets`, `total_reps`, `duration_seconds`, `counting_mode` |
| `workout_abandoned` | User backs out mid-session | `exercise_id`, `level`, `day_number`, `sets_completed`, `sets_total` |

#### Program Progress

| Event | Trigger | Key Properties |
|---|---|---|
| `level_test_attempted` | User starts a test-day session | `exercise_id`, `current_level` |
| `level_advanced` | User passes test | `exercise_id`, `from_level`, `to_level`, `max_reps_achieved` |
| `level_test_failed` | User does not meet threshold | `exercise_id`, `level`, `max_reps_achieved`, `threshold_required` |

#### Engagement

| Event | Trigger | Key Properties |
|---|---|---|
| `streak_broken` | First day past due with no workout | `streak_length_at_break` |
| `progress_viewed` | User opens Program or History tab | *(none — just the count matters)* |
| `scheduled_session_skipped` | Due workout passes midnight without being started | `exercise_id`, `level`, `day_number`, `consecutive_skips` |

---

## iOS Implementation

### AnalyticsService

A new `AnalyticsService` actor in `inch/inch/Services/`. Injected via SwiftUI environment (consistent with existing service injection pattern — not a singleton):

```swift
actor AnalyticsService {
    private let sessionId = UUID()              // generated once per launch, in memory only
    private var pendingEvents: [PendingEvent] = []
    private let maxQueueSize = 500              // cap; oldest events dropped when exceeded

    func record(_ event: AnalyticsEvent)
    func flush() async                          // called from BGProcessingTask
}
```

**Swift 6 / Sendable compliance:** Properties are not typed as `[String: Any]`. Each event is a typed `Sendable` struct:

```swift
struct AnalyticsEvent: Sendable, Encodable {
    let name: String
    let occurredAt: Date
    let properties: AnalyticsProperties       // typed per-event payload, not [String: Any]
}

enum AnalyticsProperties: Sendable, Encodable {
    case appInstalled(appVersion: String, osVersion: String)
    case appOpened(appVersion: String)
    case onboardingCompleted(exercisesEnrolled: [String], dataConsentGiven: Bool)
    case workoutStarted(exerciseId: String, level: Int, dayNumber: Int)
    case workoutCompleted(exerciseId: String, level: Int, dayNumber: Int, totalSets: Int, totalReps: Int, durationSeconds: Int, countingMode: CountingMode)
    case workoutAbandoned(exerciseId: String, level: Int, dayNumber: Int, setsCompleted: Int, setsTotal: Int)
    case levelTestAttempted(exerciseId: String, currentLevel: Int)
    case levelAdvanced(exerciseId: String, fromLevel: Int, toLevel: Int, maxRepsAchieved: Int)
    case levelTestFailed(exerciseId: String, testedLevel: Int, maxRepsAchieved: Int, thresholdRequired: Int)
    case streakBroken(streakLengthAtBreak: Int)
    case programViewed
    case historyViewed
    case scheduledSessionSkipped(exerciseId: String, level: Int, dayNumber: Int, consecutiveSkips: Int)

    enum CountingMode: String, Sendable, Encodable {
        case realTime = "real_time"
        case postSetConfirmation = "post_set_confirmation"
    }
}
```

`record(_:)` appends to the in-memory queue (max 500 events; oldest dropped when cap is reached). No disk write per event — the queue is persisted to `URL.applicationSupportDirectory/pending_analytics.json` when `scenePhase` transitions to `.background` (written atomically: write to `.tmp` file, then rename). On next launch, the file is read, prepended to the new queue, and deleted.

`flush()` uploads all pending events in a single batch `POST` to Supabase `/rest/v1/app_events` using `URLSession`. Each `PendingEvent` includes a client-generated `id: UUID` for idempotency — if the upload partially succeeds and retries, Supabase's `ON CONFLICT (id) DO NOTHING` prevents duplicates. After a confirmed 2xx response, the queue is cleared.

**Flush integration:** `AnalyticsService.flush()` is called from the BGProcessingTask handler in `InchApp` alongside `DataUploadService`. Unlike sensor uploads, analytics flush does **not** require `requiresExternalPower = true` — it uses a separate, less restrictive task registration (or is appended to the existing task with `requiresNetworkConnectivity = true` only).

### Batching and Upload

Events are buffered in memory and flushed via the existing `BGProcessingTask` (alongside sensor data upload). No additional background task registration needed.

If the app is terminated before flushing, queued events are written to a temporary file on `scenePhase` change to `.background`. On next launch, the file is read and events are prepended to the new session's queue with their original `occurred_at` timestamps. The `session_id` for recovered events is the *new* launch's session ID — no cross-session linking.

### Call Sites

Events are fired from existing view models and services. No UI code fires analytics directly. `AnalyticsService` is injected via the SwiftUI environment (matching the `NotificationService` injection pattern already in the codebase).

```swift
// TodayViewModel (injected via init)
analytics.record(AnalyticsEvent(
    name: "workout_started",
    occurredAt: .now,
    properties: .workoutStarted(exerciseId: enrolment.exerciseId, level: enrolment.currentLevel, dayNumber: enrolment.currentDay)
))

// InchApp — first launch detection
// isFirstLaunch is a Bool on UserSettings, set to true at model creation,
// cleared to false after app_installed fires. UserSettings.isFirstLaunch
// must be added alongside other new UserSettings properties.
if settings.isFirstLaunch {
    analytics.record(AnalyticsEvent(name: "app_installed", occurredAt: .now,
        properties: .appInstalled(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            osVersion: UIDevice.current.systemVersion
        )
    ))
    settings.isFirstLaunch = false
}
```

**`scheduled_session_skipped` trigger:** Fired from `TodayViewModel.loadToday()` when it detects that an enrolled exercise's `nextTrainingDate` is in the past (before today's start of day) and no `CompletedSet` exists for that date. `consecutiveSkips` is computed as the number of past-due dates with no completion. This fires at most once per exercise per app open (guarded by checking if the event was already recorded today for that exercise using the session-scoped ID).

---

## Analytics Queries

These SQL queries answer the five most important questions immediately after launch:

```sql
-- 1. Where in the program do users drop off?
SELECT
    properties->>'day_number' AS day,
    properties->>'exercise_id' AS exercise,
    COUNT(*) AS completions
FROM app_events
WHERE event_name = 'workout_completed'
GROUP BY 1, 2
ORDER BY exercise, day::int;

-- 2. Onboarding → first workout conversion (aggregate funnel)
SELECT
    COUNT(*) FILTER (WHERE event_name = 'onboarding_completed') AS onboarded,
    COUNT(*) FILTER (WHERE event_name = 'workout_started'
        AND (properties->>'day_number')::int = 1) AS first_workout_started;

-- 3. Workout abandonment by exercise
SELECT
    properties->>'exercise_id' AS exercise,
    COUNT(*) AS abandonments
FROM app_events
WHERE event_name = 'workout_abandoned'
GROUP BY 1 ORDER BY 2 DESC;

-- 4. Level test pass/fail rates
SELECT
    properties->>'exercise_id' AS exercise,
    properties->>'level' AS level,
    COUNT(*) FILTER (WHERE event_name = 'level_advanced') AS passed,
    COUNT(*) FILTER (WHERE event_name = 'level_test_failed') AS failed
FROM app_events
WHERE event_name IN ('level_advanced', 'level_test_failed')
GROUP BY 1, 2;

-- 5. Streak break distribution
SELECT
    (properties->>'streak_length_at_break')::int AS streak_length,
    COUNT(*) AS occurrences
FROM app_events
WHERE event_name = 'streak_broken'
GROUP BY 1 ORDER BY 1;
```

---

## Format Conventions

- **`app_version`**: `CFBundleShortVersionString` (e.g. `"1.2"`) — marketing version only, not build number
- **`os_version`**: `UIDevice.current.systemVersion` (e.g. `"18.3.1"`) — no "iOS " prefix

## Analytics Opt-Out

Add a toggle to `PrivacySettingsView`: "Share anonymous usage analytics." Defaults to `true`. Stored as `analyticsEnabled: Bool` on `UserSettings`. When disabled, `AnalyticsService.record(_:)` is a no-op and the pending queue is cleared. Events already uploaded cannot be recalled (they are anonymous and unlinked). This must be added to `UserSettings` alongside `isFirstLaunch` and requires inclusion in the same lightweight schema migration.

## Scope Boundaries

- **iPhone only** in v1. Watch events added in a later phase.
- No Watch-side `AnalyticsService` — iPhone captures all meaningful program events.
- No real-time streaming. Batch upload is sufficient for the questions being answered.
- No dashboarding tool required at launch — SQL queries in Supabase's built-in editor are sufficient for an indie app.
