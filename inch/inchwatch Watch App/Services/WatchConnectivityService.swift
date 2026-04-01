import Foundation
import WatchConnectivity
import InchShared

@Observable
final class WatchConnectivityService: NSObject, WCSessionDelegate {
    private var wcSession: WCSession?
    private let sessionsKey = "watchSessions"

    // let constants so nonisolated delegate methods can access them safely
    private let sessionContinuation: AsyncStream<[WatchSession]>.Continuation
    private let sessionStream: AsyncStream<[WatchSession]>
    private let _recordingTriggers: AsyncStream<WatchRecordingTrigger>.Continuation
    let recordingTriggers: AsyncStream<WatchRecordingTrigger>
    private let _historyEntries: AsyncStream<WatchHistoryEntry>.Continuation
    let historyEntries: AsyncStream<WatchHistoryEntry>

    var sessions: [WatchSession] = []
    var lastSyncDate: Date? = nil

    override init() {
        let (stream, continuation) = AsyncStream<[WatchSession]>.makeStream()
        sessionStream = stream
        sessionContinuation = continuation
        let (triggerStream, triggerContinuation) = AsyncStream<WatchRecordingTrigger>.makeStream()
        recordingTriggers = triggerStream
        _recordingTriggers = triggerContinuation
        let (historyStream, historyContinuation) = AsyncStream<WatchHistoryEntry>.makeStream()
        historyEntries = historyStream
        _historyEntries = historyContinuation
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        wcSession = WCSession.default
        wcSession?.delegate = self
        wcSession?.activate()
        loadStoredSessions()
    }

    func processSessions() async {
        for await received in sessionStream {
            sessions = received
            lastSyncDate = .now
            store(received)
        }
    }

    func removeSession(exerciseId: String) {
        sessions.removeAll { $0.exerciseId == exerciseId }
        store(sessions)
    }

    func sendCompletionReport(_ report: WatchCompletionReport) {
        guard let wcSession, wcSession.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(report) else { return }
        wcSession.transferUserInfo(["type": "completion", "data": data])
    }

    // MARK: - Private

    private func loadStoredSessions() {
        // Prefer the latest application context from the phone
        if let context = wcSession?.receivedApplicationContext,
           let data = context["data"] as? Data,
           let received = try? JSONDecoder().decode([WatchSession].self, from: data) {
            sessions = received
            return
        }
        // Fall back to locally cached sessions
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let stored = try? JSONDecoder().decode([WatchSession].self, from: data)
        else { return }
        sessions = stored
    }

    private func store(_ sessions: [WatchSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: sessionsKey)
    }

    // MARK: - WCSessionDelegate

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        guard let type = applicationContext["type"] as? String,
              type == "schedule",
              let data = applicationContext["data"] as? Data,
              let received = try? JSONDecoder().decode([WatchSession].self, from: data)
        else { return }
        sessionContinuation.yield(received)
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        guard let type = userInfo["type"] as? String else { return }
        switch type {
        case "schedule":
            guard let data = userInfo["data"] as? Data,
                  let received = try? JSONDecoder().decode([WatchSession].self, from: data)
            else { return }
            sessionContinuation.yield(received)
        case "historyEntry":
            guard let exerciseName = userInfo["exerciseName"] as? String,
                  let level = userInfo["level"] as? Int,
                  let dayNumber = userInfo["dayNumber"] as? Int,
                  let totalReps = userInfo["totalReps"] as? Int,
                  let setCount = userInfo["setCount"] as? Int,
                  let completedAtInterval = userInfo["completedAt"] as? Double
            else { return }
            let entry = WatchHistoryEntry(
                exerciseName: exerciseName,
                level: level,
                dayNumber: dayNumber,
                totalReps: totalReps,
                setCount: setCount,
                completedAt: Date(timeIntervalSince1970: completedAtInterval)
            )
            _historyEntries.yield(entry)
        default:
            break
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        guard let type = message["type"] as? String else { return }
        switch type {
        case "recordingStart":
            guard let exerciseId = message["exerciseId"] as? String,
                  let setNumber = message["setNumber"] as? Int,
                  let sessionId = message["sessionId"] as? String
            else { return }
            _recordingTriggers.yield(.start(exerciseId: exerciseId, setNumber: setNumber, sessionId: sessionId))
        case "recordingStop":
            guard let exerciseId = message["exerciseId"] as? String,
                  let setNumber = message["setNumber"] as? Int
            else { return }
            _recordingTriggers.yield(.stop(exerciseId: exerciseId, setNumber: setNumber))
        default:
            break
        }
    }

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}
}
