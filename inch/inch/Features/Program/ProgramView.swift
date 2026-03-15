import SwiftUI
import SwiftData
import InchShared

struct ProgramView: View {
    @Query private var allEnrolments: [ExerciseEnrolment]
    @State private var viewModel = ProgramViewModel()

    private var active: [ExerciseEnrolment] {
        allEnrolments
            .filter(\.isActive)
            .sorted { ($0.exerciseDefinition?.sortOrder ?? 0) < ($1.exerciseDefinition?.sortOrder ?? 0) }
    }

    var body: some View {
        Group {
            if active.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(active, id: \.persistentModelID) { enrolment in
                        NavigationLink(value: ProgramDestination.exerciseDetail(enrolment.persistentModelID)) {
                            EnrolmentRow(enrolment: enrolment, viewModel: viewModel)
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Program")
        .navigationBarTitleDisplayMode(.large)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)
            Text("No exercises enrolled")
                .font(.headline)
            Text("Complete onboarding to enrol in exercises.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

private struct EnrolmentRow: View {
    let enrolment: ExerciseEnrolment
    let viewModel: ProgramViewModel

    private var def: ExerciseDefinition? { enrolment.exerciseDefinition }
    private var progress: Double { viewModel.levelProgress(for: enrolment) }
    private var totalDays: Int { viewModel.levelTotalDays(for: enrolment) ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(def?.name ?? "Exercise")
                    .font(.body)
                    .fontWeight(.semibold)
                Spacer()
                Text("L\(enrolment.currentLevel)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accentColor.opacity(0.15), in: Capsule())
                    .foregroundStyle(accentColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.secondary.opacity(0.15))
                        .frame(height: 6)
                    Capsule()
                        .fill(accentColor)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.easeInOut, value: progress)
                }
            }
            .frame(height: 6)

            HStack {
                Text("Day \(enrolment.currentDay) of \(totalDays)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let next = enrolment.nextScheduledDate {
                    Text(next.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var accentColor: Color {
        Color(hex: def?.color ?? "") ?? .accentColor
    }
}

