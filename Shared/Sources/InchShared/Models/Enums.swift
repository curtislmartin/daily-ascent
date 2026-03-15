import Foundation

enum MuscleGroup: String, Codable, Sendable, CaseIterable {
    case upperPush = "upper_push"
    case upperPull = "upper_pull"
    case lower = "lower"
    case lowerPosterior = "lower_posterior"
    case coreFlexion = "core_flexion"
    case coreStability = "core_stability"

    /// Muscle groups that conflict with each other for test day isolation
    var conflictGroups: [MuscleGroup] {
        switch self {
        case .upperPush: [.upperPush]
        case .upperPull: [.upperPull]
        case .lower, .lowerPosterior: [.lower, .lowerPosterior]
        case .coreFlexion, .coreStability: [.coreFlexion, .coreStability]
        }
    }
}

enum CountingMode: String, Codable, Sendable {
    case realTime = "real_time"
    case postSetConfirmation = "post_set_confirmation"
}

enum SensorDevice: String, Codable, Sendable {
    case iPhone
    case appleWatch
}

enum UploadStatus: String, Codable, Sendable {
    case pending
    case uploading
    case uploaded
    case failed
    case localOnly
}
