# Community Benchmarks — Feature Spec

> Anonymous, percentile-based community features that let users see where they
> stand without ever identifying who they are.

## Design Principles

1. **Zero PII** — no accounts, no emails, no names, no Apple IDs
2. **One-way identity** — a SHA-256 hash of a random Keychain UUID; irreversible
3. **Insert-only RLS** — devices can submit benchmarks but never read individual rows
4. **Read from aggregates only** — users see pre-computed distributions, not raw data
5. **Auto-expiring** — raw records decay and delete; only aggregates persist
6. **Fire-and-forget uploads** — the app works fully offline; uploads are opportunistic
7. **No leaderboards** — distributions and percentiles only; no ranked lists

---

## Anonymous Identity

- On first community upload, check Keychain for a stored UUID
- If none exists (new install or existing user updating to this version), generate `UUID().uuidString` and store in **Keychain**
- Before transmitting, compute `SHA256(keychain_uuid)` → `device_hash`
- The raw UUID never leaves the device
- On-device the user sees "You" markers on distribution charts — no alias needed
- If the Keychain entry is lost (device wipe), a new identity is generated — old data ages out naturally

**Existing users (app already launched):**

The Keychain UUID is generated lazily — not at app launch, but on first community
feature interaction. This means:
- Users who update to the version with community features get a UUID generated
  transparently the first time a benchmark is uploaded
- No migration step needed — there's nothing to migrate from
- Their historical workout data (stored locally in SwiftData) is used to compute
  their initial personal bests, which get uploaded on the first post-update
  workout completion
- The device_hash is deterministic for a given Keychain UUID, so it remains
  stable across app restarts

Implementation:
```swift
enum CommunityIdentity {
    private static let keychainService = "daily-ascent-community-id"
    private static let keychainAccount = "device_uuid"

    /// Returns the stable device hash, generating a Keychain UUID if needed.
    static var deviceHash: String {
        if let existing = readFromKeychain() {
            return SHA256.hash(data: Data(existing.utf8)).hexString
        }
        let newUUID = UUID().uuidString
        saveToKeychain(newUUID)
        return SHA256.hash(data: Data(newUUID.utf8)).hexString
    }
}
```

---

## Privacy & Legal

**Why this avoids GDPR/CCPA/ePrivacy triggers:**

- GDPR Recital 26: "principles of data protection should therefore not apply to anonymous information, namely information which does not relate to an identified or identifiable natural person"
- `device_hash` is a hash of a random UUID — not derived from any device identifier, Apple ID, or personal attribute
- No IP addresses stored — Edge Function strips client IP before writing
- No behavioural fingerprinting — individual records can't reconstruct a person's identity
- Workout hour is stored as 0–23 (no timezone, no location)
- Workout date enables holiday detection but reveals nothing personal

**Delete My Data button (Settings → Community):**

Include it despite not being legally required. Reasons:
- App Store review sometimes asks for it
- Good UX — users who want to opt out fully can
- Trivial to implement: `DELETE FROM exercise_benchmarks WHERE device_hash = ?` (same for streak/lifetime tables)
- No confirmation theatre needed — the data is anonymous and auto-expires anyway

**CRITICAL: Scope of deletion**

The Delete My Data button **only deletes community benchmark data**. It must NOT
touch sensor/motion data uploads. Sensor data lives in a completely separate
Supabase schema, uses a different anonymous identifier, and has its own consent
flow (motionDataUploadConsented). These two systems are architecturally
independent:

| | Community Benchmarks | Sensor Data |
|---|---|---|
| Identity | SHA-256 of Keychain UUID | Session-based anonymous ID |
| Consent | Default on (anonymous) | Explicit opt-in toggle |
| Data type | Aggregate performance stats | Raw accelerometer recordings |
| Delete button | Yes (community section) | No — already anonymised, cannot be traced back |
| Purpose | Percentile distributions | Future ML rep-counting model |

The UI must label the button clearly: "Delete Community Data" — not "Delete My
Data" generically. This prevents user (and Apple reviewer) confusion about
whether it covers sensor uploads.

If a reviewer asks about sensor data deletion: the response is that sensor data
is anonymous at the point of collection (no device identifier, no user
identifier, no way to trace recordings back to a person), so there is no "my
data" to delete.

**Privacy policy update:**

