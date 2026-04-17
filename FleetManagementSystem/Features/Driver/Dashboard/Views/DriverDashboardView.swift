import SwiftUI

struct DriverDashboardView: View {
    let profile: UserProfile
    let onSignOut: () async -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.green.opacity(0.15), Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Driver Workspace")
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
