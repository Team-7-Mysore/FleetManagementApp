//
//  FleetManagementSystemApp.swift
//  FleetManagementSystem
//
//  Created by harshwardhan patil on 15/04/26.
//

import SwiftUI

@main
struct FleetManagementSystemApp: App {
    @StateObject private var sessionStore = AppSessionStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionStore)
        }
    }
}
