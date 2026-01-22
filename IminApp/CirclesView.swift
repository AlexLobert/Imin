import SwiftUI

struct CirclesView: View {
    @StateObject private var viewModel = CirclesViewModel()
    @State private var showCreateCircle = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.7, green: 0.88, blue: 1.0), Color(red: 0.32, green: 0.52, blue: 0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Circles")
                            .font(.custom("Avenir Next", size: 24))
                            .fontWeight(.heavy)

                        Text("Choose who you signal when you're in.")
                            .font(.custom("Avenir Next", size: 14))
                            .foregroundColor(.black.opacity(0.7))

                        Button(action: { showCreateCircle = true }) {
                            HStack {
                                Text("Create a circle")
                                    .font(.custom("Avenir Next", size: 16))
                                    .fontWeight(.bold)
                                Spacer()
                                Text("+")
                                    .font(.custom("Avenir Next", size: 20))
                                    .fontWeight(.bold)
                            }
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(Color(red: 0.55, green: 0.6, blue: 0.7))
                            .foregroundColor(.white)
                            .cornerRadius(16)
                        }

                        VStack(spacing: 12) {
                            ForEach(viewModel.circles) { circle in
                                NavigationLink(value: circle) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(circle.name)
                                                .font(.custom("Avenir Next", size: 16))
                                                .fontWeight(.bold)
                                            Text("\(circle.members.count) friends")
                                                .font(.custom("Avenir Next", size: 12))
                                                .foregroundColor(.black.opacity(0.7))
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.black.opacity(0.5))
                                    }
                                    .padding(14)
                                    .background(Color(red: 0.98, green: 0.95, blue: 0.85))
                                    .cornerRadius(16)
                                }
                                .foregroundColor(.black)
                            }
                        }
                    }
                    .padding(24)
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

private struct CircleDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewModel: CirclesViewModel
    @State private var showAddMember = false
    @State private var showRename = false
    @State private var showDelete = false

    let circleId: UUID

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.7, green: 0.88, blue: 1.0), Color(red: 0.32, green: 0.52, blue: 0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 16) {
                if let circle = viewModel.circle(for: circleId) {
                    Text(circle.name)
                        .font(.custom("Avenir Next", size: 22))
                        .fontWeight(.bold)

                    Text("\(circle.members.count) friends")
                        .font(.custom("Avenir Next", size: 13))
                        .foregroundColor(.black.opacity(0.7))

                    HStack(spacing: 12) {
                        Button("Add member") {
                            showAddMember = true
                        }
                        .buttonStyle(FilledCircleButtonStyle())

                        Button("Rename") {
                            showRename = true
                        }
                        .buttonStyle(OutlineCircleButtonStyle())
                    }

                    VStack(spacing: 10) {
                        ForEach(circle.members) { member in
                            HStack {
                                Text(member.name)
                                    .font(.custom("Avenir Next", size: 15))
                                    .fontWeight(.bold)
                                Spacer()
                                Button(action: {
                                    viewModel.removeMember(from: circleId, memberId: member.id)
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .padding(6)
                                        .background(Color(red: 0.55, green: 0.6, blue: 0.7))
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                }
                            }
                            .padding(12)
                            .background(Color(red: 0.98, green: 0.95, blue: 0.85))
                            .cornerRadius(16)
                        }
                    }

                    Button("Delete circle") {
                        showDelete = true
                    }
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundColor(.black.opacity(0.8))
                    .padding(.top, 8)
                }

                Spacer()
            }
            .padding(24)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.black)
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
