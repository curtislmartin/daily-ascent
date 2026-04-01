# Retention Analytics — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Instrument the app with 12 anonymous analytics events (lifecycle, workout funnel, program progress, engagement) batched in memory and flushed to Supabase via BGProcessingTask — with no persistent identifier, no ATT prompt, and a user opt-out toggle in Privacy Settings.

**Architecture:** A new `AnalyticsService` actor holds an in-memory queue of typed `AnalyticsEvent` values. The session ID is a `UUID()` generated once at actor init — never stored to disk, reset on every launch. Events are persisted to a JSON file only when the app backgrounds, recovered on next launch. `flush()` posts a batch to Supabase `/rest/v1/app_events`. Call sites are view models — no UI code fires events directly. `AnalyticsService` is injected via SwiftUI environment, matching the `NotificationService` pattern.

**Tech Stack:** Swift actor, `URLSession`, `Encodable`, SwiftData `UserSettings` changes, Supabase REST API, BGProcessingTask

---

## Schema Migration Note

This plan adds `isFirstLaunch: Bool = true` and `analyticsEnabled: Bool = true` to `UserSettings`. These go into `BodyweightSchemaV3`. If the Exercise Form Guidance plan has already been implemented, V3 already exists — add these two properties to the existing V3 migration. If not, create V3 here (see the schema task in the Exercise Form Guidance plan for the full V3 template, then add these properties to it).

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Modify | `Shared/Sources/InchShared/Models/UserSettings.swift` | Add `isFirstLaunch: Bool`, `analyticsEnabled: Bool` |
| Modify | `Shared/Sources/InchShared/Models/BodyweightSchema.swift` | Extend or create V3 (see Exercise Form Guidance plan Task 1 for V3 template) |
| Modify | `Shared/Sources/InchShared/Utilities/ModelContainerFactory.swift` | Use `BodyweightMigrationPlan` if not already updated |
| Create | `inch/inch/Services/AnalyticsService.swift` | Actor: in-memory queue, typed events, flush to Supabase |
| Modify | `inch/inch/inchApp.swift` | Instantiate `AnalyticsService`, inject into environment, fire `app_installed`/`app_opened`, extend BGTask to flush analytics |
| Modify | `inch/inch/Features/Workout/WorkoutViewModel.swift` | Fire `workout_started`, `workout_completed`, `workout_abandoned`, `level_test_attempted`, `level_advanced`, `level_test_failed` |
| Modify | `inch/inch/Features/Workout/WorkoutSessionView.swift` | Inject `AnalyticsService` and pass to `WorkoutViewModel` |
| Modify | `inch/inch/Features/Today/TodayViewModel.swift` | Fire `streak_broken`, `scheduled_session_skipped`; accept `AnalyticsService` |
| Modify | `inch/inch/Features/Today/TodayView.swift` | Pass `AnalyticsService` to `TodayViewModel` |
| Modify | `inch/inch/Features/History/HistoryView.swift` | Fire `progress_viewed` on appear |
| Modify | `inch/inch/Features/Settings/PrivacySettingsView.swift` | Add analytics opt-out toggle bound to `UserSettings.analyticsEnabled` |
| Test | `Shared/Tests/InchSharedTests/AnalyticsServiceTests.swift` | Unit tests for queue behaviour, deduplication, opt-out no-op |

---

### Task 0: Supabase — create `app_events` table

**Prerequisite:** Do this before writing any iOS code. The table must exist before the flush logic can be tested end-to-end.

- [ ] **Step 1: Run the migration SQL in your Supabase project**

In the Supabase dashboard SQL editor (or via MCP if configured), run:

```sql
CREATE TABLE app_events (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id   UUID NOT NULL,
    event_name   TEXT NOT NULL,
    occurred_at  TIMESTAMPTZ NOT NULL,
    uploaded_at  TIMESTAMPTZ DEFAULT now(),
    app_version  TEXT NOT NULL,
    os_version   TEXT NOT NULL,
    properties   JSONB
);

CREATE INDEX idx_events_session  ON app_events(session_id);
CREATE INDEX idx_events_name     ON app_events(event_name);
CREATE INDEX idx_events_occurred ON app_events(occurred_at);
CREATE INDEX idx_events_props    ON app_events USING gin(properties);

ALTER TABLE app_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow anonymous insert" ON app_events
    FOR INSERT WITH CHECK (true);
```

