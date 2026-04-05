import AudioToolbox

enum WorkoutSounds {
    /// Short tick played at 3, 2, 1 seconds remaining on the rest timer.
    static func playCountdownTick() {
        AudioServicesPlaySystemSound(1057) // Tock
    }

    /// Prominent beep played when rest ends or the user starts a set.
    static func playGo() {
        AudioServicesPlaySystemSound(1322)
    }

    /// Soft click played on every metronome beat.
    static func playMetronomeBeat() {
        AudioServicesPlaySystemSound(1306) // Tink — lighter than Tock, distinct from rest timer
    }
}
