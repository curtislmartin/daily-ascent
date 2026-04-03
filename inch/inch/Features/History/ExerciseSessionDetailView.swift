import SwiftUI
import SwiftData
import InchShared

struct ExerciseSessionDetailView: View {
    let exerciseId: String
    let sessionDate: Date

    var body: some View {
        Text("Session detail")
            .navigationTitle("Session")
    }
}
