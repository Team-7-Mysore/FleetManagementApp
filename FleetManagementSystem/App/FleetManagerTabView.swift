//
//  FleetManagerTabView.swift
//  FleetManagementSystem
//
//  Created by Disha Jain on 15/04/26.
//

import SwiftUI

struct FleetManagerTabView: View {
    init() {
        UITabBar.appearance().unselectedItemTintColor = UIColor.systemGray
    }

    var body: some View {
        TabView {
            TripsListView()
                .tabItem {
                    Image(systemName: "map.fill")
                    Text("Trips")
                }
            
            FleetListView()
                .tabItem {
                    Image(systemName: "car.2.fill")
                    Text("Fleet")
                }
            
            StaffListView()
                .tabItem {
                    Image(systemName: "person.2.fill")
                    Text("Staff")
                }
            
            ChatView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Chat")
                }
        }
        .accentColor(.primaryBrown)
        .tint(.primaryBrown)
    }
}
#Preview {
    FleetManagerTabView()
}
