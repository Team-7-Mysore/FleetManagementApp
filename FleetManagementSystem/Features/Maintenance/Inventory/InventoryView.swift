import SwiftUI

struct InventoryView: View {
    @ObservedObject var viewModel: InventoryViewModel
    @State private var selectedItem: InventoryItem?
    @State private var navigatedCategory: String?
    @State private var showDeleteAlert = false
    @State private var itemToDelete: InventoryItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                List {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Inventory")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    .padding(.top, 40)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.horizontal, 16)
                    
                    // Categories
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Categories")
                            .font(.title3)
                            .fontWeight(.bold)
                            .padding(.horizontal, 16)
                        
                        CategoryGridView(
                            lowStockItems: viewModel.lowStockItems,
                            onCategorySelected: { category in
                                navigatedCategory = category
                            }
                        )
                    }
                    .padding(.top, 24)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    
                    // Low Stock Section
                    if viewModel.hasLowStock {
                        Section {
                            ForEach(viewModel.lowStockItems) { item in
                                LowStockItemCard(item: item)
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
                        } header: {
                            Text("Low in Stock")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                                .textCase(nil)
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                                .padding(.bottom, 8)
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await viewModel.fetchInventory()
                }
            }
            .overlay(alignment: .bottomTrailing) {
                NavigationLink(destination: AddPartView(viewModel: viewModel)) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Color(hex: "#A3352A"))
                        .clipShape(Circle())
                        .shadow(color: Color(hex: "#A3352A").opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
            .navigationBarHidden(true) // Using custom header
            .navigationDestination(item: $navigatedCategory) { category in
                VehiclePartsView(viewModel: viewModel, category: category)
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
            .sheet(item: $selectedItem) { item in
                NavigationStack {
                    PartDetailView(viewModel: viewModel, item: item)
                }
            }
            .onAppear {
                viewModel.selectedVehicleFilter = "All"
                viewModel.searchText = "" // Ensure search is cleared when returning to main screen
                if viewModel.items.isEmpty {
                    Task {
                        await viewModel.fetchInventory()
                    }
                }
            }
        }
    }
}


#Preview {
    InventoryView(viewModel: InventoryViewModel())
}
