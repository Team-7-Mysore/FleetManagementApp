import SwiftUI

struct InventoryView: View {
    @StateObject private var viewModel = InventoryViewModel()
    @State private var showFilterSheet = false
    
    let filterOptions = ["All", "Car", "Truck", "Bike", "Bus"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Subtitle
                    VStack(alignment: .leading) {
                        Text("Managing fleet components")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGroupedBackground))
                    
                    // Low Stock Alert Banner
                    if viewModel.hasLowStock && viewModel.showLowStockBanner {
                        lowStockBanner
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Search + Filter Row
                    searchAndFilterRow
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    
                    // Inventory List
                    VStack(alignment: .leading) {
                        Text("Items: \(viewModel.items.count)")
                        Text("Filtered: \(viewModel.filteredItems.count)")
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                    // Inventory List
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.filteredItems) { item in
                                NavigationLink(destination: Text("\(item.partName) Details").navigationTitle(item.partName)) {
                                    inventoryRow(for: item)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Notification action
                    }) {
                        Image(systemName: "bell")
                            .foregroundColor(.blue)
                    }
                }
            }
            .task {
                await viewModel.fetchInventory()
            }
            .confirmationDialog("Filter by Category", isPresented: $showFilterSheet, titleVisibility: .visible) {
                 ForEach(filterOptions, id: \.self) { option in
                     Button(option) {
                         viewModel.selectedVehicleFilter = option
                     }
                 }
                 Button("Cancel", role: .cancel) {}
            }
        }
    }
    
    // MARK: - Subviews
    
    private var lowStockBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text("\(viewModel.lowStockItemsCount) parts are low in stock")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
            
            Button {
                withAnimation {
                    viewModel.showLowStockBanner = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(4)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(12)
    }
    
    private var searchAndFilterRow: some View {
        HStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search parts, SKU, or category", text: $viewModel.searchText)
                    .font(.subheadline)
                    .autocorrectionDisabled()
            }
            .padding(10)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            
            // Filter Button
            Button {
                showFilterSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text("Filter")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(viewModel.selectedVehicleFilter != "All" ? Color.blue.opacity(0.15) : Color(.systemBackground))
                .foregroundColor(viewModel.selectedVehicleFilter != "All" ? .blue : .primary)
                .cornerRadius(10)
            }
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
                    .font(.caption)
                    .foregroundColor(.secondary)
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

#Preview {
    InventoryView()
}
