import SwiftUI

enum AudienceSelection: Equatable {
    case everyone
    case circles([UUID])

    func label(using circles: [CircleGroup]) -> String {
        switch self {
        case .everyone:
            return "Everyone"
        case .circles(let ids):
            let names = circles.filter { ids.contains($0.id) }.map { $0.name }
            if names.isEmpty {
                if ids.isEmpty {
                    return "Everyone"
                }
                if ids.count == 1 {
                    return "1 circle"
                }
                return "\(ids.count) circles"
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
    let circles: [CircleGroup]
    @Binding var selection: AudienceSelection
    @State private var selectedCircles: Set<UUID>
    @State private var isEveryoneSelected: Bool
    private let accent = AppStyle.mint

    init(circles: [CircleGroup], selection: Binding<AudienceSelection>) {
        self.circles = circles
        self._selection = selection
        switch selection.wrappedValue {
        case .everyone:
            self._selectedCircles = State(initialValue: [])
            self._isEveryoneSelected = State(initialValue: true)
        case .circles(let ids):
            let set = Set(ids)
            self._selectedCircles = State(initialValue: set)
            self._isEveryoneSelected = State(initialValue: set.isEmpty)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(Color.white.opacity(0.35))
                .frame(width: 44, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

            Text("Who sees you in?")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(DesignColors.textPrimary)
                .padding(.horizontal, 20)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 10) {
                    Button(action: {
                        isEveryoneSelected = true
                        selectedCircles.removeAll()
                    }) {
                        row(title: "Everyone", isSelected: isEveryoneSelected)
                    }

                    ForEach(circles) { circle in
                        Button(action: { toggle(circleId: circle.id) }) {
                            row(title: circle.name, isSelected: selectedCircles.contains(circle.id))
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }

            Button(action: submit) {
                Text("Submit")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.66, green: 0.9, blue: 0.81),
                                        Color(red: 0.5, green: 0.85, blue: 0.75)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 8)
                            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private func row(title: String, isSelected: Bool) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(DesignColors.textPrimary)
                .lineLimit(1)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(glassRowBackground(isSelected: isSelected))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.55), lineWidth: 1)
                .blendMode(.overlay)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .overlay(
            LinearGradient(
                colors: [
                    Color.white.opacity(0.55),
                    Color.white.opacity(0.06),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .blendMode(.screen)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 8)
        .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
    }

    private func glassRowBackground(isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? accent.opacity(0.14) : Color.white.opacity(0.08))
            )
    }

    private func toggle(circleId: UUID) {
        if isEveryoneSelected {
            isEveryoneSelected = false
            selectedCircles.removeAll()
        }

        if selectedCircles.contains(circleId) {
            selectedCircles.remove(circleId)
        } else {
            selectedCircles.insert(circleId)
        }

        if selectedCircles.isEmpty {
            isEveryoneSelected = true
        }
    }

    private func submit() {
        if isEveryoneSelected || selectedCircles.isEmpty {
            selection = .everyone
        } else {
            let ordered = circles
                .map(\.id)
                .filter { selectedCircles.contains($0) }
            selection = .circles(ordered)
        }
        dismiss()
    }
}
