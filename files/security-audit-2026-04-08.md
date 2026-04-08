# Security Audit — Daily Ascent Bodyweight Training App

**Date:** 2026-04-08
**Scope:** Full codebase — iOS app, watchOS app, Shared package, build scripts
**Auditor:** Claude Opus 4.6 (automated static analysis)
**Status:** Read-only audit. No changes made.

---

## Executive Summary

Daily Ascent is a well-structured iOS/watchOS fitness app with **no third-party dependencies** (eliminating supply chain risk), proper use of HTTPS for all network traffic, and thoughtful consent mechanisms for sensor data collection. However, the audit identified **2 critical**, **5 high**, **8 medium**, and **5 low** severity findings across credential management, data privacy, concurrency safety, and input validation.

The most urgent issues are **exposed API credentials in the app bundle** and **demographic PII uploaded alongside sensor data** without sufficient anonymization guarantees.

| Severity | Count | Action Timeline |
|----------|-------|-----------------|
| Critical | 2 | Immediate — before next release |
| High | 5 | Before App Store submission |
| Medium | 8 | Next development cycle |
| Low | 5 | Backlog / best-practice hardening |

---

## Critical Findings

### C-1. Supabase API Key in App Bundle

**Severity:** CRITICAL
**File:** `inch/inch/Secrets.plist:5-8`

```xml
<key>SupabaseURL</key>
<string>https://xwvlewuuavpgurmtenwk.supabase.co</string>
<key>SupabaseAnonKey</key>
<string>sb_publishable_IK2eaLlO_yJo0qaexZ4tsA_d6AOe-Oj</string>
```

**Consumed by:**
- `inch/inch/Services/DataUploadService.swift:65-66`
- `inch/inch/Services/AnalyticsService.swift:192-193`
- `inch/inch/inchApp.swift:91-95`

**Mitigating factor:** The file is `.gitignore`d and the key is a Supabase "anon" (publishable) key, not a service-role key. However, the key ships inside the compiled app bundle. Anyone with the IPA can extract it and:
- Upload arbitrary sensor data to the `sensor-data` storage bucket
- Insert rows into `sensor_recordings` and `app_events` tables (depending on RLS policies)
- Enumerate the Supabase project URL and probe for misconfigurations

**Recommendation:**
1. Verify strict Row-Level Security (RLS) policies exist on all Supabase tables — the anon key should only allow INSERT, never SELECT/UPDATE/DELETE of other users' data.
2. Consider a lightweight server-side token exchange so the raw anon key never ships in the binary.
3. If key rotation is needed, rotate it in the Supabase dashboard and update the plist.

---

### C-2. Demographic PII Uploaded With Sensor Data

**Severity:** CRITICAL
**File:** `inch/inch/Services/DataUploadService.swift:139-157`

```swift
let payload = SensorRecordingPayload(
    exerciseId: recording.exerciseId,
    level: recording.level,
    ...
    ageRange: config.ageRange,           // PII
    heightRange: config.heightRange,     // PII
    biologicalSex: config.biologicalSex, // PII
    activityLevel: config.activityLevel, // PII
    sessionId: recording.sessionId
)
```

**Issue:** Sensor motion data (accelerometer + gyroscope at 50-100 Hz) is uploaded alongside demographic attributes (age bracket, height bracket, biological sex, activity level). This combination creates a re-identification risk:

- Motion signatures are biometrically unique — research shows gait/movement patterns can identify individuals.
- Linking demographics narrows the anonymity set significantly.
- The per-session UUID provides temporal correlation within a workout.

**Mitigating factor:** Upload requires explicit user consent (`motionDataUploadConsented` flag + `consentDate`). The privacy settings UI (`PrivacySettingsView.swift:123-126`) explains what is collected.

**Recommendation:**
1. Upload demographics and sensor data with separate, unlinkable identifiers — or aggregate demographics server-side.
2. Consider differential privacy techniques (adding calibrated noise to demographic buckets).
3. Document the re-identification risk in the privacy policy and consent flow.
4. Evaluate whether demographics are truly necessary for the ML training objective.

