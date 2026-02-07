import SwiftUI

struct ImInCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 4)
    }
}

extension View {
    func imInCard() -> some View {
        modifier(ImInCardStyle())
    }
}
