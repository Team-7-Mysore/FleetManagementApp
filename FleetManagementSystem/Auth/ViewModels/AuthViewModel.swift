import Foundation
import Combine
import Supabase

@MainActor
final class AuthViewModel: ObservableObject {
    enum SignInStage {
        case credentials
        case otp
    }

    @Published var email = ""
    @Published var password = ""
    @Published var otpCode = ""
    @Published private(set) var signInStage: SignInStage = .credentials
    @Published private(set) var isSigningIn = false
    @Published private(set) var isSendingOTP = false
    @Published private(set) var isVerifyingOTP = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let appSession: AppSession
    private let authService: AuthService
    private var pendingContext: PendingAuthContext?

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
            pendingContext = context
            print("✅ Credentials accepted. Waiting for OTP verification.")

            await sendOTP()
            signInStage = .otp
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

    func sendOTP() async {
        guard let context = pendingContext else { return }
        guard !isSendingOTP else { return }

        isSendingOTP = true
        errorMessage = nil
        infoMessage = nil

        do {
            try await authService.sendMFAOTP(email: context.email)
            infoMessage = "OTP sent to \(context.email)."
        } catch {
            errorMessage = error.localizedDescription
        }

        isSendingOTP = false
    }

    func verifyOTP() async {
        guard let context = pendingContext else { return }
        guard !isVerifyingOTP else { return }

        let trimmedCode = otpCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            errorMessage = "Please enter OTP."
            return
        }

        isVerifyingOTP = true
        errorMessage = nil
        infoMessage = nil

        do {
            try await authService.verifyMFAOTP(email: context.email, otp: trimmedCode)
            appSession.clearAuthenticatedState()
            appSession.setAuthenticated(profile: context.profile)
            appSession.setMFAVerified(email: context.email)
            otpCode = ""
            pendingContext = nil
            signInStage = .credentials
        } catch {
            errorMessage = error.localizedDescription
        }

        isVerifyingOTP = false
    }

    func resetOTPFlow() async {
        pendingContext = nil
        otpCode = ""
        signInStage = .credentials
        infoMessage = nil
        do {
            try await authService.signOut()
        } catch {
            errorMessage = "Unable to cancel OTP flow right now."
        }
    }
}