---

## High Findings

### H-1. Force Unwraps on HealthKit Types

**Severity:** HIGH
**File:** `inch/inch/Services/HealthKitService.swift:17-18`

```swift
HKObjectType.quantityType(forIdentifier: .heartRate)!,
HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
```

**Issue:** `quantityType(forIdentifier:)` returns `HKQuantityType?`. While these specific identifiers are guaranteed by Apple on current platforms, force unwraps violate the project's own coding standards ("Never use `!` force unwrap") and risk a crash if Apple ever deprecates an identifier or the code runs on an unexpected platform.

**Recommendation:** Use `guard let` / `compactMap` to build the set safely.

---

### H-2. Unencrypted Sensor Data at Rest

**Severity:** HIGH
**Files:**
- `inch/inch/Services/MotionRecordingService.swift:52-54`
- `inch/inchwatch Watch App/Services/WatchMotionRecordingService.swift:38-40`

```swift
FileManager.default.createFile(atPath: fileURL.path, contents: nil, attributes: [
    FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
])
```

**Issue:** Sensor binary files (accelerometer + gyroscope) use `completeUntilFirstUserAuthentication`, meaning they are accessible to any process after the user first unlocks the device post-boot. For biometric-grade motion data that reveals exercise capability, body composition, and potential disability status, this is insufficient.

**Mitigating factor:** Files are excluded from iCloud backup (`isExcludedFromBackup = true`). Data stays on-device until uploaded.

**Recommendation:** Use `FileProtectionType.complete` if background access isn't needed, or encrypt with CryptoKit before writing.

---

### H-3. `nonisolated(unsafe)` Mutable State in Motion Services

**Severity:** HIGH
**Files:**
- `inch/inch/Services/MotionRecordingService.swift:10,15,20`
- `inch/inchwatch Watch App/Services/WatchMotionRecordingService.swift:10,15,18`

```swift
nonisolated(unsafe) private let motionManager = CMMotionManager()
nonisolated(unsafe) private var flushAndClose: (() -> Void)?
nonisolated(unsafe) var onSample: ((Double, Double, Double) -> Void)?
```

**Issue:** Six `nonisolated(unsafe)` annotations bypass Swift 6 strict concurrency checking. The inline comments document the safety reasoning (assigned on `@MainActor`, read on sensor `OperationQueue`), and the reasoning appears correct for the current code. However:

- There is no compiler enforcement — a future change could introduce a data race silently.
- `onSample` is a public `var` that external code could set at any time.

**Mitigating factor:** Well-documented access patterns. This is a known limitation of bridging Core Motion's callback-based API into Swift concurrency.

**Recommendation:** Consider wrapping the recording session state in a small `Mutex` or dedicated serial executor to get compiler-enforced safety without `nonisolated(unsafe)`.

---

### H-4. Device UDIDs Hardcoded in Build Script

**Severity:** HIGH
**File:** `scripts/build-device.sh:14-15`

```bash
IPHONE_UDID="00008110-001609380E3B801E"
WATCH_UDID="00008006-001E2C2414C3402E"
```

**Mitigating factor:** The file is committed to a private repo and UDIDs alone don't grant access. However, they uniquely identify physical devices.

**Recommendation:** Move UDIDs to a `.local` config file that is `.gitignore`d, or read from environment variables.

---

### H-5. No Keychain Usage for Any Secrets

**Severity:** HIGH
**Finding:** Zero references to `SecItem`, `kSecClass`, or Keychain APIs anywhere in the codebase. The Supabase anon key lives in `Secrets.plist` (bundled plaintext). The TestFlight upload script correctly uses macOS Keychain (`scripts/upload-testflight.sh:24-25`), but the app itself stores no secrets securely.

**Recommendation:** If the app ever needs to store per-user tokens, session tokens, or refresh tokens, use the iOS Keychain. For the current anon-key-only model, this is acceptable but should be addressed before adding any authenticated endpoints.

