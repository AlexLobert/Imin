import SwiftUI

struct InOutTogglePill: View {
    let isIn: Bool
    let onInTap: () -> Void
    let onOutTap: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height: CGFloat = 52
            let knobWidth = (width - 6) / 2

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(AppColors.subtleBackground)
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(isIn ? AppColors.accentGreen : Color(.systemGray4))
                    .frame(width: knobWidth, height: height - 6)
                    .offset(x: isIn ? 3 : knobWidth + 3, y: 0)
                    .animation(.easeOut(duration: 0.2), value: isIn)

                HStack(spacing: 0) {
                    toggleLabel("In", isSelected: isIn)
                        .frame(width: knobWidth, height: height)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            triggerHaptic()
                            onInTap()
                        }

                    toggleLabel("Out", isSelected: !isIn)
                        .frame(width: knobWidth, height: height)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            triggerHaptic()
                            onOutTap()
                        }
                }
            }
        }
        .frame(height: 52)
    }

    private func toggleLabel(_ title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(isSelected ? .white : .primary)
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }
}
