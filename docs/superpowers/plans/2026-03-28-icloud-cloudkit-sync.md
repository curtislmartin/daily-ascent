# iCloud / CloudKit Sync Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable automatic iCloud sync for all user progress data using SwiftData's native CloudKit integration.

**Architecture:** The iOS app's `ModelContainer` is reconfigured to use a private CloudKit database (`iCloud.dev.clmartin.inch`). SwiftData handles all sync automatically — no sync code to write. The watchOS app is unaffected (it uses WatchConnectivity, not SwiftData). A disclosure is added to the existing Privacy & Data settings screen.

**Tech Stack:** SwiftData + CloudKit, iCloud private database, Xcode automatic signing

---

## Background

The data model was designed CloudKit-ready from day one (per CLAUDE.md):
- No `@Attribute(.unique)` or `#Unique`
- All properties have defaults or are optional
- Explicit `@Relationship` on every relationship
- `SensorRecording` stores only file-path metadata (no large blobs) — safe to sync

The change is almost entirely configuration. No model changes needed.

---

## Chunk 1: Enable capability and wire up CloudKit

### Task 1: Enable iCloud + CloudKit capability in Xcode (manual step)

**Files:**
- Modify: `inch/inch/inch.entitlements` (Xcode updates this automatically)
- Xcode project: Signing & Capabilities tab on the `inch` target

This MUST be done before running the app — the entitlements change requires Apple Developer portal provisioning.

- [ ] **Step 1: Open Xcode and add capability**

  1. Open `inch/inch.xcodeproj` in Xcode
  2. Select the `inch` target → **Signing & Capabilities** tab
  3. Click **+ Capability**
  4. Search for **iCloud** and add it
  5. Under iCloud, tick **CloudKit**
  6. Under **Containers**, click **+** and add container: `iCloud.dev.clmartin.inch`
  7. Verify Xcode shows the container with a green checkmark (may take 30s to provision)

- [ ] **Step 2: Verify entitlements file was updated**

  Open `inch/inch/inch.entitlements` and confirm it now contains:

  ```xml
  <key>com.apple.developer.icloud-container-identifiers</key>
  <array>
      <string>iCloud.dev.clmartin.inch</string>
  </array>
  <key>com.apple.developer.icloud-services</key>
  <array>
      <string>CloudKit</string>
  </array>
  ```

  If it doesn't (Xcode sometimes lags), add these keys manually.

- [ ] **Step 3: Build to verify capability is provisioned**

  Build the `inch` scheme for any simulator. A build failure with a signing error means the iCloud container isn't provisioned yet — wait and retry.

  Expected: Clean build.

- [ ] **Step 4: Commit entitlements change**

  ```bash
  git add inch/inch/inch.entitlements inch/inch.xcodeproj/project.pbxproj
  git commit -m "chore: enable iCloud + CloudKit capability on iOS target"
  ```

---

### Task 2: Update ModelContainerFactory to use CloudKit

**Files:**
- Modify: `Shared/Sources/InchShared/Utilities/ModelContainerFactory.swift`

> No tests to add — this is infrastructure configuration. CloudKit sync cannot be tested in unit tests (requires a live Apple ID and network). Validation is manual (Task 4).

- [ ] **Step 1: Update `makeContainer` to enable CloudKit**

  Replace the current implementation:

  ```swift
  public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
      let schema = Schema(BodyweightSchemaV2.models)
      let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
      return try ModelContainer(for: schema, configurations: [config])
  }
  ```

  With:

  ```swift
  public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
      let schema = Schema(BodyweightSchemaV2.models)
      let cloudKitDatabase: ModelConfiguration.CloudKitDatabase = inMemory ? .none : .private("iCloud.dev.clmartin.inch")
      let config = ModelConfiguration(
          schema: schema,
          isStoredInMemoryOnly: inMemory,
          cloudKitDatabase: cloudKitDatabase
      )
      return try ModelContainer(for: schema, configurations: [config])
  }
  ```

  Key points:
  - `inMemory: true` (used in tests) disables CloudKit via `.none` — tests are unaffected
  - `.private("iCloud.dev.clmartin.inch")` targets the app's private iCloud database — data is never shared between users
  - The container identifier must exactly match what was registered in Task 1

