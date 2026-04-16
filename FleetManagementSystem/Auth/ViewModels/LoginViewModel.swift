import Foundation
import Combine

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var emailOrUsername = ""
    @Published var password = ""
    @Published var isPasswordVisible = false
    @Published private(set) var isSigningIn = false
    @Published var errorMessage: String?

    private let authService: SupabaseAuthService

    init(authService: SupabaseAuthService? = nil) {
        self.authService = authService ?? SupabaseAuthService()
    }

    var canSubmit: Bool {
        !emailOrUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.isEmpty &&
        !isSigningIn
    }

    func signIn() async throws -> AppUserSession {
        errorMessage = nil
        isSigningIn = true
        defer { isSigningIn = false }

        do {
            return try await authService.signIn(emailOrUsername: emailOrUsername, password: password)
        } catch let error as AuthError {
            errorMessage = error.errorDescription
            throw error
        } catch {
            errorMessage = "Something went wrong. Please try again."
            throw error
        }
    }
}
