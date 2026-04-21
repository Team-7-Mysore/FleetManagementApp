import Foundation
import Supabase

final class AuthService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func signIn(email: String, password: String) async throws -> UserProfile {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        print("🔐 AuthService: Signing in with email: \(normalizedEmail)")
        let response = try await client.auth.signIn(email: normalizedEmail, password: password)
        print("✅ AuthService: Auth successful, user ID: \(response.user.id)")
        
        let profile = try await fetchProfile(userId: response.user.id)
        print("✅ AuthService: Profile fetched successfully")
        return profile
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    private func fetchProfile(userId: UUID) async throws -> UserProfile {
        print("📥 AuthService: Fetching profile for user ID: \(userId)")
        print("📥 AuthService: Querying users table with user_id = \(userId.uuidString)")
        
        do {
            let response = try await client
                .from("users")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
            
            // Print raw response for debugging
            if let jsonString = String(data: response.data, encoding: .utf8) {
                print("📋 AuthService: Raw response: \(jsonString)")
            }
            
            let profile: UserProfile = try JSONDecoder().decode(UserProfile.self, from: response.data)
            
            print("✅ AuthService: Profile decoded - Name: \(profile.name), Role: \(profile.role.rawValue)")
            return profile
        } catch {
            print("❌ AuthService: Profile fetch failed - \(error)")
            print("❌ AuthService: Error type: \(type(of: error))")
            
            if let decodingError = error as? DecodingError {
                print("❌ AuthService: Decoding error details:")
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   - Key not found: \(key.stringValue)")
                    print("   - Context: \(context.debugDescription)")
                case .typeMismatch(let type, let context):
                    print("   - Type mismatch: expected \(type)")
                    print("   - Context: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("   - Value not found: \(type)")
                    print("   - Context: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("   - Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("   - Unknown decoding error")
                }
            }
            
            throw error
        }
    }
}
