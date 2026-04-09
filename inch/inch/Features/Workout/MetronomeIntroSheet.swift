import SwiftUI

struct MetronomeIntroSheet: View {
    let exerciseId: String
    let exerciseName: String
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "metronome")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accentColor)
                    Text("Metronome Mode")
                        .font(.title2).fontWeight(.bold)
                    Text(exerciseName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(bullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 10) {
                            Circle()
                                .fill(Color.accentColor)
                                .frame(width: 6, height: 6)
                                .padding(.top, 6)
                            Text(bullet)
                                .font(.subheadline)
                        }
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)

            Spacer()

            Button("Got it") { onDismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom, 32)
        }
        .padding(.top, 32)
    }

    private var bullets: [String] {
        switch exerciseId {
        case "dead_bugs":
            return [
                "The beat paces every rep.",
                "Extend your arm and opposite leg on the pulse, then return.",
                "The screen shows which side is next — it switches automatically."
            ]
        case "hip_hinge":
            return [
                "The beat sets your tempo.",
                "Hinge your hips back on the strong pulse.",
                "Return to standing on the soft pulse. Slow and controlled."
            ]
        case "spinal_extension":
            return [
                "The beat controls your pace.",
                "Lift on the first pulse, lower slowly on the second.",
                "Both beats are equal — there's no rush phase."
            ]
        default:
            return [
                "The beat sets your tempo — move with each pulse.",
                "Strong pulse marks the start of each rep.",
                "Soft pulse signals the return or recovery phase."
            ]
        }
    }
}
