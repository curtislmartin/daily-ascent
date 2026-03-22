# UX Polish & Bug Fixes Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix five user-reported issues: Reset App not returning to onboarding, Select All creating duplicate enrolments, cluttered demographic chip picker in Settings, notification permission never requested in-app, and Settings moved from tab bar into History toolbar.

**Architecture:** All changes are isolated to existing view/viewmodel files. No new services are needed. The notification permission task adds an inline "Enable Notifications" button to `NotificationsSettingsSection` using the existing `NotificationService.requestPermission()` method. The profile picker refactor extracts a new `DemographicPickerSheet` file to keep `PrivacySettingsView` focused. Moving Settings out of the tab bar removes one tab slot and adds a toolbar button to `HistoryView`.

**Tech Stack:** SwiftUI, SwiftData, UserNotifications, Swift 6.2 strict concurrency, `@Observable` view models, main-actor isolation.

---

## Files

| File | Change |
|---|---|
| `inch/inch/Navigation/RootView.swift` | Add `.onChange` to reset `onboardingComplete` when `UserSettings` is deleted |
| `inch/inch/Navigation/AppTabView.swift` | Remove Settings tab, add badge to History tab |
| `inch/inch/Features/History/HistoryView.swift` | Add Settings toolbar button |
| `inch/inch/Features/Onboarding/EnrolmentViewModel.swift` | Guard `saveEnrolments` against duplicate enrolments |
| `inch/inch/Features/Settings/NotificationsSettingsSection.swift` | Add "Enable Notifications" button when permission is not yet determined |
| `inch/inch/Features/Settings/PrivacySettingsView.swift` | Replace chip rows with tappable `LabeledContent` rows |
| `inch/inch/Features/Settings/DemographicPickerSheet.swift` | **New** — picker sheet opened from each demographic row |

No changes to the Shared package. No new services.

---

## Task 1: Fix Reset App → returns to onboarding

**Problem:** `RootView` uses `@State private var onboardingComplete = false` as a direct signal so the demographics-screen fix works. But that `@State` persists for the app session — after Reset App deletes `UserSettings`, `onboardingComplete` is still `true`, so the condition `!onboardingComplete && settings.first?.onboardingComplete != true` evaluates to `false` and `AppTabView` stays visible.

**Fix:** Add `.onChange(of: settings)` — when `settings` becomes empty (UserSettings deleted), reset `onboardingComplete = false`.

**Files:**
- Modify: `inch/inch/Navigation/RootView.swift`

- [ ] **Step 1: Add `.onChange` observer to `RootView.body`**

Open `inch/inch/Navigation/RootView.swift`. The current `body` is:

```swift
var body: some View {
    Group {
        if !onboardingComplete && settings.first?.onboardingComplete != true {
            OnboardingCoordinatorView { onboardingComplete = true }
        } else {
            AppTabView()
        }
    }
    .preferredColorScheme(preferredColorScheme)
}
```

Replace with:

```swift
var body: some View {
    Group {
        if !onboardingComplete && settings.first?.onboardingComplete != true {
            OnboardingCoordinatorView { onboardingComplete = true }
        } else {
            AppTabView()
        }
    }
    .preferredColorScheme(preferredColorScheme)
    .onChange(of: settings) {
        if settings.isEmpty { onboardingComplete = false }
    }
}
```

- [ ] **Step 2: Build to confirm no errors**

```bash
xcodebuild -project inch/inch.xcodeproj -scheme inch \
  -destination 'generic/platform=iOS Simulator' build \
  2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)' | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add inch/inch/Navigation/RootView.swift
git commit -m "fix: reset app now returns to onboarding"
```

---

## Task 2: Fix Select All creating duplicate enrolments

**Problem:** `EnrolmentViewModel.saveEnrolments(from:context:)` creates a new `ExerciseEnrolment` for every selected definition without checking whether one already exists. If the placement step fires twice (e.g. double-tap), or if `ManageEnrolmentsView` re-uses the same flow without dedup, duplicate active enrolments are created.

**Fix:** Fetch existing active enrolments before inserting, skip any definition that already has one.

**Files:**
- Modify: `inch/inch/Features/Onboarding/EnrolmentViewModel.swift`

- [ ] **Step 1: Update `saveEnrolments` to dedup**

Open `inch/inch/Features/Onboarding/EnrolmentViewModel.swift`. The current method is:

