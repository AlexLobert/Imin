import SwiftUI

enum CozyColor {
    static let blueStart = Color(red: 0.63, green: 0.8, blue: 0.98)
    static let blueEnd = Color(red: 0.25, green: 0.45, blue: 0.85)
    static let warmGlowStart = Color(red: 0.98, green: 0.86, blue: 0.6)
    static let warmGlowEnd = Color(red: 0.98, green: 0.72, blue: 0.45)
    static let cream = Color(red: 0.98, green: 0.95, blue: 0.85)
    static let slate = Color(red: 0.55, green: 0.6, blue: 0.7)
    static let ink = Color.black
    static let inkMuted = Color.black.opacity(0.7)
    static let accent = Color(red: 0.98, green: 0.85, blue: 0.2)
}

enum CozyType {
    static func title(_ size: CGFloat) -> Font {
        Font.custom("Avenir Next", size: size).weight(.heavy)
    }

    static func body(_ size: CGFloat) -> Font {
        Font.custom("Avenir Next", size: size)
    }
}

struct CozyBackground: View {
    let isIn: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [CozyColor.blueStart, CozyColor.blueEnd], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            if isIn {
                LinearGradient(colors: [CozyColor.warmGlowStart.opacity(0.35), CozyColor.warmGlowEnd.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
    }
}