State that benchmark data is:
- Anonymous and not linked to any account or identity
- Used solely to compute aggregate community statistics
- Automatically deleted after 90 days
- Deletable on demand via in-app button

Also highlight in the privacy policy:
- The app is **offline-first** — all workout data lives on-device and in iCloud
- Community uploads are optional, anonymous, and contain no identifying information
- Sensor data (if consented) is anonymised at collection time with no reversible identifier

---

## What Gets Uploaded

### After each exercise completion

| Field | Type | Purpose |
|---|---|---|
| device_hash | text | Anonymous identity |
| exercise_id | text | e.g. "push_ups" |
| level | smallint | 1, 2, or 3 |
| best_set_reps | int | Highest single set in this session (rep-based exercises) |
| best_set_duration | int | Longest hold in seconds (timed exercises, i.e. plank) |
| session_total_reps | int | Sum of all set reps in this session |
| session_duration_secs | int | Wall-clock time from first set start to completion |
| workout_hour | smallint | 0–23, local device time (no timezone sent) |
| workout_date | date | For holiday/seasonal detection |
| is_test_day | bool | Whether this was a max-rep test |
| test_reps | int? | If test day, the test result |
| recorded_at | timestamptz | Server-side timestamp |

### After daily streak check-in

| Field | Type | Purpose |
|---|---|---|
| device_hash | text | Anonymous identity |
| streak_days | int | Current streak length |
| exercises_completed_today | smallint | How many exercises done today |
| recorded_at | timestamptz | Server-side timestamp |

### Periodic sync (daily, on app foreground)

| Field | Type | Purpose |
|---|---|---|
| device_hash | text | Anonymous identity |
| total_workouts | int | All-time workout count |
| total_lifetime_reps | int | All-time rep count across all exercises |
| enrolled_exercise_count | smallint | How many exercises currently enrolled |
| recorded_at | timestamptz | Server-side timestamp |

---

## Supabase Schema

