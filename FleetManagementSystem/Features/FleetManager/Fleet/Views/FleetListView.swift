import SwiftUI

// MARK: - Models
struct VehicleCategory: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let type: String
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
        .init(name: "Bikes", icon: "bicycle", type: "bike"),
        .init(name: "Cars", icon: "car.fill", type: "car"),
        .init(name: "Buses", icon: "bus.fill", type: "bus"),
        .init(name: "Trucks", icon: "box.truck.fill", type: "truck")
    ]
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
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
                NavigationStack {
                    AddVehicleView(fleetVM: vm)
                }
            }
            .task {
                if vm.vehicles.isEmpty {
                    await vm.fetchVehicles()
                }
            }
        }
    }
}

// MARK: - Grid Card Component
struct CategoryCardView: View {
    let category: VehicleCategory
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: category.icon)
                .font(.system(size: 36))
                .foregroundColor(.blue)
                .frame(height: 50)
            
            Text(category.name)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Category Detail View
struct VehicleCategoryDetailView: View {
    let category: VehicleCategory
    @ObservedObject var vm: FleetListViewModel
    
    var filteredVehicles: [Vehicle] {
        vm.vehicles.filter { $0.vehicleType.lowercased() == category.type.lowercased() }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if filteredVehicles.isEmpty {
                    ContentUnavailableView(
                        "No \(category.name)",
                        systemImage: category.icon,
                        description: Text("You haven't added any \(category.name.lowercased()) yet.")
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(filteredVehicles) { vehicle in
                        NavigationLink(destination: VehicleDetailView(vehicleId: vehicle.id)) {
                            CompactVehicleRow(vehicle: vehicle)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Compact Vehicle Row
struct CompactVehicleRow: View {
    let vehicle: Vehicle
    
    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: URL(string: vehicle.imageURL ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ZStack {
                    Color.gray.opacity(0.1)
                    Image(systemName: vehicle.imageSystemName)
                        .foregroundColor(.gray.opacity(0.3))
                }
            }
            .frame(width: 70, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(vehicle.registrationNumber)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.blue)
                
                Text("\(vehicle.brand ?? "") \(vehicle.model ?? "")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // FIXED: Changed .tertiaryLabel to .tertiary
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}
