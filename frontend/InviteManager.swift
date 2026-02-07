import Foundation
import UIKit

@MainActor
final class InviteManager {
    static func presentInviteShareSheet(referralURL: URL) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }

        let vc = UIActivityViewController(activityItems: [referralURL], applicationActivities: nil)
        root.present(vc, animated: true)
    }
}
