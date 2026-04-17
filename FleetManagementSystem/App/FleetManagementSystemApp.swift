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
                    SetPasswordView()
                } else {
                    LoginView()
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
        }
    }

    func handleDeepLink(_ url: URL) {
        print("📩 Received deep link:", url)

        guard let fixedURL = convertFragmentToQuery(url) else {
            print("❌ Failed to convert URL")
            return
        }

        Task {
            do {
                let session = try await SupabaseManager.shared.client.auth.session(from: fixedURL)

                try await SupabaseManager.shared.client.auth.setSession(
                    accessToken: session.accessToken,
                    refreshToken: session.refreshToken
                )
                print("✅ Session restored successfully!")

                await MainActor.run {
                    print("🔄 Switching to SetPasswordView")
                    showSetPassword = true
                }

            } catch {
                print("❌ Error restoring session:", error)
            }
        }
    }

    func convertFragmentToQuery(_ url: URL) -> URL? {
        guard let fragment = url.fragment else {
            return url
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        let existingQuery = components?.query   // 👈 read first (safe)

        if let existingQuery = existingQuery {
            components?.query = existingQuery + "&" + fragment
        } else {
            components?.query = fragment
        }

        components?.fragment = nil
        return components?.url
    }
}
