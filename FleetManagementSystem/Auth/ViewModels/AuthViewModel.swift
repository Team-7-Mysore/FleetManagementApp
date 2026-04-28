import Foundation
import Combine
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published private(set) var isSigningIn = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

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

        // Pre-check: ensure user's status allows login
        do {
            struct StatusRecord: Decodable { let status: String? }
            // Fetch at most one record and decode as an array, then take the first element
            let records: [StatusRecord] = try await SupabaseManager.shared.client
                .from("users")
                .select("status")
                .eq("email", value: trimmedEmail)
                .limit(1)
                .execute()
                .value

            let record = records.first

            if let status = record?.status?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
                if status == "inactive" {
                    errorMessage = "Your account is inactive. Please contact your administrator."
                    return
                }
                if status == "blocked" {
                    errorMessage = "Your account is blocked. Please contact your administrator."
                    return
                }
                if status == "pending" {
                    // Optional: prevent login for pending accounts too
                    // errorMessage = "Your account is pending activation. Please check your email or contact support."
                    // return
                }
            } else {
                // No user row found for this email. You can choose to block here or allow auth to surface error.
                // errorMessage = "No account found for this email."
                // return
            }
        } catch {
            // If the status check fails (network/schema), fall back to normal sign-in but capture a helpful log.
            print("⚠️ Status check failed: \(error)")
        }

        isSigningIn = true
        errorMessage = nil
        infoMessage = nil

        do {
            print("🔐 Attempting sign in for: \(trimmedEmail)")
            let context = try await authService.signIn(email: trimmedEmail, password: password)
            appSession.clearAuthenticatedState()
            appSession.setAuthenticated(profile: context.profile)
            password = ""
        } catch {
            print("❌ Sign in error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")

            // Provide more specific error messages
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, _):
                    errorMessage = "Profile setup incomplete. Missing: \(key.stringValue)"
                case .typeMismatch(_, let context):
                    errorMessage = "Profile data mismatch for: \(context.codingPath.last?.stringValue ?? "unknown")"
                case .valueNotFound(_, let context):
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
