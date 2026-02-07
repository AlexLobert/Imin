import SwiftUI

struct AvatarView: View {
    let name: String
    let systemImage: String?
    let showsStatus: Bool
    let isOnline: Bool

    init(name: String, systemImage: String? = nil, showsStatus: Bool = false, isOnline: Bool = false) {
        self.name = name
        self.systemImage = systemImage
        self.showsStatus = showsStatus
        self.isOnline = isOnline
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if systemImage == nil {
                    Circle()
                        .fill(AvatarGradient.gradient(for: name))
                } else {
                    Circle()
                        .fill(DesignColors.card)
                }
            }
            .frame(width: 52, height: 52)
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 2)
            )
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )

            Group {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(DesignColors.textSecondary)
                } else {
                    Text(initials(from: name))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(DesignColors.textPrimary)
                        .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
                }
            }
            .frame(width: 52, height: 52, alignment: .center)

            if showsStatus {
                Circle()
                    .fill(isOnline ? DesignColors.accentGreen : Color.black.opacity(0.2))
                    .frame(width: 10, height: 10)
                    .shadow(color: isOnline ? DesignColors.accentGreen.opacity(0.45) : .clear, radius: 3, x: 0, y: 1)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .offset(x: 3, y: 3)
            }
        }
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.dropFirst().first?.prefix(1) ?? ""
        return (first + last).uppercased()
    }
}

struct AvatarView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 12) {
            AvatarView(name: "John Doe", showsStatus: true, isOnline: true)
            AvatarView(name: "Rachel Zane", systemImage: "person.fill", showsStatus: true, isOnline: false)
        }
        .padding()
        .background(DesignColors.background)
        .previewLayout(.sizeThatFits)
    }
}
