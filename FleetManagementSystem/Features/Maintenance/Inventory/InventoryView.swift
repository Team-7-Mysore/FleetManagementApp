import SwiftUI

struct InventoryView: View {
    @StateObject private var viewModel = InventoryViewModel()
    @State private var showFilterSheet = false
    @State private var selectedItem: InventoryItem?
    
    let filterOptions = ["All", "Car", "Truck", "Bike", "Bus"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header Subtitle
                    VStack(alignment: .leading) {
                        Text("Managing vehicle components")
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
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.filteredItems) { item in
                                Button {
                                    selectedItem = item
                                } label: {
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
            .overlay(alignment: .bottomTrailing) {
                NavigationLink(destination: AddPartView(viewModel: viewModel)) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color(hex: "#A3352A"))
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 3)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Inventory")
            .sheet(item: $selectedItem) { item in
                NavigationStack {
                    PartDetailView(viewModel: viewModel, item: item)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: NotificationsView()) {
                        Image(systemName: "bell")
                            .foregroundColor(Color(hex: "#A3352A"))
                    }
                }
            }
            .task {
                await viewModel.fetchInventory()
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
            
            NavigationLink(destination: LowStockView(viewModel: viewModel)) {
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(4)
            }
            
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
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44)
                    .background(Color(.systemBackground))
                    .foregroundColor(
                        viewModel.selectedVehicleFilter != "All"
                        ? Color(hex: "#A3352A")
                        : .primary
                    )
                    .background(
                        viewModel.selectedVehicleFilter != "All"
                        ? Color(hex: "#A3352A").opacity(0.1)
                        : Color.clear
                    )
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            }
            .popover(isPresented: $showFilterSheet, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Filter by Category")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    Divider()
                        .padding(.horizontal, 20)
                    
                    ForEach(filterOptions, id: \.self) { option in
                        Button {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            
                            withAnimation {
                                viewModel.selectedVehicleFilter = option
                                showFilterSheet = false
                            }
                        } label: {
                            HStack {
                                Text(option)
                                    .foregroundColor(.primary)
                                Spacer()
                                if viewModel.selectedVehicleFilter == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color(hex: "#A3352A"))
                                        .font(.system(size: 14, weight: .bold))
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .contentShape(Rectangle())
                        }
                        
                        if option != filterOptions.last {
                            Divider()
                                .padding(.leading, 20)
                        }
                    }
                }
                .frame(minWidth: 220)
                .presentationDetents([.medium, .large]) // For iPhone sheet behavior fallback
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

#Preview {
    InventoryView()
}
