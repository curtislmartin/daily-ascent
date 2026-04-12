import SwiftUI

struct ResumePromptOverlay: View {
    let resumeSetNumber: Int
    let onResume: () -> Void
    let onStartOver: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.accent)

                VStack(spacing: 8) {
                    Text("Resume Workout?")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("You have progress from a previous session.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    Button {
                        onResume()
                    } label: {
                        Text("Resume from Set \(resumeSetNumber)")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        onStartOver()
                    } label: {
                        Text("Start Over")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.red)
                }
            }
            .padding(32)
            .background(
                Color(.systemBackground),
                in: RoundedRectangle(cornerRadius: 20)
            )
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            .padding(.horizontal, 40)
        }
        .transition(.opacity)
    }
}