```sql
-- ── Raw benchmark records ───────────────────────────────────────────────────

create table exercise_benchmarks (
    id                    uuid primary key default gen_random_uuid(),
    device_hash           text not null,
    exercise_id           text not null,
    level                 smallint not null,
    best_set_reps         int,
    best_set_duration     int,
    session_total_reps    int,
    session_duration_secs int,
    workout_hour          smallint not null,
    workout_date          date not null,
    is_test_day           boolean not null default false,
    test_reps             int,
    recorded_at           timestamptz not null default now()
);

-- Upsert key: one record per device per exercise per level
-- Update if the new value is better (handled in Edge Function)
create unique index idx_exercise_bench_unique
    on exercise_benchmarks (device_hash, exercise_id, level);

create table streak_benchmarks (
    id                          uuid primary key default gen_random_uuid(),
    device_hash                 text not null unique,
    streak_days                 int not null,
    exercises_completed_today   smallint not null default 0,
    recorded_at                 timestamptz not null default now()
);

create table lifetime_benchmarks (
    id                      uuid primary key default gen_random_uuid(),
    device_hash             text not null unique,
    total_workouts          int not null default 0,
    total_lifetime_reps     int not null default 0,
    enrolled_exercise_count smallint not null default 0,
    recorded_at             timestamptz not null default now()
);

-- ── Pre-computed distributions (refreshed by cron) ──────────────────────────

-- Fine-grained percentiles: every 5th from P5 to P95 (19 breakpoints)
-- This lets the client interpolate smoothly so users see "better than 63%"
-- instead of jumping between "better than 50%" and "better than 75%"
create table exercise_distributions (
    exercise_id   text not null,
    level         smallint not null,
    metric_type   text not null,  -- 'best_set_reps', 'best_set_duration', 'session_total', 'test_reps'
    p5            int not null,
    p10           int not null,
    p15           int not null,
    p20           int not null,
    p25           int not null,
    p30           int not null,
    p35           int not null,
    p40           int not null,
    p45           int not null,
    p50           int not null,
    p55           int not null,
    p60           int not null,
    p65           int not null,
    p70           int not null,
    p75           int not null,
    p80           int not null,
    p85           int not null,
    p90           int not null,
    p95           int not null,
    total_users   int not null,
    updated_at    timestamptz not null default now(),
    primary key (exercise_id, level, metric_type)
);

create table streak_distributions (
    id          int primary key default 1,  -- singleton row
    p5          int not null,
    p10         int not null,
    p15         int not null,
    p20         int not null,
    p25         int not null,
    p30         int not null,
    p35         int not null,
    p40         int not null,
    p45         int not null,
    p50         int not null,
    p55         int not null,
    p60         int not null,
    p65         int not null,
    p70         int not null,
    p75         int not null,
    p80         int not null,
    p85         int not null,
    p90         int not null,
    p95         int not null,
    total_users int not null,
    updated_at  timestamptz not null default now()
);

create table workout_hour_distribution (
    workout_hour  smallint primary key,  -- 0–23
    user_count    int not null,
    updated_at    timestamptz not null default now()
);

create table lifetime_distributions (
    metric_type   text primary key,  -- 'total_workouts', 'total_lifetime_reps'
    p5            int not null,
    p10           int not null,
    p15           int not null,
    p20           int not null,
    p25           int not null,
    p30           int not null,
    p35           int not null,
    p40           int not null,
    p45           int not null,
    p50           int not null,
    p55           int not null,
    p60           int not null,
    p65           int not null,
    p70           int not null,
    p75           int not null,
    p80           int not null,
    p85           int not null,
    p90           int not null,
    p95           int not null,
    total_users   int not null,
    updated_at    timestamptz not null default now()
);

create table holiday_counts (
    holiday_key   text primary key,  -- e.g. 'christmas_2026', 'new_year_2027'
    workout_count int not null,
    updated_at    timestamptz not null default now()
);

-- ── RLS ─────────────────────────────────────────────────────────────────────

-- Raw tables: insert-only, no select, no update, no delete from client
alter table exercise_benchmarks enable row level security;
alter table streak_benchmarks enable row level security;
alter table lifetime_benchmarks enable row level security;

create policy "insert_only" on exercise_benchmarks for insert with check (true);
create policy "insert_only" on streak_benchmarks for insert with check (true);
create policy "insert_only" on lifetime_benchmarks for insert with check (true);

-- Distribution tables: read-only from client
alter table exercise_distributions enable row level security;
alter table streak_distributions enable row level security;
alter table workout_hour_distribution enable row level security;
alter table lifetime_distributions enable row level security;
alter table holiday_counts enable row level security;

create policy "read_only" on exercise_distributions for select using (true);
create policy "read_only" on streak_distributions for select using (true);
create policy "read_only" on workout_hour_distribution for select using (true);
create policy "read_only" on lifetime_distributions for select using (true);
create policy "read_only" on holiday_counts for select using (true);
```

---

## Anti-Cheating

### 1. Server-side plausibility bounds

