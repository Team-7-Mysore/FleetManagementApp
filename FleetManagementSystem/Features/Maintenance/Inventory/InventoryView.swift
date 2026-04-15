import SwiftUI

struct InventoryView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("Brake Pads (10)")
                Text("Oil Filters (25)")
                Text("Tires (4)")
            }
            .navigationTitle("Inventory")
        }
    }
}

#Preview {
    InventoryView()
}
