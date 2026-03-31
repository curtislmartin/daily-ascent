# Exercise Form Guidance — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every user the information they need to perform each exercise safely: a tappable info sheet with looping demo video and coaching cues, a first-occurrence nudge banner in the workout session, and a pre-session intro for unfamiliar exercises (Dead Bug, Glute Bridge).

**Architecture:** Three new SwiftUI components (`ExerciseInfoSheet`, `ExerciseNudgeBanner`, `LoopingVideoView`) backed by a static `ExerciseContent` lookup keyed by `exerciseId` + `level`. Persistence is a single new `[String]` property on `UserSettings` tracking which exercises the user has already seen. An `ExerciseInfoButton` (ⓘ) is added to `ExerciseCard` (Today tab) and `WorkoutSessionView` (pre-set screen). The Tier 3 pre-session intro fires from `WorkoutSessionView` on first load.

**Tech Stack:** SwiftUI, `AVPlayer` + `UIViewRepresentable` for looping muted MP4, `@Query` for settings reads, `ModelContext` for settings writes. SwiftData schema bump to `BodyweightSchemaV3`.

---

## Schema Migration Note

This plan introduces `BodyweightSchemaV3`. The Retention Analytics, Milestones & Achievements, and Adaptive Difficulty plans also need V3 (adding other properties). **Batch all V3 changes into one migration.** If implementing multiple plans: create V3 with all new properties in one pass, then run schema migration once. The properties added in *this* plan: `seenExerciseInfo: [String] = []` on `UserSettings`.

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Modify | `Shared/Sources/InchShared/Models/UserSettings.swift` | Add `seenExerciseInfo: [String] = []` |
| Modify | `Shared/Sources/InchShared/Models/BodyweightSchema.swift` | Add `BodyweightSchemaV3`, extend `BodyweightMigrationPlan` |
| Modify | `Shared/Sources/InchShared/Utilities/ModelContainerFactory.swift` | Use `BodyweightMigrationPlan` (not raw schema) |
| Create | `inch/inch/Features/Workout/ExerciseContent.swift` | Static lookup: coaching cues, muscles, common mistakes, level tips |
| Create | `inch/inch/Features/Workout/LoopingVideoView.swift` | `UIViewRepresentable` wrapping `AVPlayerLayer` for muted looping MP4 |
| Create | `inch/inch/Features/Workout/ExerciseInfoSheet.swift` | Full sheet: video + cues + level tip |
| Create | `inch/inch/Features/Workout/ExerciseInfoButton.swift` | Reusable ⓘ button that presents `ExerciseInfoSheet` as a `.sheet` |
| Create | `inch/inch/Features/Workout/ExerciseNudgeBanner.swift` | Inline "first time?" prompt shown below exercise name pre-set |
| Modify | `inch/inch/Features/Today/ExerciseCard.swift` | Add `ExerciseInfoButton` next to exercise name |
| Modify | `inch/inch/Features/Workout/WorkoutSessionView.swift` | Add `ExerciseNudgeBanner` pre-set; add `ExerciseInfoButton`; handle Tier 3 intro sheet |
| Test | `Shared/Tests/InchSharedTests/SeenExerciseInfoTests.swift` | Tests for the `seenExerciseInfo` model property |
| Test | `Shared/Tests/InchSharedTests/ExerciseContentTests.swift` | Tests that all 6 exercises have valid content entries for all 3 levels |

---

### Task 1: Schema migration — add `seenExerciseInfo` to `UserSettings`

**Files:**
- Modify: `Shared/Sources/InchShared/Models/UserSettings.swift`
- Modify: `Shared/Sources/InchShared/Models/BodyweightSchema.swift`
- Modify: `Shared/Sources/InchShared/Utilities/ModelContainerFactory.swift`

