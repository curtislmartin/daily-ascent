import Foundation

@Observable @MainActor final class WatchSettings {
    var showHeartRate: Bool = true {
        didSet { UserDefaults.standard.set(showHeartRate, forKey: "watch.showHeartRate") }
    }
    var heartRateAlertBPM: Int = 0 {
        didSet { UserDefaults.standard.set(heartRateAlertBPM, forKey: "watch.heartRateAlertBPM") }
    }
    var autoAdvanceAfterRest: Bool = false {
        didSet { UserDefaults.standard.set(autoAdvanceAfterRest, forKey: "watch.autoAdvanceAfterRest") }
    }
    var hapticFinalCountdown: Bool = true {
        didSet { UserDefaults.standard.set(hapticFinalCountdown, forKey: "watch.hapticFinalCountdown") }
    }

    init() {
        let ud = UserDefaults.standard
        if let v = ud.object(forKey: "watch.showHeartRate") as? Bool { showHeartRate = v }
        if let v = ud.object(forKey: "watch.heartRateAlertBPM") as? Int { heartRateAlertBPM = v }
        if let v = ud.object(forKey: "watch.autoAdvanceAfterRest") as? Bool { autoAdvanceAfterRest = v }
        if let v = ud.object(forKey: "watch.hapticFinalCountdown") as? Bool { hapticFinalCountdown = v }
    }
}
