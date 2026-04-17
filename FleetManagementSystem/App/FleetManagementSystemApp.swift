//
//  FleetManagementSystemApp.swift
//  FleetManagementSystem
//
//  Created by harshwardhan patil on 15/04/26.
//

import SwiftUI

@main
struct FleetManagementSystemApp: App {
    var body: some Scene {
        WindowGroup {
//            LoginView()
           MaintenanceHomeView()
                .tint(Color(hex: "#A3352A"))
        }
    }
}
