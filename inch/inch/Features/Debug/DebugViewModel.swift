#if DEBUG
import Foundation
import SwiftData
import UserNotifications
import InchShared

@Observable
final class DebugViewModel {
    // MARK: - Checkmark State

    private let defaults = UserDefaults.standard
    private var doneKeys: Set<DebugCheckKey>  // @Observable-tracked mirror of UserDefaults

    init() {
        doneKeys = Set(DebugCheckKey.allCases.filter {
            UserDefaults.standard.bool(forKey: $0.rawValue)
        })
    }

    func isDone(_ key: DebugCheckKey) -> Bool {
        doneKeys.contains(key)
    }

    func markDone(_ key: DebugCheckKey) {
        doneKeys.insert(key)
        defaults.set(true, forKey: key.rawValue)
    }

    func resetAllDone() {
        doneKeys.removeAll()
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
