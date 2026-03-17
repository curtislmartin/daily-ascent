---
status: complete
priority: p2
issue_id: "011"
tags: [privacy, gdpr, ui, settings]
dependencies: ["010"]
---

# Privacy Settings Missing "Delete My Contributed Data" Button

## Problem Statement

`DataUploadService.unlinkContributorData()` exists in code but is never called from anywhere in the app. The `PrivacySettingsView` "Data" section only has "Delete Workout History" and "Reset App" — neither deletes server-side contributed sensor data. The app's privacy policy promises users can delete their contributed data, but there is no UI path to do so. This is required for GDPR Article 17 compliance and App Store Review Guideline 5.1.1.

Note: This todo depends on todo 010 which changes the unlink to an actual delete.

## Findings

- `inch/inch/Features/Settings/PrivacySettingsView.swift:148-157` — `dataSection` has no unlink/delete button
- `inch/inch/Services/DataUploadService.swift:41-63` — `unlinkContributorData(contributorId:)` is defined but never called
- `inch/inch/Features/Settings/SettingsViewModel.swift` — may need a new method to call unlink + regenerate contributorId
- `files/privacy-policy.md` states users can reset their contributor ID and delete contributed data

## Proposed Solutions

### Option 1: Add button to Privacy Settings (Recommended)

**Approach:** Add a "Delete My Contributed Data" button in the `dataSection` of `PrivacySettingsView` that:
1. Shows a confirmation alert
2. Calls `DataUploadService.unlinkContributorData(contributorId:)`
3. Generates a new `contributorId` in `UserSettings`
4. Disables upload consent (requires user to re-consent if they want to contribute again)

**Pros:**
- GDPR-compliant right to erasure
- Clear user control
- Matches privacy policy promise

**Cons:**
- Requires async error handling in the UI

**Effort:** 2-3 hours

**Risk:** Low

## Recommended Action

**To be filled during triage.**

## Technical Details

**Affected files:**
- `inch/inch/Features/Settings/PrivacySettingsView.swift:148-157`
- `inch/inch/Features/Settings/SettingsViewModel.swift`
- `inch/inch/Services/DataUploadService.swift` (call site)

## Acceptance Criteria

- [ ] "Delete My Contributed Data" button visible in Data & Privacy settings (only when `motionDataUploadConsented == true`)
- [ ] Confirmation alert warns the action is irreversible
- [ ] On confirm: calls unlinkContributorData, clears contributorId, sets `motionDataUploadConsented = false`
- [ ] Error state handled if network unavailable
- [ ] Button is disabled / shows loading state during request

## Work Log

### 2026-03-17 - Security Review Discovery

**By:** Privacy manifest agent + Claude Code

**Actions:**
- Confirmed unlinkContributorData is never called from any UI
- Verified privacy policy promises the capability
