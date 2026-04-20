import SwiftUI
import Supabase

@main
struct FleetManagementSystemApp: App {

    @State private var showSetPassword = false
    @State private var userRole: String? = nil
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
                } else if let role = userRole {
                    switch role {
                    case "driver":
                       LoginView()
                    case "maintenance":
                        MaintenanceHomeView()
                    case "fleet_manager":
                        FleetManagerTabView()
                    default:
                        LoginView()
                    }
                } else {
                    LoginView()
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

    // MARK: - Session Check
    private func checkSession() async {
        do {
            let session = try await SupabaseManager.shared.client.auth.session

            if session != nil {
                await fetchUserRole()
            } else {
                isLoading = false
            }
        } catch {
            print("❌ Session error:", error)
            isLoading = false
        }
    }

    // MARK: - Fetch Role
    private func fetchUserRole() async {
        do {
            let user = try await SupabaseManager.shared.client.auth.user()

            let response = try await SupabaseManager.shared.client
                .from("users")
                .select("role")
                .eq("user_id", value: user.id)
                .single()
                .execute()

            if let json = try JSONSerialization.jsonObject(with: response.data) as? [String: Any],
               let role = json["role"] as? String {

                await MainActor.run {
                    self.userRole = role
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }

        } catch {
            print("❌ Role fetch error:", error)
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    // MARK: - Deep Link
    private func handleDeepLink(_ url: URL) {
        Task {
            do {
                let params = authParams(from: url)

                if let accessToken = params["access_token"],
                   let refreshToken = params["refresh_token"] {
                    try await SupabaseManager.shared.client.auth.setSession(
                        accessToken: accessToken,
                        refreshToken: refreshToken
                    )
                } else if params["code"] != nil {
                    _ = try await SupabaseManager.shared.client.auth.session(from: url)
                }

                let isInvite = params["type"] == "invite"

                await MainActor.run {
                    showSetPassword = isInvite
                }

                await fetchUserRole()

            } catch {
                print("❌ Deep link error:", error)
            }
        }
    }

    // MARK: - URL Params
    private func authParams(from url: URL) -> [String: String] {
        var result: [String: String] = [:]

        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            for item in queryItems {
                result[item.name] = item.value
            }
        }

        if let fragment = URLComponents(url: url, resolvingAgainstBaseURL: false)?.fragment,
           let fragmentItems = URLComponents(string: "?\(fragment)")?.queryItems {
            for item in fragmentItems {
                result[item.name] = item.value
            }
        }

        return result
    }
}
