import SwiftUI
import InchShared

/// Shown at the top of the Today exercise list.
/// - Before any exercise is done: a compact streak + availability line (D-style).
/// - After the first exercise: a segmented progress card (E-style).
struct TodaySessionBanner: View {
    let streak: Int
    let completedCount: Int
    let totalCount: Int
    let advisory: LoadAdvisory?

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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(streak)-day streak. \(totalCount) exercise\(totalCount == 1 ? "" : "s") available today.")
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

            Text(advisoryCopy)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's session: \(completedCount) of \(totalCount) done. \(advisoryCopy)")
    }

    private var advisoryCopy: String {
        LoadAdvisoryCopy.copy(completedCount: completedCount, advisory: advisory)
    }
}

#Preview("No advisory") {
    TodaySessionBanner(streak: 3, completedCount: 1, totalCount: 4, advisory: nil)
        .padding()
}

#Preview("Taper — stop here") {
    TodaySessionBanner(
        streak: 3,
        completedCount: 2,
        totalCount: 4,
        advisory: LoadAdvisory(
            recommendedCount: 2,
            overloadedGroups: [],
            cautionGroups: [],
            preTestTaperActive: true,
            lookbackPenaltyActive: false,
            budgetFraction: 0.7
        )
    )
    .padding()
}

#Preview("Lower body overloaded") {
    TodaySessionBanner(
        streak: 3,
        completedCount: 2,
        totalCount: 4,
        advisory: LoadAdvisory(
            recommendedCount: 3,
            overloadedGroups: [.lower],
            cautionGroups: [.lowerPosterior],
            preTestTaperActive: false,
            lookbackPenaltyActive: false,
            budgetFraction: 0.85
        )
    )
    .padding()
}