Validated in the Edge Function before insert. Reject silently (200 OK, just don't write).

| Exercise | Max credible set reps | Max credible duration |
|---|---|---|
| push_ups | 150 | — |
| squats | 200 | — |
| pull_ups | 60 | — |
| dips | 100 | — |
| rows | 100 | — |
| hip_hinge | 100 | — |
| spinal_extension | 100 | — |
| dead_bugs | 100 | — |
| plank | — | 600s (10 min) |

These are generous. A world-class athlete doing bodyweight work would still fall under them.
As the app's level progressions evolve, bump ceilings accordingly.

### 2. Tempo plausibility

If `session_duration_secs` is provided, check reps-per-second:
- General exercises: reject if > 1 rep/second average
- Pull-ups, dips: reject if > 0.5 rep/second average
- This catches "50 reps in 3 seconds" type fabrication

**Important edge case — retroactive set confirmation:**

Users sometimes need to go back and quickly check off sets they've already
completed (e.g. after an app error or interruption). In this scenario:
- The actual reps are legitimate
- But session_duration_secs will be very short (a few seconds of tapping)

To handle this, the tempo check uses **per-set duration** (time from set start
to set end), not total session wall-clock time. Each set already records its
own start/end timestamps in the workout flow:
- Post-set confirmation mode: skip tempo check entirely — the user already
  did the reps and is just entering the count
- Real-time mode: set duration = time between "Start Set" and "Done" taps
- Metronome mode: set duration = metronome running time (inherently paced)
- Timed mode: set duration = hold duration (inherently paced)

This means: if a user taps through post-set confirmations quickly, their reps
still get uploaded. The tempo check only catches impossible claims in modes
where the app controls the timer.

### 3. Percentile trimming

When computing distributions, exclude the top and bottom 2% of values.
Outliers (whether cheaters or data errors) don't shift the percentiles real users see.

### 4. Rate limiting

- One upsert per exercise per level per device_hash per calendar day
- One streak upsert per device_hash per day
- One lifetime sync per device_hash per day
- Enforced in Edge Function; excess calls get 200 OK but no write

### 5. Freshness decay

- Records not updated in 60 days: excluded from distribution calculations
- Records not updated in 90 days: deleted by Supabase pg_cron job
- Distributions are recomputed daily; stale data fades out naturally

### 6. Future: sensor-verified benchmarks

For consenting users, the uploaded sensor recording could be cross-referenced
to validate rep counts. Flag these as "verified" and optionally weight them
higher in distribution calculations. Not needed for v1.

---

## All Possible Distributions & Community Achievements

### Performance Distributions

These show users where their numbers land relative to the community.
Each is computed per exercise and per level.

| Distribution | Metric | What it shows |
|---|---|---|
| **Best Set** | best_set_reps | "Your best set of 42 push-ups is better than 78% of Level 2 users" |
| **Best Hold** | best_set_duration | "Your 90-second plank is longer than 65% of Level 1 users" (plank only) |
| **Session Volume** | session_total_reps | "Your total of 120 reps this session beats 55% of Level 2 users" |
| **Test Day Score** | test_reps | "Your max-rep test of 35 is in the top 30% for Level 1 push-ups" |

### Streak Distributions

| Distribution | Metric | What it shows |
|---|---|---|
| **Current Streak** | streak_days | "Your 15-day streak is longer than 85% of active users" |

### Lifetime Distributions

| Distribution | Metric | What it shows |
|---|---|---|
| **Total Workouts** | total_workouts | "You've completed more workouts than 70% of users" |
| **Total Lifetime Reps** | total_lifetime_reps | "You've done more total reps than 62% of users" |

### Time-of-Day Distribution

| Distribution | Metric | What it shows |
|---|---|---|
| **Workout Hour** | workout_hour | Bar chart: "Most users work out at 7am. You prefer 6pm." |

Not a percentile — this is a histogram. Shows when the community works out
and where the user's pattern fits. Fun, non-competitive, creates a sense of
shared routine.

---

### Community Achievements

Unlocked and shown in the Community section of the Achievements view.
These use threshold-based triggers, not leaderboard positions.

#### Percentile-Based Achievements

Earned when a user's personal best crosses a percentile threshold.
Re-evaluated whenever new distributions are fetched.

| Achievement | Trigger | Icon idea |
|---|---|---|
| **Top Half** | Any exercise metric ≥ P50 | 🏔️ Basecamp |
| **Upper Quarter** | Any exercise metric ≥ P75 | 🏔️ High Camp |
| **Top 10%** | Any exercise metric ≥ P90 | 🏔️ Summit |
| **Iron Streak** | Streak ≥ P90 | 🔗 |
| **Volume Machine** | Lifetime reps ≥ P90 | 🏋️ |
| **Dedicated** | Total workouts ≥ P75 | 📅 |
| **Veteran** | Total workouts ≥ P90 | 🎖️ |

These are per-exercise, so a user could earn "Summit" for push-ups but only
"Basecamp" for pull-ups. Creates granular, meaningful progress.

#### Time-of-Day Achievements

Earned based on accumulated workout_hour data.

| Achievement | Trigger | Flavour text |
|---|---|---|
| **Early Bird** | 10+ workouts started before 6am | "The world is still sleeping" |
| **Dawn Patrol** | 10+ workouts started before 7am | "First light, first rep" |
| **Lunch Break Legend** | 10+ workouts between 12pm–1pm | "Gains between meetings" |
| **Night Owl** | 10+ workouts started after 9pm | "The gym never closes" |
| **5am Club** | 10+ workouts started before 5am | "Discipline has an alarm clock" |
| **Sunrise to Sunset** | Workouts logged in every 4-hour block (0-3, 4-7, 8-11, 12-15, 16-19, 20-23) | "Any hour is workout hour" |

Count threshold (10) prevents a single accidental early alarm from triggering.
These can be computed client-side from local workout history — no server data needed.

#### Holiday Achievements

Earned by completing a workout on a specific date. Detected server-side from
workout_date. The server increments holiday_counts so users can see
"247 people worked out on Christmas 2026."

| Achievement | Date(s) | Flavour text |
|---|---|---|
| **New Year, New You** | Jan 1 | "Starting the year right" |
| **Valentine's Flex** | Feb 14 | "Self-love is the best love" |
| **Leap Day Legend** | Feb 29 | "Once every four years — you showed up" |
| **St. Patrick's Strength** | Mar 17 | "Lucky? No, disciplined" |
| **Easter Riser** | Easter Sunday (variable) | "Risen and repping" |
| **Independence Rep** | Jul 4 | "Freedom to push harder" |
| **Halloween Grind** | Oct 31 | "No rest for the wicked" |
| **Turkey Burner** | US Thanksgiving (variable) | "Earning the second plate" |
| **Christmas Gains** | Dec 25 | "Unwrapping potential" |
| **New Year's Eve Send-Off** | Dec 31 | "Finishing strong" |

Show the community count: "You and 183 others worked out on Christmas Day."
This creates a warm, anonymous sense of solidarity.

Holiday detection runs server-side. For variable-date holidays (Easter,
Thanksgiving), use a lookup table or compute algorithmically.

#### Seasonal Achievements

Earned over longer periods. Computed from workout_date ranges.

| Achievement | Trigger | Flavour text |
|---|---|---|
| **January Persistence** | ≥ 20 workouts in January | "Most resolutions don't survive January. Yours did." |
| **Summer Shape-Up** | ≥ 50 workouts in Jun–Aug | "Summer body, built by summer" |
| **Winter Warrior** | ≥ 40 workouts in Dec–Feb | "Cold outside, fire inside" |
| **Year-Round** | ≥ 1 workout in every calendar month of a year | "No off-season" |

These can be computed client-side from local history.

#### Playful / Quirky Achievements

Fun milestones that create delight without competitive pressure.

| Achievement | Trigger | Flavour text |
|---|---|---|
| **Century Club** | 100 total workouts | "Triple digits" |
| **Thousand Repper** | 1,000 lifetime reps of any single exercise | "A thousand times, and counting" |
| **Ten Thousand** | 10,000 total lifetime reps (all exercises) | "Dedication has a number" |
| **Full Roster** | Enrolled in all 9 exercises | "No muscle left behind" |
| **Perfect Week** | Completed every scheduled workout in a 7-day span | "Seven for seven" |
| **Triple Threat** | 3 different exercises completed in one day | "Variety is strength" |
| **Five-a-Day** | 5 different exercises in one day | "Overachiever (complimentary)" |
| **Plank Minutes** | 10 cumulative minutes of plank holds | "600 seconds of character" |
| **Metronome Master** | 100 metronome-guided sets completed | "Rhythm and reps" |
| **Test Day Ace** | Passed 3 max-rep tests in a row | "Clutch performer" |
| **Level Up Trifecta** | Reached Level 2 in 3 different exercises | "Broad-based strength" |
| **Maxed Out** | Reached Level 3 in any exercise | "Peak progression" |
| **Grand Master** | Reached Level 3 in all 9 exercises | "The summit of summits" |
| **Friday the 13th** | Worked out on a Friday the 13th | "Superstition? Never heard of it." |
| **Palindrome Day** | Worked out on a palindrome date (e.g. 2026-02-06 → 60202026... hmm, rare) | "Forwards, backwards, always moving" |
| **Groundhog Day** | Same exercise, same reps, two days in a row | "Didn't he do this yesterday?" |

---

## UI Integration

### Community Stats View

A dedicated view accessible from the tab bar or a section in the existing
stats/progress area. Similar pattern to the Achievements view.

**Sections:**

1. **Your Rankings** — per-exercise percentile cards
   - Card per enrolled exercise showing best set percentile
   - Tap to expand: session volume percentile, test score percentile
   - Simple bar or dot-on-a-line showing P25/P50/P75/P90 with "You" marker

2. **Streak** — your streak vs community
   - "Your 15-day streak is longer than 85% of active users"
   - Mini distribution visualization

3. **When We Work Out** — time-of-day histogram
   - Bar chart of community workout hours
   - User's most common hour highlighted
   - Pure delight, no competition

4. **Community Pulse** — lightweight engagement stats
   - "247 workouts logged today"
   - "38 people worked out on Easter"
   - Refreshed from holiday_counts and a simple daily counter

### Achievements View — Community Section

Add a "Community" category tab/section to the existing Achievements view.

**Sub-sections within Community:**

- **Rankings** — percentile-based achievements (Top Half, Upper Quarter, Top 10%)
- **Time & Season** — Early Bird, Night Owl, holiday achievements, seasonal
- **Milestones** — Century Club, Thousand Repper, etc.

Each achievement shows:
- Icon (SF Symbol or custom)
- Title and flavour text
- Locked/unlocked state
- Date earned (if unlocked)
- For community-count achievements: "You and 183 others"

### Personal Best Notification

**Context:** The full-screen personal best overlay was previously removed because
it fired after every exercise completion and disrupted the user flow. Community
percentiles must not reintroduce that problem.

**Approach:** Use a non-disruptive toast/banner that appears briefly at the top
of the exercise completion screen. It auto-dismisses after ~4 seconds without
requiring user interaction.

```
┌──────────────────────────────────────┐
│  ↑ New PB: 42 push-ups              │
│    Better than 78% of Level 2 users  │
└──────────────────────────────────────┘
```

- Slides in from the top, slides out after 4 seconds
- No tap required to dismiss — doesn't block the completion screen
- Only shown when a personal best is actually broken (not every workout)
- The achievement itself (with the rep count) is still earned and visible
  in the Achievements view regardless of whether the toast was seen
- If the community data hasn't been fetched yet (offline, first upload, or
  below the minimum user threshold), show just "New PB: 42 push-ups" without
  the percentile line

