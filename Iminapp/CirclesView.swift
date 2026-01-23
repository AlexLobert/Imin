import SwiftUI

struct CirclesView: View {
    @StateObject private var viewModel = CirclesViewModel()
    @State private var showCreateCircle = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.sectionSpacing) {
                        HStack(spacing: 10) {
                            Image("IminLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 60)

                            Text("Circles")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.primary)

                            Spacer()

                            Button(action: { showCreateCircle = true }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                    Text("New")
                                }
                                .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(AppColors.accentGreen)
                        }

                        Text("Choose who sees you when you're in.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        Text("Circles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)

                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.circles.enumerated()), id: \.element.id) { index, circle in
                                NavigationLink(value: circle) {
                                    CircleRow(
                                        name: circle.name,
                                        subtitle: "\(circle.members.count) friends"
                                    )
                                }
                                .foregroundColor(.primary)

                                if index < viewModel.circles.count - 1 {
                                    Divider()
                                        .background(AppColors.separator)
                                }
                            }
                        }
                    }
                    .padding(AppSpacing.screenPadding)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .navigationDestination(for: CircleGroup.self) { circle in
                CircleDetailView(circleId: circle.id)
                    .environmentObject(viewModel)
            }
            .sheet(isPresented: $showCreateCircle) {
                CreateCircleSheet { name in
                    viewModel.createCircle(named: name)
                    showCreateCircle = false
                }
            }
        }
    }
}

@MainActor
final class CirclesViewModel: ObservableObject {
    @Published var circles: [CircleGroup] = [
        CircleGroup(name: "Inner circle", members: [
            CircleMember(name: "Ava"),
            CircleMember(name: "Jordan"),
            CircleMember(name: "Maya")
        ]),
        CircleGroup(name: "Roommates", members: [
            CircleMember(name: "Kai"),
            CircleMember(name: "Lena")
        ]),
        CircleGroup(name: "Late-night crew", members: [
            CircleMember(name: "Sam"),
            CircleMember(name: "Rae"),
            CircleMember(name: "Noah")
        ])
    ]

    func createCircle(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        circles.append(CircleGroup(name: trimmed, members: []))
    }

    func renameCircle(id: UUID, name: String) {
        guard let index = circles.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        circles[index].name = trimmed
    }

    func deleteCircle(id: UUID) {
        circles.removeAll { $0.id == id }
    }

    func addMember(to circleId: UUID, name: String) {
        guard let index = circles.firstIndex(where: { $0.id == circleId }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        circles[index].members.append(CircleMember(name: trimmed))
    }

    func removeMember(from circleId: UUID, memberId: UUID) {
        guard let index = circles.firstIndex(where: { $0.id == circleId }) else { return }
        circles[index].members.removeAll { $0.id == memberId }
    }

    func circle(for id: UUID) -> CircleGroup? {
        circles.first(where: { $0.id == id })
    }
}

struct CircleGroup: Identifiable, Hashable {
    let id: UUID
    var name: String
    var members: [CircleMember]

    init(id: UUID = UUID(), name: String, members: [CircleMember]) {
        self.id = id
        self.name = name
        self.members = members
    }
}

struct CircleMember: Identifiable, Hashable {
    let id: UUID
    let name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

private struct CircleRow: View {
    let name: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, AppSpacing.rowVertical)
    }
}

private struct CircleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: CirclesViewModel
    @State private var showAddMember = false
    @State private var showRename = false
    @State private var showDelete = false

    let circleId: UUID

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            if let circle = viewModel.circle(for: circleId) {
                List {
                    Text("\(circle.members.count) friends")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .listRowInsets(EdgeInsets(top: 6, leading: AppSpacing.screenPadding, bottom: 6, trailing: AppSpacing.screenPadding))
                        .listRowSeparator(.hidden)

                    Section(header: sectionHeader("Members")) {
                        ForEach(circle.members) { member in
                            CircleMemberRow(name: member.name)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.removeMember(from: circleId, memberId: member.id)
                                    } label: {
                                        Text("Remove")
                                    }
                                }
                        }
                    }

                    Section(header: sectionHeader("Actions")) {
                        Button("Add member") {
                            showAddMember = true
                        }

                        Button("Rename circle") {
                            showRename = true
                        }
                    }

                    Section {
                        Button("Delete circle", role: .destructive) {
                            showDelete = true
                        }
                        .foregroundColor(.red)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .navigationTitle(circle.name)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(AppColors.accentGreen)
            }
        }
        .sheet(isPresented: $showAddMember) {
            CircleTextEntrySheet(title: "Add member", buttonTitle: "Add") { name in
                viewModel.addMember(to: circleId, name: name)
                showAddMember = false
            }
        }
        .sheet(isPresented: $showRename) {
            CircleTextEntrySheet(title: "Rename circle", buttonTitle: "Save") { name in
                viewModel.renameCircle(id: circleId, name: name)
                showRename = false
            }
        }
        .alert("Delete circle?", isPresented: $showDelete) {
            Button("Delete", role: .destructive) {
                viewModel.deleteCircle(id: circleId)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the circle and its members.")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(nil)
    }
}

private struct CircleMemberRow: View {
    let name: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppColors.avatarBackground)
                    .frame(width: 36, height: 36)

                Text(initials(from: name))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }

            Text(name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.dropFirst().first?.prefix(1) ?? ""
        return (first + last).uppercased()
    }
}

private struct CreateCircleSheet: View {
    @State private var name = ""
    let onCreate: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Create a circle")
                .font(.custom("Avenir Next", size: 20))
                .fontWeight(.bold)

            TextField("Circle name", text: $name)
                .textFieldStyle(.roundedBorder)

            Button("Create") {
                onCreate(name)
            }
            .buttonStyle(FilledCircleButtonStyle())
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
                .font(.custom("Avenir Next", size: 20))
                .fontWeight(.bold)

            TextField("Name", text: $value)
                .textFieldStyle(.roundedBorder)

            Button(buttonTitle) {
                onConfirm(value)
            }
            .buttonStyle(FilledCircleButtonStyle())
        }
        .padding(24)
    }
}

private struct FilledCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Avenir Next", size: 14))
            .fontWeight(.bold)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color(red: 0.55, green: 0.6, blue: 0.7).opacity(configuration.isPressed ? 0.7 : 1.0))
            .foregroundColor(.white)
            .cornerRadius(12)
    }
}

private struct OutlineCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("Avenir Next", size: 14))
            .fontWeight(.bold)
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(Color(red: 0.98, green: 0.95, blue: 0.85))
            .foregroundColor(.black)
            .cornerRadius(12)
    }
}
