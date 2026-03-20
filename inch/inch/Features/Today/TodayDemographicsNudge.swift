import SwiftUI

struct TodayDemographicsNudge: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            NavigationLink(value: TodayDestination.aboutMe) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Complete your profile")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.tint)
                    Text("Help improve rep counting accuracy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.tint.opacity(0.25))
        )
    }
}
