import SwiftUI
import MapKit
import Supabase

struct FleetManagerTripDetailView: View {
    let trip: Trip
    
    @StateObject private var vm: TripDetailViewModel
    @State private var showingEditSheet = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629), // India center
        span: MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 5)
    )
    
    init(trip: Trip) {
        self.trip = trip
        _vm = StateObject(wrappedValue: TripDetailViewModel(trip: trip))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Map Section
                if let location = vm.driverLocation {
                    mapSection(location: location)
                } else {
                    placeholderMapSection
                }
                
                // Trip Information
                tripInfoSection
                
                // Vehicle Information
                if let vehicle = vm.vehicle {
                    vehicleInfoSection(vehicle: vehicle)
                }
                
                // Driver Information
                if let driver = vm.driver {
                    driverInfoSection(driver: driver)
                }
                
                // Route Details
                routeDetailsSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingEditSheet = true
                }) {
                    Text("Edit")
                        .font(.body.weight(.semibold))
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTripSheet(trip: trip, vm: vm)
        }
        .task {
            await vm.loadTripDetails()
        }
        .overlay {
            if vm.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.2))
            }
        }
    }
    
    // MARK: - Map Section
    private func mapSection(location: CLLocationCoordinate2D) -> some View {
        Map(coordinateRegion: .constant(MKCoordinateRegion(
            center: location,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )), annotationItems: [MapPin(coordinate: location)]) { pin in
            MapMarker(coordinate: pin.coordinate, tint: .blue)
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                Image(systemName: "location.fill")
                    .font(.caption)
                Text("Live Location")
                    .font(.caption.weight(.semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .clipShape(Capsule())
            .padding(12)
        }
    }
    
    private var placeholderMapSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(height: 250)
            
            VStack(spacing: 8) {
                Image(systemName: "map")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("Location Unavailable")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Driver location will appear here")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Trip Info Section
    private var tripInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Trip Information")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                statusBadge
            }
            
            VStack(spacing: 12) {
                infoRow(icon: "signpost.right.fill", title: "Route Name", value: trip.tripNameText)
                infoRow(icon: "calendar", title: "Pickup Time", value: trip.formattedPickupTime)
                infoRow(icon: "calendar.badge.clock", title: "Estimated Delivery", value: trip.formattedEstimatedDate)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Vehicle Info Section
    private func vehicleInfoSection(vehicle: Vehicle) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "car.fill")
                    .font(.title3)
                    .foregroundColor(.TechBlue)
                
                Text("Assigned Vehicle")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                infoRow(icon: "car.2.fill", title: "Vehicle Name", value: vehicle.name)
                infoRow(icon: "number", title: "Registration", value: vehicle.registrationNumber)
                if let brand = vehicle.brand {
                    infoRow(icon: "building.2.fill", title: "Brand", value: brand)
                }
                if let model = vehicle.model {
                    infoRow(icon: "gearshape.fill", title: "Model", value: model)
                }
                infoRow(icon: "fuelpump.fill", title: "Fuel Type", value: vehicle.fuelType ?? "N/A")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Driver Info Section
    private func driverInfoSection(driver: DriverInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.fill")
                    .font(.title3)
                    .foregroundColor(.green)
                
                Text("Assigned Driver")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 12) {
                infoRow(icon: "person.circle.fill", title: "Name", value: driver.name)
                if let phone = driver.phone {
                    HStack {
                        Image(systemName: "phone.fill")
                            .font(.body)
                            .foregroundColor(.TechBlue)
                            .frame(width: 24)
                        
                        Text("Phone")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            if let url = URL(string: "tel://\(phone)") {
                                UIApplication.shared.open(url)
                            }
                        }) {
                            Text(phone)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.TechBlue)
                        }
                    }
                }
                infoRow(icon: "creditcard.fill", title: "License", value: driver.licenseNumber)
                infoRow(icon: "calendar.badge.clock", title: "License Expiry", value: driver.licenseExpiry)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Route Details Section
    private var routeDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "map.fill")
                    .font(.title3)
                    .foregroundColor(.orange)
                
                Text("Route Details")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
            }
            
            VStack(spacing: 16) {
                // Distance and ETA (if available)
                if let distance = trip.distance_travelled {
                    HStack {
                        Image(systemName: "road.lanes")
                            .font(.body)
                            .foregroundColor(.TechBlue)
                            .frame(width: 24)
                        
                        Text("Distance")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(String(format: "%.2f km", distance))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                }
                
                if let eta = trip.eta {
                    HStack {
                        Image(systemName: "clock")
                            .font(.body)
                            .foregroundColor(.TechBlue)
                            .frame(width: 24)
                        
                        Text("Estimated Time")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(formatETA(eta))
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.primary)
                    }
                }
                
                if trip.distance_travelled != nil || trip.eta != nil {
                    Divider()
                        .padding(.vertical, 4)
                }
                
                // Origin
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "mappin.circle.fill")
                            .font(.body)
                            .foregroundColor(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Origin")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(trip.originText)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                }
                
                // Destination
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "mappin.circle.fill")
                            .font(.body)
                            .foregroundColor(.red)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Destination")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(trip.destinationText)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
    
    // MARK: - Helper Views
    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.body)
                .foregroundColor(.TechBlue)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
    
    private func formatETA(_ minutes: Double) -> String {
        let hours = Int(minutes) / 60
        let mins = Int(minutes) % 60
        
        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }
    
    private var statusBadge: some View {
        Text(trip.normalisedStatus.displayTitle)
            .font(.caption.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusColor)
            .clipShape(Capsule())
    }
    
    private var statusColor: Color {
        switch trip.normalisedStatus {
        case .inTransit:
            return Color.orange
        case .inProgress:
            return Color.green
        case .scheduled:
            return Color.blue
        case .completed:
            return Color.green
        case .cancelled:
            return Color.red
        default:
            return Color.gray
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
            eta: 180.0
        ))
    }
}
