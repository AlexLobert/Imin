import SwiftUI

struct NewCircleView: View {
    @State private var name = ""

    var body: some View {
        Form {
            Section(header: Text("Circle name")) {
                TextField("Name", text: $name)
            }
            Button("Create") {}
        }
        .navigationTitle("New Circle")
    }
}
