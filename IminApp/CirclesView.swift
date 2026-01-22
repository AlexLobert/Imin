import SwiftUI

struct CirclesView: View {
    private let circles = [
        CircleGroup(name: "Inner circle", count: 6),
        CircleGroup(name: "Roommates", count: 3),
        CircleGroup(name: "Late-night crew", count: 8)
    ]

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

                        Button(action: {}) {
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
                            ForEach(circles) { circle in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(circle.name)
                                            .font(.custom("Avenir Next", size: 16))
                                            .fontWeight(.bold)
                                        Text("\(circle.count) friends")
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
                        }
                    }
                    .padding(24)
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
        }
    }
}

private struct CircleGroup: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}
