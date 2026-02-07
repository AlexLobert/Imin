import SwiftUI

struct FilterPillsView: View {
    let filters: [ConnectViewModel.ChatFilter]
    let selectedFilter: ConnectViewModel.ChatFilter
    let onSelect: (ConnectViewModel.ChatFilter) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(filters, id: \.self) { filter in
                Button(filter.rawValue) {
                    onSelect(filter)
                }
                .buttonStyle(FilterPillStyle(isSelected: filter == selectedFilter))
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(Color(white: 0.95))
        )
        .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 4)
    }
}
