import Foundation

final class SupabaseAuthService {
    private let manager: SupabaseClientManager

    private struct MockCredential {
        let email: String
        let username: String
        let password: String
        let user: AppUser
    }

    private let mockCredentials: [MockCredential] = [
        MockCredential(
            email: "driver@fms.com",
            username: "driver01",
            password: "Driver@123",
            user: AppUser(
                id: UUID(uuidString: "C9E2BA8D-6E44-4D95-BC10-7A0FEC0D6EE1") ?? UUID(),
                fullName: "Aarav Kulkarni",
                email: "driver@fms.com",
                role: .driver
            )
        ),
        MockCredential(
            email: "manager@fms.com",
            username: "manager01",
            password: "Manager@123",
            user: AppUser(
                id: UUID(uuidString: "496D2596-2D5E-49B1-83E2-A5F03D7C6F30") ?? UUID(),
                fullName: "Riya Sharma",
                email: "manager@fms.com",
                role: .fleetManager
            )
        ),
        MockCredential(
            email: "maintenance@fms.com",
            username: "maint01",
            password: "Maintain@123",
            user: AppUser(
                id: UUID(uuidString: "9740D2FF-A2BA-45EA-B95E-7B716613B1D0") ?? UUID(),
                fullName: "Kabir Naik",
                email: "maintenance@fms.com",
                role: .maintenance
            )
        )
    ]

    init(manager: SupabaseClientManager = .shared) {
        self.manager = manager
    }

    func signIn(emailOrUsername: String, password: String) async throws -> AppUserSession {
        _ = manager.isConfigured
        try await Task.sleep(for: .milliseconds(450))

        let normalizedIdentifier = emailOrUsername
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let credential = mockCredentials.first(where: {
            ($0.email.lowercased() == normalizedIdentifier || $0.username.lowercased() == normalizedIdentifier) &&
            $0.password == normalizedPassword
        }) else {
            throw AuthError.invalidCredentials
        }

        return AppUserSession(user: credential.user)
    }
}
