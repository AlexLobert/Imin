import SwiftUI

struct InOutHeroCard: View {
    let isIn: Bool
    let resetText: String
    let onInTap: () -> Void
    let onOutTap: () -> Void

    var body: some View {
        CozyCard {
            VStack(alignment: .leading, spacing: 16) {
                InOutPillToggle(isIn: isIn, onInTap: onInTap, onOutTap: onOutTap)

                Text(resetText)
                    .font(CozyType.body(13))
                    .foregroundColor(CozyColor.inkMuted)
            }
        }
    }
}

private struct InOutPillToggle: View {
    let isIn: Bool
    let onInTap: () -> Void
    let onOutTap: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height: CGFloat = 50
            let knobWidth = (width - 6) / 2

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(CozyColor.cream.opacity(0.8))
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(CozyColor.slate)
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
        .frame(height: 50)
    }

    private func toggleLabel(_ title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(CozyType.title(16))
            .foregroundColor(isSelected ? .white : CozyColor.ink)
    }

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }
}
