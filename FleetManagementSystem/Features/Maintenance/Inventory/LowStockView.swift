import SwiftUI

struct LowStockView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var selectedItem: InventoryItem?
    @State private var showDeleteAlert = false
    @State private var itemToDelete: InventoryItem?
    
    var lowStockItems: [InventoryItem] {
        viewModel.items.filter { $0.quantity <= 10 }
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            if lowStockItems.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Inventory looks good!")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("No parts are currently low in stock.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            } else {
                List {
                    ForEach(lowStockItems) { item in
                        inventoryRow(for: item)
                            .padding(.horizontal, 16)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedItem = item
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                itemToDelete = item
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Low Stock")
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                PartDetailView(viewModel: viewModel, item: item)
            }
        }
        .onAppear {
            if viewModel.items.isEmpty {
                Task {
                    await viewModel.fetchInventory()
                }
            }
        }
        .alert("Delete Part", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                if let item = itemToDelete {
                    Task {
                        do {
                            try await viewModel.deleteInventoryItem(id: item.inventoryId)
                        } catch {
                            print("DELETE ERROR:", error.localizedDescription)
                        }
                        itemToDelete = nil
                    }
                }
            }
            Button("Cancel", role: .cancel) { 
                itemToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this part? This action cannot be undone.")
        }
        .alert(item: $viewModel.deleteErrorMessage) { alertItem in
            Alert(
                title: Text("Cannot Delete"),
                message: Text(alertItem.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private func inventoryRow(for item: InventoryItem) -> some View {
        HStack(spacing: 16) {
            // Circular Image
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 50, height: 50)
                
                if let urlString = item.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundColor(.gray)
                }
            }
            
            // Center Content
            VStack(alignment: .leading, spacing: 4) {
                Text(item.partName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                let locationText = item.location ?? "Unknown"
                let categoryText = item.categoryDescription ?? item.vehicleCategory ?? "Uncategorized"
                
                Text("\(locationText) • \(categoryText)")
                    .font(.subheadline)
                    .foregroundColor(.primary.opacity(0.8))
            }
            
            Spacer()
            
            // Quantity Badge
            Text("\(item.quantity)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(quantityColor(for: item.quantity))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(quantityColor(for: item.quantity).opacity(0.15))
                .clipShape(Capsule())
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Color(.tertiaryLabel))
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private func quantityColor(for quantity: Int) -> Color {
        if quantity == 0 {
            return .red
        } else if quantity <= 10 {
            return .orange
        } else {
            return .green
        }
    }
}
