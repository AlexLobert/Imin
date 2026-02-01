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
            Circle()
                .fill(DesignColors.card)
                .frame(width: 52, height: 52)
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
                        .foregroundColor(DesignColors.textSecondary)
                }
            }

            if showsStatus {
                Circle()
                    .fill(isOnline ? DesignColors.accentGreen : Color.black.opacity(0.2))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(DesignColors.card, lineWidth: 2)
                    )
                    .offset(x: 2, y: 2)
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
