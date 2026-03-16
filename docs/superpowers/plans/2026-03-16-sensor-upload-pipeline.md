# Sensor Upload Pipeline Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the sensor data upload pipeline by adding optional demographics collection to onboarding, fixing the DataUploadService to use real user identity, wiring Watch file transfers into SwiftData, and replacing data deletion with anonymous unlinking.

**Architecture:** Four loosely-coupled changes that all feed into the same upload pipeline: (1) collect demographics in onboarding + nudge incomplete users; (2) fix DataUploadService to read identity from UserSettings instead of Secrets.plist; (3) create SensorRecording objects when the Watch transfers files to iPhone using an AsyncStream bridge; (4) add an unlink endpoint that replaces the contributor UUID rather than deleting data.

**Tech Stack:** Swift 6.2, SwiftUI, SwiftData, WatchConnectivity, Supabase REST API, BGProcessingTask, Swift Testing

**Spec:** `docs/superpowers/specs/2026-03-16-sensor-upload-pipeline-design.md`

---

## Chunk 1: Foundation — Model, Migration, Onboarding

### Task 1: Add `onboardingComplete` and `hasDemographics` to UserSettings

**Files:**
- Modify: `Shared/Sources/InchShared/Models/UserSettings.swift`

- [ ] **Step 1: Add `onboardingComplete` stored property and `hasDemographics` computed property**

  Open `Shared/Sources/InchShared/Models/UserSettings.swift`. Add after `activityLevel`:

  ```swift
  public var onboardingComplete: Bool = false
  ```

  Add a computed property after all stored properties (before `init`):

  ```swift
  public var hasDemographics: Bool {
      ageRange != nil && heightRange != nil &&
      biologicalSex != nil && activityLevel != nil
  }
  ```

  Add `onboardingComplete: Bool = false` as the last parameter of `public init` and `self.onboardingComplete = onboardingComplete` as the last assignment. The full updated signature is:

  ```swift
  public init(
      createdAt: Date = Date.now,
      restOverrides: [String: Int] = [:],
      countingModeOverrides: [String: String] = [:],
      interExerciseRestEnabled: Bool = false,
      interExerciseRestSeconds: Int = 120,
      dailyReminderEnabled: Bool = true,
      dailyReminderHour: Int = 8,
      dailyReminderMinute: Int = 0,
      streakProtectionEnabled: Bool = true,
      testDayNotificationEnabled: Bool = true,
      levelUnlockNotificationEnabled: Bool = true,
      streakProtectionHour: Int = 19,
      streakProtectionMinute: Int = 0,
      showConflictWarnings: Bool = true,
      motionDataUploadConsented: Bool = false,
      consentDate: Date? = nil,
      contributorId: String = "",
      ageRange: String? = nil,
      heightRange: String? = nil,
      biologicalSex: String? = nil,
      activityLevel: String? = nil,
      onboardingComplete: Bool = false
  ) {
      self.createdAt = createdAt
      self.restOverrides = restOverrides
      self.countingModeOverrides = countingModeOverrides
      self.interExerciseRestEnabled = interExerciseRestEnabled
      self.interExerciseRestSeconds = interExerciseRestSeconds
      self.dailyReminderEnabled = dailyReminderEnabled
      self.dailyReminderHour = dailyReminderHour
      self.dailyReminderMinute = dailyReminderMinute
      self.streakProtectionEnabled = streakProtectionEnabled
      self.testDayNotificationEnabled = testDayNotificationEnabled
      self.levelUnlockNotificationEnabled = levelUnlockNotificationEnabled
      self.streakProtectionHour = streakProtectionHour
      self.streakProtectionMinute = streakProtectionMinute
      self.showConflictWarnings = showConflictWarnings
      self.motionDataUploadConsented = motionDataUploadConsented
      self.consentDate = consentDate
      self.contributorId = contributorId
      self.ageRange = ageRange
      self.heightRange = heightRange
      self.biologicalSex = biologicalSex
      self.activityLevel = activityLevel
      self.onboardingComplete = onboardingComplete
  }
  ```

- [ ] **Step 2: Build the Shared package to confirm no errors**

  ```bash
  cd /Users/curtismartin/Work/inch-project
  swift build --package-path Shared
  ```

  Expected: `Build complete!`

