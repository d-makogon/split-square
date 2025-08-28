import Foundation
import SwiftUI

final class AppRouter: ObservableObject {
    @Published var pendingInviteToken: String? = nil

    func handleIncomingURL(_ url: URL) {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              comps.path.contains("/invite"),
              let token = comps.queryItems?.first(where: { $0.name == "token" })?.value
        else { return }
        DispatchQueue.main.async {
            self.pendingInviteToken = token
        }
    }
}
