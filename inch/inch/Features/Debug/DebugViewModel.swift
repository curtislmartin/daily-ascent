#if DEBUG
import Foundation
import SwiftData
import UserNotifications
import InchShared

@Observable
final class DebugViewModel {
    // MARK: - Checkmark State

    private let defaults = UserDefaults.standard

    func isDone(_ key: DebugCheckKey) -> Bool {
        defaults.bool(forKey: key.rawValue)
    }

    func markDone(_ key: DebugCheckKey) {
        defaults.set(true, forKey: key.rawValue)
    }

    func resetAllDone() {
        for key in DebugCheckKey.allCases {
            defaults.removeObject(forKey: key.rawValue)
        }
    }

    // MARK: - Info Alert State (non-destructive feedback)

    var alertTitle: String = ""
    var alertMessage: String = ""
    var showAlert: Bool = false

    // MARK: - Danger Confirmation State

    var dangerTitle: String = ""
    var dangerMessage: String = ""
    var pendingDangerAction: (() -> Void)? = nil
    var showDangerConfirmation: Bool = false

    func confirmDanger(title: String, message: String, action: @escaping () -> Void) {
        dangerTitle = title
        dangerMessage = message
        pendingDangerAction = action
        showDangerConfirmation = true
    }
}
#endif
