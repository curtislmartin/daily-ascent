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
