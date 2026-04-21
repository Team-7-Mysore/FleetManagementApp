import SwiftUI

struct FleetManagerTabView: View {
    let profile: UserProfile?
    let onSignOut: () async -> Void
    
    init(profile: UserProfile? = nil, onSignOut: @escaping () async -> Void = {}) {
        self.profile = profile
        self.onSignOut = onSignOut
        UITabBar.appearance().unselectedItemTintColor = UIColor.systemGray
    }

    var body: some View {
        TabView {
            TripsListView(profile: profile, onSignOut: onSignOut)
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

            ChatListView()
                .tabItem {
                    Image(systemName: "message.fill")
                    Text("Chat")
                }
        }
        .accentColor(.TechBlue)
        .tint(.TechBlue)
    }
}

#Preview {
    FleetManagerTabView()
}