```swift
func saveEnrolments(from definitions: [ExerciseDefinition], context: ModelContext) throws {
    let selected = definitions.filter { selectedExerciseIds.contains($0.exerciseId) }
    for definition in selected {
        let chosenLevel = levelChoices[definition.exerciseId] ?? 1
        let enrolment = ExerciseEnrolment(enrolledAt: startDate, currentLevel: chosenLevel)
        enrolment.exerciseDefinition = definition
        enrolment.nextScheduledDate = startDate
        context.insert(enrolment)
    }
    try context.save()
}
```

Replace with:

```swift
func saveEnrolments(from definitions: [ExerciseDefinition], context: ModelContext) throws {
    let existing = (try? context.fetch(FetchDescriptor<ExerciseEnrolment>(
        predicate: #Predicate { $0.isActive }
    ))) ?? []
    let existingIds = Set(existing.compactMap { $0.exerciseDefinition?.exerciseId })

    let selected = definitions.filter {
        selectedExerciseIds.contains($0.exerciseId) && !existingIds.contains($0.exerciseId)
    }
    for definition in selected {
        let chosenLevel = levelChoices[definition.exerciseId] ?? 1
        let enrolment = ExerciseEnrolment(enrolledAt: startDate, currentLevel: chosenLevel)
        enrolment.exerciseDefinition = definition
        enrolment.nextScheduledDate = startDate
        context.insert(enrolment)
    }
    try context.save()
}
```

- [ ] **Step 2: Build to confirm no errors**

```bash
xcodebuild -project inch/inch.xcodeproj -scheme inch \
  -destination 'generic/platform=iOS Simulator' build \
  2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)' | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add inch/inch/Features/Onboarding/EnrolmentViewModel.swift
git commit -m "fix: guard saveEnrolments against duplicate active enrolments"
```

---

## Task 3: Add in-app notification permission request

**Problem:** `NotificationsSettingsSection` currently shows an "Open Settings" button when permission is not authorized — but this is wrong for users who have never been asked. There is no in-app prompt. `NotificationService.requestPermission()` exists and is safe to call (system prompt appears once; subsequent calls are no-ops if already determined).

**Fix:** Check the raw `authorizationStatus`. If `.notDetermined`, show an "Enable Notifications" button that calls `requestPermission()`. Only fall back to "Open Settings" for `.denied`.

**Files:**
- Modify: `inch/inch/Features/Settings/NotificationsSettingsSection.swift`

`NotificationsSettingsSection` receives `isAuthorized: Bool`. That bool alone can't distinguish "never asked" from "denied". We need to expose the raw status from `NotificationService`.

- [ ] **Step 1: Add `authorizationStatus` property to `NotificationService`**

Open `inch/inch/Services/NotificationService.swift`. Add a stored property and update both methods.

Add the property after `var isAuthorized: Bool = false`:

```swift
var authorizationStatus: UNAuthorizationStatus = .notDetermined
```

Replace `requestPermission()` with:

```swift
func requestPermission() async {
    let center = UNUserNotificationCenter.current()
    _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    // Read back the real status rather than inferring from the Bool return value —
    // the OS may have granted partial/provisional permissions that the Bool doesn't capture.
    await checkAuthorizationStatus()
}
```

In `checkAuthorizationStatus()`, add one line after setting `isAuthorized`:

```swift
func checkAuthorizationStatus() async {
    let settings = await UNUserNotificationCenter.current().notificationSettings()
    isAuthorized = settings.authorizationStatus == .authorized
    authorizationStatus = settings.authorizationStatus   // ← add this
}
```

- [ ] **Step 2: Update `NotificationsSettingsSection` to use status**

Open `inch/inch/Features/Settings/NotificationsSettingsSection.swift`.

Replace the entire file with:

