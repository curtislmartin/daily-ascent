# Skills Catalog — Inch

All skill packages reviewed against the Inch spec documents and 17-step build order. Organised by tier and mapped to specific build phases.

---

## Tier 1: Essential (install before starting)

These four skills are referenced directly in `CLAUDE.md` and must be active for every session.

### `swiftui-pro` — SwiftUI-Agent-Skill-main.zip
**Covers:** `@Observable`, `NavigationStack`, `TabView`, view composition, `@State`/`@Environment`, list performance, sheets, animations.
**Used in:** Steps 6–17 (everything with a UI — iOS app shell through Watch app).
**Notes:** The CLAUDE.md `@Observable`, navigation, and state management rules were written with this skill in mind. Source of truth for view model ownership and `@State` patterns.

### `swiftdata-pro` — SwiftData-Agent-Skill-main.zip
**Covers:** `@Model`, `@Relationship`, `FetchDescriptor`, `#Predicate`, `ModelContext`, CloudKit-readiness, migrations.
**Used in:** Steps 1, 7–17 (models first, then every feature that reads/writes data).
**Notes:** All CloudKit-readiness rules in CLAUDE.md (no `@Attribute(.unique)`, explicit `@Relationship(deleteRule:, inverse:)`) come from this skill. Essential from the first line of code.

### `swift-concurrency-pro` — Swift-Concurrency-Agent-Skill-main.zip
**Covers:** `async`/`await`, actors, `@concurrent`, `AsyncStream`, `Sendable`, isolation errors, Swift 6.2 patterns.
**Used in:** All steps — the shared package is non-isolated, app targets are `@MainActor` by default.
**Notes:** Strict concurrency is enabled from day one. This skill resolves the isolation patterns used throughout `architecture.md` (nonisolated delegates, AsyncStream bridging, `@concurrent` background work).

### `swift-testing-pro` — Swift-Testing-Agent-Skill-main.zip
**Covers:** `@Test`, `#expect`, `#require`, `@Suite`, parameterized tests, tags, fixtures.
**Used in:** Steps 1–5 (shared package — scheduling engine has 12 required test cases), and all subsequent features.
**Notes:** CLAUDE.md prohibits XCTest for unit tests. All test patterns in CLAUDE.md (struct suites, no `setUp`, `#require` for preconditions) come from this skill.

---

## Tier 2: Recommended (install before starting)

Skills that address significant surface areas of the project.

### `swift-accessibility-skill` — swift-accessibility-skill-main.zip
**Covers:** SwiftUI accessibility labels, traits, hints, Dynamic Type, Reduce Motion, VoiceOver, Voice Control.
**Used in:** Steps 6–13 (all SwiftUI views — iOS and Watch).
**Notes:** The handoff checklist designates this recommended. The skill is described as an "essential companion to any SwiftUI skill" and should be used whenever writing ANY SwiftUI views. iOS Accessibility guidelines matter for App Store approval.

### `ios-accessibility` — iOS-Accessibility-Agent-Skill-main.zip
**Covers:** Broader iOS accessibility culture, Dynamic Type in SwiftUI and UIKit, Full Keyboard Access, VoiceOver, automated auditing.
**Used in:** Overlaps with `swift-accessibility-skill`. Adds culture/context, Dynamic Type reference docs, and automated audit guidance.
**Notes:** This and `swift-accessibility-skill` overlap significantly. See decision note at bottom.

### `writing-for-interfaces` — skills-main.zip (writing-for-interfaces/)
**Covers:** UI copy, button labels, empty states, error messages, onboarding text, microcopy principles.
**Used in:** Steps 7–10 (onboarding, Today dashboard, workout session, program view).
**Notes:** Inch has substantial UI copy — exercise names, coaching prompts, conflict warnings, consent text. This skill prevents AI-generated filler copy.

---

## Tier 3: Situational (install when reaching the relevant build phase)

These skills are valuable but only needed for specific phases.

