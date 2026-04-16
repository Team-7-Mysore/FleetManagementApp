import SwiftUI

struct WorkOrdersView: View {
    var body: some View {
        NavigationStack {
            List {
                Text("Sample Work Order 101")
                Text("Sample Work Order 102")
                Text("Sample Work Order 103")
            }
            .navigationTitle("Work Orders")
        }
    }
}

#Preview {
    WorkOrdersView()
}
