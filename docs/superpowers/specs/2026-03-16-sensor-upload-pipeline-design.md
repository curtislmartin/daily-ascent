# Sensor Upload Pipeline — Design Spec

**Date:** 2026-03-16
**Status:** Approved for implementation

---

## Overview

This spec covers four related areas that complete the sensor data upload pipeline:

1. **Demographics collection** — wire existing `DemographicTagsView` into onboarding + persistent nudge
2. **`DataUploadService` fix** — use `UserSettings` instead of `Secrets.plist` for identity
3. **Watch recording fix** — create `SensorRecording` when the Watch transfers a file to iPhone
4. **Data unlinking** — replace the contributor ID with a fresh UUID instead of deleting data

---

## 1. Demographics Collection

### Existing code

`DemographicTagsView` already exists in `Features/Onboarding/`. It presents four tag-chip pickers (age, height, biological sex, activity level), with a "Continue" button (calls `onComplete` with current selections) and a "Skip" toolbar button (calls `onComplete(nil, nil, nil, nil)`). It does not touch `UserSettings` — all saving is delegated to the caller.

### Onboarding flow

`OnboardingCoordinatorView` adds a `.demographics` case to its `Step` enum:

```
.enrolment → .placement → .consent → .demographics
```

`DataConsentView` is updated to accept a completion callback `var onComplete: () -> Void`. The coordinator passes `{ step = .demographics }`. `DataConsentView.saveAndFinish()` calls this callback instead of relying on the `RootView` `@Query` side-effect.

**RootView race fix:** Currently, inserting `UserSettings` in `DataConsentView.saveAndFinish()` triggers `RootView`'s `@Query`, which immediately switches to `AppTabView` before the coordinator can advance to `.demographics`. The fix is to add `onboardingComplete: Bool = false` to `UserSettings`. `RootView` guards on `settings.first?.onboardingComplete == true` instead of `!settings.isEmpty`. `DataConsentView` inserts `UserSettings` with `onboardingComplete: false`. The `.demographics` step (both Save and Skip paths) calls a `finishOnboarding()` helper that fetches `UserSettings`, sets `onboardingComplete = true`, and saves — this is the moment `RootView` transitions.

The coordinator passes `DemographicTagsView` an `onComplete` closure that:
1. Updates `UserSettings` with the four values (or leaves nil if skipped)
2. Calls `finishOnboarding()`

### `UserSettings` changes

Two additions (no breaking migration — new properties have defaults):

```swift
var onboardingComplete: Bool = false

var hasDemographics: Bool {
    ageRange != nil && heightRange != nil &&
    biologicalSex != nil && activityLevel != nil
}
```

### Settings tab + badge

`AppTab` gains a `.settings` case. `AppTabView` adds a Settings tab. `SettingsView` currently presents its own `NavigationStack` (designed for sheet presentation); when moved to a tab, its internal `NavigationStack` and `Done` dismiss button are removed — the tab's stack handles navigation.

`AppTabView` reads `UserSettings` via `@Query`. The Settings tab gets `.badge(1)` when:

```swift
(settings.first?.motionDataUploadConsented == true) &&
(settings.first?.hasDemographics == false)
```

Badge disappears automatically once all four demographic fields are set. No badge when consent is not given.

### Today view banner

`TodayViewModel` gets:

```swift
var showDemographicsNudge: Bool = false
```

Set to `true` on `load()` when consent is given and `!settings.hasDemographics`. The `×` button sets it to `false` (session-only — not persisted).

`TodayView` renders the banner at the **bottom** of the scroll content, below the exercise list. Tapping the banner body navigates to `PrivacySettingsView` using the `TodayDestination` routing pattern (see below). Tapping `×` sets `showDemographicsNudge = false`.

**Navigation:** A new `TodayDestination` enum is added to `NavigationDestinations.swift`:

```swift
enum TodayDestination: Hashable {
    case privacySettings
}
```

