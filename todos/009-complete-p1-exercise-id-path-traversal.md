---
status: complete
priority: p1
issue_id: "009"
tags: [security, path-traversal, upload, watchconnectivity]
dependencies: []
---

# exerciseId Used Unsanitised in Storage URLs and Local File Paths

## Problem Statement

`exerciseId` is used directly in Supabase storage upload paths and local device file paths without any validation against the known allowlist. The exerciseId originates from WatchConnectivity messages (on the iPhone side), which means a crafted watch message could inject path traversal sequences (`../`) into:

1. The Supabase storage bucket URL: `sensor-data/{exerciseId}/{fileName}`
2. The local iPhone file path when receiving watch sensor files

The only check on iPhone-side WatchConnectivity file receipt is `!exerciseId.isEmpty` (line 178), which does not prevent `../` or other traversal sequences.

## Findings

- `inch/inch/Services/DataUploadService.swift:115-116` — `storagePath = "\(recording.exerciseId)/\(fileName)"` used in URL construction
- `inch/inch/Services/WatchConnectivityService.swift:178` — only `!exerciseId.isEmpty` validation before using in file operations
- `inch/inch/Services/WatchConnectivityService.swift:174` — `file.fileURL.lastPathComponent` used as destination filename without sanitisation
- The known valid exerciseIds are a fixed set: `push_ups`, `squats`, `sit_ups`, `pull_ups`, `glute_bridges`, `dead_bugs`
- A crafted exerciseId of `../` in a WatchConnectivity message could write files outside `sensor_data/`
- Same issue in the Supabase storage path could write objects to arbitrary bucket paths

## Proposed Solutions

### Option 1: Allowlist validation (Recommended)

**Approach:** Validate `exerciseId` against the known set of valid IDs before using it in any path or URL. Reject the recording/file if it doesn't match.

```swift
// Define in InchShared or as a constant
private static let validExerciseIds: Set<String> = [
    "push_ups", "squats", "sit_ups", "pull_ups", "glute_bridges", "dead_bugs"
]

// In uploadRecording, before building storagePath:
guard Self.validExerciseIds.contains(recording.exerciseId) else {
    recording.uploadStatus = .localOnly
    try? context.save()
    return
}

// In WatchConnectivityService.session(_:didReceive:), after extracting exerciseId:
guard Self.validExerciseIds.contains(exerciseId) else { return }
```

**Pros:**
- Simple, comprehensive fix
- Validates at both ingestion points
- No performance cost

**Cons:**
- The allowlist must be kept in sync with exercise data (though exercises are fixed and won't change)

**Effort:** 30 minutes

**Risk:** Low

---

### Option 2: Sanitise the string (path encoding)

**Approach:** Use `addingPercentEncoding` or replace `/` and `..` in the exerciseId.

**Pros:**
- Slightly more flexible if exercises were ever added

**Cons:**
- Allowlist is more defensive and more correct given the fixed exercise set
- Encoding could create unexpected storage paths

**Effort:** 15 minutes

**Risk:** Medium (less defensive)

## Recommended Action

**To be filled during triage.**

## Technical Details

**Affected files:**
- `inch/inch/Services/DataUploadService.swift:115-116`
- `inch/inch/Services/WatchConnectivityService.swift:174,178`

**Related components:**
- `Shared/Sources/InchShared/Models/` — ExerciseDefinition has `exerciseId` property

## Acceptance Criteria

- [ ] `exerciseId` validated against allowlist before being used in any path or URL
- [ ] WatchConnectivity file receipt rejects any exerciseId not in the allowlist
- [ ] Supabase upload rejects any recording with an invalid exerciseId
- [ ] Valid recordings are unaffected
- [ ] No crash or silent data loss on invalid exerciseId

## Work Log

### 2026-03-17 - Security Review Discovery

**By:** Security Sentinel agent + Claude Code

**Actions:**
- Identified exerciseId used unsanitised in storage URL construction
- Confirmed WatchConnectivity only checks `!exerciseId.isEmpty`
- Identified the fixed allowlist of valid exercise IDs