> **Cross-plan note:** If you are implementing all 5 plans, add *all* new V3 properties in one go here:
> - `UserSettings`: `seenExerciseInfo`, `isFirstLaunch`, `analyticsEnabled`, `achievementNotificationEnabled`
> - `ExerciseEnrolment`: `recentDifficultyRatings`, `recentCompletionRatios`, `needsRepeat`, `isRepeatSession`, `sessionPrescriptionOverride`
> - New `Achievement` model (stub only if the Achievements plan hasn't been done yet)

- [ ] **Step 1: Write the failing test for UserSettings defaults**

Create `Shared/Tests/InchSharedTests/SeenExerciseInfoTests.swift`:

```swift
import Testing
@testable import InchShared

struct SeenExerciseInfoTests {

    @Test func defaultsToEmptyArray() {
        let settings = UserSettings()
        #expect(settings.seenExerciseInfo.isEmpty)
    }

    @Test func canAddExerciseId() {
        let settings = UserSettings()
        if !settings.seenExerciseInfo.contains("push_ups") {
            settings.seenExerciseInfo.append("push_ups")
        }
        #expect(settings.seenExerciseInfo.contains("push_ups"))
        #expect(settings.seenExerciseInfo.count == 1)
    }

    @Test func deduplicatesOnWrite() {
        let settings = UserSettings()
        // Simulate the write pattern used in the UI
        func markSeen(_ id: String) {
            if !settings.seenExerciseInfo.contains(id) {
                settings.seenExerciseInfo.append(id)
            }
        }
        markSeen("push_ups")
        markSeen("push_ups")
        #expect(settings.seenExerciseInfo.count == 1)
    }
}
```

- [ ] **Step 2: Run to confirm it fails (property doesn't exist yet)**

```
swift test --package-path Shared --filter SeenExerciseInfoTests
```

Expected: FAIL — `value of type 'UserSettings' has no member 'seenExerciseInfo'`

- [ ] **Step 3: Add `seenExerciseInfo` to `UserSettings`**

In `Shared/Sources/InchShared/Models/UserSettings.swift`:

Add property (after `onboardingComplete`):
```swift
public var seenExerciseInfo: [String] = []
```

Add to `init` signature (with default):
```swift
seenExerciseInfo: [String] = []
```

Add to `init` body:
```swift
self.seenExerciseInfo = seenExerciseInfo
```

- [ ] **Step 4: Run tests again to confirm they pass**

```
swift test --package-path Shared --filter SeenExerciseInfoTests
```

Expected: PASS

- [ ] **Step 5: Add `BodyweightSchemaV3` and extend the migration plan**

In `Shared/Sources/InchShared/Models/BodyweightSchema.swift`, after the existing V2 block, add:

```swift
// V3 schema — adds seenExerciseInfo, isFirstLaunch, analyticsEnabled,
// achievementNotificationEnabled to UserSettings; adds adaptation fields
// to ExerciseEnrolment; adds Achievement model.
// All new fields have defaults. Lightweight migration.
public enum BodyweightSchemaV3: VersionedSchema {
    public static let versionIdentifier = Schema.Version(3, 0, 0)
    public static var models: [any PersistentModel.Type] {
        [
            ExerciseDefinition.self,
            LevelDefinition.self,
            DayPrescription.self,
            ExerciseEnrolment.self,
            CompletedSet.self,
            SensorRecording.self,
            UserSettings.self,
            StreakState.self,
            UserEntitlement.self
            // Achievement.self  — uncomment when Achievements plan adds the model
        ]
    }
}
```

In the `BodyweightMigrationPlan`, add V3 to `schemas` and a new lightweight stage:

```swift
public static var schemas: [any VersionedSchema.Type] {
    [BodyweightSchemaV1.self, BodyweightSchemaV2.self, BodyweightSchemaV3.self]
}
public static var stages: [MigrationStage] {
    [migrateV1toV2, migrateV2toV3]
}

static let migrateV2toV3 = MigrationStage.lightweight(
    fromVersion: BodyweightSchemaV2.self,
    toVersion: BodyweightSchemaV3.self
)
```

- [ ] **Step 6: Update `ModelContainerFactory` to use the migration plan**

In `Shared/Sources/InchShared/Utilities/ModelContainerFactory.swift`, replace:

```swift
let schema = Schema(BodyweightSchemaV2.models)
```

with:

```swift
let schema = Schema(BodyweightSchemaV3.models)
```

And replace the `ModelContainer` initialiser call:

```swift
return try ModelContainer(for: schema, configurations: [config])
```

with:

```swift
return try ModelContainer(
    for: schema,
    migrationPlan: BodyweightMigrationPlan.self,
    configurations: [config]
)
```

- [ ] **Step 7: Build to verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 8: Commit**

```bash
git add Shared/Sources/InchShared/Models/UserSettings.swift \
        Shared/Sources/InchShared/Models/BodyweightSchema.swift \
        Shared/Sources/InchShared/Utilities/ModelContainerFactory.swift \
        Shared/Tests/InchSharedTests/SeenExerciseInfoTests.swift
git commit -m "$(cat <<'EOF'
feat: add BodyweightSchemaV3 migration with seenExerciseInfo on UserSettings

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Create `ExerciseContent` static lookup

**Files:**
- Create: `inch/inch/Features/Workout/ExerciseContent.swift`

- [ ] **Step 1: Write the failing test for content completeness**

Create `Shared/Tests/InchSharedTests/ExerciseContentTests.swift`:

```swift
import Testing
@testable import InchShared

// This test verifies that ExerciseContent has entries for all 6 exercises × 3 levels.
// It imports from the app target — adjust the import if needed once the file is in place.
```

> Note: `ExerciseContent` lives in the `inch` app target, not `InchShared`. Write the content completeness check as a build-time assertion (using `precondition` or a compile-time array) or verify manually after building. Skip an automated test for this task; instead, verify at the end of step 2.

- [ ] **Step 2: Create `ExerciseContent.swift`**

```swift
import Foundation

struct ExerciseInfo {
    let muscles: [String]
    let setup: String
    let movement: String
    let focus: String
    let commonMistake: String
    let levelTip: String
}

enum ExerciseContent {
    static func info(exerciseId: String, level: Int) -> ExerciseInfo? {
        return lookup[exerciseId]?[level]
    }

    private static let lookup: [String: [Int: ExerciseInfo]] = [
        "push_ups": [
            1: ExerciseInfo(
                muscles: ["Chest", "Triceps", "Core"],
                setup: "Hands under shoulders, body in a straight line from head to heels.",
                movement: "Lower chest to an inch above the floor, then press fully back up.",
                focus: "Keep your core tight — don't let your hips sag.",
                commonMistake: "Flaring elbows wide — keep them at roughly 45° from your torso.",
                levelTip: "At Level 1 focus on full range of motion over speed."
            ),
            2: ExerciseInfo(
                muscles: ["Chest", "Triceps", "Core"],
                setup: "Hands wider than shoulder-width, body in a straight line.",
                movement: "Lower chest to the floor, press back up with control.",
                focus: "Feel the stretch across your chest at the bottom.",
                commonMistake: "Partial reps — go all the way down on every rep.",
                levelTip: "Wide grip loads the chest more — use a full range of motion."
            ),
            3: ExerciseInfo(
                muscles: ["Chest", "Triceps", "Core"],
                setup: "Hands close together, index fingers and thumbs forming a diamond.",
                movement: "Lower chest toward your hands, press back up to full extension.",
                focus: "Squeeze your triceps hard at the top of each rep.",
                commonMistake: "Wrist pain from tight position — warm up wrists before starting.",
                levelTip: "Diamond grip isolates your triceps far more than standard width."
            )
        ],
        "squats": [
            1: ExerciseInfo(
                muscles: ["Quads", "Glutes"],
                setup: "Feet hip-width, toes turned out slightly, arms forward for balance.",
                movement: "Lower until thighs are parallel to the floor, then drive back up.",
                focus: "Keep your chest tall and your weight through your heels.",
                commonMistake: "Knees caving inward — push them out in line with your toes.",
                levelTip: "At Level 1 use a doorframe for balance if needed."
            ),
            2: ExerciseInfo(
                muscles: ["Quads", "Glutes", "Hamstrings"],
                setup: "Feet hip-width, hands clasped at chest.",
                movement: "Squat to parallel, pause 1 second at the bottom, drive up.",
                focus: "The pause removes momentum — each rep starts from a dead stop.",
                commonMistake: "Rising onto toes at the bottom — keep heels flat throughout.",
                levelTip: "The 1-second pause at depth makes Level 2 significantly harder."
            ),
            3: ExerciseInfo(
                muscles: ["Quads", "Glutes", "Hamstrings", "Core"],
                setup: "Feet together, arms extended forward for balance.",
                movement: "Lower into a full squat, maintaining a tall torso throughout.",
                focus: "Narrow stance demands more ankle mobility — warm up calves first.",
                commonMistake: "Leaning heavily forward — keep your chest as vertical as possible.",
                levelTip: "Narrow stance eliminates the hip abductor assist from wide stance."
            )
        ],
        "sit_ups": [
            1: ExerciseInfo(
                muscles: ["Abs", "Hip Flexors"],
                setup: "Lie on your back, knees bent, feet flat, hands crossed on chest.",
                movement: "Curl up until elbows touch thighs, then lower with control.",
                focus: "Lead with your chest — don't yank your neck forward.",
                commonMistake: "Pulling on your neck — keep hands on chest, not behind your head.",
                levelTip: "At Level 1 focus on controlled lowering, not just the way up."
            ),
            2: ExerciseInfo(
                muscles: ["Abs", "Hip Flexors"],
                setup: "Lie on back, knees bent, arms extended straight toward the ceiling.",
                movement: "Reach your hands toward the ceiling as you curl up to sitting.",
                focus: "Arms extended removes the momentum — engage your core from the start.",
                commonMistake: "Jerking up explosively — maintain a smooth, controlled tempo.",
                levelTip: "Arms extended increases the load on your abs throughout the movement."
            ),
            3: ExerciseInfo(
                muscles: ["Abs", "Hip Flexors", "Core"],
                setup: "Lie on back, knees bent, arms overhead (hands clasped).",
                movement: "Swing arms forward to generate momentum, then engage abs to finish the sit-up.",
                focus: "Control the descent — don't collapse back down.",
                commonMistake: "Using all arm momentum — the abs must still engage to complete the rep.",
                levelTip: "Arms overhead increases the range of motion and load on your abs."
            )
        ],
        "pull_ups": [
            1: ExerciseInfo(
                muscles: ["Back", "Biceps"],
                setup: "Hang from a bar with palms facing away, hands shoulder-width.",
                movement: "Pull your chin over the bar, then lower fully until arms are straight.",
                focus: "Think about pulling your elbows down toward your hips.",
                commonMistake: "Partial range of motion — fully extend at the bottom of each rep.",
                levelTip: "At Level 1 every rep from a full dead hang is the non-negotiable standard."
            ),
            2: ExerciseInfo(
                muscles: ["Back", "Biceps", "Core"],
                setup: "Hang from a bar, legs extended straight and held together.",
                movement: "Pull chin to bar with legs held straight, lower with control.",
                focus: "Keeping legs straight engages your core throughout the movement.",
                commonMistake: "Bending knees to make it easier — legs must remain extended.",
                levelTip: "Straight legs shift load to your core and make the pull harder."
            ),
            3: ExerciseInfo(
                muscles: ["Back", "Biceps", "Core"],
                setup: "Hang from a bar with a wide grip (wider than shoulder-width).",
                movement: "Pull until your upper chest touches the bar, lower fully.",
                focus: "Wide grip targets the outer lats — pull your elbows straight down.",
                commonMistake: "Swinging the body — use strict form with no kipping.",
                levelTip: "Wide grip is the most demanding pull-up variation for the lats."
            )
        ],
        "glute_bridges": [
            1: ExerciseInfo(
                muscles: ["Glutes", "Hamstrings"],
                setup: "Lie on your back, knees bent, feet flat, arms at your sides.",
                movement: "Drive hips toward the ceiling until your body forms a straight line, lower slowly.",
                focus: "Squeeze your glutes hard at the top before lowering.",
                commonMistake: "Overextending the lower back — stop when hips form a straight line with knees.",
                levelTip: "At Level 1 focus on the glute squeeze at the top of every rep."
            ),
            2: ExerciseInfo(
                muscles: ["Glutes", "Hamstrings", "Core"],
                setup: "Lie on back, one leg extended straight, the other knee bent.",
                movement: "Drive hips up using only the bent-knee leg, hold briefly, lower slowly.",
                focus: "Keep hips level — don't let the unsupported side drop.",
                commonMistake: "Hips tilting to one side — brace your core to stay level.",
                levelTip: "Single-leg doubles the load on each glute compared to the standard bridge."
            ),
            3: ExerciseInfo(
                muscles: ["Glutes", "Hamstrings", "Core"],
                setup: "Sit on the floor with your upper back against a bench, feet flat, knees bent.",
                movement: "Drive hips up until your body is parallel to the floor, lower slowly.",
                focus: "The elevated torso increases hip range of motion — use full depth.",
                commonMistake: "Letting the hips drop too quickly — control the descent.",
                levelTip: "Hip thrust allows greater range and load than a floor bridge."
            )
        ],
        "dead_bugs": [
            1: ExerciseInfo(
                muscles: ["Core", "Abs"],
                setup: "Lie on your back, arms pointing toward ceiling, hips and knees at 90°.",
                movement: "Slowly lower opposite arm and leg toward the floor, return, alternate sides.",
                focus: "Press your lower back flat into the floor throughout the movement.",
                commonMistake: "Lower back arching off the floor — if it lifts, reduce your range of motion.",
                levelTip: "At Level 1 move slowly and focus entirely on keeping your back flat."
            ),
            2: ExerciseInfo(
                muscles: ["Core", "Abs", "Hip Flexors"],
                setup: "Same starting position — arms up, legs at 90°.",
                movement: "Extend arm and *same-side* leg (ipsilateral), return, alternate.",
                focus: "Same-side extension is harder to stabilise — brace harder.",
                commonMistake: "Rushing the movement — slow down to maintain lumbar contact.",
                levelTip: "Ipsilateral (same-side) extension challenges rotational stability more."
            ),
            3: ExerciseInfo(
                muscles: ["Core", "Abs", "Hip Flexors", "Shoulders"],
                setup: "Same starting position, holding a light weight or medicine ball overhead.",
                movement: "Lower opposite arm and leg toward the floor with added resistance, return.",
                focus: "The weight amplifies any instability — move even more deliberately.",
                commonMistake: "Letting the weight pull your arm down too fast — resist it.",
                levelTip: "Added resistance at Level 3 significantly increases anti-extension demand."
            )
        ]
    ]
}
```

- [ ] **Step 3: Verify all 6 exercises × 3 levels are present**

Run:
```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Count entries in the lookup manually. Each of the 6 exercise IDs must have levels 1, 2, and 3.

- [ ] **Step 4: Commit**

```bash
git add inch/inch/Features/Workout/ExerciseContent.swift
git commit -m "$(cat <<'EOF'
feat: add static ExerciseContent lookup with coaching cues for all exercises

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Create `LoopingVideoView`

**Files:**
- Create: `inch/inch/Features/Workout/LoopingVideoView.swift`

This is the only component in the project that uses UIKit types. `AVPlayerLayer` is a QuartzCore type with no native SwiftUI equivalent for looping muted video. The wrapper is self-contained and does not expose UIKit types to callers.

- [ ] **Step 1: Create `LoopingVideoView.swift`**

```swift
import SwiftUI
import AVFoundation

/// Displays a muted, looping MP4 clip. Falls back to a static image if the
/// video cannot be loaded. This is the only UIViewRepresentable in the app —
/// AVPlayerLayer has no native SwiftUI equivalent for looping muted video.
struct LoopingVideoView: UIViewRepresentable {
    let exerciseId: String
    let fallbackImageName: String

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        // Configure audio session so the clip doesn't interrupt music playback
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: .mixWithOthers)

        guard !UIAccessibility.isReduceMotionEnabled,
              let url = Bundle.main.url(forResource: exerciseId, withExtension: "mp4") else {
            // Fallback: show static image
            addFallbackImage(to: view)
            return view
        }

        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        view.layer.addSublayer(playerLayer)
        context.coordinator.player = player
        context.coordinator.playerLayer = playerLayer

        // Loop on end
        context.coordinator.loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        player.play()
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // Keep playerLayer frame in sync with view bounds
        context.coordinator.playerLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(fallbackImageName: fallbackImageName)
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.player?.pause()
        if let observer = coordinator.loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func addFallbackImage(to view: UIView) {
        let imageView = UIImageView(image: UIImage(named: fallbackImageName))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    final class Coordinator: NSObject {
        var player: AVPlayer?
        var playerLayer: AVPlayerLayer?
        var loopObserver: Any?
        let fallbackImageName: String

        init(fallbackImageName: String) {
            self.fallbackImageName = fallbackImageName
        }
    }
}
```

> **Media dependency:** Exercise MP4 clips must be in `Resources/ExerciseMedia/` bundled with the app, named by `exerciseId` (e.g. `push_ups.mp4`). Until video assets are purchased and added, `LoopingVideoView` will display the fallback image. Purchase from gym-animations.com or exerciseanimatic.com. This is a content dependency, not a code blocker.

- [ ] **Step 2: Build to verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 3: Commit**

```bash
git add inch/inch/Features/Workout/LoopingVideoView.swift
git commit -m "$(cat <<'EOF'
feat: add LoopingVideoView UIViewRepresentable for muted exercise demo clips

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Create `ExerciseInfoSheet` and `ExerciseInfoButton`

**Files:**
- Create: `inch/inch/Features/Workout/ExerciseInfoSheet.swift`
- Create: `inch/inch/Features/Workout/ExerciseInfoButton.swift`

- [ ] **Step 1: Create `ExerciseInfoSheet.swift`**

```swift
import SwiftUI

struct ExerciseInfoSheet: View {
    let exerciseId: String
    let exerciseName: String
    let level: Int

    private var info: ExerciseInfo? {
        ExerciseContent.info(exerciseId: exerciseId, level: level)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Looping demo video
                LoopingVideoView(
                    exerciseId: exerciseId,
                    fallbackImageName: exerciseId
                )
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if let info {
                    // Muscle tags
                    HStack {
                        ForEach(info.muscles, id: \.self) { muscle in
                            Text(muscle)
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.secondary.opacity(0.15), in: Capsule())
                        }
                    }

                    // How to do it
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to do it")
                            .font(.headline)
                        VStack(alignment: .leading, spacing: 6) {
                            bulletRow(info.setup)
                            bulletRow(info.movement)
                            bulletRow(info.focus)
                        }
                    }

                    // Common mistake
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Common mistake")
                            .font(.headline)
                        bulletRow(info.commonMistake)
                    }

                    // Level tip
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Level \(level) tip")
                            .font(.headline)
                        Text(info.levelTip)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Content not available.")
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 24)
            }
            .padding()
        }
        .navigationTitle(exerciseName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
        }
    }
}
```

- [ ] **Step 2: Create `ExerciseInfoButton.swift`**

```swift
import SwiftUI

/// A reusable ⓘ button that presents ExerciseInfoSheet as a sheet.
/// Place next to any exercise name in the UI.
struct ExerciseInfoButton: View {
    let exerciseId: String
    let exerciseName: String
    let level: Int

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                ExerciseInfoSheet(
                    exerciseId: exerciseId,
                    exerciseName: exerciseName,
                    level: level
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { isPresented = false }
                    }
                }
            }
        }
        .accessibilityLabel("Exercise info for \(exerciseName)")
    }
}
```

- [ ] **Step 3: Build to verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 4: Commit**

```bash
git add inch/inch/Features/Workout/ExerciseInfoSheet.swift \
        inch/inch/Features/Workout/ExerciseInfoButton.swift
git commit -m "$(cat <<'EOF'
feat: add ExerciseInfoSheet and ExerciseInfoButton components

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Wire `ExerciseInfoButton` into `ExerciseCard` (Today tab)

**Files:**
- Modify: `inch/inch/Features/Today/ExerciseCard.swift`

- [ ] **Step 1: Read ExerciseCard**

Open `inch/inch/Features/Today/ExerciseCard.swift` to locate where the exercise name is displayed. You need `exerciseId`, `exerciseName`, and `level` to be available in this context (they are almost certainly already there since the card shows this data).

- [ ] **Step 2: Add `ExerciseInfoButton` next to the exercise name**

Find the exercise name `Text` view (likely `Text(exercise.name)` or similar) and wrap it with an `HStack` that includes the info button:

```swift
HStack {
    Text(exerciseName)  // use the actual variable name
        .font(.headline)
    ExerciseInfoButton(
        exerciseId: exerciseId,   // use the actual variable name
        exerciseName: exerciseName,
        level: currentLevel       // use the actual variable name
    )
}
```

- [ ] **Step 3: Build and verify visually on simulator**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Run on simulator. Confirm the ⓘ button appears next to each exercise name on the Today tab. Tap it — the info sheet should appear.

- [ ] **Step 4: Commit**

```bash
git add inch/inch/Features/Today/ExerciseCard.swift
git commit -m "$(cat <<'EOF'
feat: add ExerciseInfoButton to ExerciseCard on Today tab

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Create `ExerciseNudgeBanner` and Tier 3 intro; wire into `WorkoutSessionView`

**Files:**
- Create: `inch/inch/Features/Workout/ExerciseNudgeBanner.swift`
- Modify: `inch/inch/Features/Workout/WorkoutSessionView.swift`

- [ ] **Step 1: Create `ExerciseNudgeBanner.swift`**

```swift
import SwiftUI

struct ExerciseNudgeBanner: View {
    let exerciseName: String
    let onDismiss: () -> Void   // called when user taps ✕ or starts a set

    var body: some View {
        HStack(spacing: 12) {
            Text("First time doing \(exerciseName)? Tap ⓘ to see how.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Dismiss hint")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
    }
}
```

- [ ] **Step 2: Add nudge and Tier 3 intro logic to `WorkoutSessionView`**

Read `WorkoutSessionView.swift` fully first. The pre-set "ready" screen is where `phase == .ready` is shown. You need to:

1. Add `@Query private var allSettings: [UserSettings]` (already present — check).
2. Add computed property `private var settings: UserSettings? { allSettings.first }`.
3. Add `@State private var showTier3Intro = false` and `@State private var showNudge = false`.
4. On `.onAppear` (or `.task`) when `phase == .ready` and `currentSetIndex == 0`:
   - Check if exercise should show Tier 3 intro (only `dead_bugs` and `glute_bridges`, and only if `exerciseId` is NOT in `settings?.seenExerciseInfo`):
     ```swift
     let tier3Exercises = ["dead_bugs", "glute_bridges"]
     if tier3Exercises.contains(exerciseId),
        let s = settings,
        !s.seenExerciseInfo.contains(exerciseId) {
         showTier3Intro = true
     } else if let s = settings, !s.seenExerciseInfo.contains(exerciseId) {
         showNudge = true
     }
     ```
5. Show `ExerciseNudgeBanner` when `showNudge && phase == .ready && currentSetIndex == 0`:
   ```swift
   if showNudge && viewModel.phase == .ready && viewModel.currentSetIndex == 0 {
       ExerciseNudgeBanner(exerciseName: viewModel.exerciseName) {
           dismissNudge()
       }
   }
   ```
6. Add `dismissNudge()` helper that writes `exerciseId` to `seenExerciseInfo` and sets `showNudge = false`:
   ```swift
   private func dismissNudge() {
       showNudge = false
       markExerciseSeen()
   }

   private func markExerciseSeen() {
       guard let s = settings,
             !s.seenExerciseInfo.contains(exerciseId) else { return }
       s.seenExerciseInfo.append(exerciseId)
       try? modelContext.save()
   }
   ```
7. Also call `dismissNudge()` (without writing to settings a second time — use `showNudge = false` only) when the user taps "Start Set". Find the "Start Set" button action and add `showNudge = false` before or after the `viewModel.startSet()` call.
8. Add Tier 3 intro sheet:
   ```swift
   .sheet(isPresented: $showTier3Intro, onDismiss: markExerciseSeen) {
       NavigationStack {
           ExerciseInfoSheet(
               exerciseId: exerciseId,
               exerciseName: viewModel.exerciseName,
               level: viewModel.enrolment?.currentLevel ?? 1
           )
           .toolbar {
               ToolbarItem(placement: .confirmationAction) {
                   Button("Got it") { showTier3Intro = false }
               }
           }
       }
   }
   ```

- [ ] **Step 3: Build and verify**

```
xcodebuild build -project inch/inch.xcodeproj -scheme inch -destination 'generic/platform=iOS Simulator' | grep -E '(error:|Build succeeded)'
```

Expected: `Build succeeded`

- [ ] **Step 4: Manual test on simulator**

Fresh install (or reset `seenExerciseInfo` via Settings reset). Start a Dead Bug or Glute Bridge session — the Tier 3 intro sheet should appear. Tap "Got it" and re-enter the session — it should not appear again. For Push-Ups, the nudge banner should appear instead. Tap ✕ or tap "Start Set" — both should dismiss and not show again.

- [ ] **Step 5: Commit**

```bash
git add inch/inch/Features/Workout/ExerciseNudgeBanner.swift \
        inch/inch/Features/Workout/WorkoutSessionView.swift
git commit -m "$(cat <<'EOF'
feat: add first-occurrence nudge and Tier 3 intro for unfamiliar exercises

Dead Bug and Glute Bridge show a pre-session intro sheet on first encounter.
All other exercises show a dismissable inline nudge on the pre-set screen.
Both write exerciseId to seenExerciseInfo to prevent repeat showings.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```
