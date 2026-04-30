import SwiftUI
import Supabase

// MARK: - Driver Profile View
struct DriverProfileView: View {
    let user: User
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss

    @State private var showLogoutConfirmation = false
    @State private var showLicencePhotoViewer = false
    @State private var isLoadingDriverProfile = true
    @State private var assignedVehicle: Vehicle?
    @State private var driverProfile: Driver?
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

                // MARK: - Licence
                Section("Driving Licence") {
                    if isLoadingDriverProfile {
                        HStack(spacing: 12) {
                            ProgressView()
                                .tint(AppTheme.primaryGreen)
                            Text("Loading licence details...")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    } else if let driverProfile {
                        profileRow(icon: "number", title: "Licence No", value: driverProfile.licenseNo)
                        profileRow(
                            icon: "calendar.badge.clock",
                            title: "Expiry",
                            value: formattedLicenceExpiry(driverProfile.licenseExpiry)
                        )

                        if licenceImageURL != nil {
                            HStack {
                                Label("Licence Photo", systemImage: "photo.on.rectangle.angled")
                                    .foregroundStyle(.primary)

                                Spacer()

                                Button {
                                    showLicencePhotoViewer = true
                                } label: {
                                    Text("View")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 8)
                                        .background(AppTheme.primaryGreen)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 4)
                        } else {
                            licencePlaceholder(
                                title: "No licence photo uploaded",
                                subtitle: "Your fleet manager has not added a licence image yet."
                            )
                        }
                    } else {
                        licencePlaceholder(
                            title: "Licence details unavailable",
                            subtitle: "We couldn't load your licence information right now."
                        )
                    }
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
//                    profileRow(icon: "road.lanes", title: "Total Miles",
//                               value: String(format: "%.0f mi", totalMiles))
                    profileRow(icon: "truck.box", title: "Total Trips",
                               value: "\(totalTrips)")
//                    profileRow(icon: "chart.line.uptrend.xyaxis", title: "Avg Distance",
//                               value: String(format: "%.0f mi", avgDistance))
                }

                // MARK: - Preferences
                Section("Preferences") {
                    HStack {
                        Label("Language", systemImage: "globe")
                            .foregroundStyle(.primary)
                        Spacer()
                        LanguagePickerView()
                    }
                }

                // MARK: - Preferences
                Section("Preferences") {
                    HStack {
                        Label("Language", systemImage: "globe")
                            .foregroundStyle(.primary)
                        Spacer()
                        LanguagePickerView()
                    }
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
            .alert("Log Out", isPresented: $showLogoutConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Log Out", role: .destructive) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        router.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
            .sheet(isPresented: $showLicencePhotoViewer) {
                if let licenceURL = licenceImageURL {
                    NavigationStack {
                        ZStack {
                            Color.white.ignoresSafeArea()

                            CachedAsyncImage(url: licenceURL) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .padding()
                                case .failure:
                                    VStack(spacing: 12) {
                                        Image(systemName: "exclamationmark.triangle")
                                            .font(.title2)
                                            .foregroundStyle(AppTheme.statusWarning)
                                        Text("Unable to load licence photo")
                                            .foregroundStyle(.primary)
                                    }
                                case .empty:
                                    ProgressView()
                                        .tint(AppTheme.primaryGreen)
                                }
                            }
                        }
                        .navigationTitle("Licence Photo")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button {
                                    showLicencePhotoViewer = false
                                } label: {
                                    Image(systemName: "xmark")
                                        .foregroundStyle(AppTheme.primaryGreen)
                                }
                            }
                        }
                    }
                }
            }
            .onAppear { loadProfileData() }
        }
    }

    private func loadProfileData() {
        Task {
            isLoadingDriverProfile = true
            do {
                // Step 1: Get driver profile details
                let driverRes = try await SupabaseManager.shared.client
                    .from("drivers")
                    .select("driver_id, user_id, license_no, license_expiry, license_image_url")
                    .eq("user_id", value: user.id)
                    .single()
                    .execute()

                let driverProfile = try JSONDecoder().decode(Driver.self, from: driverRes.data)
                self.driverProfile = driverProfile

                // Step 2: Fetch trips
                let tripRes = try await SupabaseManager.shared.client
                    .from("trips")
                    .select("*")
                    .eq("driver_id", value: driverProfile.driverId)
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

            isLoadingDriverProfile = false
        }
    }

    private var licenceImageURL: URL? {
        guard let rawURL = driverProfile?.licenseImageURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawURL.isEmpty else {
            return nil
        }
        return URL(string: rawURL)
    }

    private func formattedLicenceExpiry(_ rawValue: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        guard let date = formatter.date(from: rawValue) else {
            return rawValue
        }

        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func licencePlaceholder(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "photo")
                    .foregroundStyle(AppTheme.primaryGreen)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
