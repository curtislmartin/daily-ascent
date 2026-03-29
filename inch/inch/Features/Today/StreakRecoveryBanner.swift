import SwiftUI

struct StreakRecoveryBanner: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.counterclockwise")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Everyone misses a day.")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Your streak starts fresh today — pick up where you left off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Everyone misses a day. Your streak starts fresh today. Dismiss button.")
    }
}

#Preview {
    StreakRecoveryBanner(onDismiss: {})
        .padding()
}
