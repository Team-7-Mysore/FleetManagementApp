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

    // Updated with exact enum values: icons and hex colors
    let categories: [VehicleCategory] = [
        .init(name: "Bike", icon: "motorcycle", type: "bike",
              iconColor: Color(hex: "#2C2C2E"), iconBG: Color(hex: "#2C2C2E").opacity(0.1)),
        .init(name: "Car", icon: "car.fill", type: "car",
              iconColor: Color(hex: "#0A84FF"), iconBG: Color(hex: "#0A84FF").opacity(0.1)),
        .init(name: "Bus", icon: "bus.fill", type: "bus",
              iconColor: Color(hex: "#2E7D32"), iconBG: Color(hex: "#2E7D32").opacity(0.1)),
        .init(name: "Truck", icon: "box.truck.fill", type: "truck",
              iconColor: Color(hex: "#C75C1A"), iconBG: Color(hex: "#C75C1A").opacity(0.1))
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // 1. The Grid of Categories (Bike, Car, etc.)
                        categoriesSection

                        // 2. The Repairs Section (Blue - from Database)
                        maintenanceListSection(
                            title: "Upcoming Maintenance",
                            alerts: vm.maintenanceAlerts,
                            emptyText: "No upcoming maintenance",
                            badgeColor: .blue
                        )

                        // 3. The Monthly Reminders (Purple - Calculated by App)
                        if !vm.monthlyReminders.isEmpty {
                            maintenanceListSection(
                                title: "Monthly Service Reminders",
                                alerts: vm.monthlyReminders,
                                emptyText: nil,
                                badgeColor: .purple
                            )
                        }

                        Spacer(minLength: 100)
                    }
                    .padding(.vertical)
                    .padding(.vertical)
                }

                floatingActionButton
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
    // This builds the list sections (Repairs and Monthly)
    @ViewBuilder
    private func maintenanceListSection(title: String, alerts: [MaintenanceAlert], emptyText: String?, badgeColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title).font(.title2.weight(.bold))
                Spacer()
                if !alerts.isEmpty {
                    Text("\(alerts.count) Due")
                        .font(.caption.weight(.bold))
                        .foregroundColor(badgeColor)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(badgeColor.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)

            if alerts.isEmpty {
                if let text = emptyText {
                    emptyMaintenanceStateView(text: text)
                }
            } else {
                VStack(spacing: 12) {
                    ForEach(alerts) { alert in
                        MaintenanceAlertCard(alert: alert)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // This builds the green checkmark view
    private func emptyMaintenanceStateView(text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 32)).foregroundColor(.green)
            Text(text).font(.subheadline.weight(.medium)).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
        .padding(.horizontal, 20)
    }

    // MARK: - Extracted Subviews
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Categories")
                .font(.title2.weight(.bold))
                .padding(.horizontal, 20)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(categories) { category in
                    NavigationLink(destination: VehicleCategoryDetailView(category: category, vm: vm)) {
                        CategoryCardView(category: category)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var upcomingMaintenanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                Text("Upcoming Maintenance")
                    .font(.title2.weight(.bold))

                Spacer()

                if !vm.maintenanceAlerts.isEmpty {
                    Text("\(vm.maintenanceAlerts.count) Alerts")
                        .font(.caption.weight(.bold))
                        .foregroundColor(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)

            if vm.maintenanceAlerts.isEmpty {
                emptyMaintenanceState
            } else {
                VStack(spacing: 12) {
                    ForEach(vm.maintenanceAlerts) { alert in
                        MaintenanceAlertCard(alert: alert)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var emptyMaintenanceState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 32))
                .foregroundColor(.green)
            Text("All vehicles operational")
                .font(.subheadline.weight(.medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 20)
    }

    private var floatingActionButton: some View {
        Button(action: { showingAddVehicle = true }) {
            Image(systemName: "plus")
                .font(.title2.weight(.bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }
}

// MARK: - Category Card Component
struct CategoryCardView: View {
    let category: VehicleCategory

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
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
        .frame(height: 130)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: .black.opacity(0.03), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Maintenance Alert Card
struct MaintenanceAlertCard: View {
    let alert: MaintenanceAlert

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(alert.status == .overdue ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: alert.status == .overdue ? "wrench.and.screwdriver.fill" : "clock.badge.exclamationmark.fill")
                    .font(.system(size: 18))
                    .foregroundColor(alert.status == .overdue ? .red : .blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Unit \(alert.unitNumber)")
                    .font(.system(size: 15, weight: .bold))

                Text(alert.serviceType)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(alert.status == .overdue ? "OVERDUE" : "DUE SOON")
                .font(.system(size: 10, weight: .black))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(alert.status == .overdue ? Color.red.opacity(0.1) : Color.blue.opacity(0.1))
                .foregroundColor(alert.status == .overdue ? .red : .blue)
                .clipShape(Capsule())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Detail View Components
struct VehicleCategoryDetailView: View {
    let category: VehicleCategory
    @ObservedObject var vm: FleetListViewModel

    @State private var vehicleToDelete: Vehicle?
    @State private var showingDeleteConfirmation = false
    @State private var selectedVehicle: Vehicle?

    var filteredVehicles: [Vehicle] {
        vm.vehicles.filter { $0.vehicleType.lowercased() == category.type.lowercased() }
    }

    var body: some View {
        Group {
            if filteredVehicles.isEmpty {
                ContentUnavailableView("No \(category.name)s",
                                       systemImage: category.icon,
                                       description: Text("No vehicles found in this category."))
            } else {
                vehicleList
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(category.name)
        .sheet(item: $selectedVehicle) { vehicle in
            NavigationStack {
                VehicleDetailView(vehicle: vehicle)
            }
        }
        .confirmationDialog("Delete Vehicle", isPresented: $showingDeleteConfirmation, presenting: vehicleToDelete) { vehicle in
            Button("Delete \(vehicle.name)", role: .destructive) {
                Task { await vm.deleteVehicle(vehicle) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { vehicle in
            Text("Are you sure you want to delete \(vehicle.registrationNumber)? This action cannot be undone.")
        }
        
    }

    private var vehicleList: some View {
        List {
            ForEach(filteredVehicles) { vehicle in
                Button {
                    selectedVehicle = vehicle
                } label: {
                    CompactVehicleRow(vehicle: vehicle)
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        vehicleToDelete = vehicle
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - Compact Vehicle Row
struct CompactVehicleRow: View {
    let vehicle: Vehicle

    var body: some View {
        HStack(spacing: 16) {
            AsyncImage(url: URL(string: vehicle.imageURL ?? "")) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ZStack {
                    Color(.tertiarySystemFill)
                    Image(systemName: vehicle.imageSystemName)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.name)
                    .font(.system(size: 16, weight: .bold))

                Text(vehicle.registrationNumber)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(vehicle.statusDisplayName) // Uses "Maintenance" or "Active" (Title Case)
                .font(.system(size: 11, weight: .bold)) // Cleaned up weight and size
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .foregroundColor(vehicle.statusColor) // Orange for Maintenance, Green for Active
                .background(vehicle.statusColor.opacity(0.1))
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(.systemGray4))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .shadow(color: .black.opacity(0.02), radius: 6, x: 0, y: 3)
    }
}