A `withTodayDestinations()` view modifier is added to `NavigationDestinations.swift` and applied to the Today tab's `NavigationStack` in `AppTabView`.

### Demographics in Privacy Settings

`PrivacySettingsView` adds a `demographicsSection` reusing the same tag-chip style as `DemographicTagsView` (inline, not navigating to the full onboarding view). The section has four picker rows backed by bindings on `viewModel.settings` (consistent with how the existing consent toggle works in the same view), calling `modelContext.save()` on each change. This allows users who skipped onboarding to fill in or update their demographics, which clears the badge/banner.

---

## 2. `DataUploadService` Fix

### Problem

`DataUploadService.loadConfig()` reads `contributorId` and demographics from `Secrets.plist`. This means:
- Uploads ignore `motionDataUploadConsented`
- All uploads use the hardcoded dev UUID, not the per-device UUID
- Demographics are never included in uploaded metadata

### Fix

`loadConfig()` is removed. `uploadPending(context:)` fetches `UserSettings` from the passed `ModelContext` and constructs config inline:

```swift
private func uploadPending(context: ModelContext) async {
    let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first
    guard let settings,
          settings.motionDataUploadConsented,
          !settings.contributorId.isEmpty
    else { return }

    guard let plistURL = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
          let dict = NSDictionary(contentsOf: plistURL) as? [String: Any],
          let supabaseURL = dict["SupabaseURL"] as? String,
          let anonKey = dict["SupabaseAnonKey"] as? String
    else { return }

    let config = SupabaseConfig(
        supabaseURL: supabaseURL,
        anonKey: anonKey,
        contributorId: settings.contributorId,
        ageRange: settings.ageRange,
        heightRange: settings.heightRange,
        biologicalSex: settings.biologicalSex,
        activityLevel: settings.activityLevel
    )
    // fetch and upload pending recordings ...
}
```

`Secrets.plist` retains only `SupabaseURL` and `SupabaseAnonKey`. The `ContributorId` key is removed.

`uploadPending` is called from `handleBGUpload(task:context:)`, which creates its `ModelContext` on `@MainActor` in `inchApp.swift` — the fetch and insert are on the same actor, satisfying SwiftData's threading requirements.

---

## 3. Watch File Transfer Fix

### Problem

`WatchConnectivityService.session(_:didReceive file:)` moves the transferred `.bin` file to disk but never creates a `SensorRecording`. The `file` object (including its URL) is invalidated after the delegate method returns, so the file must be moved synchronously in the delegate — but inserting into SwiftData requires the main actor.

### Solution — `AsyncStream` pattern

Follow the same pattern already used for `completionReports`. A new `receivedFiles` stream is added:

```swift
private let _receivedFiles: AsyncStream<ReceivedSensorFile>.Continuation
let receivedFiles: AsyncStream<ReceivedSensorFile>
```

Where `ReceivedSensorFile` and `WatchSensorMetadata` are `Sendable` value types. `[String: Any]` is not `Sendable` and cannot cross the concurrency boundary, so the delegate extracts all values into typed fields before yielding:

```swift
struct WatchSensorMetadata: Sendable {
    let exerciseId: String
    let setNumber: Int
    let device: String
    let level: Int
    let dayNumber: Int
    let confirmedReps: Int
    let durationSeconds: Double
    let countingMode: String
    let sampleRateHz: Int
    let recordedAt: Double  // Unix timestamp
}

struct ReceivedSensorFile: Sendable {
    let fileURL: URL
    let metadata: WatchSensorMetadata
    let fileSizeBytes: Int
}
```

The `nonisolated` delegate method moves the file, extracts typed metadata, and yields to the stream:

```swift
nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
    let destDir = URL.documentsDirectory.appending(path: "sensor_data", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
    let dest = destDir.appending(path: file.fileURL.lastPathComponent)
    try? FileManager.default.moveItem(at: file.fileURL, to: dest)

    guard let raw = file.metadata,
          let exerciseId = raw["exerciseId"] as? String, !exerciseId.isEmpty
    else { return }  // drop files with missing or empty exerciseId

    let attrs = try? FileManager.default.attributesOfItem(atPath: dest.path)
    let size = (attrs?[.size] as? Int) ?? 0
    let meta = WatchSensorMetadata(
        exerciseId: exerciseId,
        setNumber: raw["setNumber"] as? Int ?? 0,
        device: raw["device"] as? String ?? SensorDevice.appleWatch.rawValue,
        level: raw["level"] as? Int ?? 0,
        dayNumber: raw["dayNumber"] as? Int ?? 0,
        confirmedReps: raw["confirmedReps"] as? Int ?? 0,
        durationSeconds: raw["durationSeconds"] as? Double ?? 0,
        countingMode: raw["countingMode"] as? String ?? "",
        sampleRateHz: raw["sampleRateHz"] as? Int ?? 50,
        recordedAt: raw["recordedAt"] as? Double ?? Date.now.timeIntervalSince1970
    )
    _receivedFiles.yield(ReceivedSensorFile(fileURL: dest, metadata: meta, fileSizeBytes: size))
}
```

Files with a missing or empty `exerciseId` are dropped — a `SensorRecording` with no exercise ID is not useful for training.

A new method `handleReceivedFiles(context:)` consumes the stream on the main actor, creating and inserting `SensorRecording` objects:

```swift
func handleReceivedFiles(context: ModelContext) async {
    for await received in receivedFiles {
        let meta = received.metadata
        let recording = SensorRecording(
            recordedAt: Date(timeIntervalSince1970: meta.recordedAt),
            device: .appleWatch,
            exerciseId: meta.exerciseId,
            level: meta.level,
            dayNumber: meta.dayNumber,
            setNumber: meta.setNumber,
            confirmedReps: meta.confirmedReps,
            sampleRateHz: meta.sampleRateHz,
            durationSeconds: meta.durationSeconds,
            countingMode: meta.countingMode,
            filePath: received.fileURL.path,
            fileSizeBytes: received.fileSizeBytes
        )
        context.insert(recording)
        try? context.save()
    }
}
```

`inchApp.swift` adds a `.task` call mirroring `handleCompletionReports`:

```swift
await watchConnectivity.handleReceivedFiles(context: context)
```

No `nonisolated(unsafe)` or container injection needed — safe structured concurrency throughout.

### Watch side — expand metadata

`WatchMotionRecordingService.stopAndTransfer()` is updated to accept all fields needed for `SensorRecording` reconstruction and includes them in the metadata dictionary:

```swift
func stopAndTransfer(
    exerciseId: String,
    setNumber: Int,
    level: Int,
    dayNumber: Int,
    confirmedReps: Int,
    durationSeconds: Double,
    countingMode: String
) -> URL?
```

Metadata keys: `exerciseId`, `setNumber`, `device`, `level`, `dayNumber`, `confirmedReps`, `durationSeconds`, `countingMode`, `sampleRateHz` (constant 50), `recordedAt` (Unix timestamp as `Double`).

The watch workout view passes all values at the call site.

---

## 4. Data Unlinking

### Rationale

Sensor data is already anonymous. Deleting it destroys training value. Instead, the contributor ID on the user's Supabase rows is replaced with a fresh random UUID, severing the device-to-data link while preserving all recordings for model training. After unlinking, `UserSettings.contributorId` is regenerated so future uploads use a new identity.

### Supabase migration

New `UPDATE` RLS policy on `sensor_recordings`:

```sql
CREATE POLICY "Allow contributor unlink" ON sensor_recordings
    FOR UPDATE
    USING (contributor_id = (current_setting('request.headers')::json->>'x-contributor-id')::uuid)
    WITH CHECK (true);
```

### `DataUploadService` — new method