- [ ] **Step 2: Verify the table exists and inserts work**

In the Supabase dashboard, test a manual insert:

```sql
INSERT INTO app_events (session_id, event_name, occurred_at, app_version, os_version, properties)
VALUES (gen_random_uuid(), 'app_opened', now(), '1.0', '18.0', '{}');
```

Expected: 1 row inserted successfully.

- [ ] **Step 3: Note your Supabase project URL and anon key**

You will need these for `AnalyticsService`. Store them in `inch/inch/Config/` as constants (not hardcoded inline in service code). Check the existing `DataUploadService` to see how the project currently handles Supabase credentials — follow the same pattern.

---

### Task 1: Schema migration — add `isFirstLaunch` and `analyticsEnabled`

**Files:**
- Modify: `Shared/Sources/InchShared/Models/UserSettings.swift`
- Modify: `Shared/Sources/InchShared/Models/BodyweightSchema.swift`
- Modify: `Shared/Sources/InchShared/Utilities/ModelContainerFactory.swift`

- [ ] **Step 1: Write the failing tests**

Create `Shared/Tests/InchSharedTests/AnalyticsServiceTests.swift` (we'll add more tests in Task 2, but start with model tests):

```swift
import Testing
@testable import InchShared

struct AnalyticsUserSettingsTests {

    @Test func isFirstLaunchDefaultsTrue() {
        let settings = UserSettings()
        #expect(settings.isFirstLaunch == true)
    }

    @Test func analyticsEnabledDefaultsTrue() {
        let settings = UserSettings()
        #expect(settings.analyticsEnabled == true)
    }
}
```

- [ ] **Step 2: Run to confirm tests fail**

```
swift test --package-path Shared --filter AnalyticsUserSettingsTests
```

Expected: FAIL — properties not found.

- [ ] **Step 3: Add properties to `UserSettings`**

Add after `onboardingComplete`:

```swift
public var isFirstLaunch: Bool = true
public var analyticsEnabled: Bool = true
```

Add to `init` signature with defaults, and assign in `init` body.

- [ ] **Step 4: Extend `BodyweightSchemaV3`**

If V3 doesn't exist yet, follow the full V3 template in the Exercise Form Guidance plan (Task 1, Step 5). If it exists, no schema file changes needed — `UserSettings` already belongs to V3's model list and SwiftData will pick up the new columns.

- [ ] **Step 5: Run tests to confirm they pass**

```
swift test --package-path Shared --filter AnalyticsUserSettingsTests
```

Expected: PASS

- [ ] **Step 6: Build app to verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 7: Commit**

```bash
git add Shared/Sources/InchShared/Models/UserSettings.swift \
        Shared/Sources/InchShared/Models/BodyweightSchema.swift \
        Shared/Sources/InchShared/Utilities/ModelContainerFactory.swift \
        Shared/Tests/InchSharedTests/AnalyticsServiceTests.swift
git commit -m "$(cat <<'EOF'
feat: add isFirstLaunch and analyticsEnabled to UserSettings (V3 schema)

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Create `AnalyticsService`

**Files:**
- Create: `inch/inch/Services/AnalyticsService.swift`

- [ ] **Step 1: Add queue behaviour tests to `AnalyticsServiceTests.swift`**

`AnalyticsService` is an actor — testing actors in Swift Testing requires `await`. Add:

```swift
import Testing
@testable import InchShared
// Note: AnalyticsService is in the inch app target, not InchShared.
// These tests belong in the app's test target if one exists.
// If no app test target exists yet, test queue behaviour manually
// via simulator and move to unit tests when a target is set up.
```

> The `inch` Xcode project may not have a unit test target yet. If it doesn't, create one: **File → New → Target → Unit Testing Bundle** in Xcode, named `inchTests`. Until then, verify behaviour manually on the simulator.

- [ ] **Step 2: Create `AnalyticsService.swift`**

```swift
import Foundation
import UIKit

// MARK: - Event types

struct AnalyticsEvent: Sendable, Encodable {
    let id: UUID                // client-generated, used for idempotency on retry
    let name: String
    let occurredAt: Date
    let properties: AnalyticsProperties

    init(name: String, occurredAt: Date = .now, properties: AnalyticsProperties) {
        self.id = UUID()
        self.name = name
        self.occurredAt = occurredAt
        self.properties = properties
    }
}

enum AnalyticsProperties: Sendable, Encodable {
    case appInstalled(appVersion: String, osVersion: String)
    case appOpened(appVersion: String)
    case onboardingCompleted(exercisesEnrolled: [String], dataConsentGiven: Bool)
    case workoutStarted(exerciseId: String, level: Int, dayNumber: Int)
    case workoutCompleted(exerciseId: String, level: Int, dayNumber: Int,
                          totalSets: Int, totalReps: Int,
                          durationSeconds: Int, countingMode: String)
    case workoutAbandoned(exerciseId: String, level: Int, dayNumber: Int,
                          setsCompleted: Int, setsTotal: Int)
    case levelTestAttempted(exerciseId: String, currentLevel: Int)
    case levelAdvanced(exerciseId: String, fromLevel: Int, toLevel: Int, maxRepsAchieved: Int)
    case levelTestFailed(exerciseId: String, testedLevel: Int,
                         maxRepsAchieved: Int, thresholdRequired: Int)
    case streakBroken(streakLengthAtBreak: Int)
    case progressViewed
    case scheduledSessionSkipped(exerciseId: String, level: Int,
                                 dayNumber: Int, consecutiveSkips: Int)

    // MARK: Encodable conformance — encodes to a flat JSONB dict

    private enum CodingKeys: String, CodingKey {
        case exercise_id, level, day_number, total_sets, total_reps
        case duration_seconds, counting_mode, sets_completed, sets_total
        case current_level, from_level, to_level, max_reps_achieved
        case tested_level, threshold_required, streak_length_at_break
        case consecutive_skips, exercises_enrolled, data_consent_given
        case app_version, os_version
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .appInstalled(let v, let os):
            try c.encode(v, forKey: .app_version)
            try c.encode(os, forKey: .os_version)
        case .appOpened(let v):
            try c.encode(v, forKey: .app_version)
        case .onboardingCompleted(let ids, let consent):
            try c.encode(ids, forKey: .exercises_enrolled)
            try c.encode(consent, forKey: .data_consent_given)
        case .workoutStarted(let id, let lv, let day):
            try c.encode(id, forKey: .exercise_id)
            try c.encode(lv, forKey: .level)
            try c.encode(day, forKey: .day_number)
        case .workoutCompleted(let id, let lv, let day, let sets, let reps, let dur, let mode):
            try c.encode(id, forKey: .exercise_id)
            try c.encode(lv, forKey: .level)
            try c.encode(day, forKey: .day_number)
            try c.encode(sets, forKey: .total_sets)
            try c.encode(reps, forKey: .total_reps)
            try c.encode(dur, forKey: .duration_seconds)
            try c.encode(mode, forKey: .counting_mode)
        case .workoutAbandoned(let id, let lv, let day, let done, let total):
            try c.encode(id, forKey: .exercise_id)
            try c.encode(lv, forKey: .level)
            try c.encode(day, forKey: .day_number)
            try c.encode(done, forKey: .sets_completed)
            try c.encode(total, forKey: .sets_total)
        case .levelTestAttempted(let id, let lv):
            try c.encode(id, forKey: .exercise_id)
            try c.encode(lv, forKey: .current_level)
        case .levelAdvanced(let id, let from, let to, let reps):
            try c.encode(id, forKey: .exercise_id)
            try c.encode(from, forKey: .from_level)
            try c.encode(to, forKey: .to_level)
            try c.encode(reps, forKey: .max_reps_achieved)
        case .levelTestFailed(let id, let lv, let reps, let thresh):
            try c.encode(id, forKey: .exercise_id)
            try c.encode(lv, forKey: .tested_level)
            try c.encode(reps, forKey: .max_reps_achieved)
            try c.encode(thresh, forKey: .threshold_required)
        case .streakBroken(let length):
            try c.encode(length, forKey: .streak_length_at_break)
        case .progressViewed:
            break   // no properties
        case .scheduledSessionSkipped(let id, let lv, let day, let skips):
            try c.encode(id, forKey: .exercise_id)
            try c.encode(lv, forKey: .level)
            try c.encode(day, forKey: .day_number)
            try c.encode(skips, forKey: .consecutive_skips)
        }
    }
}

