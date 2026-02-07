import SwiftUI

struct GlassHeaderContainer<Content: View>: View {
    let opacity: Double
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity)
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(opacity)
                    .ignoresSafeArea(edges: .top)
            )
            .overlay(
                Rectangle()
                    .fill(Color.black.opacity(0.06))
                    .frame(height: 1)
                    .opacity(opacity),
                alignment: .bottom
            )
    }
}

