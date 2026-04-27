//AppSession

import Foundation
import Combine

@MainActor
final class AppSession: ObservableObject {



    private enum Storage {
        static let profileKey = "app_session_profile"
        static let mfaEmailKey = "app_session_mfa_email"
    }


    @Published private(set) var profile: UserProfile?
    @Published var errorMessage: String?
    
    private let authService: AuthService
    
    init(authService: AuthService = AuthService()) {
        self.authService = authService

        restorePersistedProfile()
    }
    
    func setAuthenticated(profile: UserProfile) {
        self.profile = profile
        errorMessage = nil
        persist(profile: profile)
    }

    func setMFAVerified(email: String) {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        UserDefaults.standard.set(normalized, forKey: Storage.mfaEmailKey)
    }

    func hasMFAVerified(email: String) -> Bool {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return UserDefaults.standard.string(forKey: Storage.mfaEmailKey) == normalized
    }
    func signOut() async {
        do {
            try await authService.signOut()
            clearAuthenticatedState()
        } catch {
            errorMessage = "Unable to sign out right now. Please try again."
        }
    }

    func clearAuthenticatedState() {
        profile = nil
        errorMessage = nil
        clearPersistedProfile()
        clearMFAState()
    }

    private func restorePersistedProfile() {
        guard
            let data = UserDefaults.standard.data(forKey: Storage.profileKey),
            let decodedProfile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else {
            return
        }

        profile = decodedProfile
    }

    private func persist(profile: UserProfile) {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        UserDefaults.standard.set(data, forKey: Storage.profileKey)
    }

    private func clearPersistedProfile() {
        UserDefaults.standard.removeObject(forKey: Storage.profileKey)
    }

    private func clearMFAState() {
        UserDefaults.standard.removeObject(forKey: Storage.mfaEmailKey)
    }
}
