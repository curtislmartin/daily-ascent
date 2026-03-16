import MetricKit
import OSLog

final class MetricKitService: NSObject, MXMetricManagerSubscriber {
    private let logger = Logger(subsystem: "com.curtislmartin.inch", category: "MetricKit")

    override init() {
        super.init()
        MXMetricManager.shared.add(self)
    }

    deinit {
        MXMetricManager.shared.remove(self)
    }

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
        // Metric payloads (CPU, memory, etc.) — not needed
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let json = payload.jsonRepresentation()
            logger.error("DiagnosticPayload: \(json.count) bytes")
            writeToDisk(json, prefix: "diagnostic")
        }
    }

    private nonisolated func writeToDisk(_ data: Data, prefix: String) {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let filename = "\(prefix)-\(formatter.string(from: .now)).json"
        let url = docs.appendingPathComponent(filename)
        try? data.write(to: url)
    }
}
