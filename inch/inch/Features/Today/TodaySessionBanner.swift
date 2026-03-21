import SwiftUI

/// Shown at the top of the Today exercise list.
/// - Before any exercise is done: a compact streak + availability line (D-style).
/// - After the first exercise: a segmented progress card (E-style).
struct TodaySessionBanner: View {
    let streak: Int
    let completedCount: Int
    let totalCount: Int

    var body: some View {
        if completedCount == 0 {
            if streak > 0 {
                streakAvailabilityBanner
            }
            // streak == 0 && completedCount == 0 → show nothing
        } else {
            sessionProgressCard
        }
    }

    // MARK: - D-style

    private var streakAvailabilityBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .foregroundStyle(.orange)
            Text("\(streak)-day streak · \(totalCount) exercise\(totalCount == 1 ? "" : "s") available")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - E-style

    private var sessionProgressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today's session")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(completedCount) of \(totalCount) done")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 4) {
                ForEach(0..<totalCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index < completedCount ? Color.accentColor : Color(.systemFill))
                        .frame(height: 5)
                }
            }

            Text(progressCopy)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var progressCopy: String {
        switch completedCount {
        case 1:
            return "Good start — keep going if you feel up to it."
        case 2:
            return "Building momentum — listen to your body."
        default:
            return "Solid session — the rest are optional."
        }
    }
}
