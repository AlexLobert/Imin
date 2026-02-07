import SwiftUI
import UIKit

struct InOutSlider: View {
    @Binding var value: AvailabilityState
    let onInTap: () -> Void
    let onOutTap: () -> Void

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height: CGFloat = 60
            let knobSize: CGFloat = 52
            let isIn = value == .inOffice
            let trackWidth = width / 2
            let trackOffset = isIn ? 0 : trackWidth
            let knobOffset = isIn ? 4 : width - knobSize - 4

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color(white: 0.95))
                    .frame(height: height)

                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.66, green: 0.9, blue: 0.81),
                        Color(red: 0.5, green: 0.85, blue: 0.75)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: trackWidth, height: height)
                .cornerRadius(height / 2)
                .offset(x: trackOffset)

                HStack(spacing: 0) {
                    sideLabel("In", isSelected: isIn)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { set(.inOffice) }

                    sideLabel("Out", isSelected: !isIn)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { set(.out) }
                }
                .frame(height: height)

                Circle()
                    .fill(Color.white)
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 4)
                    .offset(x: knobOffset)
            }
            .frame(height: height)
            .animation(.easeInOut(duration: 0.25), value: value)
        }
        .frame(height: 60)
        .clipShape(Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Availability")
        .accessibilityValue(value.label)
    }

    private func sideLabel(_ text: String, isSelected: Bool) -> some View {
        Text(text)
            .font(.system(size: 16, weight: isSelected ? .semibold : .medium))
            .foregroundColor(isSelected ? .white : DesignColors.textSecondary)
    }

    private func set(_ newValue: AvailabilityState) {
        guard value != newValue else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        if newValue == .inOffice {
            onInTap()
        } else {
            onOutTap()
        }
    }
}
