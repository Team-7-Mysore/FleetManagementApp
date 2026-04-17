import Foundation
import Supabase

final class AuthService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func signIn(email: String, password: String) async throws -> UserProfile {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let response = try await client.auth.signIn(email: normalizedEmail, password: password)
        return try await fetchProfile(userId: response.user.id)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    private func fetchProfile(userId: UUID) async throws -> UserProfile {
        try await client
            .from("users")
            .select()
            .eq("user_id", value: userId.uuidString)
            .single()
            .execute()
            .value
    }
}
