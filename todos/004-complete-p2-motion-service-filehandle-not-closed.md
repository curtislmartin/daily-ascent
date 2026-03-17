---
status: complete
priority: p2
issue_id: "004"
tags: [data-integrity, sensor-recording, file-handling]
dependencies: []
---

# MotionRecordingService: Last Buffer Not Flushed and FileHandle Not Closed on Stop

## Problem Statement

`MotionRecordingService` buffers 50 samples (~0.5 seconds at 100 Hz) before flushing to disk. When `stopRecording()` is called, `motionManager.stopDeviceMotionUpdates()` halts new samples but the in-memory buffer is **not flushed**. Up to 49 samples (the tail of every recording) are silently dropped. The `FileHandle` is also never explicitly closed — it relies on ARC deallocation, which is non-deterministic.

## Findings

- `inch/inch/Services/MotionRecordingService.swift:87-89` — buffer is only written when `buffer.count >= 50 * 36`; the remainder is never written
- `inch/inch/Services/MotionRecordingService.swift:48-55` — `stopRecording()` does not flush the buffer or close the file handle
- The `fileHandle` and `buffer` are captured in the `CMDeviceMotionHandler` closure; `stopRecording()` has no reference to either
- For a 3-set workout this drops ~1.5 seconds of motion data per set
- Same pattern likely exists in `inch/inchwatch Watch App/Services/WatchMotionRecordingService.swift`

## Proposed Solutions

### Option 1: Flush buffer in stopDeviceMotionUpdates handler + expose flush closure (Recommended)

**Approach:** Store the `fileHandle` and a flush closure as instance properties so `stopRecording()` can flush and close before returning.

```swift
private var flushAndClose: (() -> Void)?

func stopRecording() -> URL? {
    motionManager.stopDeviceMotionUpdates()
    flushAndClose?()      // flush remainder + close
    flushAndClose = nil
    sensorQueue = nil
    isRecording = false
    let url = currentRecordingURL
    currentRecordingURL = nil
    return url
}
```

In `startDeviceMotionUpdates`, after defining the handler, store:
```swift
flushAndClose = {
    if !buffer.isEmpty {
        try? fileHandle.write(contentsOf: buffer)
        buffer.removeAll()
    }
    try? fileHandle.close()
}
```

**Pros:**
- Complete data capture
- Explicit resource cleanup

**Cons:**
- Small refactor required for nonisolated boundary
- `nonisolated(unsafe)` or a sendable wrapper needed for the closure

**Effort:** 1-2 hours

**Risk:** Medium (careful handling of nonisolated context needed)

---

### Option 2: Reduce buffer size to 1 (flush every sample)

**Approach:** Change buffer threshold to 1 to flush on every sample, eliminating the tail-drop issue.

**Pros:**
- Simplest code change

**Cons:**
- Very high I/O frequency (100 writes/sec)
- File system pressure; battery impact

**Effort:** 5 minutes

**Risk:** Medium (performance)

## Recommended Action

**To be filled during triage.**

## Technical Details

**Affected files:**
- `inch/inch/Services/MotionRecordingService.swift:48-92`
- `inch/inchwatch Watch App/Services/WatchMotionRecordingService.swift` (check for same pattern)

## Acceptance Criteria

- [ ] `stopRecording()` flushes any remaining buffered samples to disk
- [ ] `FileHandle` is explicitly closed after recording stops
- [ ] Binary files have complete data (no tail truncation)
- [ ] No crash or data race introduced

## Work Log

### 2026-03-17 - Security Review Discovery

**By:** Claude Code

**Actions:**
- Traced `startDeviceMotionUpdates` closure — buffer only flushed at 50-sample threshold
- Confirmed `stopRecording()` has no flush or close step
- Estimated ~49 samples lost per set (~0.5s of motion data)
