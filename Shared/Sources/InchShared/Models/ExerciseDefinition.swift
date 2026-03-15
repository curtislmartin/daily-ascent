import SwiftData

@Model
final class ExerciseDefinition {
    var exerciseId: String = ""
    var name: String = ""
    var muscleGroup: MuscleGroup = MuscleGroup.upperPush
    var color: String = ""
    var countingMode: CountingMode = CountingMode.postSetConfirmation
    var defaultRestSeconds: Int = 60
    var sortOrder: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \LevelDefinition.exercise)
    var levels: [LevelDefinition]? = []

    @Relationship(deleteRule: .nullify, inverse: \ExerciseEnrolment.exerciseDefinition)
    var enrolments: [ExerciseEnrolment]? = []

    init(exerciseId: String = "", name: String = "", muscleGroup: MuscleGroup = .upperPush, color: String = "", countingMode: CountingMode = .postSetConfirmation, defaultRestSeconds: Int = 60, sortOrder: Int = 0) {
        self.exerciseId = exerciseId
        self.name = name
        self.muscleGroup = muscleGroup
        self.color = color
        self.countingMode = countingMode
        self.defaultRestSeconds = defaultRestSeconds
        self.sortOrder = sortOrder
    }
}
