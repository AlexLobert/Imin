import SwiftUI

struct GlassSheetStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(32)
                .presentationDragIndicator(.visible)
        } else {
            content
        }
    }
}

extension View {
    func glassSheetStyle() -> some View {
        modifier(GlassSheetStyle())
    }
}

