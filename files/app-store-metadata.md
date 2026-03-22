# Daily Ascent — App Store Metadata

> **Purpose:** Draft metadata for App Store Connect submission. Review and adjust before submitting.
>
> **Last updated:** 2026-03-22

---

## App Identity

| Field | Value | Notes |
|---|---|---|
| **App name** | Daily Ascent | 30 char max. Check availability in App Store Connect. |
| **Subtitle** | Progressive Bodyweight Program | 30 char max. |
| **Bundle ID** | [INSERT — e.g. dev.clmartin.inch] | Must match Xcode project. |
| **SKU** | inch-bodyweight | Internal reference only, not public. |
| **Primary language** | English (Australia) | |
| **Category** | Health & Fitness | |
| **Secondary category** | — | Optional. Could use "Lifestyle." |
| **Content rights** | Does not contain third-party content | |

---

## App Store Description

> **Promotional text** (170 chars, can be updated without a new build):
>
> Structured bodyweight programs that adapt to your schedule. Six exercises, three levels each, zero guesswork.

> **Description** (4000 chars max):
>
> Build a real bodyweight training habit — and actually get stronger.
>
> Daily Ascent gives you a structured programme across six exercises, each with three progressive levels. Follow your prescribed sets and reps, pass a max-rep test, and unlock the next level. No guesswork.
>
> SIX EXERCISES, THREE LEVELS EACH
> Push-Ups, Squats, Sit-Ups, Pull-Ups, Glute Bridges, and Dead Bugs — from beginner to advanced, with every training day mapped out.
>
> SMART SCHEDULING
> Rest days are calculated automatically based on when you actually trained — not when you planned to. Miss a session? Your schedule shifts. No lost progress.
>
> TEST DAYS THAT MEAN SOMETHING
> Each level ends with a max-rep test. Pass it and move up. No guesswork, no self-assessment.
>
> TRAIN FROM YOUR WRIST
> Pair with Apple Watch to count reps, time rest periods, and log sessions without touching your phone.
>
> YOUR PROGRESS, YOUR DATA
> Workout history, streak tracking, and weekly volume charts help you see your progress over time. All your data lives on your device. Nothing is uploaded without your explicit opt-in consent.
>
> CONTRIBUTE TO SMARTER TRAINING
> Optionally share anonymous motion sensor data to help build automatic rep counting. No account required. No personal information collected. You can delete your contributions at any time.

> **Keywords** (100 chars, comma-separated):
>
> home,reps,sets,strength,beginner,routine,core,abs,plan,daily,level,pushup,squat,exercise,habit

---

## App Review Information

| Field | Value |
|---|---|
| **Contact first name** | Curtis |
| **Contact last name** | Martin |
| **Contact email** | support@clmartin.dev |
| **Contact phone** | [INSERT PHONE NUMBER] |
| **Demo account** | Not required — no accounts in the app |
| **Review notes** | See below |

**Review notes for Apple:**

> Daily Ascent is a bodyweight training app with no user accounts and no login. All features are accessible immediately after choosing exercises during onboarding.
>
> The app requests the following permissions, each at the point of use (not at launch):
> - HealthKit: requested before the first workout is saved, to log training sessions as workouts.
> - Motion & Fitness: used to record accelerometer/gyroscope data during sets for future rep detection features.
> - Notifications: requested after the first completed workout, for training reminders and streak protection.
>
> The app includes an optional data-sharing consent screen during onboarding. Users can opt in to uploading anonymous sensor data. The toggle defaults to OFF. Data is never linked to any personal identity.
>
> The privacy policy is hosted at: https://clmartin.dev/daily-ascent/privacy

---

## Privacy Nutrition Label

Declare the following in App Store Connect under "App Privacy":

| Data type | Collected | Linked to identity | Used for tracking | Purpose |
|---|---|---|---|---|
| Fitness & Exercise (workout type, reps, sets) | Yes | No | No | App Functionality |
| Sensor Data (accelerometer, gyroscope) | Yes — only if user opts in to sharing | No | No | App Functionality, Product Improvement |
| Body (age range, height range, biological sex) | Yes — only if user opts in AND chooses to provide | No | No | Product Improvement |
| Other Diagnostic Data (device type, sample rate, activity level) | Yes — only if user opts in | No | No | Product Improvement |

**Data NOT collected:** name, email, user ID, location, purchases, browsing history, contacts, photos, search history, identifiers, or any data linked to identity.

If the user declines data sharing, sensor data is processed entirely on-device and does not need to be declared.

---

## Age Rating

| Question | Answer |
|---|---|
| Cartoon or fantasy violence | None |
| Realistic violence | None |
| Sexual content | None |
| Profanity | None |
| Drug/alcohol/tobacco reference | None |
| Simulated gambling | None |
| Horror/fear themes | None |
| Medical/treatment information | None |
| Unrestricted web access | No |

**Expected rating:** 4+ (all ages)

---

## Pricing

| Field | Value |
|---|---|
| **Price** | Free |
| **In-App Purchases** | None (v1) |
| **Territories** | All territories (or Australia-only for initial launch — your call) |

---

## Screenshots Required

Screenshots must be provided for the following device sizes. Capture these once the UI is stable.

| Device | Size | Required |
|---|---|---|
| iPhone 6.9" (16 Pro Max) | 1320 × 2868 | Yes — covers 6.7" and 6.9" |
| iPhone 6.3" (16 Pro) | 1206 × 2622 | Yes — covers 6.1" and 6.3" |
| iPad Pro 13" | 2064 × 2752 | Only if app supports iPad |

Minimum 3 screenshots, maximum 10 per device. Recommended set: Today dashboard, Workout session (both counting modes), Program overview, Test day pass, Apple Watch workout.

---

## App Store Icon

Already exists at `icon/AppIcon.appiconset.zip`. Ensure the 1024×1024 version is included — App Store Connect requires it.
