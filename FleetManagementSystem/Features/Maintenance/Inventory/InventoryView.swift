import SwiftUI

struct InventoryView: View {
    @ObservedObject var viewModel: InventoryViewModel
    let profile: UserProfile?
    let onSignOut: () async -> Void
    
    @State private var selectedItem: InventoryItem?
    @State private var navigatedCategory: String?
    @State private var showDeleteAlert = false
    @State private var itemToDelete: InventoryItem?
    @State private var showOptions = false
    @State private var showScanner = false
    @State private var navigateToManual = false
    @State private var navigateToScanned = false
    @State private var scannedName: String?
    @State private var scannedQuantity: Int?
    @State private var scannedCost: Double?
    @State private var showNotifications = false
    @State private var showingProfile = false // Added for Profile routing
    
    // Initializer added to receive profile data without breaking previews
    init(viewModel: InventoryViewModel, profile: UserProfile? = nil, onSignOut: @escaping () async -> Void = {}) {
        self.viewModel = viewModel
        self.profile = profile
        self.onSignOut = onSignOut
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                List {
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
                    await viewModel.syncLowStockNotifications()
                }
            }
            .navigationTitle("Inventory")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // 🔔 Notification Bell
                    Button {
                        showNotifications = true
                    } label: {
                        ZStack {
                            Image(systemName: "bell")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(Color(hex:"#A3352A"))
                            
                            if viewModel.notifications.count > 0 {
                                Text("\(viewModel.notifications.count)")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(4)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 8, y: -8)
                            }
                        }
                    }
                    
                    // 👤 Profile Icon
                    Button {
                        showingProfile = true
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.title3)
                            .foregroundColor(Color(hex:"#A3352A"))
                    }
                }
            }
            .overlay(alignment: .bottomTrailing) {
                ZStack(alignment: .bottomTrailing) {
                    if showOptions {
                        VStack(spacing: 8) {
                            // 🔺 Arrow pointing to + button
                            Triangle()
                                .fill(Color(.systemBackground))
                                .frame(width: 20, height: 10)
                                .offset(x: -20) // Adjust to align with + button
                            
                            VStack(spacing: 12) {
                                Button {
                                    showOptions = false
                                    showScanner = true
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text.viewfinder")
                                        Text("Scan Invoice")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                
                                Divider()
                                
                                Button {
                                    showOptions = false
                                    navigateToManual = true
                                } label: {
                                    HStack {
                                        Image(systemName: "pencil.and.outline")
                                        Text("Add Manually")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding()
                            .frame(width: 180)
                            .background(Color(.systemBackground))
                            .cornerRadius(16)
                            .shadow(radius: 10)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 80)
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    Button {
                        withAnimation(.spring()) {
                            showOptions.toggle()
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color(hex: "#A3352A"))
                            .clipShape(Circle())
                            .rotationEffect(.degrees(showOptions ? 45 : 0))
                            .shadow(color: Color(hex: "#A3352A").opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
            .hideKeyboardOnTap()
            .navigationDestination(isPresented: $navigateToManual) {
                AddPartView(viewModel: viewModel)
            }
            .navigationDestination(isPresented: $navigateToScanned) {
                AddPartView(
                    viewModel: viewModel,
                    prefilledName: scannedName,
                    prefilledQuantity: scannedQuantity,
                    prefilledCost: scannedCost
                )
            }
            
            // MARK: - Standardized Navigation (Maintenance Personnel)
            .navigationDestination(isPresented: $showNotifications) {
                MaintenanceNotificationsView(unreadCount: .constant(viewModel.notifications.count))
            }
            .sheet(isPresented: $showingProfile) {
                // 🚨 Swap this with your actual Maintenance Profile View name if it's different!
                MaintenanceProfileView(profile: profile, onSignOut: onSignOut)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            
            .fullScreenCover(isPresented: $showScanner) {
                DocumentScanner(showScanner: $showScanner) { images in
                    guard let firstImage = images.first else { return }
                    Task {
                        do {
                            let result = try await OCRService.shared.recognizeText(from: firstImage)
                            await MainActor.run {
                                scannedName = result.name
                                scannedQuantity = result.quantity
                                scannedCost = result.costPerUnit
                                navigateToScanned = true
                            }
                        } catch {
                            print("OCR Failed: \(error.localizedDescription)")
                            await MainActor.run {
                                navigateToManual = true // Fallback to manual
                            }
                        }
                    }
                }
                .ignoresSafeArea()
            }
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
            }
            .task {
                await viewModel.fetchInventory()
                await viewModel.syncLowStockNotifications()
            }
        }
    }
}

// 🔺 Triangle Shape for pointing
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    InventoryView(viewModel: InventoryViewModel())
}
