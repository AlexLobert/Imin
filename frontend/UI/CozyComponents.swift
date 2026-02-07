import SwiftUI

struct CozyCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(CozyColor.cream)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
    }
}

struct CozySectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(CozyType.title(16))
            .foregroundColor(CozyColor.ink)
    }
}

struct CozyRow: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(CozyType.body(15).weight(.bold))
                if let subtitle {
                    Text(subtitle)
                        .font(CozyType.body(13))
                        .foregroundColor(CozyColor.inkMuted)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(CozyColor.inkMuted)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(CozyColor.cream.opacity(0.8))
        .cornerRadius(16)
    }
}
