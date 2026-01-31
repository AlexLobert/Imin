import SwiftUI

enum DesignColors {
    static let accentGreen = Color(red: 0.36, green: 0.67, blue: 0.49)
    static let background = Color(red: 0.96, green: 0.96, blue: 0.97)
    static let card = Color(red: 0.99, green: 0.99, blue: 0.99)
    static let textPrimary = Color(red: 0.16, green: 0.16, blue: 0.16)
    static let textSecondary = Color(red: 0.46, green: 0.46, blue: 0.46)
}

struct Colors_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            Circle().fill(DesignColors.accentGreen).frame(width: 24, height: 24)
            RoundedRectangle(cornerRadius: 12).fill(DesignColors.background).frame(height: 32)
            RoundedRectangle(cornerRadius: 12).fill(DesignColors.card).frame(height: 32)
            Text("Primary")
                .foregroundColor(DesignColors.textPrimary)
            Text("Secondary")
                .foregroundColor(DesignColors.textSecondary)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