---

## Medium Findings

### M-1. YouTube Video ID Interpolated Into HTML Without Sanitization

**Severity:** MEDIUM
**File:** `inch/inch/Features/Workout/YouTubePlayerView.swift:44`

```swift
src="https://www.youtube-nocookie.com/embed/\(id)?playsinline=1&rel=0&modestbranding=1"
```

**Current risk: LOW** — all video IDs are currently empty strings hardcoded in `ExerciseContent.swift`. No dynamic or user-supplied IDs exist.

**Future risk: HIGH** — if video IDs ever come from a server, JSON config, or user input, this is an XSS injection point inside a `WKWebView`.

**Recommendation:** Validate video IDs against the YouTube format `^[a-zA-Z0-9_-]{11}$` before interpolation.

---

### M-2. Incomplete Privacy Manifest

**Severity:** MEDIUM
**Files:** `inch/inch/PrivacyInfo.xcprivacy`, `inch/inchwatch Watch App/PrivacyInfo.xcprivacy`

**Declared:**
- `NSPrivacyCollectedDataTypeFitness` — workout data
- `NSPrivacyCollectedDataTypeOtherDiagnosticData` — MetricKit diagnostics
- `NSPrivacyCollectedDataTypeHealth` — HealthKit heart rate
- `NSPrivacyAccessedAPICategoryUserDefaults` (reason `CA92.1`)

**Missing:**
- No declaration for **analytics event collection** (`AnalyticsService` collects exercise type, level, reps, duration, streaks)
- No declaration for **demographic data** (age range, height range, biological sex) which is collected and uploaded
- No `NSPrivacyAccessedAPICategoryFileTimestamp` despite `FileManager.attributesOfItem` usage
- Heart rate data collected via HealthKit should arguably be called out more specifically

**Risk:** Inaccurate privacy manifests can trigger App Store review rejection on iOS 17+.

**Recommendation:** Audit all collected data types against Apple's [privacy manifest categories](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files) and add missing entries.

---

### M-3. WatchConnectivity Metadata Lacks Range Validation

**Severity:** MEDIUM
**File:** `inch/inch/Services/WatchConnectivityService.swift:294-302`

```swift
let setNumber = raw["setNumber"] as? Int ?? 0
let level = raw["level"] as? Int ?? 0
let dayNumber = raw["dayNumber"] as? Int ?? 0
let confirmedReps = raw["confirmedReps"] as? Int ?? 0
let durationSeconds = raw["durationSeconds"] as? Double ?? 0
let sampleRateHz = raw["sampleRateHz"] as? Int ?? 50
```

**Issue:** Exercise ID is validated against a whitelist (good), but numeric metadata fields accept any value. A compromised watch app could send `level: 999`, `confirmedReps: -1`, or `durationSeconds: 1e18`.

**Recommendation:** Add range validation: `level` in `1...3`, `dayNumber` in `1...maxDays`, `confirmedReps` in `0...999`, `sampleRateHz` in `[50, 100]`.

---

### M-4. Analytics Queue Stored Unencrypted Without File Protection

**Severity:** MEDIUM
**File:** `inch/inch/Services/AnalyticsService.swift:119`

```swift
private var queueFileURL: URL {
    URL.applicationSupportDirectory.appending(path: "pending_analytics.json")
}
```

**Issue:** Pending analytics events (exercise types, rep counts, level progressions, streak data) are stored as plaintext JSON in Application Support. Unlike sensor data files, no `FileProtectionKey` is applied.

**Recommendation:** Apply `FileProtectionType.completeUntilFirstUserAuthentication` at minimum.

---

### M-5. MetricKit Diagnostics Written Without File Protection

**Severity:** MEDIUM
**File:** `inch/inch/Services/MetricKitService.swift:16-35`

MetricKit diagnostic payloads (CPU, memory, crash data) are written as `diagnostic-*.json` files to the Documents directory without explicit file protection attributes. System-level performance data could reveal implementation details useful for exploitation.

