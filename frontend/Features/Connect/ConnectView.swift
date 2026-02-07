import SwiftUI
import UIKit

struct ConnectView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var chatStore: ChatStore
    @EnvironmentObject private var safetyStore: SafetyStore
    @EnvironmentObject private var statusStore: StatusStore
    @StateObject private var viewModel = ConnectViewModel()
    @State private var showActions = false
    @State private var path: [ConnectRoute] = []
    @State private var showAudienceSheet = false
    @State private var headerOpacity: Double = 0
    @AppStorage("audienceSelectionMode") private var audienceSelectionMode = "everyone"
    @AppStorage("audienceSelectionCircles") private var audienceSelectionCircles = ""
    @AppStorage("audienceSelectionCircleIds") private var audienceSelectionCircleIds = ""
    @AppStorage("audienceSelectionCircle") private var legacyAudienceSelectionCircle = ""
    @State private var friends: [FriendListItem] = []
    @Environment(\.scenePhase) private var scenePhase

    @EnvironmentObject private var circleStore: CircleStore
    private let friendRequestService = FriendRequestService()

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                DesignColors.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    ScrollOffsetReader(coordinateSpace: "connectScroll")

                    VStack(alignment: .leading, spacing: 24) {
                        StatusCardView(
                            status: $viewModel.status,
                            visibleChips: visibleChips,
                            onVisibleToTap: { showAudienceSheet = true },
                            onStatusChange: { newStatus in
                                Task {
                                    guard let session = await sessionManager.validSession() else { return }
                                    let visibility = availabilityVisibility
                                    await viewModel.setStatus(
                                        newStatus,
                                        visibilityMode: visibility.mode,
                                        visibilityCircleIds: visibility.circleIds,
                                        session: session
                                    )
                                }
                            }
                        )

                        if !viewModel.pendingRequests.isEmpty {
                            PendingRequestsCard(
                                requests: viewModel.pendingRequests,
                                onAccept: { request in
                                    Task {
                                        guard let session = await sessionManager.validSession() else { return }
                                        await viewModel.respondToRequest(request, accept: true, session: session)
                                    }
                                },
                                onDecline: { request in
                                    Task {
                                        guard let session = await sessionManager.validSession() else { return }
                                        await viewModel.respondToRequest(request, accept: false, session: session)
                                    }
                                }
                            )
                        }

                        InNowRowView(
                            users: viewModel.inNowUsers,
                            isLoading: viewModel.isLoadingInNow,
                            onSelect: { user in
                                if let existing = viewModel.thread(for: user) {
                                    path.append(.thread(existing))
                                } else {
                                    path.append(.chatDetail(user))
                                }
                            },
                            onAddFriend: { path.append(.friends) }
                        )

                        ChatsSection(
                            threads: viewModel.filteredThreads,
                            selectedFilter: viewModel.selectedFilter,
                            isLoading: viewModel.isLoadingThreads,
                            onStartChat: { path.append(.newChat(nil)) }
                        ) { filter in
                            viewModel.selectedFilter = filter
                        } onSelect: { thread in
                            path.append(.thread(thread))
                        } onDelete: { thread in
                            Task {
                                guard let session = await sessionManager.validSession() else { return }
                                await viewModel.deleteThread(thread, session: session)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
                .coordinateSpace(name: "connectScroll")
                .onPreferenceChange(ScrollOffsetKey.self) { value in
                    let progress = min(max((-value) / 14, 0), 1)
                    headerOpacity = progress
                }
                .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
                    Task { await enforceAutoResetIfNeeded() }
                }
            }
            .safeAreaInset(edge: .top) {
                GlassHeaderContainer(opacity: headerOpacity) {
                    ConnectNavBar(
                        onAdd: { showActions = true }
                    )
                }
            }
            .plusActionSheet(
                isPresented: $showActions,
                friends: friends,
                onNewChat: { friend in
                    Task {
                        guard let session = await sessionManager.validSession() else { return }
                        let inUser = InUser(id: friend.id, name: friend.name, handle: friend.handle)
                        if let thread = await chatStore.openThread(for: inUser, session: session) {
                            path.append(.thread(thread))
                        } else {
                            viewModel.errorMessage = chatStore.errorMessage ?? "Unable to start chat thread."
                        }
                    }
                },
                onNewCircle: { name in
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    Task {
                        guard let session = await sessionManager.validSession() else { return }
                        await circleStore.createCircle(named: trimmed, session: session)
                    }
                },
                onFriends: { path.append(.friends) }
            )
            .navigationDestination(for: ConnectRoute.self) { route in
                switch route {
                case let .chatDetail(user):
                    ChatDetailView(user: user)
                case let .thread(thread):
                    ChatDetailView(thread: thread)
                case let .newChat(initial):
                    NewChatView(initialEmail: initial ?? "")
                case .newCircle:
                    NewCircleView()
                case .friends:
                    FriendsView()
                }
            }
            .alert("Something went wrong", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .sheet(isPresented: $showAudienceSheet) {
                AudiencePickerSheet(circles: circleStore.circles, selection: audienceSelectionBinding)
                    .presentationDetents([.medium])
                    .glassSheetStyle()
            }
            .task(id: sessionManager.session?.userId) {
                guard let session = await sessionManager.validSession() else { return }
                await safetyStore.load(session: session)
                await circleStore.load(session: session)
                normalizeAudienceSelection(using: circleStore.circles)
                await viewModel.loadPendingRequests(session: session)
                await viewModel.loadInNowUsers(session: session)
                await viewModel.loadThreads(session: session)
                await loadFriends(session: session)
                await enforceAutoResetIfNeeded()
            }
            .onAppear {
                Task {
                    guard let session = await sessionManager.validSession() else { return }
                    await viewModel.loadThreads(session: session)
                    await loadFriends(session: session)
                    await enforceAutoResetIfNeeded()
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task { await enforceAutoResetIfNeeded() }
            }
            .onChange(of: viewModel.status) { _, newValue in
                statusStore.recordStatusChange(newValue)
            }
            .onChange(of: circleStore.circles) { _, _ in
                normalizeAudienceSelection(using: circleStore.circles)
            }
            .onChange(of: audienceSelection) { _, _ in
                guard viewModel.status == .in else { return }
                Task {
                    guard let session = await sessionManager.validSession() else { return }
                    let visibility = availabilityVisibility
                    await viewModel.setStatus(
                        .in,
                        visibilityMode: visibility.mode,
                        visibilityCircleIds: visibility.circleIds,
                        session: session
                    )
                }
            }
        }
    }
}

