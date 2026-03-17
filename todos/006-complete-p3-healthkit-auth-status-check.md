---
status: complete
priority: p3
issue_id: "006"
tags: [healthkit, permissions]
dependencies: []
---

# HealthKitService Sets isAuthorized=true Without Checking Actual Grant

## Problem Statement

`HealthKitService.requestAuthorization()` sets `isAuthorized = true` when the `try await healthStore.requestAuthorization(...)` call completes without throwing. However, HealthKit's `requestAuthorization` always completes successfully (without throwing) even when the user denies permission — it throws only for programmer errors (e.g., invalid types). As a result, `isAuthorized` is always `true` after the first authorization request regardless of what the user chose.

## Findings

- `inch/inch/Services/HealthKitService.swift:22-23` — `isAuthorized = true` set after successful `requestAuthorization` call
- HealthKit by design does not tell apps whether the user denied — it's a privacy protection
- The `saveWorkout` guard `guard HKHealthStore.isHealthDataAvailable(), isAuthorized` would pass even after denial
- Calling `healthStore.save(_:)` after denial simply throws an error (silently caught on line 51), so there's no functional crash — but `isAuthorized` is semantically wrong and could mislead future UI code

## Proposed Solutions

### Option 1: Check `authorizationStatus` after request (Recommended)

**Approach:** After `requestAuthorization`, check the actual status for at least one required type to set `isAuthorized`.

```swift
try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
let workoutStatus = healthStore.authorizationStatus(for: HKObjectType.workoutType())
isAuthorized = workoutStatus == .sharingAuthorized
```

**Pros:**
- Accurate `isAuthorized` state
- UI can show correct status

**Cons:**
- HealthKit still doesn't reveal read permission status (by design)
- Only workout write permission is verifiable

**Effort:** 15 minutes

**Risk:** None

---

### Option 2: Remove `isAuthorized` and always attempt save

**Approach:** Remove the `isAuthorized` flag. Call `healthStore.save` and handle errors silently as already done. The guard becomes just `HKHealthStore.isHealthDataAvailable()`.

**Pros:**
- Simpler; let HealthKit be the authority
- Correctly handles partial permissions

**Cons:**
- Less observable — harder to show HealthKit status in Settings UI

**Effort:** 20 minutes

**Risk:** Low

## Recommended Action

**To be filled during triage.**

## Technical Details

**Affected files:**
- `inch/inch/Services/HealthKitService.swift:9-24`

## Acceptance Criteria

- [ ] `isAuthorized` reflects actual HealthKit write authorization, not just successful request
- [ ] No change to app functionality (save still attempted, errors still caught)

## Work Log

### 2026-03-17 - Security Review Discovery

**By:** Claude Code

**Actions:**
- Reviewed HealthKit authorization pattern
- Confirmed HealthKit's `requestAuthorization` always succeeds even on denial
