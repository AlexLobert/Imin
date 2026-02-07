import SwiftUI

struct CirclesView: View {
    @EnvironmentObject private var circleStore: CircleStore
    @EnvironmentObject private var sessionManager: SessionManager
    @State private var showCreateCircle = false
    @State private var headerOpacity: Double = 0

    var body: some View {
        NavigationStack {
            ZStack {
                DesignColors.background
                    .ignoresSafeArea()

                ScrollView {
                    ScrollOffsetReader(coordinateSpace: "circlesScroll")
                    VStack(alignment: .leading, spacing: 16) {
                        subtitle

                        circlesList

                        if let errorMessage = circleStore.errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .coordinateSpace(name: "circlesScroll")
                .onPreferenceChange(ScrollOffsetKey.self) { value in
                    let progress = min(max((-value) / 14, 0), 1)
                    headerOpacity = progress
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .tint(.primary)
            .safeAreaInset(edge: .top) {
                GlassHeaderContainer(opacity: headerOpacity) {
                    header
                }
            }
            .navigationDestination(for: CircleGroup.self) { circle in
                CircleDetailView(circleId: circle.id)
                    .environmentObject(circleStore)
            }
            .sheet(isPresented: $showCreateCircle) {
                CreateCircleSheet { name in
                    Task {
                        guard let session = await sessionManager.validSession() else { return }
                        await circleStore.createCircle(named: name, session: session)
                        showCreateCircle = false
                    }
                }
            }
            .task(id: sessionManager.session?.userId) {
                guard let session = await sessionManager.validSession() else { return }
                await circleStore.load(session: session)
            }
        }
    }
}

private extension CirclesView {
    var header: some View {
        IminTopNavBar(title: "Circles") {
            TopIconCircleButton(systemName: "plus", accessibilityLabel: "Create a circle") {
                showCreateCircle = true
            }
        }
    }

    var subtitle: some View {
        EmptyView()
    }

    var circlesList: some View {
        VStack(spacing: 0) {
            if circleStore.isLoading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Loading circles...")
                        .font(.system(size: 15))
                        .foregroundStyle(DesignColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if circleStore.circles.isEmpty {
                VStack(spacing: 12) {
                    Text("No circles yet.")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DesignColors.textPrimary)
                    Text("Create a circle to control who can see your status.")
                        .font(.system(size: 14))
                        .foregroundStyle(DesignColors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Create circle") {
                        showCreateCircle = true
                    }
                    .buttonStyle(AppPillButtonStyle(kind: .mint))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ForEach(Array(circleStore.circles.enumerated()), id: \.element.id) { index, circle in
                    NavigationLink(value: circle) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(circle.name)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(DesignColors.textPrimary)
                                Text("\(circle.members.count) friends")
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundStyle(DesignColors.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DesignColors.textSecondary)
                        }
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)

                    if index < circleStore.circles.count - 1 {
                        Divider()
                            .background(ConnectColors.divider)
                            .padding(.leading, 2)
                    }
                }
            }
        }
        .padding(18)
        .cardStyle()
    }
}

struct CircleGroup: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var members: [CircleMember]

    init(id: UUID = UUID(), name: String, members: [CircleMember]) {
        self.id = id
        self.name = name
        self.members = members
    }
}

struct CircleMember: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let handle: String?

    init(id: UUID = UUID(), name: String, handle: String? = nil) {
        self.id = id
        self.name = name
        self.handle = handle
    }
}

private struct CircleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: CircleStore
    @EnvironmentObject private var sessionManager: SessionManager
    private let friendRequestService = FriendRequestService()
    @State private var showAddMember = false
    @State private var showRename = false
    @State private var showDelete = false
    @State private var friends: [FriendListItem] = []
    @State private var isLoadingFriends = false
    @State private var friendsError: String?

    let circleId: UUID

