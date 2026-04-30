import SwiftUI

struct NotificationView: View {
    var notifications: [NotificationItem]
    @ObservedObject var viewModel: InventoryViewModel
    @State private var selectedItem: InventoryItem?

    var body: some View {
        List {
            ForEach(notifications) { notification in
                Button {
                    if let inventoryId = notification.inventoryId,
                       let item = viewModel.items.first(where: { $0.inventoryId == inventoryId }) {
                        selectedItem = item
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(notification.title)
                            .font(.headline)

                        Text(notification.message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        if let date = notification.createdAt {
                            Text(date, style: .time)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .navigationTitle("Notifications")
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                PartDetailView(viewModel: viewModel, item: item)
            }
        }
    }
}


#Preview {
    NotificationView(notifications: [], viewModel: InventoryViewModel())
}
