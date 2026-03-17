---
status: complete
priority: p2
issue_id: "003"
tags: [privacy, storage, icloud, sensor-data]
dependencies: []
---

# Sensor Data Files Stored in Documents Directory (iCloud Backed Up)

## Problem Statement

Motion sensor binary files are written to `.documentsDirectory/sensor_data/`. This directory is included in iCloud backups and iTunes backups by default. Sensor data files grow with every workout (each set generates a `.bin` file). This causes:

1. **Privacy concern**: Raw motion sensor data is backed up to Apple's iCloud servers even when the user has not consented to upload it.
2. **Backup size**: Files accumulate indefinitely until uploaded; for active users this could be hundreds of MB backed up unnecessarily.
3. **Data leakage on restore**: If a user restores to a new device with a different `contributorId`, the backed-up files reference the old ID and cannot be correctly attributed.

## Findings

- `inch/inch/Services/MotionRecordingService.swift:16` — `URL.documentsDirectory.appending(path: "sensor_data")`
- `inch/inch/Services/WatchConnectivityService.swift:172` — same path used for files received from watch
- `inch/inchwatch Watch App/Services/WatchMotionRecordingService.swift:18` — same pattern on watchOS
- No `isExcludedFromBackup` resource value is set anywhere
- Apple recommends `Application Support` for app-generated data the user didn't create, or explicitly excluding from backup

## Proposed Solutions

### Option 1: Move to Application Support directory (Recommended)

**Approach:** Store sensor data in `FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first` instead of Documents. Application Support is not shown in Files app but IS backed up — however, Apple explicitly states it's for "app-generated data that is not user data". Alternatively, combine with Option 2.

**Pros:**
- Correct semantic for app-generated data
- Still available after device restore if user restores from backup

**Cons:**
- Backed up unless explicitly excluded

**Effort:** 30 minutes (update all 3 storage locations)

**Risk:** Low — path change only, existing `.bin` files already on device won't move

---

### Option 2: Exclude `sensor_data` directory from backup (Recommended)

**Approach:** After creating the `sensor_data` directory, set `URLResourceValues.isExcludedFromBackup = true`.

```swift
let dir = URL.documentsDirectory.appending(path: "sensor_data", directoryHint: .isDirectory)
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
var values = URLResourceValues()
values.isExcludedFromBackup = true
try? dir.setResourceValues(values)
```

**Pros:**
- Keeps current Documents path (no migration needed)
- Files remain available on device but are not backed up
- Correct behaviour: sensor data can be re-recorded; no need to preserve in backup

**Cons:**
- Files are lost on device restore (acceptable — sensor data is ephemeral)

**Effort:** 15 minutes per location (3 locations)

**Risk:** Low

---

### Option 3: Combine — Application Support + exclude from backup

**Approach:** Move to Application Support AND mark as excluded from backup.

**Effort:** 1 hour

**Risk:** Low

## Recommended Action

**To be filled during triage.**

## Technical Details

**Affected files:**
- `inch/inch/Services/MotionRecordingService.swift:16`
- `inch/inch/Services/WatchConnectivityService.swift:172`
- `inch/inchwatch Watch App/Services/WatchMotionRecordingService.swift:18`

**Related components:**
- `DataUploadService` reads `recording.filePath` — path must stay consistent after any change

## Acceptance Criteria

- [ ] Sensor data files are not included in iCloud/iTunes backups
- [ ] `isExcludedFromBackup` is set on the `sensor_data` directory at creation time
- [ ] `DataUploadService` can still locate and upload files after the path change (if path changed)
- [ ] No regression in sensor recording or upload flow

## Work Log

### 2026-03-17 - Security Review Discovery

**By:** Claude Code

**Actions:**
- Identified three locations writing sensor files to Documents directory
- Confirmed no backup exclusion is set anywhere
- Confirmed Apple's iCloud backup includes Documents by default