```swift
import SwiftUI
import UserNotifications
import InchShared

struct NotificationsSettingsSection: View {
    @Bindable var settings: UserSettings
    @Environment(\.openURL) private var openURL
    @Environment(NotificationService.self) private var notifications

    var body: some View {
        // Group wrapper lets us attach .task once regardless of which branch is shown.
        // The .task refreshes authorizationStatus on first appearance so the correct
        // branch renders immediately, even if SettingsView's own .task hasn't fired yet.
        Group {
            if notifications.isAuthorized {
                Section("Notifications") {
                    Toggle("Daily Reminder", isOn: $settings.dailyReminderEnabled)
                    if settings.dailyReminderEnabled {
                        DatePicker(
                            "Reminder time",
                            selection: dailyReminderBinding,
                            displayedComponents: .hourAndMinute
                        )
                    }

                    Toggle("Streak Protection", isOn: $settings.streakProtectionEnabled)
                    if settings.streakProtectionEnabled {
                        DatePicker(
                            "Reminder time",
                            selection: streakProtectionBinding,
                            displayedComponents: .hourAndMinute
                        )
                    }

                    Toggle("Level Unlock Alerts", isOn: $settings.levelUnlockNotificationEnabled)
                }
            } else if notifications.authorizationStatus == .notDetermined {
                Section("Notifications") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Allow notifications to get workout reminders and streak alerts.")
                            .font(.subheadline)
                        Button("Enable Notifications") {
                            Task { await notifications.requestPermission() }
                        }
                        .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Section("Notifications") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notifications are disabled")
                            .font(.subheadline)
                        Text("Enable in Settings → Notifications → Daily Ascent")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Open Settings") {
                            // "App-Prefs:NOTIFICATIONS" is the iOS 16+ deep-link to the app's
                            // notification settings. UIApplication.openNotificationSettingsURLString
                            // is UIKit (banned) so we use the string literal directly.
                            if let url = URL(string: "App-Prefs:NOTIFICATIONS") {
                                openURL(url)
                            }
                        }
                        .font(.caption)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .task { await notifications.checkAuthorizationStatus() }
    }

    // MARK: - Private

    private var dailyReminderBinding: Binding<Date> {
        timeBinding(hour: $settings.dailyReminderHour, minute: $settings.dailyReminderMinute)
    }

    private var streakProtectionBinding: Binding<Date> {
        timeBinding(hour: $settings.streakProtectionHour, minute: $settings.streakProtectionMinute)
    }

    private func timeBinding(hour: Binding<Int>, minute: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: hour.wrappedValue,
                    minute: minute.wrappedValue,
                    second: 0,
                    of: .now
                ) ?? .now
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                hour.wrappedValue = c.hour ?? hour.wrappedValue
                minute.wrappedValue = c.minute ?? minute.wrappedValue
            }
        )
    }
}
```

Note: `NotificationsSettingsSection` now reads `NotificationService` from the environment directly instead of receiving `isAuthorized: Bool`. Update all call sites.

- [ ] **Step 3: Update `SettingsView` call site**

Open `inch/inch/Features/Settings/SettingsView.swift`. The current usage is:

```swift
NotificationsSettingsSection(
    settings: settings,
    isAuthorized: notifications.isAuthorized
)
```

Replace with:

```swift
NotificationsSettingsSection(settings: settings)
```

Also remove the `@Environment(NotificationService.self) private var notifications` property from `SettingsView` only if it is not used elsewhere in that file. If it is still used (e.g. for `.task { await notifications.checkAuthorizationStatus() }`), keep it.

Looking at the current `SettingsView.body`:
```swift
.task { await notifications.checkAuthorizationStatus() }
```
Keep `@Environment(NotificationService.self) private var notifications` in `SettingsView` — it is still needed for the `.task`.

- [ ] **Step 4: Build to confirm no errors**

```bash
xcodebuild -project inch/inch.xcodeproj -scheme inch \
  -destination 'generic/platform=iOS Simulator' build \
  2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)' | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add inch/inch/Services/NotificationService.swift \
  inch/inch/Features/Settings/NotificationsSettingsSection.swift \
  inch/inch/Features/Settings/SettingsView.swift
git commit -m "feat: add in-app notification permission request button"
```

---

## Task 4: Replace demographic chip picker with tappable rows + edit sheet

**Problem:** The Profile section in `PrivacySettingsView` exposes all chip options for every demographic field inline in the list. This is visually noisy. Once a value is selected it should just be a label row; editing opens a clean picker sheet.

**Design:**
- Each demographic field becomes a single `LabeledContent` row showing the selected value or "Not set"
- Tapping opens a `.sheet` containing a `List` with radio-style selection
- A new file `DemographicPickerSheet.swift` holds the sheet view
- `PrivacySettingsView` is simplified: `demographicsSection` becomes a short list of tappable rows

**Files:**
- Create: `inch/inch/Features/Settings/DemographicPickerSheet.swift`
- Modify: `inch/inch/Features/Settings/PrivacySettingsView.swift`

- [ ] **Step 1: Create `DemographicPickerSheet.swift`**

Create `inch/inch/Features/Settings/DemographicPickerSheet.swift`:

