import SwiftUI

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ScrollOffsetReader: View {
    let coordinateSpace: String

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .preference(key: ScrollOffsetKey.self, value: proxy.frame(in: .named(coordinateSpace)).minY)
        }
        .frame(height: 0)
    }
}