---

## Upload & Sync Flow

### Exercise completion (immediate)

```
1. User finishes exercise → app checks for personal best
2. If new best (or first upload for this exercise/level):
   POST to Edge Function: /community/exercise-benchmark
   Body: { device_hash, exercise_id, level, best_set_reps, ... }
3. Edge Function validates plausibility → upserts
4. Fire-and-forget — failure logged locally, retried next session
```

### Streak check-in (immediate)

```
1. Streak recalculated locally (already happens)
2. POST to Edge Function: /community/streak-benchmark
   Body: { device_hash, streak_days, exercises_completed_today }
3. Upsert on device_hash
```

### Periodic sync (daily, on foreground)

```
1. App enters foreground → check if 24h since last sync
2. POST to Edge Function: /community/lifetime-sync
   Body: { device_hash, total_workouts, total_lifetime_reps, enrolled_exercise_count }
3. Upsert on device_hash
```

### Distribution fetch (read path)

```
1. On Community Stats view load, or pull-to-refresh
2. GET from distributions tables (public read-only RLS)
3. Cache locally in UserDefaults or a SwiftData entity
4. Refresh at most once per day
5. Compare user's local personal bests against percentile breakpoints
```

---

## Data Retention & Cleanup

**Supabase pg_cron jobs (daily):**

