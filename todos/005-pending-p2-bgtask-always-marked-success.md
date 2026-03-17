---
status: pending
priority: p2
issue_id: "005"
tags: [background-task, networking, reliability]
dependencies: []
---

# BGProcessingTask Always Marked as Successful Regardless of Upload Outcome

## Problem Statement

`DataUploadService.handleBGUpload` always calls `task.setTaskCompleted(success: true)` even if the upload was cancelled (by the expiration handler) or all uploads failed. iOS uses the success/failure signal to schedule future background task opportunities — always reporting success prevents iOS from learning that uploads are failing and may result in suboptimal retry scheduling.

## Findings

- `inch/inch/Services/DataUploadService.swift:36` — `task.setTaskCompleted(success: true)` called unconditionally
- `inch/inch/Services/DataUploadService.swift:28-35` — `expirationHandler` cancels `uploadTask`, but after `await uploadTask?.value` the code still reports success
- `uploadPending` swallows all errors silently (line 98-100) and leaves recordings in `.pending` state — so "success" is ambiguous
- Apple's documentation recommends `success: false` when the task was interrupted, which causes iOS to schedule a retry sooner

## Proposed Solutions

### Option 1: Track completion state and report accurately (Recommended)

**Approach:** Use a flag to track whether the task was cancelled/expired and report accordingly.

```swift
func handleBGUpload(task: BGProcessingTask, context: ModelContext) async {
    var cancelled = false
    var uploadTask: Task<Void, Never>?

    task.expirationHandler = {
        cancelled = true
        uploadTask?.cancel()
    }

    uploadTask = Task {
        await uploadPending(context: context)
    }

    await uploadTask?.value
    task.setTaskCompleted(success: !cancelled)
    scheduleBGUpload()
}
```

**Pros:**
- iOS gets accurate signal for retry scheduling
- No behaviour change when uploads succeed normally

**Cons:**
- None

**Effort:** 15 minutes

**Risk:** None

---

### Option 2: Check for remaining pending recordings after upload

**Approach:** After `uploadPending`, fetch any remaining `.pending` recordings and report `success: false` if any remain.

**Pros:**
- More semantically accurate (success = all uploaded)

**Cons:**
- Requires extra fetch; penalises partial failures that may be expected
- More complex

**Effort:** 30 minutes

**Risk:** Low

## Recommended Action

**To be filled during triage.**

## Technical Details

**Affected files:**
- `inch/inch/Services/DataUploadService.swift:26-39`

## Acceptance Criteria

- [ ] `task.setTaskCompleted(success: false)` when expiration handler fires
- [ ] `task.setTaskCompleted(success: true)` on normal completion
- [ ] iOS background scheduling behaviour is not regressed

## Work Log

### 2026-03-17 - Security Review Discovery

**By:** Claude Code

**Actions:**
- Reviewed BGProcessingTask lifecycle in DataUploadService
- Confirmed expiration handler cancels task but success is always reported
