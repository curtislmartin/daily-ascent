import Foundation

struct ExerciseInfo {
    let muscles: [String]
    let setup: String
    let movement: String
    let focus: String
    let commonMistake: String
    let levelTip: String
    /// YouTube video ID (the part after ?v= in the URL). Empty = shows "Video coming soon".
    var youtubeVideoId: String = ""
}

enum ExerciseContent {
    static func info(exerciseId: String, level: Int) -> ExerciseInfo? {
        lookup[exerciseId]?[level]
    }

    // swiftlint:disable line_length
    private static let lookup: [String: [Int: ExerciseInfo]] = [
        "push_ups": [
            0: ExerciseInfo(
                muscles: ["Chest", "Triceps", "Core"],
                setup: "Hands on a bench, counter, or sturdy elevated surface. Body in a straight line.",
                movement: "Lower your chest toward the surface, then press back up to full arm extension.",
                focus: "Keep your core tight — the incline makes it easier, but the form is the same as a full push-up.",
                commonMistake: "Sagging hips — maintain a rigid plank from head to heels.",
                levelTip: "The higher the surface, the easier it is. Start with a counter and work down to a bench."
            ),
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
        "pull_ups": [
            0: ExerciseInfo(
                muscles: ["Back", "Biceps"],
                setup: "Stand under a bar you can reach by jumping. Grip with palms facing away, shoulder-width.",
                movement: "Jump to get your chin above the bar, then lower yourself as slowly as possible (3-5 seconds).",
                focus: "Resist gravity on the way down — the slower you lower, the stronger you get.",
                commonMistake: "Dropping fast — if the descent takes less than 2 seconds, you're not getting the benefit.",
                levelTip: "Negatives build the pulling strength you need for a full pull-up. Focus on control, not speed."
            ),
            1: ExerciseInfo(
                muscles: ["Back", "Biceps"],
                setup: "Hang from a bar with palms facing away, hands shoulder-width.",
                movement: "Pull your chin over the bar, then lower fully until arms are straight.",
                focus: "Think about pulling your elbows down toward your hips.",
                commonMistake: "Partial range of motion — fully extend at the bottom of each rep.",
                levelTip: "Every rep from a full dead hang is the non-negotiable standard."
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
        "dips": [
            0: ExerciseInfo(
                muscles: ["Triceps", "Chest", "Shoulders"],
                setup: "Hands on the edge of a bench behind you, feet flat on the floor, knees bent at 90 degrees.",
                movement: "Lower your body by bending elbows to about 90 degrees, then press back up.",
                focus: "Keep your back close to the bench — don't let your hips drift forward.",
                commonMistake: "Going too deep — stop at 90-degree elbow bend to protect your shoulders.",
                levelTip: "Bent knees take weight off your arms. As you get stronger, you'll extend your legs in Level 1."
            ),
            1: ExerciseInfo(
                muscles: ["Triceps", "Chest", "Shoulders"],
                setup: "Hands on the edge of a bench or chair behind you, legs extended forward.",
                movement: "Lower your body by bending your elbows to 90°, then press back up.",
                focus: "Keep your back close to the bench — don't let your hips drift forward.",
                commonMistake: "Lowering too far — stop at 90° to protect your shoulders.",
                levelTip: "Bench dips are a safe entry point — master the range before progressing."
            ),
            2: ExerciseInfo(
                muscles: ["Triceps", "Chest", "Shoulders"],
                setup: "Grip two parallel bars with straight arms, body hanging freely.",
                movement: "Lower until your upper arms are parallel to the floor, press back to full extension.",
                focus: "Lean slightly forward to recruit more chest; stay upright to target triceps.",
                commonMistake: "Flaring elbows out — keep them tracking back, not sideways.",
                levelTip: "Parallel bar dips require shoulder stability you don't need on a bench."
            ),
            3: ExerciseInfo(
                muscles: ["Triceps", "Chest", "Shoulders", "Core"],
                setup: "Grip parallel bars, legs crossed and tucked or straight.",
                movement: "Lower below parallel (upper arms past horizontal), press back up.",
                focus: "Full depth increases chest recruitment — only go deeper if shoulders are healthy.",
                commonMistake: "Bouncing out of the bottom — pause briefly, then press.",
                levelTip: "Deep dips demand significant shoulder mobility and stability — earn this range."
            )
        ],
        "rows": [
            1: ExerciseInfo(
                muscles: ["Back", "Biceps", "Core"],
                setup: "Lie under a table or low bar, grip with palms facing away, body in a straight line.",
                movement: "Pull your chest up to the bar, lower with control until arms are fully extended.",
                focus: "Keep your body rigid — don't let your hips sag.",
                commonMistake: "Pulling with arms only — initiate by retracting your shoulder blades.",
                levelTip: "The higher the bar (more inclined body angle), the easier the row."
            ),
            2: ExerciseInfo(
                muscles: ["Back", "Biceps", "Core"],
                setup: "Grip a low bar with body horizontal to the floor, heels on the ground.",
                movement: "Pull chest to bar, lower until arms are straight.",
                focus: "Keep your core braced — your body should be a straight plank throughout.",
                commonMistake: "Hips dropping at the top — squeeze your glutes to stay rigid.",
                levelTip: "Horizontal body angle means you're lifting close to full bodyweight."
            ),
            3: ExerciseInfo(
                muscles: ["Back", "Biceps", "Core"],
                setup: "Grip a low bar with feet elevated on a chair or bench, body angled past horizontal.",
                movement: "Pull chest to bar, lower with full control.",
                focus: "Feet elevated shifts more weight to the upper body — brace harder.",
                commonMistake: "Jerking or using momentum — slow the eccentric to build strength.",
                levelTip: "Feet elevated rows are as close as bodyweight gets to a weighted bent-over row."
            )
        ],
        "hip_hinge": [
            1: ExerciseInfo(
                muscles: ["Hamstrings", "Glutes", "Lower Back"],
                setup: "Stand with feet hip-width, hands on hips or crossed on chest.",
                movement: "Push hips back while keeping a neutral spine, lowering torso toward horizontal, then drive hips forward to stand.",
                focus: "Think about your hips moving backward, not your torso moving downward.",
                commonMistake: "Rounding the lower back — maintain a neutral spine throughout.",
                levelTip: "At Level 1 practise near a wall to feel your hips push back."
            ),
            2: ExerciseInfo(
                muscles: ["Hamstrings", "Glutes", "Lower Back", "Core"],
                setup: "Stand on one leg, hands on hips, slight bend in the standing knee.",
                movement: "Hinge forward at the hip, extending the free leg behind you, return to standing.",
                focus: "Keep your hips square — the free leg should not rotate outward.",
                commonMistake: "Letting the standing hip hike up — keep both hips level throughout.",
                levelTip: "Single-leg hinge doubles the demand on each glute and challenges balance."
            ),
            3: ExerciseInfo(
                muscles: ["Hamstrings", "Glutes", "Lower Back", "Core"],
                setup: "Stand with feet hip-width, hands behind your head.",
                movement: "Hinge slowly to horizontal, pause 2 seconds, return to standing with control.",
                focus: "The pause removes all momentum — your posterior chain must produce the force.",
                commonMistake: "Rushing out of the pause — hold the full 2 seconds on every rep.",
                levelTip: "The pause at the bottom is what makes Level 3 disproportionately harder."
            )
        ],
        "spinal_extension": [
            1: ExerciseInfo(
                muscles: ["Lower Back", "Glutes", "Hamstrings"],
                setup: "Lie face down, arms at your sides, forehead resting on the floor.",
                movement: "Lift your chest and legs off the floor simultaneously, hold 1 second, lower.",
                focus: "Squeeze your glutes to protect your lower back as you lift.",
                commonMistake: "Lifting too high — a small, controlled lift is safer and more effective.",
                levelTip: "At Level 1 focus on the squeeze at the top, not the height of the lift."
            ),
            2: ExerciseInfo(
                muscles: ["Lower Back", "Glutes", "Hamstrings", "Shoulders"],
                setup: "Lie face down, arms extended overhead (Y-position).",
                movement: "Lift arms, chest, and legs off the floor simultaneously, hold briefly, lower.",
                focus: "Arms overhead increases the lever arm — the lift will feel much harder.",
                commonMistake: "Bending the elbows to cheat the range — keep arms straight throughout.",
                levelTip: "Extended arms make Level 2 significantly harder than Level 1."
            ),
            3: ExerciseInfo(
                muscles: ["Lower Back", "Glutes", "Hamstrings", "Shoulders"],
                setup: "Lie face down, arms extended overhead.",
                movement: "Lift into the superman position, hold 3 seconds, lower with control.",
                focus: "A 3-second hold per rep turns this into an isometric strength exercise.",
                commonMistake: "Losing position during the hold — maintain full extension for the count.",
                levelTip: "The extended hold at Level 3 builds spinal erector endurance, not just strength."
            )
        ],
        "plank": [
            1: ExerciseInfo(
                muscles: ["Core", "Abs", "Shoulders"],
                setup: "Forearms on the floor, elbows under shoulders, body in a straight line from head to heels.",
                movement: "Hold the position for the prescribed duration, breathing steadily.",
                focus: "Press your forearms into the floor and pull your elbows toward your feet — this creates full-body tension.",
                commonMistake: "Hips rising or sagging — your body should form a single rigid plank.",
                levelTip: "At Level 1 build to 60 seconds before progressing — time under tension is the goal."
            ),
            2: ExerciseInfo(
                muscles: ["Core", "Abs", "Shoulders", "Chest"],
                setup: "Hands on the floor under shoulders, arms straight, body in a straight line.",
                movement: "Hold the high plank position for the prescribed duration.",
                focus: "Actively push the floor away — don't just hang in the position.",
                commonMistake: "Letting the lower back arch — keep your pelvis neutral throughout.",
                levelTip: "High plank increases shoulder and wrist demand compared to forearm plank."
            ),
            3: ExerciseInfo(
                muscles: ["Core", "Abs", "Shoulders", "Glutes"],
                setup: "High plank position, feet on an elevated surface (bench or chair).",
                movement: "Hold the feet-elevated plank for the prescribed duration.",
                focus: "Elevated feet shift more load to your shoulders and upper core — brace harder.",
                commonMistake: "Hips hiking up — keep your body in a straight downward-angled line.",
                levelTip: "Even a small elevation significantly increases the difficulty of the hold."
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
                movement: "Extend arm and same-side leg (ipsilateral), return, alternate.",
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
    // swiftlint:enable line_length

    /// Per-exercise metronome guidance bullets. Returns nil for non-metronome exercises.
    static func metronomeBullets(for exerciseId: String) -> [String]? {
        switch exerciseId {
        case "dead_bugs":
            [
                "The beat paces every rep.",
                "Extend your arm and opposite leg on the pulse, then return.",
                "The screen shows which side is next — it switches automatically."
            ]
        case "hip_hinge":
            [
                "The beat sets your tempo.",
                "Hinge your hips back on the strong pulse.",
                "Return to standing on the soft pulse. Slow and controlled."
            ]
        case "spinal_extension":
            [
                "The beat controls your pace.",
                "Lift on the first pulse, lower slowly on the second.",
                "Both beats are equal — there's no rush phase."
            ]
        default:
            nil
        }
    }
}