```swift
import SwiftUI

struct DemographicPickerSheet: View {
    let title: String
    let options: [String]
    @Binding var selection: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(options, id: \.self) { option in
                Button {
                    selection = selection == option ? nil : option
                    dismiss()
                } label: {
                    HStack {
                        Text(option)
                            .foregroundStyle(.primary)
                        Spacer()
                        if selection == option {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.insetGrouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    if selection != nil {
                        Button("Clear") {
                            selection = nil
                            dismiss()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 2: Update `demographicsSection` in `PrivacySettingsView`**

Open `inch/inch/Features/Settings/PrivacySettingsView.swift`.

**Important:** Attaching `.sheet` to individual rows inside a `List` is unreliable in SwiftUI (sheets may not present or may dismiss immediately). Use a single `@State var activeDemographicField` with an enum, and attach the `.sheet` to the parent `List` — this is the safe, documented pattern.

Add a private enum and a single `@State` property inside `PrivacySettingsView`:

```swift
private enum DemographicField {
    case age, height, sex, activity
}

@State private var activeDemographicField: DemographicField?
```

Replace the entire `demographicsSection` computed property and the `demographicRow` function with:

```swift
private var demographicsSection: some View {
    Section {
        demographicRow(title: "Age range",      value: settings?.ageRange,      field: .age)
        demographicRow(title: "Height",          value: settings?.heightRange,   field: .height)
        demographicRow(title: "Biological sex",  value: settings?.biologicalSex, field: .sex)
        demographicRow(title: "Activity level",  value: settings?.activityLevel, field: .activity)
    } header: {
        Text("Profile")
    } footer: {
        Text("Optional. Used only to improve rep-counting accuracy for different body types.")
    }
}

private func demographicRow(title: String, value: String?, field: DemographicField) -> some View {
    Button {
        activeDemographicField = field
    } label: {
        LabeledContent(title) {
            Text(value ?? "Not set")
                .foregroundStyle(value == nil ? .secondary : .primary)
        }
    }
    .buttonStyle(.plain)
    .foregroundStyle(.primary)
}
```

Then add the `.sheet` modifier **to the `List`** in `body` (not to individual rows). Locate the `List { ... }` block and append:

```swift
.sheet(item: $activeDemographicField) { field in
    switch field {
    case .age:
        DemographicPickerSheet(
            title: "Age Range",
            options: ["Under 18", "18–29", "30–39", "40–49", "50–59", "60+"],
            selection: Binding(
                get: { settings?.ageRange },
                set: { settings?.ageRange = $0; try? modelContext.save() }
            )
        )
    case .height:
        DemographicPickerSheet(
            title: "Height",
            options: ["Under 160cm", "160–170cm", "171–180cm", "181–190cm", "Over 190cm"],
            selection: Binding(
                get: { settings?.heightRange },
                set: { settings?.heightRange = $0; try? modelContext.save() }
            )
        )
    case .sex:
        DemographicPickerSheet(
            title: "Biological Sex",
            options: ["Male", "Female", "Prefer not to say"],
            selection: Binding(
                get: { settings?.biologicalSex },
                set: { settings?.biologicalSex = $0; try? modelContext.save() }
            )
        )
    case .activity:
        DemographicPickerSheet(
            title: "Activity Level",
            options: ["Beginner", "Intermediate", "Advanced"],
            selection: Binding(
                get: { settings?.activityLevel },
                set: { settings?.activityLevel = $0; try? modelContext.save() }
            )
        )
    }
}
```

For `.sheet(item:)` to work, `DemographicField` must conform to `Identifiable`. Add the conformance inside `PrivacySettingsView`:

```swift
private enum DemographicField: Identifiable {
    case age, height, sex, activity
    var id: Self { self }
}
```

Also remove the `contributorSection` call from `body` if it is missing — in the current file it was already removed. Check the current `body` and ensure the `if let id = settings?.contributorId, !id.isEmpty { contributorSection(id: id) }` block is present. If it was accidentally removed in a previous session, add it back between `demographicsSection` and `dataSection`:

```swift
if let id = settings?.contributorId, !id.isEmpty {
    contributorSection(id: id)
}
```

And ensure the `contributorSection` function exists:

```swift
private func contributorSection(id: String) -> some View {
    Section("Contributor") {
        LabeledContent("Contributor ID") {
            Text(id.prefix(8) + "…")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospaced()
        }
    }
}
```

- [ ] **Step 3: Build to confirm no errors**

```bash
xcodebuild -project inch/inch.xcodeproj -scheme inch \
  -destination 'generic/platform=iOS Simulator' build \
  2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)' | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add inch/inch/Features/Settings/DemographicPickerSheet.swift \
  inch/inch/Features/Settings/PrivacySettingsView.swift
