import SwiftUI

struct ConnectView: View {
    @StateObject private var viewModel = ConnectViewModel()
    @State private var showActions = false
    @State private var path: [ConnectRoute] = []
    @State private var showAudienceSheet = false
    @AppStorage("audienceSelectionMode") private var audienceSelectionMode = "everyone"
    @AppStorage("audienceSelectionCircles") private var audienceSelectionCircles = ""
    @AppStorage("audienceSelectionCircle") private var legacyAudienceSelectionCircle = ""

    private let circles = ["Inner circle", "Roommates", "Late-night crew", "Gym buddies"]

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                DesignColors.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        ConnectNavBar(
                            onAdd: { showActions = true }
                        )

                        StatusCardView(
                            status: $viewModel.status,
                            visibleChips: visibleChips,
                            onVisibleToTap: { showAudienceSheet = true },
                            onStatusChange: viewModel.setStatus
                        )
                        .frame(maxWidth: .infinity)

                        InNowRowView(users: viewModel.inNowUsers) { user in
                            path.append(.chatDetail(user))
                        }

                        ChatsSection(
                            threads: viewModel.filteredThreads,
                            selectedFilter: viewModel.selectedFilter
                        ) { filter in
                            viewModel.selectedFilter = filter
                        } onSelect: { thread in
                            let user = thread.participants.first ?? UserPreview(name: thread.title, status: .out)
                            path.append(.chatDetail(user))
                        }
                    }
                    .padding(.horizontal, 20)
                    .safeAreaPadding(.top, 8)
                    .padding(.bottom, 28)
                }
            }
            .plusActionSheet(
                isPresented: $showActions,
                onNewChat: { path.append(.newChat) },
                onNewCircle: { path.append(.newCircle) },
                onAddFriend: { path.append(.addFriend) }
            )
            .navigationDestination(for: ConnectRoute.self) { route in
                switch route {
                case let .chatDetail(user):
                    ChatDetailView(user: user)
                case .newChat:
                    NewChatView()
                case .newCircle:
                    NewCircleView()
                case .addFriend:
                    AddFriendView()
                }
            }
            .alert("Couldn’t update status", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { _ in viewModel.errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
            .sheet(isPresented: $showAudienceSheet) {
                AudiencePickerSheet(circles: circles, selection: audienceSelectionBinding)
                    .presentationDetents([.medium])
            }
        }
    }
}

private struct ConnectNavBar: View {
    let onAdd: () -> Void

    var body: some View {
        ZStack {
            HStack {
                LogoBubble()

                Spacer()

                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(DesignColors.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(DesignColors.card)
                                .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
                        )
                }
                .buttonStyle(.plain)
            }

            ZStack {
                Image("IminLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .opacity(0.03)
                    .offset(y: -10)

                Text("Connect")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(DesignColors.textPrimary)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct LogoBubble: View {
    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(DesignColors.accentGreen)
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
            )
    }
}

private struct ChatsSection: View {
    let threads: [ChatThread]
    let selectedFilter: ConnectViewModel.ChatFilter
    let onFilterChange: (ConnectViewModel.ChatFilter) -> Void
    let onSelect: (ChatThread) -> Void

    init(
        threads: [ChatThread],
        selectedFilter: ConnectViewModel.ChatFilter,
        onFilterChange: @escaping (ConnectViewModel.ChatFilter) -> Void,
        onSelect: @escaping (ChatThread) -> Void
    ) {
        self.threads = threads
        self.selectedFilter = selectedFilter
        self.onFilterChange = onFilterChange
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Chats")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(DesignColors.textPrimary)

                Spacer()

                FilterPills(
                    filters: FilterPill.allCases,
                    selected: filterPillSelection
                ) { selection in
                    onFilterChange(selection.toChatFilter())
                }
            }

            if threads.isEmpty {
                Text(selectedFilter == .unread ? "No unread chats." : "No chats yet.")
                    .font(.system(size: 15))
                    .foregroundColor(DesignColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
                    .cardStyle()
            } else {
                ChatThreadsListView(threads: threads, onSelect: onSelect)
            }
        }
    }

    private var filterPillSelection: FilterPill {
        selectedFilter.toFilterPill()
    }
}

private struct ChatDetailView: View {
    let user: UserPreview
    @State private var messageText = ""

    var body: some View {
        ZStack {
            DesignColors.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        Image("IminLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 54, height: 54)
                            .opacity(0.2)

                        Text("No messages yet.")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(DesignColors.textSecondary)
                    }
                    .padding(.top, 90)
                    .frame(maxWidth: .infinity)
                }

                messageComposer
            }
        }
        .navigationTitle(user.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var messageComposer: some View {
        let isDisabled = messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return VStack(spacing: 0) {
            Divider()
                .background(Color.black.opacity(0.08))

            HStack(spacing: 10) {
                TextField("Message", text: $messageText, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(DesignColors.card)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button(action: {}) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(isDisabled ? Color.black.opacity(0.1) : DesignColors.accentGreen)
                        .clipShape(Circle())
                }
                .disabled(true)
                .accessibilityLabel("Send")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(DesignColors.background)
        }
    }
}

enum ConnectRoute: Hashable {
    case newChat
    case newCircle
    case addFriend
    case chatDetail(UserPreview)
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
        case .circles(let names):
            return names.isEmpty ? ["Choose circles"] : names
        }
    }
}
