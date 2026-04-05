import SwiftData

@Model
public final class ExerciseDefinition {
    public var exerciseId: String = ""
    public var name: String = ""
    public var muscleGroup: MuscleGroup = MuscleGroup.upperPush
    public var color: String = ""
    public var countingMode: CountingMode = CountingMode.postSetConfirmation
    public var defaultRestSeconds: Int = 60
    public var sortOrder: Int = 0
    public var metronomeBeatIntervalSeconds: Double = 0
    public var metronomeBeatPattern: [String] = []
    public var metronomeSidesPerRep: Int = 1

    @Relationship(deleteRule: .cascade, inverse: \LevelDefinition.exercise)
    public var levels: [LevelDefinition]? = []

    @Relationship(deleteRule: .nullify, inverse: \ExerciseEnrolment.exerciseDefinition)
    public var enrolments: [ExerciseEnrolment]? = []

    public init(
        exerciseId: String = "",
        name: String = "",
        muscleGroup: MuscleGroup = .upperPush,
        color: String = "",
        countingMode: CountingMode = .postSetConfirmation,
        defaultRestSeconds: Int = 60,
        sortOrder: Int = 0,
        metronomeBeatIntervalSeconds: Double = 0,
        metronomeBeatPattern: [String] = [],
        metronomeSidesPerRep: Int = 1
    ) {
        self.exerciseId = exerciseId
        self.name = name
        self.muscleGroup = muscleGroup
        self.color = color
        self.countingMode = countingMode
        self.defaultRestSeconds = defaultRestSeconds
        self.sortOrder = sortOrder
        self.metronomeBeatIntervalSeconds = metronomeBeatIntervalSeconds
        self.metronomeBeatPattern = metronomeBeatPattern
        self.metronomeSidesPerRep = metronomeSidesPerRep
    }
}