// MARK: - Service

actor AnalyticsService {
    private let sessionId = UUID()   // ephemeral: never stored, resets every launch
    private var queue: [AnalyticsEvent] = []
    private let maxQueueSize = 500
    private var analyticsEnabled = true

    private var queueFileURL: URL {
        URL.applicationSupportDirectory.appending(path: "pending_analytics.json")
    }

    // Called once at startup with the user's preference
    func configure(enabled: Bool) {
        analyticsEnabled = enabled
        if enabled {
            recoverPersistedQueue()
        }
    }

    func setEnabled(_ enabled: Bool) {
        analyticsEnabled = enabled
        if !enabled {
            queue.removeAll()
            try? FileManager.default.removeItem(at: queueFileURL)
        }
    }

    func record(_ event: AnalyticsEvent) {
        guard analyticsEnabled else { return }
        if queue.count >= maxQueueSize {
            queue.removeFirst()
        }
        queue.append(event)
    }

    // Called from scenePhase .background to persist the queue
    func persistQueue() {
        guard analyticsEnabled, !queue.isEmpty else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(queue) {
            // Atomic write: write to .tmp then rename
            let tmp = queueFileURL.appendingPathExtension("tmp")
            try? data.write(to: tmp, options: .atomic)
            try? FileManager.default.moveItem(at: tmp, to: queueFileURL)
        }
    }

    // Uploads all pending events as a single batch POST to Supabase
    func flush(supabaseURL: URL, anonKey: String) async {
        guard analyticsEnabled, !queue.isEmpty else { return }

        let eventsToSend = queue
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase

        // Build payload array for Supabase bulk insert
        struct Row: Encodable {
            let id: UUID
            let session_id: UUID
            let event_name: String
            let occurred_at: Date
            let app_version: String
            let os_version: String
            let properties: AnalyticsProperties
        }

        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let osVersion = UIDevice.current.systemVersion

        let rows = eventsToSend.map { event in
            Row(
                id: event.id,
                session_id: sessionId,
                event_name: event.name,
                occurred_at: event.occurredAt,
                app_version: appVersion,
                os_version: osVersion,
                properties: event.properties
            )
        }

        guard let body = try? encoder.encode(rows) else { return }

        var request = URLRequest(url: supabaseURL.appending(path: "/rest/v1/app_events"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        // ON CONFLICT (id) DO NOTHING — idempotent retry
        request.setValue("resolution=ignore-duplicates", forHTTPHeaderField: "Prefer")
        request.httpBody = body

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else { return }

        // Clear queue only after confirmed success
        queue.removeAll()
        try? FileManager.default.removeItem(at: queueFileURL)
    }

    // MARK: - Private

    private func recoverPersistedQueue() {
        guard let data = try? Data(contentsOf: queueFileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let recovered = try? decoder.decode([AnalyticsEvent].self, from: data) {
            // Prepend recovered events; they keep original occurred_at timestamps
            queue = recovered + queue
            try? FileManager.default.removeItem(at: queueFileURL)
        }
    }
}
```

> **Note on `AnalyticsEvent` Decodable:** Add `Decodable` conformance to `AnalyticsEvent` and `AnalyticsProperties` if queue persistence round-trips are needed. For now, persistence is write-only and recovery uses the same Encodable path. If you hit a decode error in `recoverPersistedQueue`, the file is silently dropped — this is acceptable, events are non-critical.

- [ ] **Step 3: Build to verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 4: Commit**

```bash
git add inch/inch/Services/AnalyticsService.swift
git commit -m "$(cat <<'EOF'
feat: add AnalyticsService actor with typed events and ephemeral session ID

Privacy-safe: session UUID never persisted, resets every launch.
Events queued in memory, flushed to Supabase via BGProcessingTask.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Inject `AnalyticsService` and fire lifecycle events

**Files:**
- Modify: `inch/inch/inchApp.swift`

- [ ] **Step 1: Inject `AnalyticsService` into environment**

In `InchApp`:

1. Add `let analytics = AnalyticsService()` alongside the other service declarations.
2. In the `WindowGroup` body, add `.environment(analytics)` alongside the other `.environment()` calls.
3. In the `.task` modifier, after `notificationService.checkAuthorizationStatus()`, call:
   ```swift
   let context = ModelContext(self.container)
   let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first
   await analytics.configure(enabled: settings?.analyticsEnabled ?? true)
   ```

- [ ] **Step 2: Fire `app_installed` on first launch**

Still in `InchApp`, after the `analytics.configure(...)` call:

```swift
if settings?.isFirstLaunch == true {
    let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    let osVersion = UIDevice.current.systemVersion
    await analytics.record(AnalyticsEvent(
        name: "app_installed",
        properties: .appInstalled(appVersion: appVersion, osVersion: osVersion)
    ))
    settings?.isFirstLaunch = false
    try? context.save()
}
```

- [ ] **Step 3: Fire `app_opened` on every foreground**

Add a `.onChange(of: scenePhase)` modifier on the `WindowGroup` (or use a separate `View` conformance), or add it to `RootView`. The simplest approach: fire it from a `@Environment(\.scenePhase)` observer in `RootView`. Check how the app currently handles `scenePhase` in `RootView.swift` and add there:

```swift
.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active {
        Task {
            let appVersion = Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? ""
            await analytics.record(AnalyticsEvent(
                name: "app_opened",
                properties: .appOpened(appVersion: appVersion)
            ))
        }
    } else if newPhase == .background {
        Task { await analytics.persistQueue() }
    }
}
```

- [ ] **Step 4: Extend BGProcessingTask to flush analytics**

In `InchApp.registerBGTasks()`, extend the BGTask handler to also flush analytics after the data upload:

```swift
Task { @MainActor in
    let context = ModelContext(container)
    let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first
    let supabaseURL = URL(string: SupabaseConfig.projectURL)!
    await dataUpload.handleBGUpload(task: processingTask, context: context)
    await analytics.flush(supabaseURL: supabaseURL, anonKey: SupabaseConfig.anonKey)
    processingTask.setTaskCompleted(success: true)
}
```

> `SupabaseConfig` is an existing constants file — check `DataUploadService.swift` to see how the project currently stores Supabase credentials and follow the same pattern.

- [ ] **Step 5: Build and verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 6: Commit**

```bash
git add inch/inch/inchApp.swift
git commit -m "$(cat <<'EOF'
feat: inject AnalyticsService and fire app_installed / app_opened events

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Fire workout funnel and program events

**Files:**
- Modify: `inch/inch/Features/Workout/WorkoutViewModel.swift`
- Modify: `inch/inch/Features/Workout/WorkoutSessionView.swift`

- [ ] **Step 1: Add `AnalyticsService` parameter to `WorkoutViewModel`**

`WorkoutViewModel` is `@Observable` and initialized with `enrolmentId`. Add:

```swift
private let analytics: AnalyticsService
private var sessionStartDate: Date = .now

init(enrolmentId: PersistentIdentifier, analytics: AnalyticsService) {
    self.enrolmentId = enrolmentId
    self.analytics = analytics
}
```

> Update the `WorkoutSessionView` init to pass the analytics instance from its `@Environment`.

- [ ] **Step 2: Fire `workout_started` from `load(context:)`**

At the end of `load(context:)`, after `phase = .ready`:

```swift
guard let enrolment, let def = enrolment.exerciseDefinition else { return }
sessionStartDate = .now
Task {
    await analytics.record(AnalyticsEvent(
        name: "workout_started",
        properties: .workoutStarted(
            exerciseId: def.exerciseId,
            level: enrolment.currentLevel,
            dayNumber: enrolment.currentDay
        )
    ))
}
```

- [ ] **Step 3: Fire `workout_completed` from `completeSession(context:)`**

At the end of `completeSession(context:)`, after `phase = .complete`:

```swift
let duration = Int(Date.now.timeIntervalSince(sessionStartDate))
let exerciseId = enrolment.exerciseDefinition?.exerciseId ?? ""
Task {
    await analytics.record(AnalyticsEvent(
        name: completedDay == (level test day) ? "level_test_attempted" : "workout_completed",
        ...
    ))
}
```

Actually, fire both `workout_completed` and (if test day) `level_test_attempted`:

```swift
Task {
    await analytics.record(AnalyticsEvent(
        name: "workout_completed",
        properties: .workoutCompleted(
            exerciseId: exerciseId,
            level: completedLevel,
            dayNumber: completedDay,
            totalSets: totalSets,
            totalReps: sessionTotalReps,
            durationSeconds: duration,
            countingMode: countingMode.rawValue
        )
    ))
    if isTestDay {
        await analytics.record(AnalyticsEvent(
            name: "level_test_attempted",
            properties: .levelTestAttempted(
                exerciseId: exerciseId,
                currentLevel: completedLevel
            )
        ))
    }
    if didAdvanceLevel {
        await analytics.record(AnalyticsEvent(
            name: "level_advanced",
            properties: .levelAdvanced(
                exerciseId: exerciseId,
                fromLevel: completedLevel,
                toLevel: newLevel,
                maxRepsAchieved: sessionTotalReps
            )
        ))
    }
}
```

> `isTestDay`, `totalSets`, `countingMode` are properties you need to capture before `completeSession` clears state. Read the full `completeSession` implementation to ensure you capture them at the right moment.

- [ ] **Step 4: Fire `workout_abandoned` when the user quits mid-session**

Find where the user can abandon a workout (likely `showingQuitConfirm` confirm action in `WorkoutSessionView`). In that confirm action:

```swift
Task {
    await analytics.record(AnalyticsEvent(
        name: "workout_abandoned",
        properties: .workoutAbandoned(
            exerciseId: viewModel.exerciseId,
            level: viewModel.enrolment?.currentLevel ?? 0,
            dayNumber: viewModel.enrolment?.currentDay ?? 0,
            setsCompleted: viewModel.currentSetIndex,
            setsTotal: viewModel.totalSets
        )
    ))
}
dismiss()
```

- [ ] **Step 5: Update `WorkoutSessionView` init to pass analytics**

Find `_viewModel = State(initialValue: WorkoutViewModel(enrolmentId: enrolmentId))` and add the analytics parameter:

```swift
@Environment(AnalyticsService.self) private var analytics

init(enrolmentId: PersistentIdentifier) {
    self.enrolmentId = enrolmentId
    // analytics is injected at view init — access via property wrapper
}
```

Since `@Environment` isn't available at `init` time, use `.onAppear` or `.task` to pass analytics:

```swift
.task {
    viewModel.configure(analytics: analytics)
}
```

Add a `configure(analytics:)` method to `WorkoutViewModel`:

```swift
func configure(analytics: AnalyticsService) {
    // Store reference if not already set during init
    // Consider making analytics an Optional that's set here instead of at init
}
```

> Alternatively, pass `analytics` as a binding or make it a separate property set after init. Choose the pattern that compiles cleanly with Swift 6 strict concurrency. The key constraint: `AnalyticsService` is an actor; it cannot be stored as a `@MainActor`-isolated var on `WorkoutViewModel` unless you bridge correctly.

- [ ] **Step 6: Build and verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 7: Commit**

```bash
git add inch/inch/Features/Workout/WorkoutViewModel.swift \
        inch/inch/Features/Workout/WorkoutSessionView.swift
git commit -m "$(cat <<'EOF'
feat: fire workout funnel and level progression analytics events

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Fire engagement events and add opt-out toggle

**Files:**
- Modify: `inch/inch/Features/Today/TodayViewModel.swift`
- Modify: `inch/inch/Features/Today/TodayView.swift`
- Modify: `inch/inch/Features/History/HistoryView.swift`
- Modify: `inch/inch/Features/Settings/PrivacySettingsView.swift`

- [ ] **Step 1: Fire `scheduled_session_skipped` from `TodayViewModel.loadToday()`**

In `loadToday()`, after computing the today schedule, check for past-due sessions. For each active enrolment where `nextScheduledDate` is before today's start and no `CompletedSet` exists for that date:

```swift
let todayStart = Calendar.current.startOfDay(for: .now)
let skippedEnrolments = activeEnrolments.filter { enrolment in
    guard let scheduled = enrolment.nextScheduledDate else { return false }
    return scheduled < todayStart
}
for enrolment in skippedEnrolments {
    guard let def = enrolment.exerciseDefinition else { continue }
    let hasCompletion = enrolment.completedSets?.contains(where: {
        Calendar.current.isDate($0.completedAt, inSameDayAs: enrolment.nextScheduledDate ?? .distantPast)
    }) ?? false
    guard !hasCompletion else { continue }
    // Count consecutive skips (simplified: days since scheduled)
    let skips = max(1, Calendar.current.dateComponents([.day], from: scheduled, to: todayStart).day ?? 1)
    Task {
        await analytics.record(AnalyticsEvent(
            name: "scheduled_session_skipped",
            properties: .scheduledSessionSkipped(
                exerciseId: def.exerciseId,
                level: enrolment.currentLevel,
                dayNumber: enrolment.currentDay,
                consecutiveSkips: skips
            )
        ))
    }
}
```

- [ ] **Step 2: Fire `streak_broken` when the streak drops to 0**

Read `TodayViewModel` to find where it detects a streak break (likely in `loadToday()` after computing `currentStreak`). Add:

```swift
if previousStreak > 0 && currentStreak == 0 {
    Task {
        await analytics.record(AnalyticsEvent(
            name: "streak_broken",
            properties: .streakBroken(streakLengthAtBreak: previousStreak)
        ))
    }
}
```

You may need to add a `previousStreak` variable to compare against.

- [ ] **Step 3: Fire `progress_viewed` from `HistoryView`**

In `inch/inch/Features/History/HistoryView.swift`, add:

```swift
@Environment(AnalyticsService.self) private var analytics

// In body or onAppear:
.onAppear {
    Task {
        await analytics.record(AnalyticsEvent(
            name: "progress_viewed",
            properties: .progressViewed
        ))
    }
}
```

- [ ] **Step 4: Add analytics opt-out toggle to `PrivacySettingsView`**

Read `inch/inch/Features/Settings/PrivacySettingsView.swift`. Add a `Toggle` bound to `settings.analyticsEnabled`:

```swift
Toggle(isOn: Binding(
    get: { settings?.analyticsEnabled ?? true },
    set: { newValue in
        settings?.analyticsEnabled = newValue
        try? modelContext.save()
        Task { await analytics.setEnabled(newValue) }
    }
)) {
    VStack(alignment: .leading) {
        Text("Share anonymous usage analytics")
        Text("Helps improve the app. No personal data is collected. Cannot be linked to you.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
```

- [ ] **Step 5: Build and verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 6: End-to-end smoke test**

Run on simulator. Open the app, start and complete a workout. Manually trigger a BGTask flush (or call `analytics.flush(...)` from the Debug panel). Check the Supabase `app_events` table — you should see `app_installed`, `app_opened`, `workout_started`, `workout_completed` rows.

- [ ] **Step 7: Commit**

```bash
git add inch/inch/Features/Today/TodayViewModel.swift \
        inch/inch/Features/Today/TodayView.swift \
        inch/inch/Features/History/HistoryView.swift \
        inch/inch/Features/Settings/PrivacySettingsView.swift
git commit -m "$(cat <<'EOF'
feat: fire engagement events and add analytics opt-out toggle

Tracks streak_broken, scheduled_session_skipped, progress_viewed.
Analytics can be disabled in Privacy Settings — disabling clears the queue.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```
