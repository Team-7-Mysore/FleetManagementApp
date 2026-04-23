import SwiftUI
import Supabase

// MARK: - Driver Profile View
struct DriverProfileView: View {
    let user: User
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    @State private var showLogoutConfirmation = false
    @State private var assignedVehicle: Vehicle?
    @State private var totalMiles: Double = 0
    @State private var totalTrips: Int = 0
    @State private var avgDistance: Double = 0

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile Header
                Section {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(AppTheme.primaryGreen)
                            .frame(width: 64, height: 64)
                            .overlay {
                                Text(user.initials)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(.white)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.fullName)
                                .font(.title3.weight(.bold))

                            HStack(spacing: 6) {
                                Image(systemName: user.role.systemImage)
                                    .font(.caption)
                                Text(user.role.rawValue)
                                    .font(.subheadline)
                            }
                            .foregroundStyle(AppTheme.primaryGreen)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // MARK: - Account Info
                Section("Account") {
                    profileRow(icon: "envelope", title: "Email", value: user.email)
                    profileRow(icon: "calendar", title: "Member Since",
                               value: user.joinDate.formatted(date: .abbreviated, time: .omitted))
                }

                // MARK: - Assigned Vehicle
                if let vehicle = assignedVehicle {
                    Section("Assigned Vehicle") {
                        HStack(spacing: 14) {
                            Image(systemName: vehicle.imageSystemName)
                                .font(.title2)
                                .foregroundStyle(AppTheme.primaryGreen)
                                .frame(width: 44, height: 44)
                                .background(AppTheme.lightGreen)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(vehicle.name)
                                    .font(.subheadline.weight(.semibold))
                                Text("\(vehicle.make) \(vehicle.model) • \(String(vehicle.year))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)

                        profileRow(icon: "number", title: "Number Plate", value: vehicle.licensePlate)
                    }
                }

                // MARK: - Statistics
                Section("Statistics") {
                    profileRow(icon: "road.lanes", title: "Total Miles",
                               value: String(format: "%.0f mi", totalMiles))
                    profileRow(icon: "truck.box", title: "Total Trips",
                               value: "\(totalTrips)")
                    profileRow(icon: "chart.line.uptrend.xyaxis", title: "Avg Distance",
                               value: String(format: "%.0f mi", avgDistance))
                }

                // MARK: - App Info
                Section("App") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                }

                // MARK: - Logout
                Section {
                    Button(role: .destructive) {
                        showLogoutConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
//                ToolbarItem(placement: .topBarLeading) {
//                    Button(action: {
//                        dismiss()
//                    }) {
//                        Image(systemName: "xmark")
//                            .foregroundColor(AppTheme.primaryGreen)
//                            .font(.title2)
//                    }
//                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        ZStack {

                            Image(systemName: "xmark")
                                .foregroundColor(AppTheme.primaryGreen)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
            .confirmationDialog("Log Out", isPresented: $showLogoutConfirmation) {
                Button("Log Out", role: .destructive) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        router.signOut()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to log out?")
            }
            .onAppear { loadProfileData() }
        }
    }

    private func loadProfileData() {
        Task {
            do {
                // Step 1: Get driver_id
                let driverRes = try await SupabaseManager.shared.client
                    .from("drivers")
                    .select("driver_id")
                    .eq("user_id", value: user.id)
                    .single()
                    .execute()

                let driverData = try JSONDecoder().decode([String: String].self, from: driverRes.data)
                guard let driverId = driverData["driver_id"] else { return }

                // Step 2: Fetch trips
                let tripRes = try await SupabaseManager.shared.client
                    .from("trips")
                    .select("*")
                    .eq("driver_id", value: driverId)
                    .execute()

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let str = try container.decode(String.self)
                    if let date = BackendDateParser.parse(str) { return date }
                    throw DecodingError.dataCorruptedError(in: container,
                        debugDescription: "Invalid date: \(str)")
                }

                let dtoTrips = try decoder.decode([TripDTO].self, from: tripRes.data)
                let completed = dtoTrips.filter {
                    let status = $0.status.lowercased()
                    return status == "completed" || status == "done"
                }

                self.totalTrips = completed.count
                self.totalMiles = completed.compactMap { $0.distanceTravelled }.reduce(0, +)
                self.avgDistance = totalTrips > 0 ? totalMiles / Double(totalTrips) : 0

                // Step 3: Fetch vehicle from first active/assigned trip
                if let vehicleId = dtoTrips
                    .first(where: {
                        let status = $0.status.lowercased()
                        return status == "assigned"
                            || status == "planned"
                            || status == "upcoming"
                            || status == "scheduled"
                            || status == "active"
                            || status == "in_progress"
                    })?
                    .vehicleId {

                    let vRes = try await SupabaseManager.shared.client
                        .from("vehicles")
                        .select("*")
                        .eq("vehicle_id", value: vehicleId)
                        .single()
                        .execute()

                    let vDto = try JSONDecoder().decode(VehicleDTO.self, from: vRes.data)
                    self.assignedVehicle = Vehicle(dto: vDto)
                }

            } catch {
                print("❌ DriverProfileView loadProfileData error:", error)
            }
        }
    }

    private func profileRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
