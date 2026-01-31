import SwiftUI

struct CircleChipView: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(
                Capsule()
                    .fill(isSelected ? ConnectColors.accentGreenSoft : ConnectColors.cardBackground)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.clear : ConnectColors.chipBorder, lineWidth: 1)
            )
            .foregroundColor(ConnectColors.textPrimary)
    }
}