**Recommendation:** Apply file protection and consider a retention/cleanup policy.

---

### M-6. WatchConnectivity Messages Not Cryptographically Signed

**Severity:** MEDIUM
**Files:**
- `inch/inch/Services/WatchConnectivityService.swift:45-49`
- `inch/inchwatch Watch App/Services/WatchConnectivityService.swift:55-65`

**Issue:** Schedule data and completion reports transferred via `updateApplicationContext` and `transferFile` are JSON-encoded but not signed or integrity-checked at the application layer. WatchConnectivity provides BLE-level encryption, but there's no app-layer authentication.

**Practical risk: LOW** — exploiting this requires a compromised watch or BLE MITM with the pairing key.

**Recommendation:** For a fitness app this is acceptable. If the data ever drives health decisions, add HMAC signing.

---

### M-7. Potential Crash in `LoadAdvisoryCopy.pick()`

**Severity:** MEDIUM
**File:** `Shared/Sources/InchShared/Engine/LoadAdvisoryCopy.swift:154-156`

```swift
private static func pick(_ phrases: [String]) -> String {
    phrases.randomElement() ?? phrases[0]
}
```

**Issue:** If `phrases` is empty, `randomElement()` returns `nil` and `phrases[0]` crashes with index-out-of-bounds. Currently all phrase arrays are non-empty literals, but a future refactor could introduce an empty array.

**Recommendation:** Change to `phrases.randomElement() ?? ""` or add a precondition.

---

### M-8. Sensor File Size Check After Transfer, Not Before

**Severity:** MEDIUM
**File:** `inch/inch/Services/WatchConnectivityService.swift:284-291`

```swift
let size = (attrs?[.size] as? Int) ?? 0
guard size <= 5_000_000 else {  // 5 MB cap
    try? FileManager.default.removeItem(at: dest)
    return
}
```

**Issue:** The 5 MB size check runs after the file has already been received and written to disk. A misbehaving watch could repeatedly send 5 MB files, consuming I/O and temporary storage.

**Mitigating factor:** WatchConnectivity's own transfer limits and the 50 MB folder cap in `MotionRecordingService` provide secondary protection.

**Recommendation:** Acceptable for current architecture. If transfer volume grows, implement aggregate size tracking.

---

## Low Findings

### L-1. No Certificate Pinning for Supabase

**Severity:** LOW
**Finding:** The app uses `URLSession.shared` with default TLS validation. No certificate pinning is implemented for the Supabase domain.

**Practical risk:** Very low on iOS — the system trust store and App Transport Security provide strong baseline protection. Certificate pinning is mainly relevant for high-value financial/health apps operating in hostile network environments.

**Recommendation:** Not required for current threat model. Revisit if the app handles payment data or operates in enterprise environments.

---

### L-2. Force Unwrap on Privacy Policy URL

**Severity:** LOW
**File:** `inch/inch/Features/Settings/PrivacySettingsView.swift:23`

```swift
URL(string: "https://curtislmartin.github.io/daily-ascent/privacy")!
```

**Issue:** Violates project coding standards. While this specific URL will never fail to parse, it sets a bad precedent.

**Recommendation:** Use `if let url = URL(string: ...)`.

---

### L-3. Force Unwrap on Calendar Date Arithmetic

**Severity:** LOW
**File:** `Shared/Sources/InchShared/Engine/StreakCalculator.swift:77`

```swift
let yesterday = cal.date(byAdding: .day, value: -1, to: todayStart)!
```

**Issue:** `Calendar.date(byAdding:)` can theoretically return `nil`. Extremely unlikely for simple day arithmetic, but violates project standards.

**Recommendation:** Use `guard let`.

---

### L-4. `os_log` With `.public` Privacy on Error Objects

**Severity:** LOW
**File:** `inch/inch/inchApp.swift:25`

```swift
logger.critical("Failed to create ModelContainer: \(error, privacy: .public)")
```

**Issue:** Error descriptions logged with `.public` may contain stack traces or internal paths in crash reports visible to Apple or third-party crash reporting.

