import SwiftUI

struct MaintenanceDashboardView: View {
    let profile: UserProfile
    let onSignOut: () async -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.orange.opacity(0.16), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Maintenance Workspace")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Welcome, \(profile.name)")
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
