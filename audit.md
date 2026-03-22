Perform a comprehensive audit of the Daily Ascent project. I need three things:

1. Build and test status

Does the iOS app build cleanly with zero warnings? List any warnings or errors.
Does the watchOS app build cleanly? List any warnings or errors.
Do all unit tests pass? Run them and report results — how many pass, how many fail, any skipped.
Are there any Swift 6 strict concurrency warnings?

2. Feature walkthrough — test every user flow
   Walk through each flow as if you were a user. For each, report whether it works end-to-end or where it breaks:

Fresh launch → onboarding → select exercises → set start date → land on Today dashboard
Today dashboard → shows correct exercises for today → cards display sets/reps
Tap an exercise card → correct counting mode loads (real-time for squats/bridges/dead bugs, post-set confirmation for push-ups/pull-ups/sit-ups)
Complete all sets in an exercise → rest timers fire between sets with correct per-exercise duration → exercise complete screen shows → return to Today → exercise marked done
Complete a test day → pass → level unlocks → schedule advances correctly
Complete a test day → fail → stays on same day → retry scheduled after rest gap
Miss a day → exercise stays due → complete it late → rest gap applies from actual completion date → future schedule shifts
Conflict detection → if a test day collides with same-muscle-group training, is a warning shown?
Program tab → shows all enrolled exercises with correct level/day progress
Exercise detail → shows level progression, upcoming schedule, session history
History tab → shows completed workouts grouped by date
Settings → rest timer overrides work → counting mode overrides work → data consent toggle works
Watch app → receives synced schedule → shows today's exercises → can complete a workout → syncs results back to iPhone
HealthKit → workout saved after session completion
Sensor recording → accelerometer/gyroscope data recorded during sets on both devices
Data upload → recordings queued for upload when user has consented

3. Code quality issues

Any SwiftData relationships missing explicit delete rules or inverse specifications?
Any force unwraps in production code (not tests)?
Any hardcoded strings that should be localised?
Any views with excessively long body properties that should be extracted into subviews?
Any business logic living inside view bodies instead of view models?
Any TODO, FIXME, or HACK comments in the codebase?
Any dead code or unused files?

Format: For each issue found, state the file, the problem, and the severity (critical / medium / low).
