import SwiftUI

struct OnboardingView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.7, green: 0.88, blue: 1.0), Color(red: 0.3, green: 0.5, blue: 0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .fill(Color.white.opacity(0.2))
                .frame(width: 280, height: 280)
                .rotationEffect(.degrees(12))
                .offset(x: 140, y: -200)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("I'm in")
                        .font(.custom("Avenir Next", size: 36))
                        .fontWeight(.heavy)
                        .foregroundColor(.black)

                    Text("Your friends might be down too. Let them know you're in for a hang.")
                        .font(.custom("Avenir Next", size: 18))
                        .foregroundColor(.black.opacity(0.8))

                    VStack(alignment: .leading, spacing: 14) {
                        OnboardingBullet(
                            title: "Signal availability",
                            detail: "Flip to In and let your people know you're ready to hang."
                        )
                        OnboardingBullet(
                            title: "Find your crew",
                            detail: "Search by name, handle, phone, or email. Or scan contacts."
                        )
                        OnboardingBullet(
                            title: "Keep it real-time",
                            detail: "Status auto-resets so you don't get stuck with stale invites."
                        )
                    }

                    Button(action: onContinue) {
                        HStack {
                            Text("Get started")
                                .font(.custom("Avenir Next", size: 18))
                                .fontWeight(.bold)
                            Spacer()
                            Text("->")
                                .font(.custom("Avenir Next", size: 20))
                                .fontWeight(.bold)
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 20)
                        .background(Color(red: 0.55, green: 0.6, blue: 0.7))
                        .foregroundColor(.white)
                        .cornerRadius(20)
                    }
                    .padding(.top, 8)
                }
                .padding(28)
            }
        }
    }
}

private struct OnboardingBullet: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.black)
                .frame(width: 8, height: 8)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.custom("Avenir Next", size: 16))
                    .fontWeight(.bold)
                    .foregroundColor(.black)

                Text(detail)
                    .font(.custom("Avenir Next", size: 15))
                    .foregroundColor(.black.opacity(0.75))
            }
        }
    }
}
