import SwiftUI

// MARK: - Driver Profile View
struct DriverProfileView: View {
    let user: User
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    @State private var showLogoutConfirmation = false

    private let vehicleService = VehicleService.shared
    private let tripService = TripService.shared

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
                    profileRow(icon: "phone", title: "Phone", value: user.phone)
                    profileRow(icon: "calendar", title: "Member Since",
                               value: user.joinDate.formatted(date: .abbreviated, time: .omitted))
                }

                // MARK: - Assigned Vehicle
                if let vehicle = vehicleService.assignedVehicle(forDriver: user.id) {
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

                        profileRow(icon: "number", title: "License", value: vehicle.licensePlate)
                        profileRow(icon: "fuelpump", title: "Fuel", value: "\(vehicle.fuelPercentage)%")
                        profileRow(icon: "speedometer", title: "Mileage", value: vehicle.formattedMileage)
                    }
                }

                // MARK: - Statistics
                Section("Statistics") {
                    profileRow(icon: "road.lanes", title: "Total Miles",
                               value: String(format: "%.0f mi", tripService.totalMiles(forDriver: user.id)))
                    profileRow(icon: "truck.box", title: "Total Trips",
                               value: "\(tripService.totalTrips(forDriver: user.id))")
                    profileRow(icon: "chart.line.uptrend.xyaxis", title: "Avg Distance",
                               value: String(format: "%.0f mi", tripService.averageDistance(forDriver: user.id)))
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(AppTheme.primaryGreen)
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