**Recommendation:** Use `.private` for error objects unless actively debugging.

---

### L-5. Debug/TestFlight Features Properly Gated (Positive)

**Severity:** LOW — PASS
**File:** `inch/inch/Features/Debug/DebugViewModel.swift`

All debug features are wrapped in `#if DEBUG || TESTFLIGHT`, ensuring they don't ship in release builds. No sensitive data is exposed through the debug panel.

---

## Positive Security Observations

These are areas where the app demonstrates strong security practices:

| Area | Status | Details |
|------|--------|---------|
| **No third-party dependencies** | PASS | Zero SPM packages — eliminates supply chain risk entirely |
| **HTTPS everywhere** | PASS | All network requests use HTTPS; no HTTP fallback |
| **Consent-gated uploads** | PASS | Sensor data upload requires explicit opt-in with date tracking |
| **Analytics off by default** | PASS | `analyticsEnabled` defaults to `false` in `UserSettings` |
| **Secrets.plist gitignored** | PASS | Not committed to version control |
| **iCloud backup exclusion** | PASS | Sensor files marked `isExcludedFromBackup = true` |
| **Exercise ID whitelist** | PASS | WatchConnectivity validates against known exercise IDs |
| **Upload credentials in macOS Keychain** | PASS | `upload-testflight.sh` uses `security find-generic-password` |
| **Debug features gated** | PASS | `#if DEBUG \|\| TESTFLIGHT` on all debug UI |
| **Structured concurrency** | PASS | No GCD, no Combine, async/await throughout |
| **Data deletion available** | PASS | Users can delete history and fully reset the app |

---

## Recommendations Summary

### Immediate (Before Next Release)

1. **Verify Supabase RLS policies** — ensure the anon key can only INSERT, never SELECT other users' rows (C-1)
2. **Evaluate PII in sensor uploads** — consider separating or removing demographics from motion payloads (C-2)
3. **Replace HealthKit force unwraps** with safe optional binding (H-1)

### Before App Store Submission

4. **Complete the privacy manifest** — add missing collected data types for analytics and demographics (M-2)
5. **Add range validation** to WatchConnectivity metadata fields (M-3)
6. **Apply file protection** to analytics queue and MetricKit diagnostic files (M-4, M-5)
7. **Sanitize YouTube video IDs** before HTML interpolation (M-1)

### Next Development Cycle

8. **Evaluate stronger file protection** for sensor data — `complete` vs `completeUntilFirstUserAuthentication` (H-2)
9. **Reduce `nonisolated(unsafe)` surface** — consider `Mutex` for motion recording state (H-3)
10. **Move device UDIDs** out of committed scripts (H-4)
11. **Fix remaining force unwraps** in StreakCalculator and PrivacySettingsView (L-2, L-3)
12. **Guard `LoadAdvisoryCopy.pick()`** against empty arrays (M-7)

### Backlog

13. Implement Keychain storage infrastructure for future authenticated endpoints (H-5)
14. Consider app-layer HMAC for WatchConnectivity if data drives health decisions (M-6)
15. Use `.private` log level for error objects in os_log (L-4)

---

## False Positives Investigated and Dismissed

| Suspected Issue | Verdict | Reason |
|----------------|---------|--------|
| Division by zero in `DailyLoadAdvisor.averageCost` | **Not a bug** | Guarded by `guard !records.isEmpty else { return 2.0 }` at line 158 |
| `sessionTotalReps` integer overflow | **Negligible** | Would require >2 billion reps in a single session |
| WatchConnectivity BLE interception | **Negligible** | Requires compromising the Bluetooth pairing key on a paired device |
| CloudKit data accessible if iCloud compromised | **Accepted risk** | Standard for all iCloud-synced apps; private container provides user isolation |

---

*This audit covers static analysis only. It does not include dynamic testing, penetration testing, or review of the Supabase server-side configuration (RLS policies, storage bucket policies, Edge Functions). A server-side security review is recommended as a follow-up.*
