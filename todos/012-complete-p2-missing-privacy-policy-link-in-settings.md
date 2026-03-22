---
status: complete
priority: p2
issue_id: "012"
tags: [privacy, app-store, settings, ui]
dependencies: []
---

# No Privacy Policy Link in App Settings

## Problem Statement

The app's privacy policy exists at `https://clmartin.dev/daily-ascent/privacy` but there is no in-app link to it. The `PrivacySettingsView` only shows consent toggle, demographics, and destructive actions. Apple's App Store Review Guidelines require that apps with any data collection must make the privacy policy accessible from within the app. Many reviewers specifically check for an in-app privacy policy link.

## Findings

- `inch/inch/Features/Settings/PrivacySettingsView.swift` — no privacy policy link anywhere
- `inch/inch/Features/Settings/SettingsView.swift` — no privacy policy link in the settings root
- `files/privacy-policy.md` states the policy is hosted at `https://clmartin.dev/daily-ascent/privacy`
- App Store metadata requires a privacy policy URL, but in-app link is strongly recommended and expected by reviewers

## Proposed Solutions

### Option 1: Add footer link in PrivacySettingsView (Recommended)

**Approach:** Add a `Link` at the bottom of the `PrivacySettingsView` list.

```swift
Section {
    Link("Privacy Policy", destination: URL(string: "https://clmartin.dev/daily-ascent/privacy")!)
} footer: {
    Text("Last updated March 2026")
}
```

**Pros:**
- Minimal change
- Correct semantic location (in Data & Privacy settings)
- Opens in Safari

**Effort:** 15 minutes

**Risk:** None

---

### Option 2: Add to Settings root as separate row

**Approach:** Add a "Privacy Policy" row at the bottom of `SettingsView` outside the sections.

**Pros:**
- More discoverable

**Cons:**
- Less contextually appropriate than within the privacy section

**Effort:** 15 minutes

**Risk:** None

## Recommended Action

**To be filled during triage.**

## Technical Details

**Affected files:**
- `inch/inch/Features/Settings/PrivacySettingsView.swift`

**Privacy policy URL:** `https://clmartin.dev/daily-ascent/privacy`

## Acceptance Criteria

- [ ] Tapping "Privacy Policy" in settings opens `https://clmartin.dev/daily-ascent/privacy` in Safari
- [ ] Link is visible in Data & Privacy settings section
- [ ] Works correctly on first launch before onboarding is complete (if accessible)

## Work Log

### 2026-03-17 - Security Review Discovery

**By:** Privacy manifest agent + Claude Code

**Actions:**
- Confirmed no in-app privacy policy link exists
- Confirmed policy URL from privacy-policy.md
