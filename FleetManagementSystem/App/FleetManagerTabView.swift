//
//  FleetManagerTabView.swift
//  FleetManagementSystem
//
//  Created by Disha Jain on 15/04/26.
//

import SwiftUI

struct FleetManagerTabView: View {
    var body: some View {
        TabView {
            TripsListView()
                .tabItem {
                    Label("Trips", systemImage: "map")
                }
            
            FleetListView()
                .tabItem {
                    Label("Fleet", systemImage: "car.2")
                }
            
            StaffListView()
                .tabItem {
                    Label("Staff", systemImage: "person.2")
                }
            
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "message")
                }
        }
    }
}

#Preview {
    FleetManagerTabView()
}
