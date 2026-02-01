import SwiftUI

struct PillButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .padding(.vertical, 8)
            .padding(.horizontal, 18)
            .background(
                Capsule()
                    .fill(isSelected ? DesignColors.accentGreen.opacity(0.22) : DesignColors.card)
            )
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .foregroundColor(isSelected ? DesignColors.textPrimary : DesignColors.textSecondary)
    }
}

struct PillButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 8) {
            Button("In") {}
                .buttonStyle(PillButtonStyle(isSelected: true))
            Button("Out") {}
                .buttonStyle(PillButtonStyle(isSelected: false))
        }
        .padding()
        .background(DesignColors.background)
        .previewLayout(.sizeThatFits)
    }
}
