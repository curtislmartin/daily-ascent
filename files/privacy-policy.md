# Daily Ascent — Privacy Policy

> **Effective date:** April 2026
>
> **Last updated:** April 2026 (added community benchmarks)
>
> **Developer:** Curtis Martin (individual developer, no registered business entity)
>
> **Contact:** support@clmartin.dev
>
> **Hosted at:** https://clmartin.dev/daily-ascent/privacy (GitHub Pages)

---

## Overview

Daily Ascent is a bodyweight training app for iOS and watchOS. This policy explains what data the app collects, how it's used, and what choices you have. The short version: Daily Ascent collects very little, never identifies you, and gives you control over anything that leaves your device.

---

## Data We Do Not Collect

Daily Ascent does not collect, store, or transmit any of the following: your name, email address, Apple ID, phone number, location, contacts, photos, browsing history, or any other personally identifiable information. There are no user accounts in the app. You do not sign in.

---

## Data Stored On Your Device Only

The following data is created and stored locally on your device using Apple's SwiftData framework. It is not transmitted to any server unless you explicitly opt in to anonymous data sharing (see below).

**Workout data** — which exercises you're enrolled in, your current level and day, completed sets and reps, scheduled dates, and streak history. This powers the app's core training experience.

**Sensor recordings** — during active sets (not during rest periods), the app records accelerometer and gyroscope data from your iPhone and/or Apple Watch. These recordings are stored as files on your device. They exist to support current features like set timing and future on-device rep detection. If you have not opted in to data sharing, these files never leave your device.

**Settings and preferences** — rest timer durations, counting mode preferences, notification preferences, and privacy toggles.

---

## Anonymous Data Sharing (Opt-In Only)

Daily Ascent offers two separate, independent opt-in data sharing features. Both are optional and neither requires an account or collects any personally identifiable information.

### Motion Data Sharing

During onboarding, Daily Ascent asks if you'd like to contribute anonymous motion data to help train automatic rep counting models. This defaults to off.

**If you opt in**, the following is uploaded to our servers:

- Accelerometer and gyroscope sensor data recorded during your sets
- The rep count you confirmed for that set
- Exercise type, level, day number, set number, and counting mode
- Device type (iPhone or Apple Watch) and sensor sample rate
- A randomly generated contributor ID (a UUID created on your device — not linked to your Apple ID, name, or any personal information)

**If you also choose to share optional demographics** (presented only to users who opt in to data sharing), these anonymous tags may be included: age range, height range, biological sex, and activity level. All fields are optional. They are linked only to your random contributor ID.

**When uploads happen:** only when your device is connected to Wi-Fi and charging, typically overnight. Uploads are processed via a background task and do not affect your active use of the app.

**Where data is stored:** uploaded data is stored on Supabase servers. It is used solely to train and improve automatic rep counting models for this app.

### Community Benchmarks

Daily Ascent can anonymously compare your training progress against the broader community. This is a separate opt-in from motion data sharing and defaults to on. You can disable it at any time in Settings → Privacy.

**If enabled**, the following is uploaded after each workout:

- A device hash (a one-way SHA-256 hash of a randomly generated UUID stored in your device's Keychain — not linked to your Apple ID, name, or any personal information)
- Exercise ID, level, best set reps, best set duration, session total reps, session duration, and workout hour
- Whether the session was a test day, and the test result if applicable
- Current streak length and number of exercises completed that day
- Lifetime totals: total workouts, total reps, and number of enrolled exercises

**What is NOT uploaded:** your name, Apple ID, email, location, workout schedule, or any information that could identify you. The device hash cannot be reversed to recover your device's UUID.

**What you get in return:** percentile rankings showing where your personal bests and streak stand relative to other users. This data is fetched from the server and cached locally. Rankings require at least 20 users per exercise and level before they are shown.

**When uploads happen:** benchmark data is uploaded immediately after each workout completes. Lifetime totals are synced once per app launch. All uploads are fire-and-forget — failures are silent and do not affect your training experience.

**Where data is stored:** benchmark data is stored on Supabase servers. It is used solely to compute anonymous community distributions for this app.

---

## Your Choices and Controls

**Opt out of motion data sharing at any time.** Settings → Privacy → toggle off "Share anonymous motion data." Future recordings will no longer be uploaded. Recordings already on your device remain local.

**Opt out of community benchmarks at any time.** Settings → Privacy → toggle off "Share anonymous benchmarks." Your workout data will no longer be uploaded after sessions, and community rankings will no longer be displayed.

**Delete your contributed motion data.** Settings → Privacy → "Delete My Data" removes all motion data associated with your contributor ID from our servers.

**Delete your community benchmark data.** Settings → Privacy → "Delete Community Data" removes all benchmark data associated with your device hash from our servers.

**Reset your contributor ID.** Settings → Privacy → "Reset Contributor ID" generates a new random identifier, severing any link between future motion data uploads and past contributions.

**Disable local sensor recording.** If you prefer that the app not record sensor data at all (even locally), you can disable this in Settings. Note that this will prevent future on-device rep detection features from working for you.

---

## HealthKit

Daily Ascent can save your training sessions to Apple Health as workouts (activity type: Functional Strength Training). HealthKit access is requested before your first workout, not at app launch. Daily Ascent reads and writes only workout data. HealthKit data is governed by Apple's privacy controls and is never sent to our servers.

---

## Third-Party Services

Daily Ascent uses Supabase for anonymous sensor data storage (for users who opt in to motion data sharing) and for anonymous community benchmark data (for users who opt in to community benchmarks).

Exercise demonstration videos are embedded from YouTube (google.com/intl/en/policies/privacy). If you play a video, YouTube may collect data about that interaction in accordance with Google's privacy policy. No other third-party services, analytics SDKs, advertising frameworks, or tracking tools are included in the app.

---

## Children's Privacy

Daily Ascent does not knowingly collect data from children under 13. The app does not require an account and does not collect personal information from any user.

---

## Australian Privacy Act

Daily Ascent is developed by an individual developer with no registered business entity and does not generate revenue. It is not currently subject to the Privacy Act 1988 (Cth). Nonetheless, the app is designed to meet its principles — including transparency about data collection, purpose limitation, and user control over their data.

---

## Disclaimer

Daily Ascent is provided free of charge, as-is, with no warranties of any kind. The developer accepts no liability for any loss or damage arising from use of the app. The app does not collect personal information and is not responsible for data stored locally on your device.

---

## Changes to This Policy

If this policy changes, the updated version will be posted at the URL above with a new "Last updated" date. Material changes to data collection practices will be communicated through an in-app notice and may require renewed consent.

---

## Contact

For questions or requests related to your data, contact support@clmartin.dev.
