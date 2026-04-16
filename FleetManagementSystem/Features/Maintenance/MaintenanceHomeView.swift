import SwiftUI

struct MaintenanceHomeView: View {
    var body: some View {
        TabView {
            WorkOrdersView()
                .tabItem {
                    Label("Work Orders", systemImage: "list.bullet")
                }
            
            
            InventoryView()
                .tabItem {
                    Label("Inventory", systemImage: "cube.box")
                }
            
            ChatView()
                .tabItem {
                    Label("Chat", systemImage: "message")
                }
        }
    }
}

#Preview {
    MaintenanceHomeView()
}
