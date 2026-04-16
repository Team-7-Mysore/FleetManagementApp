import Foundation
import Combine

@MainActor
final class AppSessionStore: ObservableObject {
    @Published private(set) var state: AppSessionState = .signedIn(
        AppUserSession(user: AppUser(id: UUID(), fullName: "Aarav Kulkarni", email: "driver@fms.com", role: .driver))
    )

    func signIn(session: AppUserSession) {
        state = .signedIn(session)
    }

    func signOut() {
        state = .signedOut
    }
}
