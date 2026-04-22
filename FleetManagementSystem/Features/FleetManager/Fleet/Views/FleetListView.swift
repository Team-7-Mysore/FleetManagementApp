import SwiftUI

// MARK: - Models
struct VehicleCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let type: String
    let iconColor: Color
    let iconBG: Color
}

// MARK: - Main Fleet View
struct FleetListView: View {
    @StateObject private var vm = FleetListViewModel()
    @State private var showingAddVehicle = false
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    let categories: [VehicleCategory] = [
        .init(name: "Bike", icon: "bicycle", type: "bike", iconColor: Color.gray, iconBG: Color.gray.opacity(0.1)),
        .init(name: "Car", icon: "car.fill", type: "car", iconColor: Color.blue, iconBG: Color.blue.opacity(0.1)),
        .init(name: "Bus", icon: "bus.fill", type: "bus", iconColor: Color.green.opacity(0.8), iconBG: Color.green.opacity(0.1)),
        .init(name: "Truck", icon: "box.truck.fill", type: "truck", iconColor: Color.orange, iconBG: Color.orange.opacity(0.1))
    ]
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        
                        // 1. CATEGORIES SECTION
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Categories")
                                .font(.title2.weight(.bold))
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(categories) { category in
                                    NavigationLink(destination: VehicleCategoryDetailView(category: category, vm: vm)) {
                                        CategoryCardView(category: category)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // 2. UPCOMING MAINTENANCE SECTION
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Upcoming Maintenance")
                                    .font(.title2.weight(.bold))
                                
                                Spacer()
                                
                                if !vm.maintenanceAlerts.isEmpty {
                                    Text("\(vm.maintenanceAlerts.count) Alerts")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal)
                            
                            if vm.maintenanceAlerts.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                        Text("All vehicles operational")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 30)
                                .background(RoundedRectangle(cornerRadius: 20).fill(Color(.secondarySystemGroupedBackground)).padding(.horizontal))
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(vm.maintenanceAlerts) { alert in
                                        MaintenanceAlertCard(alert: alert)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.vertical)
                }
                
                Button(action: { showingAddVehicle = true }) {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
            .navigationTitle("Fleet")
            .sheet(isPresented: $showingAddVehicle) {
                NavigationStack { AddVehicleView(fleetVM: vm) }
            }
            .task {
                await vm.fetchVehicles()
                await vm.fetchMaintenanceAlerts()
            }
        }
    }
    // Inside FleetListViewModel
  
}

// MARK: - Category Card Component
struct CategoryCardView: View {
    let category: VehicleCategory
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(category.iconBG)
                    .frame(width: 56, height: 56)
                
                Image(systemName: category.icon)
                    .font(.system(size: 26))
                    .foregroundColor(category.iconColor)
            }
            
            Text(category.name)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Maintenance Alert Card
struct MaintenanceAlertCard: View {
    let alert: MaintenanceAlert
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(alert.status == .overdue ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                    .frame(width: 42, height: 42)
                
                Image(systemName: alert.status == .overdue ? "wrench.and.screwdriver.fill" : "clock.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(alert.status == .overdue ? .red : .blue)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Unit \(alert.unitNumber)")
                    .font(.subheadline.weight(.bold))
                
                Text(alert.serviceType)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Cleaned up trailing section
            VStack(alignment: .trailing) {
                Text(alert.status == .overdue ? "OVERDUE" : "SCHEDULED")
                    .font(.system(size: 9, weight: .black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(alert.status == .overdue ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                    .foregroundColor(alert.status == .overdue ? .red : .blue)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
        .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 2)
    }
}

// Detail View Components
struct VehicleCategoryDetailView: View {
    let category: VehicleCategory
    @ObservedObject var vm: FleetListViewModel
    
    @State private var vehicleToDelete: Vehicle?
    @State private var showingDeleteConfirmation = false
    
    // NEW: Tracks which vehicle ID is selected for the modal
    @State private var selectedVehicleId: UUID?
    
    var filteredVehicles: [Vehicle] {
        vm.vehicles.filter { $0.vehicleType.lowercased() == category.type.lowercased() }
    }
    
    var body: some View {
        Group {
            if filteredVehicles.isEmpty {
                ContentUnavailableView("No \(category.name)s", systemImage: category.icon, description: Text("No vehicles found."))
            } else {
                List {
                    ForEach(filteredVehicles) { vehicle in
                        // Changed from NavigationLink to Button for Modal trigger
                        Button {
                            selectedVehicleId = vehicle.id
                        } label: {
                            CompactVehicleRow(vehicle: vehicle)
                        }
                        .buttonStyle(.plain)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                vehicleToDelete = vehicle
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .tint(.red)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(category.name)
        // MODAL PRESENTATION
        .sheet(item: $selectedVehicleId) { id in
            NavigationStack {
                VehicleDetailView(vehicleId: id)
            }
        }
        .confirmationDialog(
            "Are you sure?",
            isPresented: $showingDeleteConfirmation,
            presenting: vehicleToDelete
        ) { vehicle in
            Button("Delete \(vehicle.name)", role: .destructive) {
                Task { await vm.deleteVehicle(vehicle) }
            }
            Button("Cancel", role: .cancel) { vehicleToDelete = nil }
        } message: { vehicle in
            Text("This will permanently remove \(vehicle.registrationNumber) from your fleet.")
        }
    }
}

struct CompactVehicleRow: View {
    let vehicle: Vehicle
    
    var body: some View {
        HStack(spacing: 16) {
            // 1. Vehicle Image
            AsyncImage(url: URL(string: vehicle.imageURL ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack {
                    Color.gray.opacity(0.1)
                    Image(systemName: vehicle.imageSystemName)
                        .foregroundColor(.gray.opacity(0.3))
                }
            }
            .frame(width: 70, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            
            // 2. Details Section
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(vehicle.name) // Displaying 'vehicle_name' (e.g., Activa 6G)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // STATUS CAPSULE (e.g., ACTIVE / IN SERVICE)
                    Text(vehicle.status?.uppercased() ?? "ACTIVE")
                        .font(.system(size: 8, weight: .black))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(vehicle.statusColor.opacity(0.1))
                        .foregroundColor(vehicle.statusColor)
                        .clipShape(Capsule())
                }
                
                Text(vehicle.registrationNumber) // e.g., KA03EF9012
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.blue)
                
                Text("\(vehicle.brand ?? "") \(vehicle.model ?? "")") // e.g., Honda Activa
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // 3. Navigation Indicator
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: .black.opacity(0.02), radius: 5, x: 0, y: 2)
    }
}
extension UUID: Identifiable {
    public var id: UUID { self }
}