### `swift-security-expert` — swift-security-skill-main.zip
**Covers:** Keychain Services, CryptoKit, Secure Enclave, certificate pinning, OAuth token storage.
**Used in:** Step 16 (background upload — Supabase API key must not be hardcoded; contributor UUID storage).
**Notes:** `CLAUDE.md` explicitly prohibits hardcoded API keys. The upload service needs secure credential storage.

### `ios-simulator-skill` — ios-simulator-skill-main.zip
**Covers:** 21 scripts for build automation, accessibility audit, UI navigation, simulator lifecycle.
**Used in:** Steps 6–13 (testing UI flows, accessibility audits on simulator).
**Notes:** Particularly useful for testing the Today dashboard, workout session flow, and Watch connectivity without a physical device.

### `ios-debugger-agent` — Skills-main/ios-debugger-agent/
**Covers:** Build, run, launch, and debug via XcodeBuildMCP; UI inspection, log capture, runtime diagnosis.
**Used in:** Any step when debugging runtime behaviour on the simulator.
**Notes:** Requires XcodeBuildMCP to be configured. Useful for diagnosing scheduling bugs that only appear at runtime.

### `swift-architecture-skill` — swift-architecture-skill-main.zip
**Covers:** MVVM, Clean Architecture, feature module design, architecture review checklists.
**Used in:** Steps 1–6 (shared package design, iOS app shell, service layer).
**Notes:** The architecture is already well-specified in `architecture.md`. This skill is most useful for reviewing decisions during implementation rather than upfront design.

### `swift-api-design-guidelines-skill` — Swift-API-Design-Guidelines-Agent-Skill-main.zip
**Covers:** Swift naming, argument labels, documentation comments, API fluency.
**Used in:** Steps 1–5 (shared package public API design — SchedulingEngine, ConflictDetector, etc.).
**Notes:** The shared package API is consumed by both iOS and watchOS targets. Good API design here prevents problems in later phases.

### `swiftui-ui-patterns` — Skills-main/swiftui-ui-patterns/
**Covers:** TabView architecture, screen composition, component-specific patterns.
**Used in:** Steps 6–10 (app shell, onboarding, Today, workout, program views).
**Notes:** Overlaps with `swiftui-pro`. Adds tab architecture guidance specifically, which is directly applicable to the three-tab structure.

### `swiftui-view-refactor` — Skills-main/swiftui-view-refactor/
**Covers:** View structure consistency, dependency injection, `@Observable` usage, non-optional view models.
**Used in:** Refactoring passes after initial implementation; code review.
**Notes:** Most useful after a feature is working but needs cleanup before moving to the next phase.

### `swiftui-design-principles` — swiftui-design-principles-main.zip
**Covers:** Spacing, typography, colour, native-feeling UI, avoiding AI-generated visual patterns.
**Used in:** Steps 6–13 (any screen with custom layout).
**Notes:** Particularly relevant for the exercise cards, rep-count display, and progress bars where visual quality matters.

### `app-store-aso` — app-store-aso-skill-main.zip
**Covers:** App Store metadata optimisation, keywords, title/subtitle, screenshots, competitive analysis.
**Used in:** Post-v1 (App Store submission preparation).
**Notes:** Not needed during development. Install when preparing the first App Store submission.

### `app-store-changelog` — Skills-main/app-store-changelog/
**Covers:** Generating user-facing release notes from git history.
**Used in:** Each App Store release.
**Notes:** Install alongside `app-store-aso` when preparing for release.

### `asc-*` skills — app-store-connect-cli-skills-main.zip
**Covers:** App Store Connect app creation, ASO audit, build lifecycle, crash triage (6 skills).
**Used in:** Post-v1 (App Store Connect operations).
**Notes:** CLI-based App Store Connect management. Not needed until submitting builds.

---

## Tier 4: Performance and Audit (post-v1)

### `swiftui-liquid-glass` — Skills-main/swiftui-liquid-glass/
**Covers:** `glassEffect`, `GlassEffectContainer`, glass button styles, morphing transitions, availability handling.
**Used in:** Steps 6–13 (any surface-based UI — exercise cards, workout session overlays, rest timer, program cards).
**Notes:** iOS 26+ API but the skill correctly gates everything with `#available(iOS 26, *)` and provides `.ultraThinMaterial` fallbacks, so it is fully compatible with the iOS 18.0 deployment target. The Today dashboard exercise cards, workout session controls, and rest timer are natural candidates for glass treatment. Install alongside `swiftui-pro` from step 6 onward.

