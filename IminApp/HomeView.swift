import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @StateObject private var viewModel = HomeViewModel()
    @State private var selectedCircles: Set<String> = ["Inner circle"]
    @State private var showAudienceSheet = false
    @State private var pendingInUpdate = false
    @AppStorage("audienceMode") private var audienceMode = "everyone"
    @AppStorage("audienceCircles") private var audienceCircles = ""

    private let circles = ["Inner circle", "Roommates", "Late-night crew", "Gym buddies"]
    private let friendsIn: [FriendStatus] = []

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.7, green: 0.88, blue: 1.0), Color(red: 0.32, green: 0.52, blue: 0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Tonight, you're...")
                        .font(.custom("Avenir Next", size: 22))
                        .fontWeight(.bold)
                        .foregroundColor(.black)

                    statusCard

                    if viewModel.isLoadingAvailability {
                        Text("Checking your status...")
                            .font(.custom("Avenir Next", size: 13))
                            .foregroundColor(.black.opacity(0.7))
                    }

                    visibilityCard

                    friendsCard

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.custom("Avenir Next", size: 14))
                            .foregroundColor(.black)
                            .padding(.vertical, 4)
                    }
                }
                .padding(24)
            }
        }
        .task(id: sessionManager.session?.userId) {
            await loadAvailability()
        }
        .onAppear {
            selectedCircles = decodeCircles(from: audienceCircles, fallback: selectedCircles)
        }
        .sheet(isPresented: $showAudienceSheet) {
            AudienceSheet(
                circles: circles,
                selectedCircles: $selectedCircles,
                audienceMode: $audienceMode,
                onConfirm: handleAudienceConfirm
            )
            .presentationDetents([.medium])
        }
    }

    @MainActor
    private func loadAvailability() async {
        guard let session = await sessionManager.validSession() else { return }
        await viewModel.loadAvailability(session: session)
    }
}

private extension HomeView {
    var statusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                statusButton(title: "In", isSelected: viewModel.availabilityState == .inOffice) {
                    handleInTap()
                }