```sql
-- Recompute distributions (exclude stale records and trim outliers)
-- Run as a Postgres function called by pg_cron

-- Delete records not updated in 90 days
delete from exercise_benchmarks where recorded_at < now() - interval '90 days';
delete from streak_benchmarks where recorded_at < now() - interval '90 days';
delete from lifetime_benchmarks where recorded_at < now() - interval '90 days';
```

**Distribution recomputation (daily):**

```sql
-- Example for exercise_distributions (19 breakpoints for smooth interpolation)
insert into exercise_distributions (
    exercise_id, level, metric_type,
    p5, p10, p15, p20, p25, p30, p35, p40, p45, p50,
    p55, p60, p65, p70, p75, p80, p85, p90, p95,
    total_users
)
select
    exercise_id, level, 'best_set_reps',
    percentile_cont(0.05) within group (order by best_set_reps),
    percentile_cont(0.10) within group (order by best_set_reps),
    percentile_cont(0.15) within group (order by best_set_reps),
    percentile_cont(0.20) within group (order by best_set_reps),
    percentile_cont(0.25) within group (order by best_set_reps),
    percentile_cont(0.30) within group (order by best_set_reps),
    percentile_cont(0.35) within group (order by best_set_reps),
    percentile_cont(0.40) within group (order by best_set_reps),
    percentile_cont(0.45) within group (order by best_set_reps),
    percentile_cont(0.50) within group (order by best_set_reps),
    percentile_cont(0.55) within group (order by best_set_reps),
    percentile_cont(0.60) within group (order by best_set_reps),
    percentile_cont(0.65) within group (order by best_set_reps),
    percentile_cont(0.70) within group (order by best_set_reps),
    percentile_cont(0.75) within group (order by best_set_reps),
    percentile_cont(0.80) within group (order by best_set_reps),
    percentile_cont(0.85) within group (order by best_set_reps),
    percentile_cont(0.90) within group (order by best_set_reps),
    percentile_cont(0.95) within group (order by best_set_reps),
    count(distinct device_hash)
from exercise_benchmarks
where best_set_reps is not null
  and recorded_at > now() - interval '60 days'
  -- Trim top/bottom 2%
  and best_set_reps between
      (select percentile_cont(0.02) within group (order by best_set_reps)
       from exercise_benchmarks eb2
       where eb2.exercise_id = exercise_benchmarks.exercise_id
         and eb2.level = exercise_benchmarks.level)
      and
      (select percentile_cont(0.98) within group (order by best_set_reps)
       from exercise_benchmarks eb2
       where eb2.exercise_id = exercise_benchmarks.exercise_id
         and eb2.level = exercise_benchmarks.level)
group by exercise_id, level
on conflict (exercise_id, level, metric_type) do update set
    p5 = excluded.p5, p10 = excluded.p10, p15 = excluded.p15,
    p20 = excluded.p20, p25 = excluded.p25, p30 = excluded.p30,
    p35 = excluded.p35, p40 = excluded.p40, p45 = excluded.p45,
    p50 = excluded.p50, p55 = excluded.p55, p60 = excluded.p60,
    p65 = excluded.p65, p70 = excluded.p70, p75 = excluded.p75,
    p80 = excluded.p80, p85 = excluded.p85, p90 = excluded.p90,
    p95 = excluded.p95,
    total_users = excluded.total_users, updated_at = now();
```

