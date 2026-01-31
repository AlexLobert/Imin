import SwiftUI

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(DesignColors.card)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 4)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

struct CardStyle_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Text("Card")
                .padding(20)
                .cardStyle()
        }
        .padding()
        .background(DesignColors.background)
        .previewLayout(.sizeThatFits)
    }
}
