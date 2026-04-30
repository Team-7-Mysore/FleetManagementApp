import SwiftUI
import MapKit
import Supabase

struct FleetManagerTripDetailView: View {
    let trip: Trip

    @StateObject private var vm: TripDetailViewModel
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var hasAutoFocusedVehicle = false

    init(trip: Trip) {
        self.trip = trip
        _vm = StateObject(wrappedValue: TripDetailViewModel(trip: trip))
    }

    var body: some View {
        List {
            // MARK: - Map Section
            Section {
                VStack {
                    ZStack(alignment: .bottomTrailing) {
                        Map(position: $cameraPosition) {
                            if let originLat = trip.origin_latitude, let originLng = trip.origin_longitude {
                                Marker("Origin", coordinate: CLLocationCoordinate2D(latitude: originLat, longitude: originLng))
                                    .tint(.green)
                            }

                            if let destLat = trip.destination_latitude, let destLng = trip.destination_longitude {
                                Marker("Destination", coordinate: CLLocationCoordinate2D(latitude: destLat, longitude: destLng))
                                    .tint(.red)
                            }

                            if !vm.routeCoordinates.isEmpty {
                                MapPolyline(coordinates: vm.routeCoordinates)
                                    .stroke(Color.TechBlue, lineWidth: 4)
                            }

                            if let driverLoc = vm.driverLocation {
                                Annotation("Driver", coordinate: driverLoc) {
                                    ZStack {
                                        Circle()
                                            .fill(.white)
                                            .frame(width: 38, height: 38)
                                            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

                                        Image(systemName: "car.circle.fill")
                                            .font(.system(size: 34))
                                            .foregroundStyle(.blue.gradient)
                                    }
                                }
                            }

                            // Geofences
                            ForEach(vm.geofences) { geofence in
                                MapCircle(
                                    center: CLLocationCoordinate2D(latitude: geofence.latitude, longitude: geofence.longitude),
                                    radius: geofence.radius
                                )
                                .foregroundStyle(geofence.type.color.opacity(0.12))
                                .stroke(geofence.type.color, lineWidth: 2)
                            }
                        }
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .mapControls {
                            MapUserLocationButton()
                            MapCompass()
                        }

                        if vm.driverLocation != nil {
                            HStack(spacing: 8) {
                                if vm.isRouteDeviated {
                                    HStack(spacing: 4) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                        Text("ROUTE DEVIATION")
                                    }
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.red.gradient)
                                    .clipShape(Capsule())
                                    .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
                                } else {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(.white)
                                            .frame(width: 6, height: 6)
                                            .opacity(0.8)
                                        Text("LIVE")
                                            .font(.caption.weight(.bold))
                                            .tracking(1)
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.blue.gradient)
                                    .clipShape(Capsule())
                                    .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
                                }
                            }
                            .padding(16)
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    )
                }
                .padding(.vertical, 8)
                .listRowInsets(EdgeInsets())
            }
            .listRowBackground(Color.clear)

            // MARK: - Route Monitoring Controls
            if vm.trip.normalisedStatus == .inTransit || vm.trip.normalisedStatus == .inProgress {
                Section("Route Monitoring") {
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Deviation Limit")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                Text("\(Int(vm.deviationRadius)) meters")
                                    .font(.subheadline.weight(.semibold))
                            }

                            Spacer()

                            Slider(value: $vm.deviationRadius, in: 100...2000, step: 100)
                                .frame(width: 150)
                                .tint(.TechBlue)
                        }

