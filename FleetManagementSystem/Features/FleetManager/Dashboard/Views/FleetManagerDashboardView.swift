//
//  ContentView.swift
//  FleetManagementSystem
//
//  Created by harshwardhan patil on 15/04/26.
//

import SwiftUI

struct FleetManagerDashboardView: View {
    var body: some View {
        RolePlaceholderView(
            title: "Fleet Manager Interface",
            subtitle: "The fleet manager dashboard is not completed yet. Use the seeded driver login to explore the finished driver flow.",
            symbol: "person.3.sequence.fill"
        )
    }
}

struct FleetManagerDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        FleetManagerDashboardView()
            .environmentObject(AppSessionStore())
    }
}
