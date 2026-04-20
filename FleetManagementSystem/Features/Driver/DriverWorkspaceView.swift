import SwiftUI

struct DriverWorkspaceView: View {
    let profile: UserProfile
    let onSignOut: () async -> Void

    @StateObject private var router = AppRouter()

    private var mappedUser: User {
        let parts = profile.name.split(separator: " ", maxSplits: 1).map(String.init)
        let firstName = parts.first ?? profile.name
        let lastName = parts.count > 1 ? parts[1] : ""

        return User(
            id: profile.userId,
            firstName: firstName,
            lastName: lastName,
            email: profile.email,
            role: .driver,
            phone: profile.phoneNumber ?? "",
            isActive: true,
            joinDate: parsedCreatedDate(profile.createdAt) ?? Date()
        )
    }

    var body: some View {
        NavigationStack(path: $router.path) {
            DriverDashboardView(user: mappedUser)
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .activeTrip(let trip):
                        ActiveTripView(trip: trip, user: mappedUser)
                    case .vehicleInspection(let trip, let type):
                        VehicleInspectionView(user: mappedUser, trip: trip, defaultType: type)
                    }
                }
        }
        .tint(AppTheme.primaryGreen)
        .environmentObject(router)
        .onAppear {
            router.resetPath()
            router.onSignOut = {
                await onSignOut()
            }
        }
    }

    private func parsedCreatedDate(_ value: String?) -> Date? {
        guard let value else { return nil }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