---

## Client-Side vs Server-Side Achievement Computation

| Achievement type | Computed where | Why |
|---|---|---|
| Percentile-based (Top Half, Summit, etc.) | Client | Compare local PB against fetched distributions |
| Time-of-day (Early Bird, Night Owl) | Client | Count from local workout history |
| Holiday | Server detects, client displays | Server checks workout_date, increments holiday_counts |
| Seasonal | Client | Count from local workout history date ranges |
| Milestones (Century Club, etc.) | Client | Count from local data |
| Playful (Groundhog Day, Friday 13th) | Client | Check from local workout history |

Server only needs to: store benchmarks, compute distributions, detect holidays,
and serve read-only aggregates. All achievement logic lives on the client.

---

## Minimum Viable Scope (v1)

**Ship first:**
1. Anonymous identity (Keychain UUID + SHA-256)
2. Exercise benchmark upload (best_set_reps/duration only)
3. Streak benchmark upload
4. Edge Function with plausibility checks
5. Distribution cron (daily)
6. Exercise completion screen: percentile callout on new PB
7. Community section in Achievements: percentile-based achievements only
8. Delete My Data button in Settings

**Ship second:**
9. Community Stats view with full distribution visualizations
10. Time-of-day histogram
11. Holiday achievements
12. Lifetime distributions
13. Seasonal achievements

**Ship third:**
14. Playful/quirky achievements
15. Community pulse ("247 workouts today")
16. Sensor-verified benchmarks
17. Session volume and test score distributions

---

## Client-Side Percentile Interpolation

With 19 breakpoints (P5 through P95, every 5th), the client interpolates
linearly to produce smooth, natural-looking percentages.

**Algorithm:**

```swift
func computePercentile(value: Int, breakpoints: [(percentile: Int, threshold: Int)]) -> Int {
    // Below P5 → show "top 95%"
    guard let first = breakpoints.first, value >= first.threshold else {
        return 5
    }
    // Above P95 → show "top 5%"
    guard let last = breakpoints.last, value <= last.threshold else {
        return 95
    }
    // Find the two breakpoints the value falls between
    for i in 0..<(breakpoints.count - 1) {
        let lower = breakpoints[i]
        let upper = breakpoints[i + 1]
        if value >= lower.threshold && value <= upper.threshold {
            if upper.threshold == lower.threshold { return upper.percentile }
            let fraction = Double(value - lower.threshold) / Double(upper.threshold - lower.threshold)
            return lower.percentile + Int(fraction * Double(upper.percentile - lower.percentile))
        }
    }
    return 50 // fallback
}
```

