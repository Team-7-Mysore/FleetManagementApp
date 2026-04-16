import Foundation

// MARK: - Auth Service
final class AuthService {
    static let shared = AuthService()
    private let store = MockDataStore.shared

    private init() {}

    /// Simulates sign-in. Accepts any email from mock users with any password.
    func signIn(email: String, password: String) async throws -> User {
        try await Task.sleep(for: .milliseconds(600))

        guard let user = store.users.first(where: {
            $0.email.lowercased() == email.lowercased()
        }) else {
            throw AuthError.invalidCredentials
        }

        guard user.isActive else {
            throw AuthError.accountDisabled
        }

        return user
    }

    func user(byId id: UUID) -> User? {
        store.users.first { $0.id == id }
    }

    func allUsers() -> [User] { store.users }
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case invalidCredentials
    case accountDisabled

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: return "Invalid email or password. Please try again."
        case .accountDisabled:    return "This account has been disabled. Contact your fleet manager."
        }
    }
}
