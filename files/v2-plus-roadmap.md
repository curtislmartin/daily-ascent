# v2+ Roadmap — Daily Ascent Bodyweight Training App

> **Status:** Brainstorm / bullet-point level. Nothing here is specced at implementation level yet.
>
> **Last updated:** 2026-04-03

---

## Feature Backlog

| # | Feature | Notes |
|---|---------|-------|
| 1 | **ML auto rep counting** | Trained from the sensor data users are already collecting. Spans on-device inference, model training from the central dataset, Create ML activity classifiers, and a new calibration UX. Likely needs a dedicated spec document as big as the scheduling engine one. |
| 2 | **Structured interleaving plans** | Smart weekly programming across exercises. Premium feature. |
| 3 | **Advanced analytics** | Trends, comparisons, insights. Premium feature. |
| 4 | **Subscription tier** | StoreKit 2, Sign in with Apple, paywall UX. |
| 5 | **Heart rate-based rest intelligence** | Watch HR data to suggest "you're recovered, go." |
| 6 | **External workout streak awareness** | Query HealthKit so a gym day doesn't break your streak. |
| 7 | **Post-program maintenance mode** | What happens after you pass all L3 tests. |
| 8 | **New exercise content** | Kettlebells, weighted progressions, new programs. |
| 9 | **Today widget** | WidgetKit home screen widget. |
| 10 | **CloudKit sync** | Cross-device progress. Premium feature. |
| 11 | **Training intensity preference** | Rest gap scaling ±1 day. |
| 12 | **Cold storage migration** | Move older ML data to cheaper storage. |

---

## Release Philosophy

Get the core right first. v1.0 and v1.1 ship the fundamentals. The journey from v1.1 to v1.9 is about honing — incremental point releases (v1.2, v1.3, etc.) that each tighten the free experience based on real user feedback. No new feature categories, just making what's there feel great. v1.9 is the destination: the point where the core is solid enough that paid features won't be built on shaky ground. Sensor data also needs this runway to accumulate before ML work makes sense.

---

## Release Groupings

### v1.2 → v1.9 — "The Honing Phase"

Not a single release — a series of point releases from where we are now (v1.1) to the polish destination (v1.9). Each release addresses whatever most needs attention: bugs, UX friction, performance, feel. The following features land across these releases as they become ready:

- External workout streak awareness (HealthKit gym-day awareness)
- Today widget (WidgetKit home screen widget)
- Watch complications (WidgetKit complications: accessoryCircular, accessoryCorner, accessoryRectangular, accessoryInline — shows due/completed count or rest day)
- Training intensity preference (rest gap scaling ±1 day)
- Post-program maintenance mode (what happens after all L3 tests)

v1.9 is the gate. The app should feel complete and polished for free users before anything behind a paywall ships.

### v2 — "The Money Release"

The subscription lands. Free users see enough value to pay. No ML yet — keep the scope tight.

- Subscription tier (StoreKit 2, Sign in with Apple, paywall UX)
- Advanced analytics (trends, comparisons, insights — premium)
- CloudKit sync (cross-device progress — premium)
- Structured interleaving plans (smart weekly programming — premium)

### v3 — "The Intelligence Release"

ML and AI features ship once there's enough accumulated sensor data to train meaningful models.

- ML auto rep counting (on-device inference, Create ML activity classifiers, calibration UX)
- Heart rate-based rest intelligence (Watch HR → recovery suggestions)
- New exercise content (kettlebells, weighted progressions, new programs)
- Cold storage migration (move older ML data to cheaper storage)

### Unscheduled

(Nothing currently — all features assigned to a release.)

---

## Complexity Notes

The **ML auto rep counting pipeline** is by far the most complex feature. It spans:

- On-device inference (Core ML)
- Model training from the central dataset
- Create ML activity classifiers
- New UX for calibration

This alone probably needs a dedicated spec document comparable in scope to `scheduling-engine.md`.
