//
//  FleetManagementSystemApp.swift
//  FleetManagementSystem
//
//  Created by harshwardhan patil on 15/04/26.
//

import SwiftUI

@main
struct FleetManagementSystemApp: App {
    @StateObject private var router = AppRouter()

    /// Hardcoded driver user — skips login entirely
    private let driverUser = MockDataStore.shared.users.first {
        $0.id == MockDataStore.driverJohnId
    }!

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $router.path) {
                DriverDashboardView(user: driverUser)
                    .navigationDestination(for: AppRoute.self) { route in
                        switch route {
                        case .activeTrip(let trip):
                            ActiveTripView(trip: trip, user: driverUser)
                        case .vehicleInspection(let trip):
                            VehicleInspectionView(user: driverUser, trip: trip)
                        }
                    }
            }
            .tint(AppTheme.primaryGreen)
            .environmentObject(router)
        }
    }
}