private extension ConnectView {
    @MainActor
    func loadFriends(session: UserSession) async {
        guard AppEnvironment.backend == .supabase else { return }
        do {
            friends = try await friendRequestService.fetchFriends(session: session)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func enforceAutoResetIfNeeded() async {
        guard viewModel.status == .in else { return }
        guard statusStore.shouldAutoReset(status: viewModel.status) else { return }
        guard let session = await sessionManager.validSession() else { return }
        let visibility = availabilityVisibility
        await viewModel.setStatus(
            .out,
            visibilityMode: visibility.mode,
            visibilityCircleIds: visibility.circleIds,
            session: session
        )
    }
}

private struct ConnectNavBar: View {
    let onAdd: () -> Void

    var body: some View {
        HStack {
            LogoBubble()

            Spacer()

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onAdd()
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignColors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }
}

private struct LogoBubble: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)

            Image("ImInLogov2")
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
        }
        .frame(width: 36, height: 36)
    }
}

private struct PendingRequestsCard: View {
    let requests: [FriendRequestItem]
    let onAccept: (FriendRequestItem) -> Void
    let onDecline: (FriendRequestItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pending Requests")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(DesignColors.textPrimary)

            if requests.isEmpty {
                Text("No pending requests right now.")
                    .font(.system(size: 15))
                    .foregroundColor(DesignColors.textSecondary)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(requests.enumerated()), id: \.element.id) { index, request in
                        HStack(spacing: 12) {
                            AvatarView(
                                name: request.name,
                                systemImage: "person.fill"
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(request.name)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(DesignColors.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Text(request.handle)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(DesignColors.textSecondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Button(action: { onAccept(request) }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.badge.plus")
                                    Text("Accept")
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(AppStyle.mint)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(AppStyle.mint.opacity(0.35), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)

                            Button(action: { onDecline(request) }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(DesignColors.textSecondary)
                                    .frame(width: 30, height: 30)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 12)

                        if index < requests.count - 1 {
                            Divider()
                                .background(Color.black.opacity(0.06))
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .cardStyle()
    }

    // actionPill removed in favor of accept + decline styling
}

private struct ChatsSection: View {
    let threads: [ChatThread]
    let selectedFilter: ConnectViewModel.ChatFilter
    let isLoading: Bool
    let onStartChat: () -> Void
    let onFilterChange: (ConnectViewModel.ChatFilter) -> Void
    let onSelect: (ChatThread) -> Void
    let onDelete: (ChatThread) -> Void

    init(
        threads: [ChatThread],
        selectedFilter: ConnectViewModel.ChatFilter,
        isLoading: Bool,
        onStartChat: @escaping () -> Void,
        onFilterChange: @escaping (ConnectViewModel.ChatFilter) -> Void,
        onSelect: @escaping (ChatThread) -> Void,
        onDelete: @escaping (ChatThread) -> Void
    ) {
        self.threads = threads
        self.selectedFilter = selectedFilter
        self.isLoading = isLoading
        self.onStartChat = onStartChat
        self.onFilterChange = onFilterChange
        self.onSelect = onSelect
        self.onDelete = onDelete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Chats")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(DesignColors.textPrimary)

                Spacer()

                FilterPills(
                    filters: FilterPill.allCases,
                    selected: filterPillSelection
                ) { selection in
                    UISelectionFeedbackGenerator().selectionChanged()
                    onFilterChange(selection.toChatFilter())
                }
            }

            if isLoading && threads.isEmpty {
                ChatThreadsSkeletonCardView()
            } else if threads.isEmpty {
                VStack(spacing: 12) {
                    if selectedFilter == .unread {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(DesignColors.accentGreen)
                            .clipShape(Circle())

                        Text("You're all caught up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignColors.textPrimary)

                        Text("No unread chats.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignColors.textSecondary)
                    } else {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(DesignColors.accentGreen.opacity(0.9))
                            .clipShape(Circle())

                        Text("No chats yet")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignColors.textPrimary)

                        Text("Start one from In Now or create a new chat.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignColors.textSecondary)

                        Button(action: onStartChat) {
                            Text("Start a chat")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 16)
                                .background(DesignColors.accentGreen)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ChatThreadsListView(threads: threads, onSelect: onSelect, onDelete: onDelete)
            }
        }
        .padding(16)
        .cardStyle()
    }

    private var filterPillSelection: FilterPill {
        selectedFilter.toFilterPill()
    }
}

private struct ChatDetailView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var chatStore: ChatStore
    @EnvironmentObject private var safetyStore: SafetyStore
    let user: UserPreview?
    let initialThread: ChatThread?
    @State private var messageText = ""
    @State private var thread: ChatThread?
    @State private var isOpeningThread = false
    @State private var errorMessage: String?
    @State private var reportDraft: ReportDraft?
    @State private var showBlockConfirm = false
    @State private var showUnblockConfirm = false

    private struct BlockTarget: Equatable {
        let userId: UserID
        let name: String
    }

    private struct ReportDraft: Identifiable, Equatable {
        let id = UUID()
        let threadId: String
        let messageId: String?
        let reportedUserId: UserID?
        let title: String
        let subtitle: String?
    }

    init(user: UserPreview) {
        self.user = user
        self.initialThread = nil
    }

    init(thread: ChatThread) {
        self.user = nil
        self.initialThread = thread
    }

    var body: some View {
        ZStack {
            DesignColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    if let thread {
                        let messages = chatStore
                            .messages(for: thread)
                            .filter { !safetyStore.isBlocked($0.senderId) }
                        if messages.isEmpty {
                            emptyState
                        } else {
                            VStack(spacing: 16) {
                                ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                    let previous = index > 0 ? messages[index - 1] : nil
                                    if shouldShowTimestamp(current: message, previous: previous) {
                                        timestampView(message.createdAt)
                                    }
                                    messageRow(message, previous: previous, thread: thread)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 18)
                            .padding(.bottom, 12)
                        }
                    } else {
                        emptyState
                    }
                }

                messageComposer
            }
        }
        .navigationTitle(user?.name ?? initialThread?.title ?? "Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        guard let thread else { return }
                        reportDraft = ReportDraft(
                            threadId: thread.id,
                            messageId: nil,
                            reportedUserId: blockTarget?.userId,
                            title: "Report chat",
                            subtitle: "Help us keep Imin safe."
                        )
                    } label: {
                        Label("Report", systemImage: "exclamationmark.bubble")
                    }

                    if let target = blockTarget {
                        if isBlocked(target) {
                            Button {
                                showUnblockConfirm = true
                            } label: {
                                Label("Unblock \(target.name)", systemImage: "person.crop.circle.badge.checkmark")
                            }
                        } else {
                            Button(role: .destructive) {
                                showBlockConfirm = true
                            } label: {
                                Label("Block \(target.name)", systemImage: "hand.raised.fill")
                            }
                        }
                    }
                } label: {
                    ZStack {
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
                            .overlay(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.55),
                                        Color.white.opacity(0.08),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .clipShape(Circle())
                                .blendMode(.screen)
                            )
                            .overlay(
                                Circle()
                                    .stroke(AppStyle.mint.opacity(0.2), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
                            .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)

                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignColors.textPrimary)
                    }
                    .frame(width: 34, height: 34)
                }
            }
        }
        .task {
            await openThreadIfNeeded()
        }
        .onChange(of: thread?.id) { _, _ in
            Task {
                await loadMessagesIfNeeded()
            }
        }
        .alert("Message failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { _ in errorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
        .sheet(item: $reportDraft) { draft in
            ReportSheetView(
                title: draft.title,
                subtitle: draft.subtitle
            ) { reason, details in
                guard let session = await sessionManager.validSession() else { return false }
                let ok = await safetyStore.report(
                    threadId: draft.threadId,
                    messageId: draft.messageId,
                    reportedUserId: draft.reportedUserId,
                    reason: reason.rawValue,
                    details: details,
                    session: session
                )
                if !ok {
                    errorMessage = safetyStore.errorMessage
                }
                return ok
            }
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Block user?", isPresented: $showBlockConfirm, titleVisibility: .visible) {
            if let target = blockTarget {
                Button("Block \(target.name)", role: .destructive) {
                    Task { await block(target) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won't be able to message you, and you won't see them in your chat.")
        }
        .confirmationDialog("Unblock user?", isPresented: $showUnblockConfirm, titleVisibility: .visible) {
            if let target = blockTarget {
                Button("Unblock \(target.name)") {
                    Task { await unblock(target) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll be able to message each other again.")
        }
    }

    private var blockTarget: BlockTarget? {
        if let user {
            return BlockTarget(userId: user.id.uuidString, name: user.name)
        }

        guard let thread else { return nil }
        if thread.participants.count == 1, let participant = thread.participants.first {
            let id = participant.id.uuidString
            if id == sessionManager.session?.userId { return nil }
            return BlockTarget(userId: id, name: participant.name)
        }

        if thread.participants.isEmpty, !thread.participantId.isEmpty, thread.participantId != sessionManager.session?.userId {
            return BlockTarget(userId: thread.participantId, name: thread.title)
        }

        return nil
    }

    private func isBlocked(_ target: BlockTarget) -> Bool {
        safetyStore.isBlocked(target.userId)
    }

    @MainActor
    private func block(_ target: BlockTarget) async {
        guard let session = await sessionManager.validSession() else { return }
        let ok = await safetyStore.block(userId: target.userId, session: session)
        if !ok {
            errorMessage = safetyStore.errorMessage ?? "Couldn't block user."
        }
    }

    @MainActor
    private func unblock(_ target: BlockTarget) async {
        guard let session = await sessionManager.validSession() else { return }
        let ok = await safetyStore.unblock(userId: target.userId, session: session)
        if !ok {
            errorMessage = safetyStore.errorMessage ?? "Couldn't unblock user."
        }
    }

    private var messageComposer: some View {
        let isDisabled = messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !AppEnvironment.isChatBackendEnabled
            || (blockTarget.map(isBlocked) ?? false)
        return VStack(spacing: 0) {
            Divider()
                .background(Color.black.opacity(0.08))

            if let target = blockTarget, isBlocked(target) {
                HStack(spacing: 10) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DesignColors.textSecondary)
                    Text("You blocked \(target.name).")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(DesignColors.textSecondary)
                    Spacer()
                    Button("Unblock") {
                        showUnblockConfirm = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(DesignColors.accentGreen)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            HStack(spacing: 10) {
                TextField("Message", text: $messageText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(DesignColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(isDisabled ? Color.black.opacity(0.1) : DesignColors.accentGreen)
                        .clipShape(Circle())
                }
                .disabled(isDisabled)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .padding(.bottom, 72)
        .background(DesignColors.background)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image("IminLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)
                .opacity(0.2)

            Text(isOpeningThread ? "Starting chat..." : "No messages yet.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(DesignColors.textSecondary)
        }
        .padding(.top, 90)
        .frame(maxWidth: .infinity)
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        let isMe = message.senderId == sessionManager.session?.userId
        return HStack {
            if isMe { Spacer() }
            Text(message.body)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isMe ? DesignColors.accentGreen : DesignColors.card)
                .foregroundColor(isMe ? .white : DesignColors.textPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            if !isMe { Spacer() }
        }
        .padding(.horizontal, 4)
    }

    private func messageRow(_ message: ChatMessage, previous: ChatMessage?, thread: ChatThread) -> some View {
        let isMe = message.senderId == sessionManager.session?.userId
        let showHeader = shouldShowHeader(current: message, previous: previous)
        let senderName = senderDisplayName(for: message, thread: thread)
        let timeText = Self.timeFormatter.string(from: message.createdAt)
        let outgoingBubble = AppStyle.mint.opacity(0.18)

        return HStack(alignment: .top, spacing: 12) {
            if isMe {
                Spacer()
            }

            if !isMe {
                if showHeader {
                    MessageAvatarView(name: senderName, isMe: isMe)
                } else {
                    Color.clear
                        .frame(width: 36, height: 36)
                }
            }

            VStack(alignment: isMe ? .trailing : .leading, spacing: 6) {
                if showHeader {
                    if isMe {
                        Text(timeText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(DesignColors.textSecondary.opacity(0.7))
                    } else {
                        HStack(spacing: 6) {
                            Text(senderName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(DesignColors.textPrimary)

                            Text(timeText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(DesignColors.textSecondary.opacity(0.7))
                        }
                    }
                }

                if isMe {
                    Text(message.body)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignColors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(outgoingBubble)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text(message.body)
                        .font(.system(size: 14))
                        .foregroundColor(DesignColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }

            if !isMe {
                Spacer()
            }
        }
        .contextMenu {
            if !isMe {
                Button {
                    reportDraft = ReportDraft(
                        threadId: thread.id,
                        messageId: message.id,
                        reportedUserId: message.senderId,
                        title: "Report message",
                        subtitle: "Tell us what's going on."
                    )
                } label: {
                    Label("Report message", systemImage: "exclamationmark.bubble")
                }
            }
        }
    }

    private func timestampView(_ date: Date) -> some View {
        Text(timestampText(for: date))
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(DesignColors.textSecondary.opacity(0.7))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }

    private func shouldShowTimestamp(current: ChatMessage, previous: ChatMessage?) -> Bool {
        guard let previous else { return true }
        let calendar = Calendar.current
        if !calendar.isDate(current.createdAt, inSameDayAs: previous.createdAt) {
            return true
        }
        return current.createdAt.timeIntervalSince(previous.createdAt) > 3600
    }

    private func shouldShowHeader(current: ChatMessage, previous: ChatMessage?) -> Bool {
        guard let previous else { return true }
        if current.senderId != previous.senderId {
            return true
        }
        return current.createdAt.timeIntervalSince(previous.createdAt) > 300
    }

    private func senderDisplayName(for message: ChatMessage, thread: ChatThread) -> String {
        if message.senderId == sessionManager.session?.userId {
            return "You"
        }
        if let participant = thread.participants.first(where: { $0.id.uuidString == message.senderId }) {
            return participant.name
        }
        return thread.title
    }

    private func timestampText(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today \(Self.timeFormatter.string(from: date))"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday \(Self.timeFormatter.string(from: date))"
        }
        return Self.dateFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }()

    @MainActor
    private func openThreadIfNeeded() async {
        guard AppEnvironment.isChatBackendEnabled else { return }
        guard let session = await sessionManager.validSession() else { return }
        if thread == nil {
            isOpeningThread = true
            if let initialThread {
                thread = initialThread
            } else if let user {
                let inUser = InUser(id: user.id.uuidString, name: user.name, handle: user.name)
                if let opened = await chatStore.openThread(for: inUser, session: session) {
                    thread = opened
                }
            }
            isOpeningThread = false
            if thread == nil {
                errorMessage = chatStore.errorMessage ?? "Unable to start chat thread."
            }
        }
        await loadMessagesIfNeeded()
    }

    @MainActor
    private func loadMessagesIfNeeded() async {
        guard AppEnvironment.isChatBackendEnabled else { return }
        guard let session = await sessionManager.validSession(),
              let thread else { return }
        await chatStore.loadMessages(for: thread, session: session)
    }

    private func sendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        messageText = ""
        Task {
            guard AppEnvironment.isChatBackendEnabled else { return }
            guard let session = await sessionManager.validSession() else { return }
            if thread == nil {
                isOpeningThread = true
                if let initialThread {
                    thread = initialThread
                } else if let user {
                    let inUser = InUser(id: user.id.uuidString, name: user.name, handle: user.name)
                    if let opened = await chatStore.openThread(for: inUser, session: session) {
                        thread = opened
                    }
                }
                isOpeningThread = false
            }
            guard let thread else {
                errorMessage = chatStore.errorMessage ?? "Unable to start chat thread."
                return
            }
            await chatStore.sendMessage(in: thread, body: trimmed, session: session)
            await chatStore.loadMessages(for: thread, session: session)
        }
    }
}

private struct MessageAvatarView: View {
    let name: String
    let isMe: Bool

    var body: some View {
        Circle()
            .fill(AvatarGradient.gradient(for: name))
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 2)
            )
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .overlay(
                Text(initials(from: name))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignColors.textPrimary)
                    .shadow(color: Color.black.opacity(0.08), radius: 1, x: 0, y: 1)
            )
            .frame(width: 36, height: 36)
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.dropFirst().first?.prefix(1) ?? ""
        return (first + last).uppercased()
    }
}

enum ConnectRoute: Hashable {
    case newChat(String?)
    case newCircle
    case friends
    case chatDetail(UserPreview)
    case thread(ChatThread)
}

private extension ConnectViewModel.ChatFilter {
    func toFilterPill() -> FilterPill {
        switch self {
        case .all:
            return .all
        case .unread:
            return .unread
        }
    }
}

private extension FilterPill {
    func toChatFilter() -> ConnectViewModel.ChatFilter {
        switch self {
        case .all:
            return .all
        case .unread:
            return .unread
        }
    }
}

struct ConnectView_Previews: PreviewProvider {
    static var previews: some View {
        ConnectView()
            .previewDisplayName("Connect")
    }
}

private extension ConnectView {
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
        }
    }

    var audienceSelectionBinding: Binding<AudienceSelection> {
        Binding(get: { audienceSelection }, set: { newValue in
            audienceSelection = newValue
        })
    }

    var visibleChips: [String] {
        switch audienceSelection {
        case .everyone:
            return ["Everyone"]
        case .circles(let ids):
            let names = circleStore.circles
                .filter { ids.contains($0.id) }
                .map { $0.name }
            return names.isEmpty ? ["Choose circles"] : names
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

    var availabilityVisibility: (mode: AvailabilityVisibilityMode, circleIds: [UUID]) {
        switch audienceSelection {
        case .everyone:
            return (.everyone, [])
        case .circles(let ids):
            return (.circles, ids)
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
