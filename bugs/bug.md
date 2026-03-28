When I unenroll then go to manage programs, it says I am enrolled in all of them.

Onboarding profile screen (DemographicTagsView): Skip and Continue buttons react visually but nothing happens — user cannot get past the optional profile step. [FIXED 2026-03-16]

---

## Reported 2026-03-16 (may already be fixed by parallel work — check before actioning)

**Profile picker in Settings looks cluttered**
The demographic tags (age range, height, biological sex, activity level) show all options as chips inline in the Settings list. Once a value is selected it should just display the selected value as a row label. Tapping should open a dedicated picker/edit view. Having all chips sitting exposed in the list is visually noisy.

**Select All in enrolment creates duplicate activities**
Tapping "Select All" during the enrolment step resulted in multiple entries for the same exercise/activity. Needs deduplication guard.

**Reset App does not return to onboarding**
Tapping Reset App in Settings deleted all data but the app did not navigate back to the onboarding flow. User was left on an empty or broken state. Expected: full reset → onboarding starts fresh.

**Settings screen is missing content**
Several expected settings items were not visible. Exact items unclear — needs audit against spec.

**Settings should not be a tab bar item**
User prefers settings accessible from the History tab (or similar) rather than occupying a slot in the main tab bar. The dedicated Settings tab feels out of place.
