import SwiftUI

struct WatchHRBadge: View {
    let showHeartRate: Bool
    let currentBPM: Int?

    var body: some View {
        if showHeartRate, let bpm = currentBPM {
            Text("♥ \(bpm)")
                .font(.caption2)
                .foregroundStyle(.red)
                .padding(4)
        }
    }
}