```swift
func unlinkContributorData(contributorId: String) async throws {
    guard let plistURL = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
          let dict = NSDictionary(contentsOf: plistURL) as? [String: Any],
          let supabaseURL = dict["SupabaseURL"] as? String,
          let anonKey = dict["SupabaseAnonKey"] as? String
    else { throw UploadError.configurationMissing }

    // UUIDs contain only hex chars and hyphens — safe for URL query parameters without encoding
    // UUIDs contain only hex chars and hyphens — safe for URL query parameters
    let newId = UUID().uuidString.lowercased()
    guard let url = URL(string: "\(supabaseURL)/rest/v1/sensor_recordings?contributor_id=eq.\(contributorId)") else {
        throw UploadError.configurationMissing
    }
    var request = URLRequest(url: url)
    request.httpMethod = "PATCH"
    request.setValue(anonKey, forHTTPHeaderField: "apikey")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(contributorId, forHTTPHeaderField: "x-contributor-id")
    request.httpBody = try JSONEncoder().encode(["contributor_id": newId])

    let (_, response) = try await URLSession.shared.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 204 else {
        throw UploadError.unlinkFailed
    }
}
```

`UploadError` gains an `.unlinkFailed` case.

### `PrivacySettingsView`

`DataUploadService` is already injected via `.environment(dataUpload)` in `inchApp.swift`. `PrivacySettingsView` adds `@Environment(DataUploadService.self) private var dataUpload`.

The existing "Delete" buttons are replaced with "Unlink My Sensor Data" (destructive). Flow:

1. Tap "Unlink My Sensor Data"
2. Confirmation dialog: "Your sensor recordings will remain on the server but can no longer be linked to this device. Future uploads will use a new anonymous ID."
3. On confirm: call `dataUpload.unlinkContributorData(contributorId: settings.contributorId)`
4. On success: set `settings.contributorId = UUID().uuidString.lowercased()`, save
5. On failure: show alert — "Couldn't unlink data. Check your connection and try again."

`PrivacySettingsView` adds `@State private var showingUnlinkError = false` and an `.alert` for the error case.

---

## Files Changed

| File | Change |
|---|---|
| `UserSettings.swift` | Add `onboardingComplete: Bool = false`, add `hasDemographics` computed property |
| `OnboardingCoordinatorView.swift` | Add `.demographics` step; wire `DemographicTagsView` with `onComplete` and `finishOnboarding()` |
| `DataConsentView.swift` | Accept `onComplete: () -> Void` callback; insert `UserSettings` with `onboardingComplete: false` |
| `RootView.swift` | Guard on `onboardingComplete == true` instead of `!settings.isEmpty` |
| `AppTab` enum | Add `.settings` case |
| `AppTabView.swift` | Add Settings tab; remove settings sheet logic; add `@Query` for badge |
| `SettingsView.swift` | Remove internal `NavigationStack` and `Done` toolbar button (now a tab, not a sheet) |
| `NavigationDestinations.swift` | Add `TodayDestination` enum and `withTodayDestinations()` modifier |
| `TodayViewModel.swift` | Add `showDemographicsNudge` |
| `TodayView.swift` | Add bottom nudge banner; apply `withTodayDestinations()` |
| `PrivacySettingsView.swift` | Add demographics pickers section; add unlink button + error alert; add `DataUploadService` env |
| `DataUploadService.swift` | Remove `loadConfig()`; use `UserSettings` in `uploadPending()`; add `unlinkContributorData()` |
| `WatchConnectivityService.swift` (iPhone) | Add `receivedFiles` stream; add `handleReceivedFiles(context:)`; update `session(_:didReceive file:)` |
| `WatchMotionRecordingService.swift` (Watch) | Expand `stopAndTransfer()` signature and metadata |
| `inchApp.swift` | Add `handleReceivedFiles` task |
| `Secrets.plist` | Remove `ContributorId` key |
| Supabase migration | Add `UPDATE` RLS policy for contributor unlink |

---

## Out of Scope

- Storage file deletion on unlink (v2 — noted in `backend-api.md`)
- Tracking unlinked contributor IDs in a separate table (irrelevant for ML — data remains valid anonymous training samples)
- Foreground upload trigger on app launch (BGTask is sufficient for v1)
