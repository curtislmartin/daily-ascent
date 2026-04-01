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
