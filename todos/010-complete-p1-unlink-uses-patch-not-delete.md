---
status: complete
priority: p1
issue_id: "010"
tags: [security, gdpr, privacy, supabase, rls]
dependencies: ["008"]
---

# unlinkContributorData Uses PATCH (Re-attribution), Not DELETE — GDPR Right to Erasure Not Met

## Problem Statement

`DataUploadService.unlinkContributorData` sends a `PATCH` request that overwrites `contributor_id` with a new random UUID. This **re-attributes** data rather than deleting it. Under GDPR Article 17 (right to erasure), users have the right to have their data deleted, not merely anonymised by orphaning a UUID. Additionally, the Supabase RLS policy (`Allow delete by contributor`) only covers `DELETE` operations — a `PATCH`/`UPDATE` by the anon role is not covered by any policy, meaning:

1. Any user with the anon key can PATCH any row's `contributor_id` to anything
2. The "delete my data" promise in the privacy policy is not actually implemented as deletion

The privacy agent also found that the **privacy settings UI has no button** that calls this function — `unlinkContributorData` exists in code but is unreachable from the user interface.

## Findings

- `inch/inch/Services/DataUploadService.swift:41-63` — uses `PATCH` with `httpMethod = "PATCH"`
- `inch/inch/Services/DataUploadService.swift:48` — URL pattern: `sensor_recordings?contributor_id=eq.\(contributorId)`
- `inch/inch/Features/Settings/PrivacySettingsView.swift:148-157` — no "Delete My Data" or "Unlink" button — function is never called
- `files/privacy-policy.md` promises users can delete contributed data
- `files/backend-api.md` documents an RLS policy `Allow delete by contributor` — this is for DELETE, not PATCH
- Storage files (`.bin.zlib`) are also not deleted by the current implementation — only the metadata row is re-attributed

## Proposed Solutions

### Option 1: Change PATCH to DELETE + delete storage objects (Recommended)

**Approach:**
1. Change the metadata operation from `PATCH` to `DELETE`:
   ```swift
   // Before
   request.httpMethod = "PATCH"
   request.httpBody = try JSONEncoder().encode(["contributor_id": UUID().uuidString.lowercased()])

   // After
   request.httpMethod = "DELETE"
   // No body needed
   ```
2. Add a second step to list and delete storage objects for this contributor from the `sensor-data` bucket
3. Add the missing RLS `FOR UPDATE` block on `sensor_recordings` for the anon role
4. Add a "Delete My Contributed Data" button in `PrivacySettingsView` that calls this function

**Pros:**
- Correct GDPR implementation
- Matches privacy policy promise

**Cons:**
- Supabase Storage listing/deletion requires additional API calls
- Need to update RLS policies on the backend

**Effort:** 3-4 hours (code + backend)

**Risk:** Medium (backend change)

---

### Option 2: Implement as Supabase Edge Function

**Approach:** Create a Supabase Edge Function that: receives the contributor_id, deletes all `sensor_recordings` rows, and deletes all storage objects under `sensor-data/{contributor_id}/`. The client calls the Edge Function instead of direct REST.

**Pros:**
- Runs as `service_role` — no anon PATCH/DELETE permission needed
- More auditable
- Can cascade to storage objects cleanly

**Cons:**
- Requires Edge Function deployment and maintenance
- More infrastructure

**Effort:** 6-8 hours

**Risk:** Low once deployed

## Recommended Action

**To be filled during triage.**

## Technical Details

**Affected files:**
- `inch/inch/Services/DataUploadService.swift:41-63`
- `inch/inch/Features/Settings/PrivacySettingsView.swift:148-157`
- Supabase backend: `sensor_recordings` table RLS policies

**Expected Supabase RLS changes:**
```sql
-- Add: Block anon from UPDATE/PATCH
CREATE POLICY "anon cannot update" ON sensor_recordings
  FOR UPDATE TO anon USING (false);

-- Existing DELETE policy (verify it's active)
-- Allow delete by contributor
CREATE POLICY "contributor can delete own" ON sensor_recordings
  FOR DELETE TO anon USING (contributor_id = current_setting('request.headers')::json->>'x-contributor-id');
```

## Acceptance Criteria

- [ ] `unlinkContributorData` sends `DELETE` instead of `PATCH`
- [ ] Storage objects for the contributor are also deleted (not just metadata rows)
- [ ] RLS policy blocks anon `UPDATE`/`PATCH` on `sensor_recordings`
- [ ] `PrivacySettingsView` has a "Delete My Contributed Data" button that calls this function
- [ ] Calling the function removes all traces of the contributor's data from Supabase
- [ ] Manual verification: old contributor_id returns 0 rows after deletion

## Work Log

### 2026-03-17 - Security Review Discovery

**By:** Security Sentinel agent + Claude Code

**Actions:**
- Identified PATCH semantics vs DELETE requirement for GDPR erasure
- Confirmed function is unreachable from UI
- Confirmed Supabase RLS only covers DELETE, not UPDATE/PATCH
- Checked privacy policy wording — promises actual deletion