                statusButton(title: "Out", isSelected: viewModel.availabilityState == .out) {
                    Task {
                        if let session = await sessionManager.validSession() {
                            await viewModel.updateAvailability(state: .out, session: session)
                        }
                    }
                }
            }

            Text("Auto-resets in 8 hours so you don't get stuck \"in.\"")
                .font(.custom("Avenir Next", size: 13))
                .foregroundColor(.black.opacity(0.7))
        }
        .padding(18)
        .background(Color(red: 0.98, green: 0.95, blue: 0.85))
        .cornerRadius(22)
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.black.opacity(0.1), lineWidth: 1)
        )
    }

    var visibilityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Who sees you in?")
                .font(.custom("Avenir Next", size: 16))
                .fontWeight(.bold)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(circles, id: \.self) { circle in
                    let isSelected = selectedCircles.contains(circle)
                    Button(action: {
                        if isSelected {
                            selectedCircles.remove(circle)
                        } else {
                            selectedCircles.insert(circle)
                        }
                    }) {
                        Text(circle)
                            .font(.custom("Avenir Next", size: 13))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .background(isSelected ? Color(red: 0.55, green: 0.6, blue: 0.7) : Color(red: 0.98, green: 0.95, blue: 0.85))
                            .foregroundColor(isSelected ? .white : .black)
                            .cornerRadius(14)
                    }
                }
            }
        }
        .padding(18)
        .background(Color(red: 0.98, green: 0.95, blue: 0.85))
        .cornerRadius(22)
    }

    var friendsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Friends who are in")
                    .font(.custom("Avenir Next", size: 16))
                    .fontWeight(.bold)
                Spacer()
            }

            if friendsIn.isEmpty {
                Text("No friends are in yet.")
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundColor(.black.opacity(0.7))
            } else {
                ForEach(friendsIn) { friend in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(friend.name)
                                .font(.custom("Avenir Next", size: 15))
                                .fontWeight(.bold)
                            Text(friend.note)
                                .font(.custom("Avenir Next", size: 13))
                                .foregroundColor(.black.opacity(0.7))
                        }
                        Spacer()
                        Text("Chat")
                            .font(.custom("Avenir Next", size: 13))
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.55, green: 0.6, blue: 0.7))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(18)
        .background(Color(red: 0.98, green: 0.95, blue: 0.85))
        .cornerRadius(22)
    }

    func statusButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Avenir Next", size: 16))
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isSelected ? Color(red: 0.55, green: 0.6, blue: 0.7) : Color(red: 0.98, green: 0.95, blue: 0.85))
                .foregroundColor(isSelected ? .white : .black)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
        }
        .disabled(viewModel.isUpdatingAvailability)
    }

    var audienceSummary: String {
        if audienceMode == "circles" {
            let count = selectedCircles.count
            return count == 0 ? "None" : "\(count) circle\(count == 1 ? "" : "s")"
        }
        return "Everyone"
    }

    func handleInTap() {
        guard sessionManager.session != nil else { return }
        if viewModel.availabilityState == .inOffice {
            return
        }
        pendingInUpdate = true
        showAudienceSheet = true
    }

    func handleAudienceConfirm() {
        audienceCircles = encodeCircles(selectedCircles)
        if pendingInUpdate {
            pendingInUpdate = false
            updateAvailabilityIn()
        }
    }

    func updateAvailabilityIn() {
        Task {
            guard let session = await sessionManager.validSession() else { return }
            await viewModel.updateAvailability(state: .inOffice, session: session)
        }
    }

    func encodeCircles(_ circles: Set<String>) -> String {
        circles.sorted().joined(separator: "|")
    }

    func decodeCircles(from value: String, fallback: Set<String>) -> Set<String> {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return fallback
        }
        return Set(trimmed.split(separator: "|").map { String($0) })
    }
}

private struct FriendStatus: Identifiable {
    let id = UUID()
    let name: String
    let note: String
}

private struct AudienceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let circles: [String]
    @Binding var selectedCircles: Set<String>
    @Binding var audienceMode: String
    let onConfirm: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Who sees you in?")
                .font(.custom("Avenir Next", size: 20))
                .fontWeight(.bold)

            Button(action: {
                audienceMode = "everyone"
            }) {
                HStack {
                    Text("Everyone")
                        .font(.custom("Avenir Next", size: 16))
                        .fontWeight(.bold)
                    Spacer()
                    if audienceMode == "everyone" {
                        Image(systemName: "checkmark.circle.fill")
                    }
                }
            }
            .foregroundColor(.black)

            Button(action: {
                audienceMode = "circles"
            }) {
                HStack {
                    Text("Choose circles")
                        .font(.custom("Avenir Next", size: 16))
                        .fontWeight(.bold)
                    Spacer()
                    if audienceMode == "circles" {
                        Image(systemName: "checkmark.circle.fill")
                    }
                }
            }
            .foregroundColor(.black)

            if audienceMode == "circles" {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(circles, id: \.self) { circle in
                        Toggle(isOn: Binding(
                            get: { selectedCircles.contains(circle) },
                            set: { isOn in
                                if isOn {
                                    selectedCircles.insert(circle)
                                } else {
                                    selectedCircles.remove(circle)
                                }
                            }
                        )) {
                            Text(circle)
                                .font(.custom("Avenir Next", size: 14))
                        }
                    }
                }
            }

            Spacer()

            Button(action: onConfirm) {
                Text("Continue")
                    .font(.custom("Avenir Next", size: 16))
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.55, green: 0.6, blue: 0.7))
                    .foregroundColor(.white)
                    .cornerRadius(14)
            }
            .simultaneousGesture(TapGesture().onEnded {
                dismiss()
            })
        }
        .padding(24)
    }
}