- [ ] **Step 3: Write a Swift Testing test for `hasDemographics`**

  Locate the Shared test target. Create `Shared/Tests/InchSharedTests/UserSettingsTests.swift` (flat, matching the existing test layout):

  ```swift
  import Testing
  @testable import InchShared

  struct UserSettingsTests {

      @Test func hasDemographicsReturnsFalseWhenAllNil() {
          let settings = UserSettings()
          #expect(settings.hasDemographics == false)
      }

      @Test func hasDemographicsReturnsFalseWhenPartial() {
          let settings = UserSettings(ageRange: "30–39")
          #expect(settings.hasDemographics == false)
      }

      @Test func hasDemographicsReturnsTrueWhenAllSet() {
          let settings = UserSettings(
              ageRange: "30–39",
              heightRange: "171–180cm",
              biologicalSex: "Male",
              activityLevel: "Intermediate"
          )
          #expect(settings.hasDemographics)
      }

      @Test func onboardingCompleteDefaultsFalse() {
          let settings = UserSettings()
          #expect(settings.onboardingComplete == false)
      }
  }
  ```

- [ ] **Step 4: Run the tests**

  ```bash
  swift test --package-path Shared --filter UserSettingsTests
  ```

  Expected: 4 tests pass.

- [ ] **Step 5: Commit**

  ```bash
  git add Shared/Sources/InchShared/Models/UserSettings.swift \
          Shared/Tests/InchSharedTests/UserSettingsTests.swift
  git commit -m "feat: add onboardingComplete and hasDemographics to UserSettings"
  ```

---

### Task 2: Apply Supabase UPDATE RLS policy

**Files:**
- Supabase migration (via MCP)

- [ ] **Step 1: Apply the migration**

  Use the Supabase MCP tool `apply_migration` with project ID `xwvlewuuavpgurmtenwk`:

  ```sql
  CREATE POLICY "Allow contributor unlink" ON sensor_recordings
      FOR UPDATE
      USING (contributor_id = (current_setting('request.headers')::json->>'x-contributor-id')::uuid)
      WITH CHECK (true);
  ```

  Migration name: `allow_contributor_unlink`

- [ ] **Step 2: Commit a record of the migration**

  ```bash
  git commit --allow-empty -m "feat(supabase): add UPDATE RLS policy for contributor unlink"
  ```

---

### Task 3: Update onboarding flow (DataConsentView + coordinator + RootView)

**Files:**
- Modify: `inch/inch/Features/Onboarding/DataConsentView.swift`
- Modify: `inch/inch/Features/Onboarding/OnboardingCoordinatorView.swift`
- Modify: `inch/inch/Navigation/RootView.swift`

**Context:**
- `DataConsentView` has a `saveAndFinish()` method that directly inserts `UserSettings` into the model context and relies on `RootView`'s `@Query` detecting the insert to auto-transition to `AppTabView`. This is the race: the insert fires before the coordinator can advance to `.demographics`.
- The fix: add an `onComplete: () -> Void` callback to `DataConsentView`, insert `UserSettings` with `onboardingComplete: false`, and call the callback instead of relying on `@Query`. The coordinator advances to `.demographics` via the callback.
- **Non-consent path:** If the user declines data sharing, there's no point showing demographics. The coordinator should check `motionDataUploadConsented` after consent and skip directly to `finishOnboarding()` if consent was declined.
- The `.demographics` case is new — it does not yet exist in `OnboardingCoordinatorView`.

- [ ] **Step 1: Update `DataConsentView` to accept a callback and insert with `onboardingComplete: false`**

  In `DataConsentView.swift`:

  1. Add a stored property after the `@State private var consented = true` line:
     ```swift
     var onComplete: () -> Void = {}
     ```

  2. In `saveAndFinish()`, change the `UserSettings` init to include `onboardingComplete: false` and use `.lowercased()` on the UUID:
     ```swift
     let settings = UserSettings(
         motionDataUploadConsented: consented,
         consentDate: consented ? .now : nil,
         contributorId: consented ? UUID().uuidString.lowercased() : "",
         onboardingComplete: false
     )
     ```

  3. At the end of `saveAndFinish()`, replace the comment line with a callback call:
     ```swift
     onComplete()
     ```
     Remove the comment `// RootView's @Query on UserSettings detects the new record and auto-transitions to AppTabView`.

