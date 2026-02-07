import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var circleStore: CircleStore
    @StateObject private var viewModel = HomeViewModel()
    @State private var showAudienceSheet = false
    @State private var showProfileSheet = false
    @State private var pendingInUpdate = false
    @AppStorage("audienceSelectionMode") private var audienceSelectionMode = "everyone"
    @AppStorage("audienceSelectionCircles") private var audienceSelectionCircles = ""
    @AppStorage("audienceSelectionCircleIds") private var audienceSelectionCircleIds = ""
    @AppStorage("audienceSelectionCircle") private var legacyAudienceSelectionCircle = ""

    private let friendsIn: [FriendStatus] = []

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
                    AppBarView(
                        title: "",
                        logoName: "IminLogo",
                        logoHeight: 60,
                        trailingSystemImage: "person.crop.circle",
                        trailingAction: { showProfileSheet = true }
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Tonight, are you...")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.primary)

                        InOutSlider(
                            value: $viewModel.availabilityState,
                            onInTap: handleInTap,
                            onOutTap: handleOutTap
                        )
                        .frame(height: 48)
                        .padding(.top, 4)
                    }

                    if viewModel.isLoadingAvailability {
                        Text("Checking your status...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    if viewModel.availabilityState == .inOffice {
                        audienceSection
                    }

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
            if let session = await sessionManager.validSession() {
                await circleStore.load(session: session)
                normalizeAudienceSelection(using: circleStore.circles)
            }
        }
        .sheet(isPresented: $showAudienceSheet) {
            AudiencePickerSheet(circles: circleStore.circles, selection: audienceSelectionBinding)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileView()
                .environmentObject(sessionManager)
        }
        .onChange(of: circleStore.circles) { _, _ in
            normalizeAudienceSelection(using: circleStore.circles)
        }
        .onChange(of: audienceSelection) { _, _ in
            guard viewModel.availabilityState == .inOffice else { return }
            Task {
                guard let session = await sessionManager.validSession() else { return }
                let visibility = availabilityVisibility
                await viewModel.updateAvailability(
                    state: .inOffice,
                    visibilityMode: visibility.mode,
                    visibilityCircleIds: visibility.circleIds,
                    session: session
                )
            }
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
                ListRow(title: "Visible to", value: audienceSelection.label(using: circleStore.circles), showsDivider: false)
            }
            .buttonStyle(.plain)

            Divider()
                .background(AppColors.separator)
        }
    }

    var friendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("In now")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)

            if friendsIn.isEmpty {
                Text("No one's in yet - be the first.")
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
            let storedIds = decodeCircleIds(audienceSelectionCircleIds)
            if audienceSelectionMode == "circles", !storedIds.isEmpty {
                return .circles(storedIds)
            }
            if audienceSelectionMode == "circles" {
                let legacy = legacyCircleIds(using: circleStore.circles)
                if !legacy.isEmpty {
                    return .circles(legacy)
                }
            }
            if audienceSelectionMode == "circle", !legacyAudienceSelectionCircle.isEmpty {
                let legacy = legacyCircleIds(using: circleStore.circles)
                if !legacy.isEmpty {
                    return .circles(legacy)
                }
            }
            return .everyone
        }
        nonmutating set {
            switch newValue {
            case .everyone:
                audienceSelectionMode = "everyone"
                audienceSelectionCircles = ""
                audienceSelectionCircleIds = ""
                legacyAudienceSelectionCircle = ""
            case .circles(let ids):
                if ids.isEmpty {
                    audienceSelectionMode = "everyone"
                    audienceSelectionCircles = ""
                    audienceSelectionCircleIds = ""
                    legacyAudienceSelectionCircle = ""
                } else {
                    audienceSelectionMode = "circles"
                    audienceSelectionCircles = ""
                    audienceSelectionCircleIds = encodeCircleIds(ids)
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
                let visibility = availabilityVisibility
                await viewModel.updateAvailability(
                    state: .out,
                    visibilityMode: visibility.mode,
                    visibilityCircleIds: visibility.circleIds,
                    session: session
                )
            }
        }
    }

    func updateAvailabilityIn() {
        Task {
            guard let session = await sessionManager.validSession() else { return }
            let visibility = availabilityVisibility
            await viewModel.updateAvailability(
                state: .inOffice,
                visibilityMode: visibility.mode,
                visibilityCircleIds: visibility.circleIds,
                session: session
            )
        }
    }
}

private extension HomeView {
    var availabilityVisibility: (mode: AvailabilityVisibilityMode, circleIds: [UUID]) {
        switch audienceSelection {
        case .everyone:
            return (.everyone, [])
        case .circles(let ids):
            return (.circles, ids)
        }
    }

    func normalizeAudienceSelection(using circles: [CircleGroup]) {
        guard case .circles = audienceSelection else { return }
        let allowed = Set(circles.map(\.id))
        var resolved = decodeCircleIds(audienceSelectionCircleIds)
        if resolved.isEmpty {
            resolved = legacyCircleIds(using: circles)
        }
        let filtered = resolved.filter { allowed.contains($0) }
        if filtered.isEmpty {
            audienceSelection = .everyone
        } else if filtered != resolved {
            audienceSelection = .circles(filtered)
        }
    }

    func decodeCircleIds(_ raw: String) -> [UUID] {
        raw.split(separator: "|")
            .compactMap { UUID(uuidString: String($0)) }
    }

    func encodeCircleIds(_ ids: [UUID]) -> String {
        ids.map(\.uuidString).joined(separator: "|")
    }

    func legacyCircleIds(using circles: [CircleGroup]) -> [UUID] {
        let legacyNames = audienceSelectionCircles
            .split(separator: "|")
            .map { String($0) }
            .filter { !$0.isEmpty }
        let legacySingle = legacyAudienceSelectionCircle.isEmpty ? [] : [legacyAudienceSelectionCircle]
        let names = Set((legacyNames + legacySingle).map { $0.lowercased() })
        guard !names.isEmpty else { return [] }
        return circles.filter { names.contains($0.name.lowercased()) }.map(\.id)
    }
}

private struct FriendStatus: Identifiable {
    let id = UUID()
    let name: String
    let note: String
}
