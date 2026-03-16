import SwiftUI

struct DemographicPickerSheet: View {
    let title: String
    let options: [String]
    @Binding var selection: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(options, id: \.self) { option in
                    row(for: option)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    if selection != nil {
                        Button("Clear") {
                            selection = nil
                            dismiss()
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private func row(for option: String) -> some View {
        let isSelected = selection == option
        return Button {
            selection = isSelected ? nil : option
            dismiss()
        } label: {
            HStack {
                Text(option)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.accent)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