    var body: some View {
        let circle = viewModel.circle(for: circleId)
        ZStack {
            DesignColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let circle {

                        HStack(spacing: 12) {
                            Button {
                                showAddMember = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("Add member")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.plain)
                            .foregroundColor(DesignColors.textPrimary)
                            .frame(height: 48)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(Color.white.opacity(0.55), lineWidth: 1)
                                            .blendMode(.overlay)
                                    )
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                    )
                                    .overlay(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.60),
                                                Color.white.opacity(0.06),
                                                Color.clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        .clipShape(Capsule(style: .continuous))
                                        .blendMode(.screen)
                                    )
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(AppStyle.mint.opacity(0.22), lineWidth: 1)
                                    )
                                    .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
                                    .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                            )

                            Button {
                                showRename = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("Rename")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.plain)
                            .foregroundColor(DesignColors.textPrimary)
                            .frame(height: 48)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(Color.white.opacity(0.55), lineWidth: 1)
                                            .blendMode(.overlay)
                                    )
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                    )
                                    .overlay(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.60),
                                                Color.white.opacity(0.06),
                                                Color.clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        .clipShape(Capsule(style: .continuous))
                                        .blendMode(.screen)
                                    )
                                    .shadow(color: .black.opacity(0.08), radius: 14, x: 0, y: 8)
                                    .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                            )
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 0) {
                            ForEach(Array(circle.members.enumerated()), id: \.element.id) { index, member in
                                HStack(spacing: 12) {
                                    AvatarView(name: member.name, systemImage: "person.fill")

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(member.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(DesignColors.textPrimary)
                                            .lineLimit(1)
                                        if let handle = member.handle, !handle.isEmpty {
                                            Text(handle)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(DesignColors.textSecondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    Button {
                                        Task {
                                            guard let session = await sessionManager.validSession() else { return }
                                            await viewModel.removeMember(from: circleId, memberId: member.id, session: session)
                                        }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(DesignColors.textSecondary)
                                            .frame(width: 28, height: 28)
                                            .background(
                                                Circle()
                                                    .fill(.ultraThinMaterial)
                                                    .overlay(
                                                        Circle()
                                                            .stroke(Color.white.opacity(0.55), lineWidth: 1)
                                                            .blendMode(.overlay)
                                                    )
                                                    .overlay(
                                                        Circle()
                                                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)

                                if index < circle.members.count - 1 {
                                    Divider()
                                        .background(ConnectColors.divider)
                                        .padding(.leading, 16 + 52 + 12)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .glassCardStyle(cornerRadius: 22)

                        Button("Delete circle") {
                            showDelete = true
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .glassCardStyle(cornerRadius: 22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.red.opacity(0.18), lineWidth: 1)
                        )
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.primary)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if let circle {
                    VStack(spacing: 2) {
                        Text(circle.name)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(DesignColors.textPrimary)
                        Text("\(circle.members.count) friends")
                            .font(.system(size: 12))
                            .foregroundColor(DesignColors.textSecondary)
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(DesignColors.textPrimary)
            }
        }
        .sheet(isPresented: $showAddMember) {
            CircleMemberPickerSheet(
                friends: availableFriends(for: circle),
                isLoading: isLoadingFriends,
                errorMessage: friendsError,
                onSelect: { friend in
                    Task {
                        guard let session = await sessionManager.validSession() else { return }
                        await viewModel.addMember(to: circleId, friend: friend, session: session)
                        showAddMember = false
                    }
                }
            )
            .glassSheetStyle()
            .task {
                await loadFriends()
            }
        }
        .sheet(isPresented: $showRename) {
            CircleTextEntrySheet(title: "Rename circle", buttonTitle: "Save") { name in
                Task {
                    guard let session = await sessionManager.validSession() else { return }
                    await viewModel.renameCircle(id: circleId, name: name, session: session)
                    showRename = false
                }
            }
            .glassSheetStyle()
        }
        .alert("Delete circle?", isPresented: $showDelete) {
            Button("Delete", role: .destructive) {
                Task {
                    guard let session = await sessionManager.validSession() else { return }
                    await viewModel.deleteCircle(id: circleId, session: session)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will delete this circle.")
        }
    }
}

private struct CreateCircleSheet: View {
    @State private var name = ""
    let onCreate: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create a circle")
                .font(.system(size: 20, weight: .semibold))

            TextField("Circle name", text: $name)
                .padding(16)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .cardStyle()

            Button("Create") {
                onCreate(name)
            }
            .buttonStyle(AppPillButtonStyle(kind: .mint))
        }
        .padding(24)
    }
}

private struct CircleMemberPickerSheet: View {
    let friends: [FriendListItem]
    let isLoading: Bool
    let errorMessage: String?
    let onSelect: (FriendListItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add member")
                .font(.system(size: 20, weight: .semibold))

            if isLoading {
                Text("Loading friends...")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
            } else if friends.isEmpty {
                Text("No friends to add yet.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(friends) { friend in
                            Button(action: {
                                onSelect(friend)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(friend.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(DesignColors.textPrimary)
                                        Text(friend.handle)
                                            .font(.system(size: 13))
                                            .foregroundColor(DesignColors.textSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(AppColors.accentGreen)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 16)
                                .cardStyle()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(24)
    }
}

private struct CircleTextEntrySheet: View {
    @State private var value = ""
    let title: String
    let buttonTitle: String
    let onConfirm: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 20, weight: .semibold))

            TextField("Name", text: $value)
                .padding(16)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .cardStyle()

            Button(buttonTitle) {
                onConfirm(value)
            }
            .buttonStyle(AppPillButtonStyle(kind: .mint))
        }
        .padding(24)
    }
}

private extension CircleDetailView {
    func loadFriends() async {
        guard !isLoadingFriends else { return }
        isLoadingFriends = true
        friendsError = nil
        defer { isLoadingFriends = false }

        guard let session = await sessionManager.validSession() else { return }
        do {
            friends = try await friendRequestService.fetchFriends(session: session)
        } catch {
            friendsError = error.localizedDescription
        }
    }

    func availableFriends(for circle: CircleGroup?) -> [FriendListItem] {
        guard let circle else { return friends }
        let existing = Set(circle.members.map(\.id))
        return friends.filter { friend in
            guard let id = UUID(uuidString: friend.id) else { return false }
            return !existing.contains(id)
        }
    }
}
