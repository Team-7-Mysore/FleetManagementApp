import Foundation
import Combine

@MainActor
final class AppSessionStore: ObservableObject {
    @Published private(set) var state: AppSessionState = .signedOut

    func signIn(session: AppUserSession) {
        state = .signedIn(session)
    }

    func signOut() {
        state = .signedOut
    }
}
