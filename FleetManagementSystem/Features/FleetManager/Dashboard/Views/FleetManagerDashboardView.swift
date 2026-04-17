//
//  ContentView.swift
//  FleetManagementSystem
//
//  Created by harshwardhan patil on 15/04/26.
//

import SwiftUI

struct FleetManagerDashboardView: View {
    let profile: UserProfile
    let onSignOut: () async -> Void

    var body: some View {
        roleContainer(
            title: "Manager Workspace",
            subtitle: "Welcome, \(profile.name)",
            accent: .blue
        )
    }

    @ViewBuilder
    private func roleContainer(title: String, subtitle: String, accent: Color) -> some View {
        ZStack {
            LinearGradient(
                colors: [accent.opacity(0.12), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text(subtitle)
                    .foregroundStyle(.secondary)

                Text("Role: \(profile.role.rawValue.capitalized)")
                    .font(.headline)

                Button("Sign Out") {
                    Task { await onSignOut() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}

struct FleetManagerDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        FleetManagerDashboardView(
            profile: UserProfile(
                userId: UUID(),
                name: "Fleet Manager",
                email: "manager@fleet.com",
                role: .manager,
                phoneNumber: nil,
                createdAt: nil,
                createdBy: nil,
                username: nil
            ),
            onSignOut: {}
        )
    }
}