- [ ] **Step 2: Build and run tests to confirm nothing broke**

  ```bash
  xcodebuild test \
    -scheme InchShared \
    -destination "platform=macOS" \
    CODE_SIGNING_REQUIRED=NO \
    | grep -E "(PASS|FAIL|error:)"
  ```

  Expected: All existing tests pass (they use `inMemory: true` so CloudKit is bypassed).

- [ ] **Step 3: Build the iOS app**

  Build for iPhone 16 Pro simulator:

  ```bash
  xcodebuild build \
    -scheme inch \
    -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
    | grep -E "(BUILD|error:)"
  ```

  Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

  ```bash
  git add Shared/Sources/InchShared/Utilities/ModelContainerFactory.swift
  git commit -m "feat: enable CloudKit sync via SwiftData private database"
  ```

---

### Task 3: Add iCloud sync disclosure to Privacy Settings

Users should know their progress syncs via iCloud, especially since the screen is called "Data & Privacy."

**Files:**
- Modify: `inch/inch/Features/Settings/PrivacySettingsView.swift`

- [ ] **Step 1: Add an iCloud section to the Privacy settings screen**

  In `PrivacySettingsView.swift`, add a new `iCloudSection` computed property and insert it into the `List` between `consentSection` and `dataSection`:

  ```swift
  // Add to body:
  var body: some View {
      List {
          consentSection
          iCloudSection   // ← insert here
          dataSection
          Section("Legal") {
              Link("Privacy Policy", destination: URL(string: "https://curtislmartin.github.io/daily-ascent/privacy")!)
          }
      }
      // ... rest unchanged
  }

  // New computed property:
  private var iCloudSection: some View {
      Section {
          Label("Syncing via iCloud", systemImage: "icloud")
              .foregroundStyle(.secondary)
      } header: {
          Text("iCloud")
      } footer: {
          Text("Your programme progress, workout history, and settings sync automatically across your Apple devices using your private iCloud account. Only you can access this data.")
      }
  }
  ```

- [ ] **Step 2: Build and visually verify**

  Run the app in iPhone 16 Pro simulator, navigate to Settings → Data & Privacy, and confirm the iCloud section appears between sensor data and the data management buttons.

- [ ] **Step 3: Commit**

  ```bash
  git add inch/inch/Features/Settings/PrivacySettingsView.swift
  git commit -m "feat: add iCloud sync disclosure to privacy settings"
  ```

---

### Task 4: Manual end-to-end test (on-device)

This cannot be automated — CloudKit sync requires a real device and Apple ID.

- [ ] **Step 1: Build and install to primary iPhone**

  ```bash
  ./scripts/build-device.sh
  ```

  Or install via Xcode on both test devices.

- [ ] **Step 2: Verify existing data syncs up**

  Open the app on Device A (the one with existing data). Wait ~30 seconds. Check iCloud Dashboard (`icloud.com`) or use CloudKit Console (`developer.apple.com/icloud/cloudkit`) to verify records appear in the `iCloud.dev.clmartin.inch` container's private database.

- [ ] **Step 3: Verify sync to a second device**

  On Device B (same Apple ID, freshly installed app), open the app. Within a minute or two, today's schedule and programme progress should appear. If Device B is a fresh install, it may need to go through onboarding — but on a device where the app was previously installed with the same Apple ID, data should populate automatically.

- [ ] **Step 4: Verify round-trip**

  Complete one workout set on Device A. Confirm it appears on Device B within ~30 seconds (background refresh) or immediately if the app is foregrounded.

---

## Notes

**Migration plan:** `BodyweightMigrationPlan` handles local SQLite migration (V1→V2). It is unaffected by adding CloudKit. On first launch after this update, SwiftData pushes existing local data to CloudKit automatically.

**watchOS:** No changes needed. The watch uses WatchConnectivity to push completions to iPhone, which then stores in SwiftData (and CloudKit). The sync chain is: Watch → WatchConnectivity → iPhone SwiftData → CloudKit → other iPhones.

**Reset behaviour:** "Reset App" in settings deletes local SwiftData records. CloudKit deletions propagate to other devices automatically — so a reset on one device resets all devices. This is expected behaviour (the user owns one progress state across devices).

**Testing in CI:** Tests use `inMemory: true` which sets `cloudKitDatabase: .none` — no Apple ID or network needed. The CloudKit code path is never exercised in unit tests.
