import Foundation

final class SupabaseAuthService {
    private let manager: SupabaseClientManager

    init(manager: SupabaseClientManager = .shared) {
        self.manager = manager
    }

    func signIn(emailOrUsername: String, password: String) async throws {
        _ = manager.isConfigured
        try await Task.sleep(for: .milliseconds(400))
    }
}
