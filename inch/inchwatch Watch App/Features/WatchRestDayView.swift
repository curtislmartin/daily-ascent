import SwiftUI

struct WatchRestDayView: View {
    let lastSyncDate: Date?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.fill")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("Rest Day")
                .font(.headline)
            if let syncDate = lastSyncDate {
                Text("Synced \(syncDate.formatted(.relative(presentation: .named)))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
