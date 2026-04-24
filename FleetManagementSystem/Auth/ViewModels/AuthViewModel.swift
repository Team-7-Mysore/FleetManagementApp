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
            print("🔐 Attempting sign in for: \(trimmedEmail)")
            let profile = try await authService.signIn(email: trimmedEmail, password: password)
            print("✅ Sign in successful. Profile: \(profile.name), Role: \(profile.role.rawValue)")
            appSession.setAuthenticated(profile: profile)
            password = ""
        } catch {
            print("❌ Sign in error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")

            // Provide more specific error messages
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, _):
                    errorMessage = "Profile setup incomplete. Missing: \(key.stringValue)"
                case .typeMismatch(let type, let context):
                    errorMessage = "Profile data mismatch for: \(context.codingPath.last?.stringValue ?? "unknown")"
                case .valueNotFound(let type, let context):
                    errorMessage = "Missing required value: \(context.codingPath.last?.stringValue ?? "unknown")"
                case .dataCorrupted(let context):
                    errorMessage = "Profile data corrupted: \(context.debugDescription)"
                @unknown default:
                    errorMessage = "Profile decoding error: \(error.localizedDescription)"
                }
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isSigningIn = false
    }
}
