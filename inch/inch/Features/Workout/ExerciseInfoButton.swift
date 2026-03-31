import SwiftUI

/// A reusable ⓘ button that presents ExerciseInfoSheet as a sheet.
/// Place next to any exercise name in the UI.
struct ExerciseInfoButton: View {
    let exerciseId: String
    let exerciseName: String
    let level: Int

    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                ExerciseInfoSheet(
                    exerciseId: exerciseId,
                    exerciseName: exerciseName,
                    level: level
                )
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { isPresented = false }
                    }
                }
            }
        }
        .accessibilityLabel("Exercise info for \(exerciseName)")
    }
}