### `swiftui-performance-audit` — Skills-main/swiftui-performance-audit/
**Covers:** Diagnosing slow rendering, janky scrolling, excessive view updates, Instruments profiling guidance.
**Used in:** Post-MVP performance pass.
**Notes:** Premature to use in v1. The Today dashboard (potentially 6 exercise cards) and workout session (real-time rep counting) are the most likely performance hotspots.

### `swift-concurrency-expert` — Skills-main/swift-concurrency-expert/
**Covers:** Concurrency review and remediation specifically for Swift 6.2+.
**Used in:** Code review passes for the sensor recording service and upload pipeline.
**Notes:** Overlaps significantly with `swift-concurrency-pro`. This version (Skills-main) is a review/audit tool; the Agent Skill version is for active development.

### `macos-spm-app-packaging` — Skills-main/macos-spm-app-packaging/
**Covers:** Scaffolding, building, and packaging SwiftPM-based macOS apps without an Xcode project. Bundle assembly, signing, notarization, appcast.
**Used in:** If a macOS companion app is added to the project.
**Notes:** Not applicable to the current Inch iOS/watchOS Xcode project. Relevant if expanding to a macOS target — either as a standalone SPM app or a menu bar companion. Keep available but do not install for v1.

---

## Tier 5: Not Applicable to Inch v1

| Skill | Reason |
|---|---|
| `core-data-expert` | Project uses SwiftData, not Core Data |
| `appkit-accessibility-auditor` | macOS AppKit only; Inch is iOS/watchOS |
| `github` | Utility skill for `gh` CLI; not domain-specific |
| `critical-reasoning` | Process/epistemology skill; invoke manually when needed |

---

## Installation Decision Matrix

| Phase | Skills active |
|---|---|
| Steps 1–5: Shared package | `swiftui-pro`, `swiftdata-pro`, `swift-concurrency-pro`, `swift-testing-pro`, `swift-api-design-guidelines-skill` |
| Steps 6–11: iOS app | + `swift-accessibility-skill`, `writing-for-interfaces`, `swiftui-ui-patterns`, `swiftui-design-principles`, `swiftui-liquid-glass` |
| Step 12–13: Watch app | (same set — Watch views use same skills) |
| Step 14–16: HealthKit, sensors, upload | + `swift-security-expert` |
| Post-v1: Release | + `app-store-aso`, `app-store-changelog`, `asc-*` |

---

## Accessibility Skills: Recommendation

Both `swift-accessibility-skill` and `ios-accessibility` cover overlapping ground. Recommended approach:

**Install `swift-accessibility-skill` as the active development companion** — it is scoped to code-level SwiftUI/UIKit/AppKit implementation and is designed to run alongside SwiftUI work.

**Keep `ios-accessibility` as a reference** — its `references/` folder contains detailed Dynamic Type and VoiceOver documentation that `framework-guidance.md` does not cover. Read it when implementing Dynamic Type support and running manual accessibility audits.

---

## What the Handoff Checklist Recommends vs This Review

The checklist listed 4 essential + 2 recommended. This review:
- Confirms the 4 essentials
- Adds `swift-accessibility-skill` to the install-before-starting list (it should run alongside all SwiftUI work)
- Promotes `writing-for-interfaces` to Tier 2 (significant UI copy surface area)
- Identifies `swift-security-expert` as needed for the upload pipeline (not mentioned in checklist)
- Explicitly excludes `swiftui-design-principles` from "not needed" (the checklist was too conservative; visual polish matters for an App Store app)
- Moves `swiftui-liquid-glass` from "Not Applicable" to Tier 3 — iOS 26+ is available, and the skill handles `#available` fallbacks correctly for the iOS 18.0 deployment target
- Moves `macos-spm-app-packaging` from "Not Applicable" to Tier 3 as a future option if a macOS companion app is added
