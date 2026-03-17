---
status: complete
priority: p2
issue_id: "002"
tags: [crash, safety, networking]
dependencies: []
---

# Force-Unwrap URL Construction in DataUploadService Crashes on Bad Config

## Problem Statement

`DataUploadService` uses `URL(string: ...)!` (force-unwrap) when constructing Supabase storage and REST API URLs. If `Secrets.plist` is missing, malformed, or contains a bad URL, the app crashes rather than failing gracefully. Both upload paths are affected.

## Findings

- `inch/inch/Services/DataUploadService.swift:119` — `URL(string: "\(config.supabaseURL)/storage/v1/object/sensor-data/\(storagePath)")!`
- `inch/inch/Services/DataUploadService.swift:153` — `URL(string: "\(config.supabaseURL)/rest/v1/sensor_recordings")!`
- `HealthKitService.swift:17-18` — `HKObjectType.quantityType(forIdentifier: .heartRate)!` and `.activeEnergyBurned!` — these are system-defined identifiers that Apple guarantees exist, so these force-unwraps are acceptable
- The `supabaseURL` comes from `Secrets.plist` which is user-provided; a developer mistake could produce an invalid URL
- The crash would happen inside a `BGProcessingTask`, so it would be invisible to the user but would silently kill background uploads

## Proposed Solutions

### Option 1: Guard with throw (Recommended)

**Approach:** Replace force-unwraps with `guard let` + `throw`.

```swift
// Before
let storageURL = URL(string: "\(config.supabaseURL)/storage/v1/object/sensor-data/\(storagePath)")!

// After
guard let storageURL = URL(string: "\(config.supabaseURL)/storage/v1/object/sensor-data/\(storagePath)") else {
    throw UploadError.configurationMissing
}
```

**Pros:**
- Consistent with the rest of the error-handling pattern in the function
- No crash; error propagates up and recording stays `.pending`

**Cons:**
- None

**Effort:** 15 minutes

**Risk:** None

---

### Option 2: Validate URL at config load time

**Approach:** Validate `supabaseURL` is a valid URL when loading from `Secrets.plist` and fail early in `uploadPending`.

**Pros:**
- Single validation point
- Clearer error message

**Cons:**
- More refactoring

**Effort:** 30 minutes

**Risk:** Low

## Recommended Action

**To be filled during triage.**

## Technical Details

**Affected files:**
- `inch/inch/Services/DataUploadService.swift:119`
- `inch/inch/Services/DataUploadService.swift:153`

## Acceptance Criteria

- [ ] No `!` force-unwraps on user-supplied URL strings in DataUploadService
- [ ] Malformed `SupabaseURL` in Secrets.plist causes upload to be skipped, not a crash
- [ ] Error is thrown and caught; recording stays in `.pending` state

## Work Log

### 2026-03-17 - Security Review Discovery

**By:** Claude Code

**Actions:**
- Identified two force-unwrap URL constructions in DataUploadService
- Confirmed both are on the hot path of background upload task
