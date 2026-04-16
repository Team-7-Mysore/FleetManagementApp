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

    var body: some Scene {
        WindowGroup {
            Group {
                if router.isLoggedIn, let user = router.currentUser {
                    switch user.role {
                    case .driver:
                        DriverTabView(user: user)
                            .environmentObject(router)
                    case .fleetManager:
                        // Placeholder — will be built later
                        Text("Fleet Manager Interface")
                            .environmentObject(router)
                    case .maintenance:
                        // Placeholder — will be built later
                        Text("Maintenance Interface")
                            .environmentObject(router)
                    }
                } else {
                    LoginView()
                        .environmentObject(router)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: router.isLoggedIn)
        }
    }
}
