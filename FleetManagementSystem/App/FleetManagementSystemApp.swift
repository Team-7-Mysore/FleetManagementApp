//
//  FleetManagementSystemApp.swift
//  FleetManagementSystem
//
//  Created by harshwardhan patil on 15/04/26.
//
import SwiftUI
import Supabase
@main
struct FleetManagementSystemApp: App {

    @State private var showSetPassword = false

    var body: some Scene {
        WindowGroup {
            Group {
                if showSetPassword {
                    SetPasswordView {
                        showSetPassword = false
                    }
                } else {
                    LoginView()
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        print("📩 Received deep link:", url)

        Task {
            do {
                let params = authParams(from: url)

                if let accessToken = params["access_token"],
                   let refreshToken = params["refresh_token"],
                   !accessToken.isEmpty,
                   !refreshToken.isEmpty {
                    try await SupabaseManager.shared.client.auth.setSession(
                        accessToken: accessToken,
                        refreshToken: refreshToken
                    )
                    print("✅ Session restored from tokens")
                } else if params["code"] != nil {
                    _ = try await SupabaseManager.shared.client.auth.session(from: url)
                    print("✅ Session restored from auth code")
                } else {
                    print("❌ Deep link did not contain usable auth data")
                    return
                }

                let isInvite = params["type"] == "invite"
                await MainActor.run {
                    showSetPassword = isInvite
                    print(isInvite ? "🔄 Switching to SetPasswordView" : "🔄 Staying on LoginView")
                }
            } catch {
                print("❌ Error restoring session:", error)
            }
        }
    }

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
