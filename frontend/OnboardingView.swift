import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void
    private let features: [OnboardingFeature] = [
        .init(
            icon: "bolt.fill",
            title: "One-tap availability",
            detail: "Flip In or Out in seconds so friends know your vibe right now."
        ),
        .init(
            icon: "person.3.fill",
            title: "Share with the right people",
            detail: "Post to everyone or only selected circles when you want a tighter plan."
        ),
        .init(
            icon: "magnifyingglass",
            title: "Find friends faster",
            detail: "Search by @handle and match contacts to quickly build your network."
        ),
        .init(
            icon: "timer",
            title: "Always up to date",
            detail: "Auto-reset keeps statuses fresh so nobody chases stale invites."
        )
    ]

    var body: some View {
        ZStack {
            DesignColors.background
                .ignoresSafeArea()

            backgroundDecor

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Stop guessing who’s free.")
                        .font(.system(size: 38, weight: .heavy))
                        .foregroundColor(DesignColors.textPrimary)

                    Text("Imin shows real-time availability, privacy by circles, and instant chat to make plans actually happen.")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(DesignColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(features) { feature in
                            OnboardingFeatureRow(feature: feature)
                        }
                    }
                    .padding(18)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.white.opacity(0.75))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.65), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.05), radius: 20, x: 0, y: 8)

                    Button(action: onContinue) {
                        HStack {
                            Text("Get started")
                                .font(.system(size: 19, weight: .bold))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 20, weight: .bold))
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.66, green: 0.90, blue: 0.81),
                                    AppStyle.mint
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.35), lineWidth: 1)
                        )
                        .shadow(color: AppStyle.mint.opacity(0.35), radius: 16, x: 0, y: 8)
                    }
                    .padding(.top, 8)
                }
                .padding(28)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private var backgroundDecor: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppStyle.mint.opacity(0.30), .clear],
                        center: .center,
                        startRadius: 24,
                        endRadius: 250
                    )
                )
                .frame(width: 420, height: 420)
                .offset(x: 170, y: -280)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [DesignColors.accentGreen.opacity(0.18), .clear],
                        center: .center,
                        startRadius: 24,
                        endRadius: 280
                    )
                )
                .frame(width: 420, height: 420)
                .offset(x: -180, y: 420)
        }
        .ignoresSafeArea()
    }
}

private struct OnboardingFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

private struct OnboardingFeatureRow: View {
    let feature: OnboardingFeature

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppStyle.mint.opacity(0.18))
                Image(systemName: feature.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppStyle.mint)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(feature.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(DesignColors.textPrimary)

                Text(feature.detail)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(DesignColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
