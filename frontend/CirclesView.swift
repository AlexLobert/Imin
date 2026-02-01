import SwiftUI

struct CirclesView: View {
    @StateObject private var viewModel = CirclesViewModel()
    @State private var showCreateCircle = false

    var body: some View {
        NavigationStack {
            ZStack {
                DesignColors.background
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    header

                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            subtitle

                            circlesList
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
                .padding(.top, 8)
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

private extension CirclesView {
    var header: some View {
        HStack {
            Circle()
                .fill(Color.clear)
                .frame(width: 40, height: 40)

            Spacer()

            Text("Circles")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.85))

            Spacer()

            Button {
                showCreateCircle = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.9))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 6)
            }
            .accessibilityLabel("Create a circle")
        }
        .padding(.horizontal, 20)
    }

    var subtitle: some View {
        Text("Choose who you signal when you're in.")
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Color.black.opacity(0.55))
    }

    var circlesList: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.circles) { circle in
                NavigationLink(value: circle) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(circle.name)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.black.opacity(0.85))
                            Text("\(circle.members.count) friends")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(Color.black.opacity(0.55))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.35))
                    }
                    .padding(16)
                }
                .buttonStyle(.plain)
                .imInCard()
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

private struct CircleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: CirclesViewModel
    @State private var showAddMember = false
    @State private var showRename = false
    @State private var showDelete = false

    let circleId: UUID

    var body: some View {
        ZStack {
            DesignColors.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let circle = viewModel.circle(for: circleId) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(circle.name)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(DesignColors.textPrimary)

                            Text("\(circle.members.count) friends")
                                .font(.system(size: 14))
                                .foregroundColor(DesignColors.textSecondary)
                        }

                        HStack(spacing: 12) {
                            Button("Add member") {
                                showAddMember = true
                            }
                            .buttonStyle(FilledPillButtonStyle())

                            Button("Rename") {
                                showRename = true
                            }
                            .buttonStyle(OutlinedPillButtonStyle())
                        }

                        VStack(spacing: 12) {
                            ForEach(circle.members) { member in
                                HStack {
                                    Text(member.name)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(DesignColors.textPrimary)
                                    Spacer()
                                    Button(action: {
                                        viewModel.removeMember(from: circleId, memberId: member.id)
                                    }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .frame(width: 28, height: 28)
                                            .background(Color.black.opacity(0.08))
                                            .foregroundColor(DesignColors.textSecondary)
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 16)
                                .background(DesignColors.card)
                                .cornerRadius(22)
                                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                            }
                        }

                        Button("Delete circle") {
                            showDelete = true
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignColors.textSecondary)
                        .padding(.top, 4)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(DesignColors.textPrimary)
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

private struct FilledPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(Color(.systemGray5).opacity(configuration.isPressed ? 0.7 : 1.0))
            .foregroundColor(DesignColors.textPrimary)
            .clipShape(Capsule())
    }
}

private struct OutlinedPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(DesignColors.card)
            .foregroundColor(DesignColors.textPrimary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
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
