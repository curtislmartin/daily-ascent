# Daily Ascent — Submission Checklist

> **Purpose:** Step-by-step checklist for TestFlight and App Store submission. Work through top to bottom.
>
> **Last updated:** 2026-04-03

---

## Prerequisites (Do These First)

- [ ] **Apple Developer Program membership** is active ($149 AUD/year). Verify at developer.apple.com/account.
- [ ] **App Store Connect** — create the app record with bundle ID matching your Xcode project.
- [ ] **Business entity decision** — decide whether to publish as "Curtis Martin" (sole developer) or register a business name first. This affects what appears as the developer name on the App Store and cannot be easily changed later.
- [ ] **Privacy policy hosted** — deploy `privacy-policy.md` as HTML to https://clmartin.dev/daily-ascent/privacy via GitHub Pages. Must be live before submission.
- [ ] **Support URL** — set up a support page at https://clmartin.dev/daily-ascent/support (can be minimal — contact info and FAQ). Required by App Store Connect.

---

## Xcode Project Configuration

- [ ] **Bundle identifier** matches App Store Connect record (e.g. `dev.clmartin.inch` for iOS, `dev.clmartin.inch.watchkitapp` for watchOS).
- [ ] **Version number** set to `1.0.0` (or `1.0`) in both targets.
- [ ] **Build number** incremented for each upload (must be unique per upload to App Store Connect).
- [ ] **Deployment targets** confirmed: iOS 18.0, watchOS 10.6.
- [ ] **Signing** — automatic signing with your Apple Developer team selected for both targets.
- [ ] **App icon** — 1024×1024 icon included in the asset catalogue for both iOS and watchOS. No alpha channel, no transparency.
- [ ] **Launch screen** — ensure a launch storyboard or SwiftUI launch screen is configured (not a static image).
- [ ] **PrivacyInfo.xcprivacy** manifest included declaring required reason APIs (CMMotionManager, any other required-reason APIs).
- [ ] **Info.plist usage descriptions** present for all permissions:
  - `NSMotionUsageDescription` — motion sensor access
  - `NSHealthUpdateUsageDescription` — HealthKit write (v1 only writes workouts)
  - `NSHealthShareUsageDescription` — HealthKit read (not needed in v1 — add in v2 when external streak awareness lands)
- [ ] **Background modes** configured if using `BGProcessingTask` for sensor upload.
- [ ] **No hardcoded API keys** in source. Supabase credentials loaded from a configuration file excluded from version control.

---

## Build & Archive

- [ ] **Clean build** succeeds with zero warnings on both targets (iPhone + Watch).
- [ ] **Run the spec audit** (`spec-audit.md`) — all items should be ✅ or have tracked issues.
- [ ] **Test on physical devices** — simulator alone is not sufficient, especially for Watch connectivity, sensor recording, and HealthKit.
- [ ] **Archive** the iOS app from Xcode (Product → Archive). The Watch app is embedded automatically.
- [ ] **Validate** the archive in Xcode's Organizer before uploading.
- [ ] **Upload** to App Store Connect via Xcode Organizer or `xcodebuild -exportArchive`.

---

## TestFlight — Internal Testing

- [ ] Build appears in App Store Connect under TestFlight → Internal Testing.
- [ ] Add yourself and any close collaborators as internal testers (up to 100, no review needed).
- [ ] Install via TestFlight app on iPhone. Watch app should install automatically if paired.
- [ ] Run through the full flow: onboarding → enrol exercises → complete a workout → check Today dashboard → verify Watch sync → check history/stats.
- [ ] Verify sensor recording starts/stops correctly during sets.
- [ ] Verify data consent toggle works (opt in, opt out, verify no upload when off).
- [ ] Verify HealthKit workout appears in Apple Health after a session.
- [ ] Verify notifications fire correctly (daily reminder, streak protection, test day).
- [ ] Test on multiple device combinations if possible.

---

## TestFlight — External Testing (Optional, Recommended)

- [ ] Create an external testing group in App Store Connect.
- [ ] Fill in the beta app description and review notes from `testflight-beta.md`.
- [ ] Add the privacy policy URL.
- [ ] Submit the build for Beta App Review (first external build only — subsequent builds auto-approve unless you change the description).
- [ ] Wait for approval (typically 24–48 hours).
- [ ] Invite external testers via email or public link.
- [ ] Collect feedback, fix issues, upload new builds as needed.

---

## App Store Submission

- [ ] **All metadata entered** in App Store Connect from `app-store-metadata.md`:
  - App name and subtitle
  - Description and promotional text
  - Keywords
  - Category (Health & Fitness)
  - Age rating questionnaire completed
  - Privacy policy URL
  - Support URL
  - App review contact information and notes
- [ ] **Privacy Nutrition Label** completed in App Store Connect (App Privacy section) matching the declarations in `app-store-metadata.md`.
- [ ] **Screenshots uploaded** for required device sizes (6.9" and 6.3" iPhone at minimum). See `app-store-metadata.md` for dimensions.
- [ ] **App icon** — verify the 1024×1024 appears correctly in App Store Connect.
- [ ] **Pricing** set to Free, available in target territories.
- [ ] **Select the build** to submit (from your uploaded archives).
- [ ] **Submit for review.**

---

## Post-Submission

- [ ] Monitor the app's review status in App Store Connect (typically 24–48 hours, can take longer).
- [ ] If rejected, read the rejection notes carefully — common issues for fitness apps:
  - Missing or inadequate permission usage descriptions
  - Privacy policy doesn't match actual data practices
  - HealthKit usage not justified or too broad
  - Metadata claims features that don't exist
- [ ] Once approved, set the release to manual or automatic (your choice).
- [ ] After release, verify the live listing looks correct — screenshots, description, privacy label.

---

## Timeline Consideration

Apple requires all new app submissions to be built with the latest Xcode and SDK after **April 28, 2026**. Your current project targets Xcode 16 / iOS 18. If you submit before that date, you're fine. If you submit after, you'll need to build with Xcode 26 (you can still deploy to iOS 18 as a minimum target).