git commit -m "feat: replace demographic chip picker with tappable rows and edit sheet"
```

---

## Task 5: Move Settings from tab bar into History toolbar

**Problem:** The user finds the Settings tab cluttered in the main tab bar and prefers access via History. Remove the Settings tab, add a gear toolbar button to `HistoryView`, and move the demographic-completion badge to the History tab.

**Files:**
- Modify: `inch/inch/Navigation/AppTabView.swift`
- Modify: `inch/inch/Features/History/HistoryView.swift`

- [ ] **Step 1: Update `AppTab` enum and `AppTabView`**

Open `inch/inch/Navigation/AppTabView.swift`. The current file:

```swift
enum AppTab: String, CaseIterable {
    case today, program, history, settings
}

struct AppTabView: View {
    @State private var selectedTab: AppTab = .today
    @Query private var allSettings: [UserSettings]

    private var showSettingsBadge: Bool {
        guard let s = allSettings.first else { return false }
        return s.motionDataUploadConsented && !s.hasDemographics
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "calendar", value: AppTab.today) {
                NavigationStack { TodayView() }
            }
            Tab("Program", systemImage: "chart.bar", value: AppTab.program) {
                NavigationStack { ProgramView().withProgramDestinations() }
            }
            Tab("History", systemImage: "clock", value: AppTab.history) {
                NavigationStack { HistoryView() }
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                NavigationStack { SettingsView() }
            }
            .badge(showSettingsBadge ? 1 : 0)
        }
    }
}
```

Replace with:

```swift
enum AppTab: String, CaseIterable {
    case today, program, history
}

struct AppTabView: View {
    @State private var selectedTab: AppTab = .today
    @Query private var allSettings: [UserSettings]

    private var showSettingsBadge: Bool {
        guard let s = allSettings.first else { return false }
        return s.motionDataUploadConsented && !s.hasDemographics
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Today", systemImage: "calendar", value: AppTab.today) {
                NavigationStack { TodayView() }
            }
            Tab("Program", systemImage: "chart.bar", value: AppTab.program) {
                NavigationStack { ProgramView().withProgramDestinations() }
            }
            Tab("History", systemImage: "clock", value: AppTab.history) {
                NavigationStack { HistoryView() }
            }
            .badge(showSettingsBadge ? 1 : 0)
        }
    }
}
```

- [ ] **Step 2: Add Settings toolbar button to `HistoryView`**

Open `inch/inch/Features/History/HistoryView.swift`.

Add a `@State` property for sheet presentation inside `HistoryView`:

```swift
@State private var showingSettings = false
```

Replace the current `body` (which ends at `.withHistoryDestinations()`) with:

```swift
var body: some View {
    VStack(spacing: 0) {
        Picker("", selection: $selectedSegment) {
            ForEach(Segment.allCases, id: \.self) { Text($0.rawValue) }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 8)

        switch selectedSegment {
        case .log:
            HistoryLogView(weekGroups: viewModel.weekGroups(from: allSets))
        case .stats:
            HistoryStatsView(
                stats: viewModel.stats(from: allSets, enrolments: allEnrolments),
                streakState: streakState
            )
        }
    }
    .navigationTitle("History")
    .navigationBarTitleDisplayMode(.large)
    .withHistoryDestinations()
    .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
        }
    }
    .sheet(isPresented: $showingSettings) {
        NavigationStack {
            SettingsView()
        }
    }
}
```

Note: `SettingsView` is opened as a `.sheet` with its own `NavigationStack` so it can push child views (Rest Timers, Tracking Method, Data & Privacy). The `NavigationLink(destination:)` closure form is banned by the project guidelines; a `.sheet` is the correct approach here.

**Environment note:** `NotificationService` is injected at the app root in `inchApp.swift` via `.environment(notificationService)` on the `WindowGroup`, so it is available inside the sheet without any additional injection.

- [ ] **Step 3: Build to confirm no errors**

```bash
xcodebuild -project inch/inch.xcodeproj -scheme inch \
  -destination 'generic/platform=iOS Simulator' build \
  2>&1 | grep -E '(error:|BUILD SUCCEEDED|BUILD FAILED)' | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add inch/inch/Navigation/AppTabView.swift \
  inch/inch/Features/History/HistoryView.swift
git commit -m "feat: move settings from tab bar to history toolbar"
```