**Example:**
- P50 = 30 reps, P55 = 33 reps, P60 = 36 reps
- User has 34 reps → falls between P55 (33) and P60 (36)
- Interpolation: 55 + (34-33)/(36-33) * 5 = 55 + 1.67 ≈ 57
- Display: "Better than 57% of Level 2 users"

This produces varied, believable numbers instead of everyone seeing the same
5 round percentages. Users with similar but slightly different performance
get appropriately different feedback.

---

## README Updates

The app README should highlight these aspects as user-facing features:

### Anonymity as a feature

```markdown
## Privacy-First Design

Daily Ascent is built with privacy as a core feature, not an afterthought:

- **No accounts required** — no email, no sign-up, no social login
- **All data stays on your device** — workout history, progress, and settings
  live in your local database and sync only to your personal iCloud
- **Anonymous community stats** — if you choose to participate, your performance
  is compared against the community using a one-way hash that can never be
  traced back to you or your device
- **Sensor data is anonymous at collection** — motion recordings (if you opt in)
  contain no device or user identifiers whatsoever
- **No tracking, no analytics profiles** — we don't know who you are, and we
  designed it that way
```

### Offline-first architecture

```markdown
## Works Everywhere, No Connection Required

Daily Ascent is offline-first:

- **Full functionality without internet** — schedule workouts, track reps,
  maintain your streak, and earn achievements entirely offline
- **iCloud sync** — your data syncs seamlessly across your iPhone and Apple
  Watch via CloudKit, no server required
- **Community features are opportunistic** — benchmark uploads happen silently
  when connectivity is available; nothing breaks when it isn't
- **No loading spinners, no "connection required" screens** — the app is always
  ready when you are
```

### Community features

```markdown
## Community Benchmarks

See where you stand — anonymously:

- **Percentile rankings** — "Your 42-rep push-up set is better than 78% of
  Level 2 users"
- **Streak comparisons** — "Your 15-day streak is longer than 85% of active
  users"
- **Community achievements** — earn badges for holiday workouts, time-of-day
  consistency, and hitting community percentile milestones
- **Zero identity** — participation uses a one-way hash with no connection to
  your person, device, or Apple ID
- **Auto-expiring data** — community records are automatically cleaned up,
  keeping the stats fresh and the footprint small
```

---

## Decisions (formerly Open Questions)

1. **Default on or opt-in?**
   **Decision: default on** with a toggle in Settings to disable uploads.
   Since the data is anonymous and contains no PII, opt-in friction would
   suppress adoption without meaningfully improving privacy. The toggle
   provides an escape hatch for users who want zero network activity.

2. **Minimum community size before showing percentiles?**
   **Decision: threshold of 20 users** per exercise/level before displaying
   percentile data. Below that, show the personal best without the community
   comparison ("New PB: 42 push-ups" with no percentile line). The
   total_users field in distributions makes this check trivial client-side.
   This will take time to reach in the early days — that's fine. The feature
   gracefully degrades to personal-best-only until the community grows.

3. **Locale-aware holidays?**
   **Decision: yes.** Send `Locale.current.region?.identifier` (just the
   country code, e.g. "US", "GB", "AU") as part of the exercise benchmark
   upload. The Edge Function uses this to:
   - Award universal holidays to everyone (Christmas, New Year, Easter, etc.)
   - Award regional holidays only to matching locales (Thanksgiving → US,
     Boxing Day → GB/AU/CA, etc.)
   - The region code is not stored with the benchmark — it's only used at
     upload time to check against the holiday calendar and increment the
     appropriate holiday_counts row
   This keeps no locale data in the database while still enabling regional
   holiday achievements.

4. **Are percentile achievements permanent?**
   **Decision: yes — once earned, kept forever.** Show "Earned on [date]" in
   the achievement detail. If the community grows and distributions shift,
   the user keeps their badge. This mirrors how the existing personal
   achievements work and avoids the frustrating experience of losing something
   you earned.
