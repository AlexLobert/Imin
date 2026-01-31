import SwiftUI

struct StatusCardView: View {
    @Binding var status: UserStatus
    let visibleChips: [String]
    let onVisibleToTap: () -> Void
    let onStatusChange: (UserStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            InOutSlider(
                value: Binding(
                    get: { status == .in ? .inOffice : .out },
                    set: { newValue in
                        onStatusChange(newValue == .inOffice ? .in : .out)
                    }
                ),
                onInTap: { onStatusChange(.in) },
                onOutTap: { onStatusChange(.out) }
            )
            .frame(height: 60)

            Button(action: onVisibleToTap) {
                HStack {
                    Text("Visible to")
                        .font(.system(size: 15))
                        .foregroundColor(ConnectColors.textSecondary)

                    Spacer()

                    HStack(spacing: 6) {
                        Text(visiblePillText)
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 15, weight: .medium))
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(red: 0.91, green: 0.96, blue: 0.94))
                    .cornerRadius(16)
                    .foregroundColor(ConnectColors.textPrimary)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .cardStyle()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var visiblePillText: String {
        visibleChips.first ?? "Roommates"
    }
}