- [ ] **Step 2: Add `.demographics` step to `OnboardingCoordinatorView`**

  In `OnboardingCoordinatorView.swift`:

  1. Add `.demographics` to the `Step` enum:
     ```swift
     private enum Step {
         case enrolment
         case placement
         case consent
         case demographics
     }
     ```

  2. Update the `DataConsentView()` call to pass the callback. The callback fetches settings to check consent — if consented, show demographics; if not, finish immediately:
     ```swift
     case .consent:
         DataConsentView(onComplete: {
             let allSettings = (try? modelContext.fetch(FetchDescriptor<UserSettings>())) ?? []
             if allSettings.first?.motionDataUploadConsented == true {
                 step = .demographics
             } else {
                 // Non-consenting users skip demographics; mark onboarding complete
                 if let s = allSettings.first {
                     s.onboardingComplete = true
                     try? modelContext.save()
                 }
             }
         })
     ```

  3. Add the `.demographics` case:
     ```swift
     case .demographics:
         DemographicTagsView { ageRange, heightRange, biologicalSex, activityLevel in
             let allSettings = (try? modelContext.fetch(FetchDescriptor<UserSettings>())) ?? []
             if let s = allSettings.first {
                 s.ageRange = ageRange
                 s.heightRange = heightRange
                 s.biologicalSex = biologicalSex
                 s.activityLevel = activityLevel
                 s.onboardingComplete = true
                 try? modelContext.save()
             }
         }
     ```

  Note: `DemographicTagsView` already has a "Skip" toolbar button that calls `onComplete(nil, nil, nil, nil)`. Both Save and Skip paths set `onboardingComplete = true` (demographics will be nil for skip, which is correct).

- [ ] **Step 3: Update `RootView` to guard on `onboardingComplete`**

  In `RootView.swift`, change:
  ```swift
  if settings.isEmpty {
  ```
  to:
  ```swift
  if settings.first?.onboardingComplete != true {
  ```

- [ ] **Step 4: Build and verify in Xcode**

  Build the `inch` scheme (⌘B). Run on iPhone 16 Pro simulator. Walk through onboarding twice:
  1. Consent → verify demographics screen appears → save demographics → verify app opens
  2. Fresh install → decline consent → verify app opens directly (no demographics screen)

- [ ] **Step 5: Commit**

  ```bash
  git add inch/inch/Features/Onboarding/DataConsentView.swift \
          inch/inch/Features/Onboarding/OnboardingCoordinatorView.swift \
          inch/inch/Navigation/RootView.swift
  git commit -m "feat: add demographics step to onboarding, fix RootView race condition"
  ```

---

## Chunk 2: UI — Settings Tab, Today Banner, Privacy Demographics

### Task 4: Add Settings tab with demographics badge

**Files:**
- Modify: `inch/inch/Navigation/AppTabView.swift`
- Modify: `inch/inch/Features/Settings/SettingsView.swift`

**Context:** Settings is currently a sheet. Moving it to a tab means removing `SettingsView`'s own `NavigationStack` and `Done` dismiss button. The badge appears on the Settings tab when the user has consented but hasn't filled in all four demographic fields.

- [ ] **Step 1: Add `.settings` to `AppTab` and update `AppTabView`**

  In `AppTabView.swift`:

  1. Add `.settings` to the enum:
     ```swift
     enum AppTab: String, CaseIterable {
         case today, program, history, settings
     }
     ```

  2. Add `@Query` and a computed badge property to `AppTabView`:
     ```swift
     @Query private var allSettings: [UserSettings]

     private var showSettingsBadge: Bool {
         guard let s = allSettings.first else { return false }
         return s.motionDataUploadConsented && !s.hasDemographics
     }
     ```

  3. Add the Settings tab after History:
     ```swift
     Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
         NavigationStack {
             SettingsView()
         }
     }
     .badge(showSettingsBadge ? 1 : 0)
     ```

- [ ] **Step 2: Strip `SettingsView` of its sheet-only wrappers**

  In `SettingsView.swift`:

  1. Remove the outer `NavigationStack { ... }` wrapper — the tab provides navigation.
  2. Remove the `@Environment(\.dismiss) private var dismiss` property.
  3. Remove the `ToolbarItem` with the `Button("Done") { dismiss() }` — there is no sheet to dismiss.

  The `body` should now be just the `List { ... }` with `.listStyle`, `.navigationTitle`, and `.navigationBarTitleDisplayMode`.

