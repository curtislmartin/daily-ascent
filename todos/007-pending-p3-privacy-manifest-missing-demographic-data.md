---
status: pending
priority: p3
issue_id: "007"
tags: [privacy, app-store, privacy-manifest]
dependencies: ["001"]
---

# Privacy Manifest May Not Fully Declare Uploaded Demographic Data

## Problem Statement

The app optionally collects and uploads demographic data: `age_range`, `height_range`, `biological_sex`, and `activity_level`. The `PrivacyInfo.xcprivacy` declares `NSPrivacyCollectedDataTypeFitness` and `NSPrivacyCollectedDataTypeOtherDiagnosticData`. However, `biological_sex` and `age_range` may fall under more specific Apple privacy label categories that need explicit declaration to pass App Store review.

## Findings

- `inch/inch/PrivacyInfo.xcprivacy` and `inch/inchwatch Watch App/PrivacyInfo.xcprivacy` — both identical; declare `Fitness` + `OtherDiagnosticData`
- `inch/inch/Services/DataUploadService.swift:148-150` — `ageRange`, `heightRange`, `biologicalSex`, `activityLevel` are sent to Supabase as part of `SensorRecordingPayload`
- Apple's privacy label categories that may apply:
  - `NSPrivacyCollectedDataTypeOtherUserContent` — unclear fit
  - The current `OtherDiagnosticData` purpose includes `ProductPersonalization` which is closest
- The demographic fields ARE optional and only sent when the user has provided them AND consented to upload
- Both manifests declare `NSPrivacyTracking: false` which is correct (no cross-app tracking)
- Motion API reason code `C617.1` ("Provide a feature that is listed in the App description") is correctly declared

## Proposed Solutions

### Option 1: Review against Apple's current privacy label taxonomy (Recommended)

**Approach:** Cross-reference the actual data fields sent against Apple's full list of `NSPrivacyCollectedDataType` values to confirm no additional declaration is needed. If `biological_sex` is considered sensitive health data under Apple's taxonomy, add the appropriate type.

**Pros:**
- Correct and complete disclosure
- Avoids rejection for under-disclosure

**Cons:**
- None

**Effort:** 1 hour research + 30 min manifest edit

**Risk:** Low

---

### Option 2: Remove demographic fields from upload

**Approach:** Strip `age_range`, `height_range`, `biological_sex`, `activity_level` from the `SensorRecordingPayload`. Only upload motion data + exercise metadata.

**Pros:**
- Eliminates the privacy label question entirely
- Simpler consent language

**Cons:**
- Loses ML training signal for body-type-specific rep counting
- Contradicts onboarding and settings UI text

**Effort:** 2 hours

**Risk:** Low

## Recommended Action

**To be filled during triage.**

## Technical Details

**Affected files:**
- `inch/inch/PrivacyInfo.xcprivacy`
- `inch/inchwatch Watch App/PrivacyInfo.xcprivacy`
- `inch/inch/Services/DataUploadService.swift:183-200` (SensorRecordingPayload)

**Apple reference:** https://developer.apple.com/documentation/bundleresources/privacy_manifest_files/describing_data_use_in_privacy_manifests

## Acceptance Criteria

- [ ] Privacy manifest accurately reflects all data types collected and uploaded
- [ ] Cross-referenced against Apple's taxonomy
- [ ] Both iOS and watchOS manifests updated identically
- [ ] App Store submission does not receive a metadata rejection for data disclosure

## Work Log

### 2026-03-17 - Security Review Discovery

**By:** Claude Code

**Actions:**
- Reviewed both PrivacyInfo.xcprivacy files
- Cross-referenced with SensorRecordingPayload fields
- Identified potential gap for demographic data categorisation
