import SwiftUI

struct MaintenanceHomeView: View {
    @StateObject private var inventoryViewModel = InventoryViewModel()

    var body: some View {
        TabView {
            WorkOrdersView()
                .tabItem {
                    Label("Work Orders", systemImage: "list.bullet")
                }


            InventoryView(viewModel: inventoryViewModel)
                .tabItem {
                    Label("Inventory", systemImage: "cube.box")
                }

            ChatListView()
                .tabItem {
                    Label("Chat", systemImage: "message")
                }
        }
        .tint(Color(red: 163/255, green: 53/255, blue: 42/255))
    }
}

#Preview {
    MaintenanceHomeView()
}
