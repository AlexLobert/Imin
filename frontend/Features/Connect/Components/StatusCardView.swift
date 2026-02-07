import SwiftUI
import UIKit

struct StatusCardView: View {
    @Binding var status: UserStatus
    let visibleChips: [String]
    let onVisibleToTap: () -> Void
    let onStatusChange: (UserStatus) -> Void

    private let controlMaxWidth: CGFloat = 230

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                backgroundArt(size: geo.size)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.6), value: status)
                    .overlay(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.black.opacity(0.0),
                                Color.black.opacity(0.10),
                                Color.black.opacity(0.30)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 10) {
                Button(action: toggleStatus) {
                    Text(status == .in ? "I'm In" : "I'm Out")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(DesignColors.textPrimary)
                        .frame(width: controlMaxWidth)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.82))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.7), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.10), radius: 14, x: 0, y: 8)
                }
                .buttonStyle(.plain)

                if status == .in {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        onVisibleToTap()
                    }) {
                        HStack(spacing: 6) {
                            Text("Visible to \(visiblePillText)")
                                .lineLimit(1)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: controlMaxWidth)
                        .foregroundColor(Color.white.opacity(0.78))
                        .padding(.vertical, 4)
                        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Click to go in")
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: controlMaxWidth)
                        .foregroundColor(Color.white.opacity(0.78))
                        .padding(.vertical, 4)
                        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 6)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.bottom, 18)
        }
        .frame(height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 20, x: 0, y: 4)
    }

    private var visiblePillText: String {
        let first = visibleChips.first ?? "Everyone"
        let extra = max(visibleChips.count - 1, 0)
        return extra > 0 ? "\(first) +\(extra)" : first
    }

    private func backgroundArt(size: CGSize) -> some View {
        let name = status == .in ? "in_cartoon_background" : "out_cartoon_background"
        return Group {
            if let image = UIImage(named: name) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.62, green: 0.78, blue: 0.9),
                        Color(red: 0.86, green: 0.92, blue: 0.95)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private func toggleStatus() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        onStatusChange(status == .in ? .out : .in)
    }
}
