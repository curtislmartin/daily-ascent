import SwiftUI

struct ElapsedTimerView: View {
    @State private var elapsed: Int = 0

    var body: some View {
        Text(timeText)
            .font(.system(size: 48, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .task {
                while true {
                    try? await Task.sleep(for: .seconds(1))
                    elapsed += 1
                }
            }
    }

    private var timeText: String {
        "\(elapsed / 60):\(String(format: "%02d", elapsed % 60))"
    }
}
