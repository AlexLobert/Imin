import SwiftUI

enum AudienceSelection: Equatable {
    case everyone
    case circles([String])

    var label: String {
        switch self {
        case .everyone:
            return "Everyone"
        case .circles(let names):
            if names.isEmpty {
                return "Everyone"
            }
            if names.count == 1 {
                return names[0]
            }
            return "\(names.count) circles"
        }
    }
}

struct AudiencePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let circles: [String]
    @Binding var selection: AudienceSelection
    @State private var selectedCircles: Set<String>
    @State private var isEveryoneSelected: Bool

    init(circles: [String], selection: Binding<AudienceSelection>) {
        self.circles = circles
        self._selection = selection
        switch selection.wrappedValue {
        case .everyone:
            self._selectedCircles = State(initialValue: [])
            self._isEveryoneSelected = State(initialValue: true)
        case .circles(let names):
            let set = Set(names)
            self._selectedCircles = State(initialValue: set)
            self._isEveryoneSelected = State(initialValue: set.isEmpty)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Who sees you in?")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)

            List {
                Button(action: {
                    isEveryoneSelected = true
                    selectedCircles.removeAll()
                }) {
                    row(title: "Everyone", isSelected: isEveryoneSelected)
                }

                ForEach(circles, id: \.self) { circle in
                    Button(action: {
                        if isEveryoneSelected {
                            isEveryoneSelected = false
                            selectedCircles.removeAll()
                        }
                        if selectedCircles.contains(circle) {
                            selectedCircles.remove(circle)
                        } else {
                            selectedCircles.insert(circle)
                        }
                        if selectedCircles.isEmpty {
                            isEveryoneSelected = true
                        }
                    }) {
                        row(title: circle, isSelected: selectedCircles.contains(circle))
                    }
                }
            }
            .listStyle(.plain)

            Button(action: {
                if isEveryoneSelected || selectedCircles.isEmpty {
                    selection = .everyone
                } else {
                    let ordered = circles.filter { selectedCircles.contains($0) }
                    selection = .circles(ordered)
                }
                dismiss()
            }) {
                Text("Submit")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.accentGreen)
                    .cornerRadius(AppRadius.small)
            }
        }
        .padding(20)
    }

    private func row(title: String, isSelected: Bool) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.accentGreen)
            }
        }
        .padding(.vertical, 4)
    }
}
