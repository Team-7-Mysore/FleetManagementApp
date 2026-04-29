import SwiftUI

struct MaintenanceHomeView: View {
    let profile: UserProfile?
    let onSignOut: () async -> Void

    @StateObject private var inventoryViewModel = InventoryViewModel()

    var body: some View {
        TabView {
            WorkOrdersView(profile: profile, onSignOut: onSignOut)
                .tabItem {
                    Label("Work Orders", systemImage: "list.bullet")
                }

            InventoryView(viewModel: inventoryViewModel)
                .tabItem {
                    Label("Inventory", systemImage: "cube.box")
                }

            if let userId = profile?.userId {
                NavigationStack {
                    ChatListView(currentUserId: userId, accentColor: Color(red: 163/255, green: 53/255, blue: 42/255))
                }
                    .tabItem {
                        Label("Chat", systemImage: "message")
                    }
            }
        }
        .tint(Color(red: 163/255, green: 53/255, blue: 42/255))
    }
}

#Preview {
    MaintenanceHomeView(profile: nil, onSignOut: {})
}