- [ ] **Step 3: Remove the SettingsView sheet from HistoryView**

  Open `inch/inch/Features/History/HistoryView.swift`. Find the `.sheet(isPresented:) { SettingsView() }` modifier and its associated `@State private var showingSettings` (or similar) property, and remove both. Settings is now reached via the tab bar.

- [ ] **Step 4: Build and verify**

  Build in Xcode (⌘B). Run on simulator. Confirm Settings appears as a tab. After completing onboarding with consent but skipping demographics, confirm the badge dot appears on the Settings tab.

- [ ] **Step 5: Commit**

  ```bash
  git add inch/inch/Navigation/AppTabView.swift \
          inch/inch/Features/Settings/SettingsView.swift
  git commit -m "feat: move Settings to tab bar with demographics badge"
  ```

---

### Task 5: Today view demographics nudge banner

**Files:**
- Modify: `inch/inch/Navigation/NavigationDestinations.swift`
- Modify: `inch/inch/Features/Today/TodayViewModel.swift`
- Modify: `inch/inch/Features/Today/TodayView.swift`

**Context:** The banner sits at the bottom of the Today scroll view. It's session-dismissible (sets `showDemographicsNudge = false` in the VM). Tapping the banner body pushes `PrivacySettingsView` via `TodayDestination.privacySettings`.

- [ ] **Step 1: Add `TodayDestination` to `NavigationDestinations.swift`**

  In `NavigationDestinations.swift`, add after the `HistoryDestination` block:

  ```swift
  enum TodayDestination: Hashable {
      case privacySettings
  }

  extension View {
      func withTodayDestinations() -> some View {
          navigationDestination(for: TodayDestination.self) { destination in
              switch destination {
              case .privacySettings:
                  PrivacySettingsView(viewModel: SettingsViewModel())
              }
          }
      }
  }
  ```

  Note: `PrivacySettingsView` takes a `SettingsViewModel`. Instantiating a new one here is fine — it will call `load(context:)` via `.task` when the view appears.

- [ ] **Step 2: Add `showDemographicsNudge` to `TodayViewModel`**

  In `TodayViewModel.swift`:

  1. Add a property alongside the other `var` properties at the top:
     ```swift
     var showDemographicsNudge: Bool = false
     ```

  2. `TodayViewModel` does not currently fetch `UserSettings`. Add a fetch at the end of `loadToday(context:showWarnings:)`, after the `resetStreakForMissedDayIfNeeded` call:
     ```swift
     let allSettings = (try? context.fetch(FetchDescriptor<UserSettings>())) ?? []
     if let s = allSettings.first {
         showDemographicsNudge = s.motionDataUploadConsented && !s.hasDemographics
     }
     ```

