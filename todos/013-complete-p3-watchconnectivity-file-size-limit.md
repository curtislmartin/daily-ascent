---
status: complete
priority: p3
issue_id: "013"
tags: [security, watchconnectivity, memory, reliability]
dependencies: []
---

# No File Size Limit on WatchConnectivity Sensor File Transfers

## Problem Statement

`WatchConnectivityService.session(_:didReceive:)` accepts any file transferred from the watch without validating its size. If the watch records an abnormally long session (due to a bug, the user leaving the app open, or a crafted message), the resulting `.bin` file could be many megabytes. `DataUploadService.uploadRecording` then loads the entire file into memory with `Data(contentsOf: fileURL)`, which could cause a memory spike or crash on upload. At 50Hz with 36 bytes/sample, 5 minutes of recording = ~10.8MB.

## Findings

- `inch/inch/Services/WatchConnectivityService.swift:181` — `attrs[.size] as? Int` is read but only stored in metadata, never validated
- `inch/inch/Services/DataUploadService.swift:112` — `Data(contentsOf: fileURL)` loads entire file into memory
- No maximum recording duration enforced on the watch side
- `inch/inchwatch Watch App/Services/WatchMotionRecordingService.swift` — no time limit on recording

## Proposed Solutions

### Option 1: Reject files over size limit on receipt (Recommended)

**Approach:** After reading the file size in `WatchConnectivityService`, reject files above a threshold (e.g., 5MB ≈ ~2.5 min at 50Hz):

```swift
let size = (attrs?[.size] as? Int) ?? 0
guard size <= 5_000_000 else {
    try? FileManager.default.removeItem(at: dest)
    return
}
```

**Pros:**
- Simple guard
- Prevents memory spike on upload

**Cons:**
- Silently discards oversized files (could add a log entry)

**Effort:** 15 minutes

**Risk:** None

---

### Option 2: Add recording duration limit on watch

**Approach:** Auto-stop recording after a maximum duration (e.g., 3 minutes) in `WatchMotionRecordingService`.

**Pros:**
- Prevents the problem at source
- Better user experience (won't record indefinitely if app hangs)

**Cons:**
- Must be set high enough for legitimate long sets

**Effort:** 30 minutes

**Risk:** Low

## Recommended Action

**To be filled during triage.**

## Technical Details

**Affected files:**
- `inch/inch/Services/WatchConnectivityService.swift:181`
- `inch/inchwatch Watch App/Services/WatchMotionRecordingService.swift`

## Acceptance Criteria

- [ ] Files over 5MB received from watch are discarded with a log message
- [ ] Normal recording files (typical set: < 1MB) are unaffected

## Work Log

### 2026-03-17 - Security Review Discovery

**By:** Security Sentinel agent

**Actions:**
- Identified unbounded file size acceptance in WatchConnectivity handler
- Traced to in-memory load in DataUploadService
