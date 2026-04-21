import Foundation
import Combine

@MainActor
final class AppSession: ObservableObject {
    @Published private(set) var profile: UserProfile?
    @Published var errorMessage: String?

    private let authService: AuthService

    init(authService: AuthService = AuthService()) {
        self.authService = authService
    }

    func setAuthenticated(profile: UserProfile) {
        self.profile = profile
        errorMessage = nil
    }

    func signOut() async {
        do {
            try await authService.signOut()
            profile = nil
            errorMessage = nil
        } catch {
            errorMessage = "Unable to sign out right now. Please try again."
        }
    }
}
