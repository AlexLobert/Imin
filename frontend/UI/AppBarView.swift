import SwiftUI

struct AppBarView: View {
    let title: String
    let logoName: String?
    let logoHeight: CGFloat
    let trailingSystemImage: String
    let trailingAction: () -> Void

    init(
        title: String,
        logoName: String? = nil,
        logoHeight: CGFloat = 22,
        trailingSystemImage: String = "person.crop.circle",
        trailingAction: @escaping () -> Void = {}
    ) {
        self.title = title
        self.logoName = logoName
        self.logoHeight = logoHeight
        self.trailingSystemImage = trailingSystemImage
        self.trailingAction = trailingAction
    }

    var body: some View {
        HStack(spacing: 10) {
            if let logoName {
                Image(logoName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: logoHeight)
            }

            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Spacer()

            Button(action: trailingAction) {
                Image(systemName: trailingSystemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(AppColors.subtleBackground)
                    .clipShape(Circle())
            }
        }
    }
}
