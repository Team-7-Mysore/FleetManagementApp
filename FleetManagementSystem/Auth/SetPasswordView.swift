//
//  SetPasswordView.swift
//  FleetManagementSystem
//
//  Created by Apple on 16/04/26.
//

import SwiftUI
import Supabase

struct SetPasswordView: View {
    let onPasswordSet: () -> Void

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

    private func setPassword() {
        isLoading = true

        Task {
            do {
                try await SupabaseManager.shared.client.auth.update(
                    user: UserAttributes(password: password)
                )

                print("✅ Password set successfully")

                await MainActor.run {
                    isLoading = false
                    onPasswordSet()
                }

            } catch {
                print("❌ Error setting password:", error)
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}
