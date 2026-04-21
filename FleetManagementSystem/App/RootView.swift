import SwiftUI

struct RootView: View {
    @StateObject private var appSession = AppSession()

    var body: some View {
        Group {
            if let profile = appSession.profile {
                roleBasedView(for: profile)
            } else {
                LoginView(viewModel: AuthViewModel(appSession: appSession))
            }
        }
    }

    @ViewBuilder
    private func roleBasedView(for profile: UserProfile) -> some View {
        switch profile.role {
        case .driver:
            DriverWorkspaceView(profile: profile) {
                await appSession.signOut()
            }
        case .fleetManager:
            FleetManagerDashboardView(profile: profile) {
                await appSession.signOut()
            }
        case .maintenance:
            MaintenanceDashboardView(profile: profile) {
                await appSession.signOut()
            }
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
    }
}
