import SwiftUI

struct RootView: View {
    @EnvironmentObject private var sessionStore: AppSessionStore

    var body: some View {
        Group {
            switch sessionStore.state {
            case .signedOut:
                LoginView()
            case .signedIn(let session):
                RoleGatewayView(session: session)
            }
        }
    }
}

struct RoleGatewayView: View {
    @EnvironmentObject private var sessionStore: AppSessionStore

    let session: AppUserSession

    var body: some View {
        switch session.user.role {
        case .driver:
            DriverDashboardView()
        case .fleetManager:
            RolePlaceholderView(
                title: "Fleet Manager Interface",
                subtitle: "This space will manage credentials, vehicles, and reports. For now, the driver module is the completed flow.",
                symbol: "person.3.sequence.fill"
            )
        case .maintenance:
            RolePlaceholderView(
                title: "Maintenance Interface",
                subtitle: "This space will handle work orders, service history, and spare parts. For now, the driver module is the completed flow.",
                symbol: "wrench.and.screwdriver.fill"
            )
        }
    }
}

struct RolePlaceholderView: View {
    @EnvironmentObject private var sessionStore: AppSessionStore

    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        NavigationStack {
            ZStack {
                DriverTheme.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: symbol)
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(DriverTheme.accent)
                        .frame(width: 96, height: 96)
                        .background(DriverTheme.cardBackground, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                    VStack(spacing: 12) {
                        Text(title)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(subtitle)
                            .font(.body)
                            .foregroundStyle(DriverTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }

                    Button("Sign Out") {
                        sessionStore.signOut()
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Fleet Management")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
