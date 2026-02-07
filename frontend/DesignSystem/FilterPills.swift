import SwiftUI

enum FilterPill: String, CaseIterable {
    case all = "All"
    case unread = "Unread"
}

struct FilterPills: View {
    let filters: [FilterPill]
    let selected: FilterPill
    let onSelect: (FilterPill) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(filters, id: \.self) { filter in
                Button(filter.rawValue) {
                    onSelect(filter)
                }
                .buttonStyle(FilterPillButtonStyle(isSelected: filter == selected))
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color(white: 0.95))
        )
    }
}

private struct FilterPillButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? AppStyle.mint.opacity(0.35) : Color.clear, lineWidth: 1)
            )
            .foregroundColor(isSelected ? DesignColors.textPrimary : DesignColors.textSecondary)
    }
}

struct FilterPills_Previews: PreviewProvider {
    static var previews: some View {
        FilterPills(filters: FilterPill.allCases, selected: .all) { _ in }
            .padding()
            .background(DesignColors.background)
            .previewLayout(.sizeThatFits)
    }
}
