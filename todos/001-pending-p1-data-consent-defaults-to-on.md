---
status: pending
priority: p1
issue_id: "001"
tags: [privacy, app-store, gdpr, security]
dependencies: []
---

# Data Sharing Consent Toggle Defaults to ON

## Problem Statement

`DataConsentView` initialises the sharing toggle with `@State private var consented = true`, meaning data upload is **opted-in by default**. Apple App Store Review Guideline 5.1.2(iv) requires that consent for data collection default to **off** (opt-in, not opt-out). GDPR Article 7 explicitly states that pre-ticked boxes do not constitute valid consent. This is a submission-blocking issue.

## Findings

- `inch/inch/Features/Onboarding/DataConsentView.swift:8` — `@State private var consented = true`
- The toggle controls `motionDataUploadConsented` which gates actual uploads in `DataUploadService.uploadPending`
- A first-time user who taps Continue without reading the screen will have sharing silently enabled
- Apple reviewers specifically check consent flows for fitness/health apps

## Proposed Solutions

### Option 1: Change default to `false` (Recommended)

**Approach:** Change the initial value of `consented` to `false`.

```swift
@State private var consented = false
```

**Pros:**
- One-line fix
- Compliant with GDPR, CCPA, and App Store guidelines
- Builds user trust

**Cons:**
- Slightly lower opt-in rate (expected and correct)

**Effort:** 2 minutes

**Risk:** None

---

### Option 2: Remove default, require explicit choice

**Approach:** Remove the toggle default and require the user to actively tap either "Share" or "Don't Share" buttons before Continue is enabled.

**Pros:**
- Clearest possible consent signal
- Unambiguous user intent

**Cons:**
- More UI work
- Higher friction in onboarding

**Effort:** 1-2 hours

**Risk:** Low

## Recommended Action

**To be filled during triage.**

## Technical Details

**Affected files:**
- `inch/inch/Features/Onboarding/DataConsentView.swift:8`

## Acceptance Criteria

- [ ] `consented` initialises to `false`
- [ ] User must actively enable the toggle to share data
- [ ] Tapping Continue without toggling results in `motionDataUploadConsented = false`
- [ ] App Store Review Guideline 5.1.2 compliant

## Work Log

### 2026-03-17 - Security Review Discovery

**By:** Claude Code

**Actions:**
- Identified default-on consent toggle during pre-submission security review
- Confirmed `DataUploadService.uploadPending` checks `settings.motionDataUploadConsented`
- Verified App Store and GDPR requirements

**Learnings:**
- Single character change but submission-blocking severity
