import SwiftUI
import Supabase

@main
struct FleetManagementSystemApp: App {

    @StateObject private var appSession = AppSession()
    @State private var showSetPassword = false
    @State private var isLoading = true

    var body: some Scene {
        WindowGroup {
            Group {
                if isLoading {
                    ProgressView("Loading...")
                } else if showSetPassword {
                    SetPasswordView {
                        showSetPassword = false
                    }
                } else if let profile = appSession.profile {
                    switch profile.role {
                    case .driver:
                        DriverWorkspaceView(profile: profile) {
                            await appSession.signOut()
                        }
                    case .maintenance:
                        MaintenanceHomeView(profile: profile) {
                            await appSession.signOut()
                        }
                    case .fleetManager:
                        FleetManagerTabView(profile: profile) {
                            await appSession.signOut()
                        }
                    }
                } else {
                    LoginView(viewModel: AuthViewModel(appSession: appSession))
                }
            }
            .tint(Color(hex: "#A3352A"))
            .onAppear {
                Task {
                    await checkSession()
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
        }
    }

    // MARK: - Check Existing Session
    private func checkSession() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            if session != nil {
                await fetchUserProfile()
            }
        } catch {
            print("❌ Session error:", error)
        }
        isLoading = false
    }

    // MARK: - Fetch User Profile
    private func fetchUserProfile() async {
        do {
            let user = try await SupabaseManager.shared.client.auth.user()

            let profile: UserProfile = try await SupabaseManager.shared.client
                .from("users")
                .select()
                .eq("user_id", value: user.id)
                .single()
                .execute()
                .value

            await MainActor.run {
                appSession.setAuthenticated(profile: profile)
            }

        } catch {
            print("❌ Profile fetch error:", error)
        }
    }

    // MARK: - Handle Deep Link (Invite / Magic Link)
    private func handleDeepLink(_ url: URL) {
        print("📩 Deep link received:", url)

        Task {
            do {
                let params = authParams(from: url)

                // Case 1: Token-based login
                if let accessToken = params["access_token"],
                   let refreshToken = params["refresh_token"],
                   !accessToken.isEmpty,
                   !refreshToken.isEmpty {

                    try await SupabaseManager.shared.client.auth.setSession(
                        accessToken: accessToken,
                        refreshToken: refreshToken
                    )

                    print("✅ Session restored via tokens")
                }

                // Case 2: Code-based login
                else if params["code"] != nil {
                    _ = try await SupabaseManager.shared.client.auth.session(from: url)
                    print("✅ Session restored via auth code")
                }

                else {
                    print("❌ Invalid deep link")
                    return
                }

                let isInvite = params["type"] == "invite"

                await MainActor.run {
                    showSetPassword = isInvite
                }

                // Fetch profile after login
                await fetchUserProfile()

            } catch {
                print("❌ Deep link error:", error)
            }
        }
    }

    // MARK: - Extract URL Params
    private func authParams(from url: URL) -> [String: String] {
        var result: [String: String] = [:]

        // Query params
        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            for item in queryItems {
                result[item.name] = item.value
            }
        }

        // Fragment params (#access_token=...)
        if let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment,
           let fragmentItems = URLComponents(string: "?\(fragment)")?.queryItems {
            for item in fragmentItems {
                result[item.name] = item.value
            }
        }

        return result
    }
}
