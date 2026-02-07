import SwiftUI

enum AvatarGradient {
    private static let palettes: [[Color]] = [
        [Color(red: 0.64, green: 0.82, blue: 0.98), Color(red: 0.36, green: 0.6, blue: 0.98)],
        [Color(red: 0.98, green: 0.78, blue: 0.62), Color(red: 0.96, green: 0.55, blue: 0.44)],
        [Color(red: 0.76, green: 0.92, blue: 0.72), Color(red: 0.46, green: 0.78, blue: 0.62)],
        [Color(red: 0.9, green: 0.78, blue: 0.98), Color(red: 0.68, green: 0.5, blue: 0.92)],
        [Color(red: 0.98, green: 0.86, blue: 0.62), Color(red: 0.94, green: 0.7, blue: 0.32)],
        [Color(red: 0.8, green: 0.88, blue: 0.98), Color(red: 0.52, green: 0.68, blue: 0.94)]
    ]

    static func gradient(for name: String) -> LinearGradient {
        let colors = palettes[stableIndex(for: name) % palettes.count]
        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private static func stableIndex(for name: String) -> Int {
        var hash: Int = 5381
        for scalar in name.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ Int(scalar.value)
        }
        return abs(hash)
    }
}
