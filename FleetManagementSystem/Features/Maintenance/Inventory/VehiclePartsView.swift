import SwiftUI

struct VehiclePartsView: View {
    @ObservedObject var viewModel: InventoryViewModel
    let category: String
    @State private var selectedItem: InventoryItem?
    @State private var showDeleteAlert = false
    @State private var itemToDelete: InventoryItem?
    @State private var showInsightsCard = false

    private var displayedMostUsedPart: InventoryItem? {
        guard viewModel.activeMostUsedCategory == category else { return nil }
        return viewModel.mostUsedPart
    }
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Search Bar
                InventorySearchBar(text: $viewModel.searchText)
                    .padding(16)

                mostUsedInsightsCard
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                    .opacity(showInsightsCard ? 1 : 0)
                    .offset(y: showInsightsCard ? 0 : -8)
                
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
            withAnimation(.easeOut(duration: 0.25)) {
                showInsightsCard = true
            }
        }
        .task(id: category) {
            await viewModel.fetchMostUsedPart(for: category)
        }
        .sheet(item: $selectedItem) { item in
            NavigationStack {
                PartDetailView(viewModel: viewModel, item: item)
            }
        }
    }

    private var mostUsedInsightsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Most Used This Week")
                .font(.headline)
                .fontWeight(.bold)

            if let item = displayedMostUsedPart {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color(hex: "#A3352A").opacity(0.12))
                            .frame(width: 42, height: 42)

                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(Color(hex: "#A3352A"))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.partName)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .lineLimit(2)

                        Text("Used \(viewModel.mostUsedQuantity) time\(viewModel.mostUsedQuantity == 1 ? "" : "s") in the last 7 days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 12)

                    Text("\(viewModel.mostUsedQuantity)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#A3352A"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(hex: "#A3352A").opacity(0.12))
                        .clipShape(Capsule())
                }

                Text("This part is frequently used. Consider restocking regularly.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Color(hex: "#A3352A"))

                    Text("No usage recorded this week")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
}
