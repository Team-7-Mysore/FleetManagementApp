import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published private(set) var isSigningIn = false
    @Published var errorMessage: String?

    private let appSession: AppSession
    private let authService: AuthService

    init(appSession: AppSession, authService: AuthService = AuthService()) {
        self.appSession = appSession
        self.authService = authService
    }

    convenience init() {
        self.init(appSession: AppSession())
    }

    func signIn() async {
        guard !isSigningIn else { return }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter email and password."
            return
        }

        isSigningIn = true
        errorMessage = nil

        do {
            let profile = try await authService.signIn(email: trimmedEmail, password: password)
            appSession.setAuthenticated(profile: profile)
            password = ""
        } catch {
            errorMessage = "Invalid credentials or profile setup issue."
        }

        isSigningIn = false
    }
}
