import SwiftUI

struct VehiclePartsView: View {
    @ObservedObject var viewModel: InventoryViewModel
    let category: String
    @State private var selectedItem: InventoryItem?
    @State private var showDeleteAlert = false
    @State private var itemToDelete: InventoryItem?
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Search Bar
                InventorySearchBar(text: $viewModel.searchText)
                    .padding(16)
                
                if viewModel.filteredItems.isEmpty {
                    Spacer()
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.4))
                        
                        Text("No parts found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Try searching for something else or add a new part.")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(viewModel.filteredItems) { item in
                                PartRow(item: item)
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
        }
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.inline)
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
        .onAppear {
            viewModel.selectedVehicleFilter = category
            viewModel.searchText = "" // Reset search when entering
            if viewModel.items.isEmpty {
                Task {
                    await viewModel.fetchInventory()
                }
            }
        }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                PartDetailView(viewModel: viewModel, item: item)
            }
        }
    }
}
