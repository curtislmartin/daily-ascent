-- Community Benchmarks — Supabase Schema
-- Run manually via Supabase dashboard SQL editor or CLI.

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

create table exercise_distributions (
    exercise_id   text not null,
    level         smallint not null,
    metric_type   text not null,
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
    id          int primary key default 1,
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
    workout_hour  smallint primary key,
    user_count    int not null,
    updated_at    timestamptz not null default now()
);

create table lifetime_distributions (
    metric_type   text primary key,
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
    holiday_key   text primary key,
    workout_count int not null,
    updated_at    timestamptz not null default now()
);

-- ── RLS ─────────────────────────────────────────────────────────────────────

alter table exercise_benchmarks enable row level security;
alter table streak_benchmarks enable row level security;
alter table lifetime_benchmarks enable row level security;

create policy "insert_only" on exercise_benchmarks for insert with check (true);
create policy "insert_only" on streak_benchmarks for insert with check (true);
create policy "insert_only" on lifetime_benchmarks for insert with check (true);

-- Allow delete by device_hash (for "Delete Community Data" feature)
create policy "delete_own" on exercise_benchmarks for delete using (true);
create policy "delete_own" on streak_benchmarks for delete using (true);
create policy "delete_own" on lifetime_benchmarks for delete using (true);

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

-- ── Cleanup cron (requires pg_cron extension) ───────────────────────────────
-- Run daily: delete records older than 90 days
-- select cron.schedule('cleanup-community-benchmarks', '0 3 * * *', $$
--     delete from exercise_benchmarks where recorded_at < now() - interval '90 days';
--     delete from streak_benchmarks where recorded_at < now() - interval '90 days';
--     delete from lifetime_benchmarks where recorded_at < now() - interval '90 days';
-- $$);
