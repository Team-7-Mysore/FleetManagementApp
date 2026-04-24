import SwiftUI
import MapKit
import Supabase

struct FleetManagerTripDetailView: View {
    let trip: Trip
    
    @StateObject private var vm: TripDetailViewModel
    @State private var showingEditSheet = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    
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
            }
            
            // MARK: - Vehicle
            if let vehicle = vm.vehicle {
                Section("Vehicle") {
                    NavigationLink {
                        // Potential navigation to vehicle detail
                    } label: {
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
                            
                            Button {
                                // Message driver
                            } label: {
                                Image(systemName: "message.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
                .fontWeight(.semibold)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTripSheet(trip: trip, vm: vm)
        }
        .task {
            await vm.loadTripDetails()
            updateCameraPosition()
            vm.startLocationPolling()
        }
        .onDisappear {
            vm.stopLocationPolling()
        }
        .onChange(of: vm.driverLocation?.latitude) { _ in
            if let loc = vm.driverLocation {
                withAnimation(.easeInOut(duration: 0.5)) {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: loc,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))
                }
            }
        }
        .refreshable {
            await vm.loadTripDetails()
            await vm.refreshVehicleLocation()
        }
    }
    
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
        case .inTransit: return .orange
        case .inProgress: return .blue
        case .scheduled: return .purple
        case .completed: return .green
        case .cancelled: return .red
        default: return .secondary
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

// MARK: - Edit Trip Sheet
struct EditTripSheet: View {
    let trip: Trip
    @ObservedObject var vm: TripDetailViewModel
    
    @Environment(\.dismiss) private var dismiss
    @State private var tripName: String
    @State private var origin: String
    @State private var destination: String
    @State private var originCoordinate: CLLocationCoordinate2D?
    @State private var destinationCoordinate: CLLocationCoordinate2D?
    @State private var status: String
    @State private var isUpdating = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var activeLocationField: EditLocationField?
    
    init(trip: Trip, vm: TripDetailViewModel) {
        self.trip = trip
        self.vm = vm
        _tripName = State(initialValue: trip.trip_name ?? "")
        _origin = State(initialValue: trip.origin ?? "")
        _destination = State(initialValue: trip.destination ?? "")
        _status = State(initialValue: trip.status ?? "assigned")
        
        // Initialize coordinates if available
        if let lat = trip.origin_latitude, let lon = trip.origin_longitude {
            _originCoordinate = State(initialValue: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        if let lat = trip.destination_latitude, let lon = trip.destination_longitude {
            _destinationCoordinate = State(initialValue: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Information") {
                    TextField("Route Name", text: $tripName)
                        .textInputAutocapitalization(.words)
                    
                    Picker("Status", selection: $status) {
                        Text("Assigned").tag("assigned")
                        Text("In Progress").tag("in_progress")
                        Text("In Transit").tag("in_transit")
                        Text("Completed").tag("completed")
                        Text("Cancelled").tag("cancelled")
                    }
                }
                
                Section("Route") {
                    Button(action: {
                        activeLocationField = .origin
                    }) {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Origin / Pickup Location")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(origin.isEmpty ? "Tap to choose on map" : origin)
                                    .font(.body)
                                    .foregroundStyle(origin.isEmpty ? .secondary : .primary)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        activeLocationField = .destination
                    }) {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Destination")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(destination.isEmpty ? "Tap to choose on map" : destination)
                                    .font(.body)
                                    .foregroundStyle(destination.isEmpty ? .secondary : .primary)
                                    .multilineTextAlignment(.leading)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                if let vehicle = vm.vehicle {
                    Section("Assigned Vehicle") {
                        HStack {
                            Text("Vehicle")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(vehicle.name)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                if let driver = vm.driver {
                    Section("Assigned Driver") {
                        HStack {
                            Text("Driver")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(driver.name)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                if let success = successMessage {
                    Section {
                        Text(success)
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await updateTrip()
                        }
                    }
                    .disabled(isUpdating || tripName.isEmpty || origin.isEmpty || destination.isEmpty)
                }
            }
            .sheet(item: $activeLocationField) { field in
                switch field {
                case .origin:
                    LocationPickerView(
                        selectedAddress: $origin,
                        selectedCoordinate: $originCoordinate,
                        title: "Select Pickup Location"
                    )
                case .destination:
                    LocationPickerView(
                        selectedAddress: $destination,
                        selectedCoordinate: $destinationCoordinate,
                        title: "Select Destination"
                    )
                }
            }
            .overlay {
                if isUpdating {
                    ProgressView()
                        .scaleEffect(1.5)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.2))
                }
            }
        }
    }
    
    private func updateTrip() async {
        isUpdating = true
        errorMessage = nil
        successMessage = nil
        
        do {
            struct TripUpdate: Encodable {
                let trip_name: String
                let origin: String
                let destination: String
                let start_location: String
                let end_location: String
                let status: String
                let origin_latitude: Double?
                let origin_longitude: Double?
                let destination_latitude: Double?
                let destination_longitude: Double?
            }
            
            let updateData = TripUpdate(
                trip_name: tripName,
                origin: origin,
                destination: destination,
                start_location: origin,
                end_location: destination,
                status: status,
                origin_latitude: originCoordinate?.latitude,
                origin_longitude: originCoordinate?.longitude,
                destination_latitude: destinationCoordinate?.latitude,
                destination_longitude: destinationCoordinate?.longitude
            )
            
            try await SupabaseManager.shared.client
                .from("trips")
                .update(updateData)
                .eq("trip_id", value: trip.id)
                .execute()
            
            successMessage = "Trip updated successfully!"
            
            // Wait a moment to show success message
            try? await Task.sleep(for: .seconds(1))
            
            isUpdating = false
            dismiss()
            
            // Reload trip details
            await vm.loadTripDetails()
            
        } catch {
            errorMessage = "Failed to update trip: \(error.localizedDescription)"
            isUpdating = false
        }
    }
}

private enum EditLocationField: String, Identifiable {
    case origin
    case destination
    var id: String { rawValue }
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
            status: "in_progress",
            trip_number: "TR-001",
            distance_travelled: 150.5,
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
