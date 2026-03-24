# ML for Rep Counting — Overview

## The Problem

Detect when a rep happens using accelerometer and gyroscope data (IMU sensors on iPhone/Watch). This is a **time-series peak detection problem** — recognising patterns in motion data that correspond to a completed rep.

---

## Two-Phase Reality

### Phase 1: Data First

The sensor data your app collects is the foundation for everything. You need:

- Raw accelerometer/gyroscope streams timestamped during real workouts
- Labels: exercise type, rep count, user
- Volume: ~50–200 labeled sessions per exercise before ML becomes meaningful

**You don't have data yet, so ML work can't really start.** This is normal — you build the data flywheel first by shipping the app and getting testers using it.

### Phase 2: Offline ML (separate from app development)

This happens on your Mac or in a cloud notebook — not in Xcode. Tools:

- **Python** (numpy, pandas, matplotlib) — explore and visualise sensor data
- **Apple Create ML** (Activity Classifier template) — designed exactly for this use case, drag-and-drop friendly, outputs a `.mlmodel` file ready for Core ML
- **scikit-learn** — if you want more control than Create ML offers

> **Best starting point for zero ML experience:** Create ML's Activity Classifier. It handles sliding windows, feature extraction, and model training with a GUI. No code required to get a first result.

---

## Practical Roadmap

| Timeframe | What to do |
|---|---|
| Now | Ship app, start collecting labeled sensor data from testers |
| 2–3 months | First real dataset (if you have active TestFlight testers) |
| 3–6 months | Explore data, run first Create ML experiments |
| 6+ months | Integrate Core ML model, enable real-time counting in app |

---

## What to Do Right Now

1. **Verify sensor recording works** — confirm data is uploading to Supabase with correct labels (exercise type, rep count)
2. **Check `files/backend-api.md`** — ensure the upload schema captures everything needed for training later
3. **Don't write any ML code yet** — there's nothing to train on

---

## Key Insight

The data collection pipeline already planned is exactly the right call. ML is genuinely the **last** thing to build, not the first. The app needs to exist and have real users generating labeled workout data before any meaningful ML work can begin.