- [ ] **Step 3: Add the nudge banner to `TodayView`**

  In `TodayView.swift`:

  1. Apply `withTodayDestinations()` to the view's `NavigationStack` (or the outermost view if it's already inside a stack from `AppTabView`). Since `AppTabView` wraps `TodayView` in a `NavigationStack`, apply the modifier inside `TodayView`'s `body`:

     ```swift
     .withTodayDestinations()
     ```

  2. Add a `@Environment(\.dismiss) private var dismiss` is NOT needed. Instead, add a path state for programmatic navigation if not already present. Use the existing pattern in `TodayView` for navigation.

  3. At the bottom of the scroll content (after the exercise list), add:

     ```swift
     if viewModel.showDemographicsNudge {
         demographicsNudgeBanner
     }
     ```

  4. Add the banner as a private computed property or extracted subview (per the project's "extracted subviews in separate files" rule, put it in a new file `TodayDemographicsNudge.swift` in the Today folder):

     `inch/inch/Features/Today/TodayDemographicsNudge.swift`:
     ```swift
     import SwiftUI

     struct TodayDemographicsNudge: View {
         let onDismiss: () -> Void

         var body: some View {
             HStack {
                 NavigationLink(value: TodayDestination.privacySettings) {
                     VStack(alignment: .leading, spacing: 2) {
                         Text("Complete your profile")
                             .font(.subheadline)
                             .fontWeight(.semibold)
                             .foregroundStyle(.tint)
                         Text("Help improve rep counting accuracy")
                             .font(.caption)
                             .foregroundStyle(.secondary)
                     }
                 }
                 Spacer()
                 Button {
                     onDismiss()
                 } label: {
                     Image(systemName: "xmark")
                         .font(.caption)
                         .foregroundStyle(.secondary)
                 }
                 .buttonStyle(.plain)
             }
             .padding(12)
             .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
             .overlay(
                 RoundedRectangle(cornerRadius: 10)
                     .strokeBorder(.tint.opacity(0.25))
             )
         }
     }
     ```

     In `TodayView.swift`, add the nudge at the end of the scroll content:
     ```swift
     if viewModel.showDemographicsNudge {
         TodayDemographicsNudge {
             viewModel.showDemographicsNudge = false
         }
     }
     ```

- [ ] **Step 4: Build and verify**

  Build in Xcode. Run on simulator. After consenting but skipping demographics in onboarding, verify the banner appears at the bottom of Today. Verify tapping `×` hides it. Verify tapping the banner body navigates to Privacy Settings.

- [ ] **Step 5: Commit**

  ```bash
  git add inch/inch/Navigation/NavigationDestinations.swift \
          inch/inch/Features/Today/TodayViewModel.swift \
          inch/inch/Features/Today/TodayView.swift \
          inch/inch/Features/Today/TodayDemographicsNudge.swift
  git commit -m "feat: add demographics nudge banner to Today view"
  ```

---

### Task 6: Demographics pickers in Privacy Settings

**Files:**
- Modify: `inch/inch/Features/Settings/PrivacySettingsView.swift`

**Context:** `PrivacySettingsView` already has access to `UserSettings` via `viewModel.settings`. The new demographics section reuses the tag-chip style from `DemographicTagsView` inline (no navigation to the full onboarding view). Changes auto-save via `modelContext.save()`, which will clear the badge/banner.

- [ ] **Step 1: Add the demographics section**

  In `PrivacySettingsView.swift`, add a new private var before `consentSection`:

  ```swift
  private var demographicsSection: some View {
      Section {
          demographicRow(
              title: "Age range",
              options: ["Under 18", "18–29", "30–39", "40–49", "50–59", "60+"],
              selection: Binding(
                  get: { settings?.ageRange },
                  set: { settings?.ageRange = $0; try? modelContext.save() }
              )
          )
          demographicRow(
              title: "Height",
              options: ["Under 160cm", "160–170cm", "171–180cm", "181–190cm", "Over 190cm"],
              selection: Binding(
                  get: { settings?.heightRange },
                  set: { settings?.heightRange = $0; try? modelContext.save() }
              )
          )
          demographicRow(
              title: "Biological sex",
              options: ["Male", "Female", "Prefer not to say"],
              selection: Binding(
                  get: { settings?.biologicalSex },
                  set: { settings?.biologicalSex = $0; try? modelContext.save() }
              )
          )
          demographicRow(
              title: "Activity level",
              options: ["Beginner", "Intermediate", "Advanced"],
              selection: Binding(
                  get: { settings?.activityLevel },
                  set: { settings?.activityLevel = $0; try? modelContext.save() }
              )
          )
      } header: {
          Text("Profile")
      } footer: {
          Text("Optional. Used only to improve rep-counting accuracy for different body types.")
      }
  }

  private func demographicRow(title: String, options: [String], selection: Binding<String?>) -> some View {
      VStack(alignment: .leading, spacing: 6) {
          Text(title)
              .font(.subheadline)
          ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 8) {
                  ForEach(options, id: \.self) { option in
                      Button {
                          selection.wrappedValue = selection.wrappedValue == option ? nil : option
                      } label: {
                          Text(option)
                              .font(.caption)
                              .padding(.horizontal, 12)
                              .padding(.vertical, 6)
                              .background(
                                  selection.wrappedValue == option
                                      ? Color.accentColor
                                      : Color.secondary.opacity(0.15),
                                  in: Capsule()
                              )
                              .foregroundStyle(selection.wrappedValue == option ? .white : .primary)
                      }
                      .buttonStyle(.plain)
                  }
              }
          }
      }
      .padding(.vertical, 4)
  }
  ```

- [ ] **Step 2: Add `demographicsSection` to the `List`**

  In the `body`, add `demographicsSection` after `consentSection` (so it appears when consent has been granted):

  ```swift
  if settings?.motionDataUploadConsented == true {
      demographicsSection
  }
  ```

- [ ] **Step 3: Build and verify**

  Build in Xcode. Navigate to Settings → Data & Privacy. Verify demographic pickers appear when consent is on. Verify selecting all four options clears the Settings tab badge.

- [ ] **Step 4: Commit**

  ```bash
  git add inch/inch/Features/Settings/PrivacySettingsView.swift
  git commit -m "feat: add demographics pickers to Privacy Settings"
  ```

---

## Chunk 3: Upload Pipeline — DataUploadService Fix, Watch Fix, Unlink

### Task 7: Fix `DataUploadService` to use `UserSettings`

**Files:**
- Modify: `inch/inch/Services/DataUploadService.swift`
- Modify: `inch/inch/inch/Secrets.plist`

**Context:** `loadConfig()` reads `contributorId` and demographics from `Secrets.plist`. This must be replaced with a fetch from `UserSettings` at upload time. `Secrets.plist` retains only `SupabaseURL` and `SupabaseAnonKey`.

- [ ] **Step 1: Remove `ContributorId` from `Secrets.plist`**

  In `inch/inch/Secrets.plist`, remove the `ContributorId` key-value pair:
  ```xml
  <!-- Remove these two lines: -->
  <key>ContributorId</key>
  <string>55706EBA-7DF0-4F07-A62E-5BAA012F59BF</string>
  ```

- [ ] **Step 2: Rewrite `uploadPending(context:)` to fetch `UserSettings`**

  In `DataUploadService.swift`, replace the `loadConfig()` call in `uploadPending` with an inline fetch:

  ```swift
  private func uploadPending(context: ModelContext) async {
      guard let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first,
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

      let pendingStatus = UploadStatus.pending
      let descriptor = FetchDescriptor<SensorRecording>(
          predicate: #Predicate { $0.uploadStatus == pendingStatus }
      )
      let pending = (try? context.fetch(descriptor)) ?? []
      for recording in pending {
          guard !Task.isCancelled else { return }
          do {
              try await uploadRecording(recording, config: config, context: context)
          } catch {
              // Leave as .pending for next BGTask run
          }
      }
  }
  ```

- [ ] **Step 3: Delete the `loadConfig()` method**

  Remove the entire `private func loadConfig() -> SupabaseConfig?` method (lines 126–143 in the current file). The `SupabaseConfig` struct stays — it's used by `uploadPending` and `unlinkContributorData`. Also remove the `guard let contributorId = dict["ContributorId"] as? String` line from `loadConfig` is moot since the whole method goes away.

- [ ] **Step 4: Build and verify**

  Build in Xcode (⌘B). Confirm zero errors. The app should build cleanly with `loadConfig()` gone.

- [ ] **Step 5: Commit**

  ```bash
  git add inch/inch/Services/DataUploadService.swift \
          inch/inch/Secrets.plist
  git commit -m "fix: DataUploadService reads identity from UserSettings not Secrets.plist"
  ```

---

### Task 8: Watch file transfer → `SensorRecording`

**Files:**
- Create: `inch/inch/Services/WatchSensorMetadata.swift`
- Modify: `inch/inch/Services/WatchConnectivityService.swift`
- Modify: `inch/inchwatch Watch App/Services/WatchMotionRecordingService.swift`
- Modify: `inch/inch/inchApp.swift`

**Context:** The Watch transfers `.bin` files to iPhone via `WCSession.transferFile`. The iPhone's delegate receives the file — but delegate methods are `nonisolated`. We use the same `AsyncStream` pattern already in place for `completionReports` to safely cross to the main actor and insert a `SensorRecording`.

- [ ] **Step 1: Create `WatchSensorMetadata.swift`**

  Create `inch/inch/Services/WatchSensorMetadata.swift`:

  ```swift
  import Foundation

  /// Typed, Sendable metadata extracted from a WatchConnectivity file transfer.
  /// [String: Any] is not Sendable — all values are extracted into typed fields
  /// within the nonisolated delegate before this struct is created.
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

- [ ] **Step 2: Add `receivedFiles` stream to `WatchConnectivityService`**

  In `WatchConnectivityService.swift`:

  1. Add stream properties alongside `completionReports`:
     ```swift
     private let _receivedFiles: AsyncStream<ReceivedSensorFile>.Continuation
     let receivedFiles: AsyncStream<ReceivedSensorFile>
     ```

  2. In `init()`, initialise them alongside the existing stream:
     ```swift
     let (filesStream, filesContinuation) = AsyncStream<ReceivedSensorFile>.makeStream()
     receivedFiles = filesStream
     _receivedFiles = filesContinuation
     ```

  3. Update `session(_:didReceive file:)` to move the file, extract all metadata fields inline (since `[String: Any]` is not Sendable), and yield to the stream:
     ```swift
     nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
         let destDir = URL.documentsDirectory.appending(path: "sensor_data", directoryHint: .isDirectory)
         try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
         let dest = destDir.appending(path: file.fileURL.lastPathComponent)
         try? FileManager.default.moveItem(at: file.fileURL, to: dest)

         guard let raw = file.metadata,
               let exerciseId = raw["exerciseId"] as? String, !exerciseId.isEmpty
         else { return }

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

  4. Add `handleReceivedFiles(context:)` method:
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

- [ ] **Step 3: Update `WatchMotionRecordingService.stopAndTransfer()` (Watch app)**

  In `inch/inchwatch Watch App/Services/WatchMotionRecordingService.swift`, update the method signature and metadata:

  ```swift
  func stopAndTransfer(
      exerciseId: String,
      setNumber: Int,
      level: Int,
      dayNumber: Int,
      confirmedReps: Int,
      durationSeconds: Double,
      countingMode: String
  ) -> URL? {
      motionManager.stopDeviceMotionUpdates()
      sensorQueue = nil
      isRecording = false
      let url = currentRecordingURL
      currentRecordingURL = nil

      guard let url,
            WCSession.default.activationState == .activated
      else { return url }

      let metadata: [String: Any] = [
          "exerciseId": exerciseId,
          "setNumber": setNumber,
          "device": SensorDevice.appleWatch.rawValue,
          "level": level,
          "dayNumber": dayNumber,
          "confirmedReps": confirmedReps,
          "durationSeconds": durationSeconds,
          "countingMode": countingMode,
          "sampleRateHz": 50,
          "recordedAt": Date.now.timeIntervalSince1970
      ]
      WCSession.default.transferFile(url, metadata: metadata)
      return url
  }
  ```

  Update the call site in `inch/inchwatch Watch App/Features/WatchWorkoutView.swift`. The current code at line ~105 (inside `.onChange(of: viewModel.phase) { _, newPhase in`) is:
  ```swift
  case .confirming:
      if motionRecording.isRecording {
          _ = motionRecording.stopAndTransfer(exerciseId: session.exerciseId, setNumber: viewModel.currentSet)
      }
  ```

  Replace it with:
  ```swift
  case .confirming:
      if motionRecording.isRecording,
         case .confirming(let targetReps, let duration) = newPhase {
          _ = motionRecording.stopAndTransfer(
              exerciseId: session.exerciseId,
              setNumber: viewModel.currentSet,
              level: session.level,
              dayNumber: session.dayNumber,
              confirmedReps: viewModel.pendingRealTimeCount ?? targetReps,
              durationSeconds: duration,
              countingMode: session.countingMode
          )
      }
  ```

  `confirmedReps` uses `pendingRealTimeCount` for real-time mode (where the counter provides the actual count) and falls back to `targetReps` for manual mode (best estimate before the user confirms).

- [ ] **Step 4: Wire `handleReceivedFiles` in `inchApp.swift`**

  Both `handleCompletionReports` and `handleReceivedFiles` consume `AsyncStream`s that never terminate — each `for await` loop runs forever. Placing two `await` calls sequentially in a `.task` block means the second never executes.

  The current `.task` in `inchApp.swift` ends with:
  ```swift
  await watchConnectivity.handleCompletionReports(context: context)
  ```

  Replace it to run both consumers concurrently using `withTaskGroup`:
  ```swift
  .task {
      watchConnectivity.activate()
      await notificationService.checkAuthorizationStatus()
      let context = ModelContext(container)
      await withTaskGroup(of: Void.self) { group in
          group.addTask { await watchConnectivity.handleCompletionReports(context: context) }
          group.addTask { await watchConnectivity.handleReceivedFiles(context: context) }
      }
  }
  ```

- [ ] **Step 5: Build both targets**

  Build `inch` scheme and `inchwatch Watch App` scheme in Xcode. Confirm zero errors in both.

- [ ] **Step 6: Commit**

  ```bash
  git add inch/inch/Services/WatchSensorMetadata.swift \
          inch/inch/Services/WatchConnectivityService.swift \
          "inch/inchwatch Watch App/Services/WatchMotionRecordingService.swift" \
          inch/inch/inchApp.swift
  git commit -m "feat: create SensorRecording when Watch transfers sensor file to iPhone"
  ```

---

### Task 9: Add `unlinkContributorData` and update Privacy Settings

**Files:**
- Modify: `inch/inch/Services/DataUploadService.swift`
- Modify: `inch/inch/Features/Settings/PrivacySettingsView.swift`

**Context:** Instead of deleting sensor data, this replaces the contributor UUID on the server with a fresh one — preserving training data while severing the link to the device. The UPDATE RLS policy was applied in Task 2.

- [ ] **Step 1: Add `.unlinkFailed` to `UploadError`**

  In `DataUploadService.swift`, add to the `UploadError` enum:
  ```swift
  case unlinkFailed
  ```

- [ ] **Step 2: Add `unlinkContributorData(contributorId:)` to `DataUploadService`**

  Add this method to `DataUploadService`:

  ```swift
  func unlinkContributorData(contributorId: String) async throws {
      guard let plistURL = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let dict = NSDictionary(contentsOf: plistURL) as? [String: Any],
            let supabaseURL = dict["SupabaseURL"] as? String,
            let anonKey = dict["SupabaseAnonKey"] as? String
      else { throw UploadError.configurationMissing }

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

- [ ] **Step 3: Update `PrivacySettingsView` with unlink button and error handling**

  In `PrivacySettingsView.swift`:

  1. Add environment and state:
     ```swift
     @Environment(DataUploadService.self) private var dataUpload
     @State private var showingUnlinkConfirm = false
     @State private var showingUnlinkError = false
     @State private var isUnlinking = false
     ```

  2. In `dataSection`, replace any "Delete Sensor Data" button with:
     ```swift
     Button("Unlink My Sensor Data from Server", role: .destructive) {
         showingUnlinkConfirm = true
     }
     .disabled(isUnlinking || !(settings?.motionDataUploadConsented == true))
     ```

  3. Add a confirmation dialog (alongside the existing dialogs):
     ```swift
     .confirmationDialog(
         "Unlink sensor data?",
         isPresented: $showingUnlinkConfirm,
         titleVisibility: .visible
     ) {
         Button("Unlink My Data", role: .destructive) {
             guard let id = settings?.contributorId, !id.isEmpty else { return }
             isUnlinking = true
             Task {
                 do {
                     try await dataUpload.unlinkContributorData(contributorId: id)
                     settings?.contributorId = UUID().uuidString.lowercased()
                     try? modelContext.save()
                 } catch {
                     showingUnlinkError = true
                 }
                 isUnlinking = false
             }
         }
         Button("Cancel", role: .cancel) {}
     } message: {
         Text("Your sensor recordings will remain on the server but can no longer be linked to this device. Future uploads will use a new anonymous ID.")
     }
     .alert("Couldn't Unlink Data", isPresented: $showingUnlinkError) {
         Button("OK", role: .cancel) {}
     } message: {
         Text("Check your connection and try again.")
     }
     ```

- [ ] **Step 4: Build and verify**

  Build in Xcode. Navigate to Settings → Data & Privacy. Verify "Unlink My Sensor Data from Server" button appears when consent is on. Verify tapping shows the confirmation dialog. (End-to-end Supabase call can be manually verified with a real device if needed.)

- [ ] **Step 5: Commit**

  ```bash
  git add inch/inch/Services/DataUploadService.swift \
          inch/inch/Features/Settings/PrivacySettingsView.swift
  git commit -m "feat: add contributor data unlinking to DataUploadService and Privacy Settings"
  ```

---

## Final Verification

- [ ] **Build both schemes clean**

  In Xcode, Product → Clean Build Folder (⇧⌘K), then build `inch` and `inchwatch Watch App`.

- [ ] **Run full test suite**

  ```bash
  swift test --package-path Shared
  ```

  All tests pass including the new `UserSettingsTests`.

- [ ] **Smoke test the full flow on simulator**

  1. Fresh install → complete onboarding → consent to data sharing → skip demographics
  2. Verify Settings tab shows badge dot
  3. Verify Today shows nudge banner at bottom
  4. Dismiss banner with `×` → verify it hides
  5. Go to Settings → Data & Privacy → fill in all four demographics → verify badge clears and banner gone on next app launch
  6. Tap "Unlink My Sensor Data" → confirm dialog → verify flow completes without crash
