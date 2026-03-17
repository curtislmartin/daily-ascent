---
status: pending
priority: p3
issue_id: "008"
tags: [security, supabase, backend, api-key]
dependencies: []
---

# Verify Supabase Row Level Security Prevents Unauthorised Data Access

## Problem Statement

The Supabase anon key is embedded in the app bundle (`Secrets.plist`). This is standard practice for Supabase and the key is designed to be semi-public. However, the security of the entire backend rests on **Row Level Security (RLS) policies** being correctly configured on the `sensor_recordings` table and the `sensor-data` storage bucket. Without proper RLS, anyone who extracts the anon key from the IPA can:

1. INSERT arbitrary sensor recording rows with any `contributor_id`
2. READ other users' sensor data rows
3. DELETE or corrupt records

This is a verification/configuration task, not a code change.

## Findings

- `inch/inch/Secrets.plist` — contains real Supabase URL and anon key (correctly in .gitignore, not committed)
- `inch/inch/Services/DataUploadService.swift:53` — uses `anonKey` for `apikey` header on all requests
- The `unlinkContributorData` function (line 41-63) issues a PATCH on `sensor_recordings?contributor_id=eq.{contributorId}` — if RLS is absent, any client could PATCH any contributor's rows
- No JWT authentication / user login — all requests use the anon role

## Proposed Solutions

### Option 1: Audit and configure RLS on Supabase (Required)

**Approach:** In the Supabase dashboard, verify and configure:

**`sensor_recordings` table:**
```sql
-- Allow INSERT for any anon (data collection from app users)
CREATE POLICY "anon can insert" ON sensor_recordings
  FOR INSERT TO anon WITH CHECK (true);

-- Disallow SELECT/UPDATE/DELETE from anon
-- (only service_role should read/modify)
CREATE POLICY "no anon read" ON sensor_recordings
  FOR SELECT TO anon USING (false);
```

**`sensor-data` storage bucket:**
- Set bucket to private (not public)
- Allow anon INSERT only (upload)
- Disallow anon SELECT (prevent others downloading recordings)

**`contributor_id` unlinking:**
The current PATCH endpoint `sensor_recordings?contributor_id=eq.{contributorId}` is a PATCH for unlinking. RLS must allow this — either:
- Allow anon PATCH (security risk if any anon can patch any row), OR
- Use a Supabase Edge Function for unlinking that runs as service_role

**Pros:**
- Correct security model
- Prevents data leakage and manipulation

**Cons:**
- Requires Supabase dashboard access and SQL knowledge

**Effort:** 2-4 hours including testing

**Risk:** High if not done before launch

---

### Option 2: Add Edge Function for unlinking

**Approach:** Replace the direct PATCH in `unlinkContributorData` with a call to a Supabase Edge Function. The function verifies the contributor_id comes from the request body and performs the update as service_role.

**Pros:**
- Removes anon PATCH permission requirement
- More auditable

**Cons:**
- More infrastructure; Edge Function deployment needed

**Effort:** 4-6 hours

**Risk:** Low once deployed

## Recommended Action

**To be filled during triage.** At minimum, verify RLS policies are in place before App Store submission. The anon key being in the app bundle is only safe if RLS is properly configured.

## Technical Details

**Affected files:**
- Supabase dashboard (not in codebase)
- `inch/inch/Services/DataUploadService.swift:41-63` (unlinkContributorData)

## Acceptance Criteria

- [ ] `sensor_recordings` table has RLS enabled in Supabase
- [ ] Anon role can INSERT but cannot SELECT or DELETE arbitrary rows
- [ ] `sensor-data` storage bucket is not publicly readable
- [ ] `unlinkContributorData` still works correctly under the RLS policies
- [ ] Manual test: extracting the anon key and attempting to read all rows from a REST client returns 0 rows or 403

## Work Log

### 2026-03-17 - Security Review Discovery

**By:** Claude Code

**Actions:**
- Identified anon key embedded in app bundle (correctly not in git)
- Reviewed DataUploadService API calls — all use anon key
- Flagged that security model depends entirely on Supabase RLS configuration
