import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @StateObject private var viewModel = HomeViewModel()
    @State private var showAudienceSheet = false
    @State private var pendingInUpdate = false
    @AppStorage("audienceSelectionMode") private var audienceSelectionMode = "everyone"
    @AppStorage("audienceSelectionCircles") private var audienceSelectionCircles = ""
    @AppStorage("audienceSelectionCircle") private var legacyAudienceSelectionCircle = ""

    private let circles = ["Inner circle", "Roommates", "Late-night crew", "Gym buddies"]
    private let friendsIn: [FriendStatus] = []

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
                    AppBarView(title: "", logoName: "IminLogo", logoHeight: 60, trailingSystemImage: "person.crop.circle")

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tonight, are you...")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.primary)

                        InOutTogglePill(
                            isIn: viewModel.availabilityState == .inOffice,
                            onInTap: handleInTap,
                            onOutTap: handleOutTap
                        )
                        .frame(height: 52)
                        .padding(.top, 4)
                    }

                    if viewModel.isLoadingAvailability {
                        Text("Checking your status...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    audienceSection

                    friendsSection

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
                .padding(AppSpacing.screenPadding)
            }
        }
        .task(id: sessionManager.session?.userId) {
            await loadAvailability()
        }
        .sheet(isPresented: $showAudienceSheet) {
            AudiencePickerSheet(circles: circles, selection: audienceSelectionBinding)
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
    var audienceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                showAudienceSheet = true
            }) {
                ListRow(title: "Visible to", value: audienceSelection.label, showsDivider: false)
            }
            .buttonStyle(.plain)

            Divider()
                .background(AppColors.separator)
        }
    }

    var friendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Friends who are in")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            if friendsIn.isEmpty {
                Text("No one's in yet. Be the first to say you're in.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(friendsIn.enumerated()), id: \.element.id) { index, friend in
                        StatusFriendRow(name: friend.name, subtitle: friend.note, showsMessageIcon: true)

                        if index < friendsIn.count - 1 {
                            Divider()
                                .background(AppColors.separator)
                        }
                    }
                }
            }
        }
    }

    var audienceSelection: AudienceSelection {
        get {
            let storedCircles = audienceSelectionCircles
                .split(separator: "|")
                .map { String($0) }
                .filter { !$0.isEmpty }
            if audienceSelectionMode == "circles", !storedCircles.isEmpty {
                return .circles(storedCircles)
            }
            if audienceSelectionMode == "circle", !legacyAudienceSelectionCircle.isEmpty {
                return .circles([legacyAudienceSelectionCircle])
            }
            return .everyone
        }
        nonmutating set {
            switch newValue {
            case .everyone:
                audienceSelectionMode = "everyone"
                audienceSelectionCircles = ""
                legacyAudienceSelectionCircle = ""
            case .circles(let names):
                if names.isEmpty {
                    audienceSelectionMode = "everyone"
                    audienceSelectionCircles = ""
                    legacyAudienceSelectionCircle = ""
                } else {
                    audienceSelectionMode = "circles"
                    audienceSelectionCircles = names.joined(separator: "|")
                    legacyAudienceSelectionCircle = ""
                }
            }

            if pendingInUpdate {
                pendingInUpdate = false
                updateAvailabilityIn()
            }
        }
    }

    var audienceSelectionBinding: Binding<AudienceSelection> {
        Binding(get: { audienceSelection }, set: { newValue in
            audienceSelection = newValue
        })
    }

    func handleInTap() {
        guard sessionManager.session != nil else { return }
        if viewModel.availabilityState == .inOffice {
            return
        }
        pendingInUpdate = true
        showAudienceSheet = true
    }

    func handleOutTap() {
        Task {
            if let session = await sessionManager.validSession() {
                await viewModel.updateAvailability(state: .out, session: session)
            }
        }
    }

    func updateAvailabilityIn() {
        Task {
            guard let session = await sessionManager.validSession() else { return }
            await viewModel.updateAvailability(state: .inOffice, session: session)
        }
    }
}

private struct FriendStatus: Identifiable {
    let id = UUID()
    let name: String
    let note: String
}