                        if vm.isRouteDeviated {
                            Button(action: { vm.approveCurrentDeviation() }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Approve Current Shortcut/Path")
                                }
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.green.gradient)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            // MARK: - Status & Key Info
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.tripNameText)
                            .font(.headline)
                        Text(trip.trip_number ?? "No Trip Number")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    statusBadge
                }
                .padding(.vertical, 4)

                HStack(spacing: 0) {
                    TripStatItem(title: "Distance", value: String(format: "%.1f km", trip.distance_travelled ?? 0), icon: "road.lanes")
                    Divider().padding(.vertical, 8)
                    TripStatItem(title: "Duration", value: formatETA(trip.eta ?? 0), icon: "clock")
                    Divider().padding(.vertical, 8)
                    TripStatItem(title: "Stops", value: "1", icon: "mappin.and.ellipse")
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
            }

            // MARK: - Route Details
            Section("Route") {
                VStack(alignment: .leading, spacing: 0) {
                    RoutePointRow(title: "Origin", address: trip.originText, icon: "circle.fill", color: .green, isLast: false)
                    RoutePointRow(title: "Destination", address: trip.destinationText, icon: "mappin.circle.fill", color: .red, isLast: true)
                }
                .padding(.vertical, 4)
            }

            // MARK: - Schedule
            Section("Schedule") {
                LabeledContent {
                    Text(trip.formattedPickupTime)
                        .foregroundStyle(.primary)
                } label: {
                    Label("Pickup Time", systemImage: "calendar")
                }

                LabeledContent {
                    Text(trip.formattedEstimatedDate)
                        .foregroundStyle(.primary)
                } label: {
                    Label("Estimated Arrival", systemImage: "clock.badge.checkmark")
                }

                // Fuel usage — only shown once the trip is completed and data is available
                if trip.normalisedStatus == .completed,
                   let fuelUsed = vm.fullTrip?.fuel_used ?? trip.fuel_used {
                    LabeledContent {
                        Text(String(format: "%.2f L", fuelUsed))
                            .foregroundStyle(.primary)
                    } label: {
                        Label("Fuel Used", systemImage: "fuelpump.fill")
                    }
                }
            }

            // MARK: - Vehicle
            if let vehicle = vm.vehicle {
                Section("Vehicle") {
                    HStack(spacing: 12) {
                        Image(systemName: "car.fill")
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.blue.gradient)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(vehicle.name)
                                .font(.subheadline.weight(.semibold))
                            Text(vehicle.registrationNumber)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("Type", value: vehicle.vehicleType ?? "N/A")
                    LabeledContent("Fuel", value: vehicle.fuelType ?? "N/A")
                }
            }

            // MARK: - Driver
            if let driver = vm.driver {
                Section("Driver") {
                    HStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(driver.name)
                                .font(.subheadline.weight(.semibold))
                            Text("License: \(driver.licenseNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if let phone = driver.phone {
                            Button {
                                if let url = URL(string: "tel://\(phone)") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Image(systemName: "phone.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.large)
        .task {
            hasAutoFocusedVehicle = false
            await vm.loadTripDetails()
            updateCameraPosition()
            vm.startLocationPolling()
            await vm.setupRealtimeLocation()
        }
        .onDisappear {
            vm.stopLocationPolling()
        }
        .onChange(of: vm.driverLocation?.latitude) { _ in
            focusOnVehicleIfNeeded()
        }
        .onChange(of: vm.driverLocation?.longitude) { _ in
            focusOnVehicleIfNeeded()
        }
        .refreshable {
            await vm.loadTripDetails()
            await vm.refreshVehicleLocation()
        }
    }

    // MARK: - Helpers

    private func updateCameraPosition() {
        var coordinates: [CLLocationCoordinate2D] = []
        if let lat = trip.origin_latitude, let lng = trip.origin_longitude {
            coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        if let lat = trip.destination_latitude, let lng = trip.destination_longitude {
            coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        if !coordinates.isEmpty {
            cameraPosition = .automatic
        }
    }

    private func focusOnVehicleIfNeeded() {
        guard !hasAutoFocusedVehicle else { return }
        guard let loc = vm.driverLocation else { return }
        hasAutoFocusedVehicle = true
        withAnimation(.easeInOut(duration: 0.5)) {
            cameraPosition = .region(MKCoordinateRegion(
                center: loc,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))
        }
    }

    private func formatETA(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
    }

    private var statusBadge: some View {
        Text(trip.normalisedStatus.displayTitle)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch trip.normalisedStatus {
        case .inTransit:  return Color(hex: "#F59E0B")  // Amber
        case .inProgress: return Color(hex: "#3B82F6")  // Blue
        case .scheduled:  return Color(hex: "#8B5CF6")  // Purple
        case .completed:  return Color(hex: "#10B981")  // Emerald
        case .cancelled:  return Color(hex: "#EF4444")  // Red
        default:          return Color(.systemGray)
        }
    }
}

// MARK: - Subviews

struct TripStatItem: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.blue)
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RoutePointRow: View {
    let title: String
    let address: String
    let icon: String
    let color: Color
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                    .background(Circle().fill(.white))

                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2, height: 30)
                }
            }
            .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(address)
                    .font(.subheadline)
                    .lineLimit(2)
            }
            .padding(.bottom, isLast ? 0 : 16)
        }
    }
}

// MARK: - Map Pin Model
struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

#Preview {
    NavigationStack {
        FleetManagerTripDetailView(trip: Trip(
            id: UUID(),
            vehicle_id: UUID(),
            driver_id: UUID(),
            trip_name: "Mumbai to Pune",
            origin: "Mumbai, Maharashtra",
            destination: "Pune, Maharashtra",
            pickup_time: "2026-04-22T10:00:00Z",
            status: "completed",
            trip_number: "TR-001",
            distance_travelled: 150.5,
            fuel_used: 12.4,
            fleet_manager_id: UUID(),
            origin_latitude: 19.0760,
            origin_longitude: 72.8777,
            destination_latitude: 18.5204,
            destination_longitude: 73.8567,
            eta: 180.0,
            created_at: "2026-04-22T10:00:00Z"
        ))
    }
}
