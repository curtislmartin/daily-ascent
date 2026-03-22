# Daily Ascent — Privacy Policy

> **Effective date:** [INSERT DATE BEFORE SUBMISSION]
>
> **Last updated:** 2026-03-16
>
> **Developer:** Curtis Martin — [INSERT BUSINESS NAME IF REGISTERED, OTHERWISE "Curtis Martin"]
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

During onboarding, Daily Ascent asks if you'd like to contribute anonymous motion data to help train automatic rep counting models. This is entirely optional and defaults to off.

**If you opt in**, the following is uploaded to our servers:

- Accelerometer and gyroscope sensor data recorded during your sets
- The rep count you confirmed for that set
- Exercise type, level, day number, set number, and counting mode
- Device type (iPhone or Apple Watch) and sensor sample rate
- A randomly generated contributor ID (a UUID created on your device — not linked to your Apple ID, name, or any personal information)

**If you also choose to share optional demographics** (presented only to users who opt in to data sharing), these anonymous tags may be included: age range, height range, biological sex, and activity level. All fields are optional. They are linked only to your random contributor ID.

**What is NOT uploaded:** your name, Apple ID, email, location, workout schedule, streak data, or any information that could identify you.

**When uploads happen:** only when your device is connected to Wi-Fi and charging, typically overnight. Uploads are processed via a background task and do not affect your active use of the app.

**Where data is stored:** uploaded data is stored on Supabase servers. It is used solely to train and improve automatic rep counting models for this app.

---

## Your Choices and Controls

**Opt out of data sharing at any time.** Settings → Privacy → toggle off "Share anonymous motion data." Future recordings will no longer be uploaded. Recordings already on your device remain local.

**Delete your contributed data.** Settings → Privacy → "Delete My Data" removes all data associated with your contributor ID from our servers.

**Reset your contributor ID.** Settings → Privacy → "Reset Contributor ID" generates a new random identifier, severing any link between future uploads and past contributions.

**Disable local sensor recording.** If you prefer that the app not record sensor data at all (even locally), you can disable this in Settings. Note that this will prevent future on-device rep detection features from working for you.

---

## HealthKit

Daily Ascent can save your training sessions to Apple Health as workouts (activity type: Functional Strength Training). HealthKit access is requested before your first workout, not at app launch. Daily Ascent reads and writes only workout data. HealthKit data is governed by Apple's privacy controls and is never sent to our servers.

---

## Third-Party Services

Daily Ascent uses Supabase for anonymous sensor data storage (for users who opt in to sharing). No other third-party services, analytics SDKs, advertising frameworks, or tracking tools are included in the app.

---

## Children's Privacy

Daily Ascent does not knowingly collect data from children under 13. The app does not require an account and does not collect personal information from any user.

---

## Australian Privacy Act

While Daily Ascent may not currently meet the turnover threshold requiring compliance with the Privacy Act 1988 (Cth), the app is designed to meet its principles from day one — including transparency about data collection, purpose limitation, and user control over their data.

---

## Changes to This Policy

If this policy changes, the updated version will be posted at the URL above with a new "Last updated" date. Material changes to data collection practices will be communicated through an in-app notice and may require renewed consent.

---

## Contact

For questions or requests related to your data, contact support@clmartin.dev.
