import SwiftUI

struct ListRow: View {
    let title: String
    let value: String
    var showsChevron: Bool = true
    var showsDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text(value)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)

                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, AppSpacing.rowVertical)

            if showsDivider {
                Divider()
                    .background(AppColors.separator)
            }
        }
    }
}
