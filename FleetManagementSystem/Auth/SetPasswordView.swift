//
//  SetPasswordView.swift
//  FleetManagementSystem
//
//  Created by Apple on 16/04/26.
//

import SwiftUI
import Supabase
struct SetPasswordView: View {
    @State private var password = ""
    @State private var isLoading = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Set Your Password")
                .font(.title)

            SecureField("Enter password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Button(isLoading ? "Saving..." : "Save Password") {
                setPassword()
            }
            .disabled(isLoading || password.isEmpty)
        }
        .padding()
    }

    func setPassword() {
        isLoading = true

        Task {
            do {
                try await SupabaseManager.shared.client.auth.update(
                    user: UserAttributes(password: password)
                )

                print("✅ Password set successfully")

                // 🔥 NEXT STEP: navigate
                await MainActor.run {
                    isLoading = false

                    // temporary test
                    print("🚀 Ready to move to dashboard")

                    // TODO: replace with navigation later
                }

            } catch {
                print("❌ Error setting password:", error)
                isLoading = false
            }
        }
    }
}
