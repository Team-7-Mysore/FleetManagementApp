import SwiftUI

struct MaintenanceHomeView: View {
    let profile: UserProfile?
    let onSignOut: () async -> Void
    
    var body: some View {
        TabView {
            WorkOrdersView(profile: profile, onSignOut: onSignOut)
                .tabItem {
                    Label("Work Orders", systemImage: "list.bullet")
                }

            InventoryView()
                .tabItem {
                    Label("Inventory", systemImage: "cube.box")
                }

            ChatListView()
                .tabItem {
                    Label("Chat", systemImage: "message")
                }
        }
    }
}

#Preview {
    MaintenanceHomeView(profile: nil, onSignOut: {})
}
