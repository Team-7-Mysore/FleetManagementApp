import SwiftUI
import CoreLocation

struct CreateTripView: View {
    let fleetManagerId: UUID?
    
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm = TripViewModel()
    
    @State private var tripName = ""
    @State private var clientContact = ""
    @State private var origin = ""
    @State private var destination = ""
    @State private var originCoordinate: CLLocationCoordinate2D?
    @State private var destinationCoordinate: CLLocationCoordinate2D?
    @State private var viaPointInput = ""
    @State private var viaPoints: [String] = []
    @State private var pickupDate = Date()
    @State private var expectedEndDate = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
    @State private var selectedVehicleID: UUID?
    @State private var selectedDriverID: UUID?
    @State private var activeLocationField: LocationField?
    
    // IST calendar & timezone for display
    private static let istTimeZone = TimeZone(identifier: "Asia/Kolkata")!
    private static var istCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = istTimeZone
        return cal
    }()
    
    var body: some View {
        Form {
            
            Section(header: Text("Trip Info")) {
                TextField("Route Name", text: $tripName)
                TextField("Client Contact", text: $clientContact)
            }
            
            Section(header: Text("Route Points")) {
                locationSelectionRow(title: "Origin / Pickup Location", value: origin) {
                    activeLocationField = .origin
                }
                
                locationSelectionRow(title: "Destination", value: destination) {
                    activeLocationField = .destination
                }
                
                HStack {
                    TextField("Add Via Point", text: $viaPointInput)
                    Button("Add") {
                        if !viaPointInput.isEmpty {
                            viaPoints.append(viaPointInput)
                            viaPointInput = ""
                        }
                    }
                }
                
                ForEach(viaPoints, id: \.self) { point in
                    Text(point)
                }
            }
            
            // Distance and ETA Section
            if !origin.isEmpty && !destination.isEmpty {
                Section(header: Text("Route Information")) {
                    if vm.isCalculatingRoute {
                        HStack {
                            ProgressView()
                                .tint(Color.TechBlue)
                            Text("Calculating route...")
                                .foregroundStyle(.secondary)
                        }
                    } else if let distance = vm.calculatedDistance, let eta = vm.calculatedETA {
                        HStack {
                            Image(systemName: "road.lanes")
                                .foregroundColor(Color.TechBlue)
                            Text("Distance")
                            Spacer()
                            Text(String(format: "%.2f km", distance))
                                .fontWeight(.semibold)
                                .foregroundColor(Color.TechBlue)
                        }
                        
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(Color.TechBlue)
                            Text("Estimated Time")
                            Spacer()
                            Text(formatETA(eta))
                                .fontWeight(.semibold)
                                .foregroundColor(Color.TechBlue)
                        }
                    } else {
                        Button {
                            Task {
                                await vm.calculateRoute(from: origin, to: destination)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "arrow.triangle.turn.up.right.diamond")
                                    .foregroundColor(Color.TechBlue)
                                Text("Calculate Route")
                                    .foregroundColor(Color.TechBlue)
                            }
                        }
                    }
                }
            }
            
            Section(header: Text("Schedule (IST)")) {
                // DatePicker binds to a Date (always UTC internally).
                // We display it in IST by setting the environment timezone.
                DatePicker(
                    "Pickup Date & Time (IST)",
                    selection: $pickupDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .environment(\.timeZone, Self.istTimeZone)
                
                DatePicker(
                    "Expected End Time (IST)",
                    selection: $expectedEndDate,
                    in: pickupDate...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .environment(\.timeZone, Self.istTimeZone)
                
                // Human-readable confirmation in IST
                VStack(alignment: .leading, spacing: 4) {
                    Label("Pickup:  \(istString(pickupDate))",     systemImage: "clock")
                    Label("End:       \(istString(expectedEndDate))", systemImage: "clock.badge.checkmark")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            Section(header: Text("Assignment")) {
                Button {
                    selectedVehicleID = nil
                    selectedDriverID  = nil
                    Task {
                        await vm.loadAssignmentOptions(
                            pickupLocation: origin,
                            pickupDate: pickupDate,
                            expectedEndDate: expectedEndDate
                        )
                    }
                } label: {
                    if vm.isLoadingAssignments {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Checking availability...")
                        }
                    } else {
                        Text("Find Available Vehicle & Driver")
                    }
                }
                
                if !vm.availableVehicles.isEmpty {
                    Picker("Vehicle", selection: $selectedVehicleID) {
                        Text("Select Vehicle").tag(UUID?.none)
                        ForEach(vm.availableVehicles) { vehicle in
                            Text(
                                vehicle.subtitle.isEmpty
                                ? vehicle.displayName
                                : "\(vehicle.displayName) • \(vehicle.subtitle)"
                            )
                            .tag(Optional(vehicle.id))
                        }
                    }
                }
                
                if !vm.availableDrivers.isEmpty {
                    Picker("Driver", selection: $selectedDriverID) {
                        Text("Select Driver").tag(UUID?.none)
                        ForEach(vm.availableDrivers) { driver in
                            Text("\(driver.name) • \(driver.subtitle)")
                                .tag(Optional(driver.id))
                        }
                    }
                }
                
                if !vm.isLoadingAssignments && vm.availableVehicles.isEmpty && vm.availableDrivers.isEmpty {
                    Text("Choose route and schedule, then load the available vehicle and driver options.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            
            if vm.isLoading { ProgressView() }
            
            if let success = vm.successMessage {
                Text(success).foregroundColor(.green)
            }
            
            if let error = vm.errorMessage {
                Text(error).foregroundColor(.red)
            }
        }
        .navigationTitle("Create Trip")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: pickupDate) { _, newValue in
            if expectedEndDate <= newValue {
                expectedEndDate = Calendar.current.date(byAdding: .hour, value: 4, to: newValue) ?? newValue
            }
            clearAssignments()
        }
        .onChange(of: expectedEndDate) { _, _ in clearAssignments() }
        .onChange(of: origin)          { _, newValue in
            clearAssignments()
            if !newValue.isEmpty && !destination.isEmpty {
                Task {
                    await vm.calculateRoute(from: newValue, to: destination)
                }
            } else {
                // If origin changed but we have coordinates from map picker, store them
                if let coord = originCoordinate {
                    vm.originCoordinates = coord
                }
            }
        }
        .onChange(of: destination)     { _, newValue in
            clearAssignments()
            if !origin.isEmpty && !newValue.isEmpty {
                Task {
                    await vm.calculateRoute(from: origin, to: newValue)
                }
            } else {
                // If destination changed but we have coordinates from map picker, store them
                if let coord = destinationCoordinate {
                    vm.destinationCoordinates = coord
                }
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
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task {
                        // Dates are already in UTC internally — TripViewModel sends
                        // them via ISO8601DateFormatter which always emits UTC strings,
                        // which is exactly what Supabase expects.
                        await vm.createTrip(
                            tripName: tripName,
                            clientContact: clientContact,
                            origin: origin,
                            destination: destination,
                            viaPoints: viaPoints,
                            pickupDate: pickupDate,
                            expectedEndDate: expectedEndDate,
                            vehicleID: selectedVehicleID,
                            driverID: selectedDriverID,
                            distance: vm.calculatedDistance,
                            fleetManagerId: fleetManagerId
                        )
                        if vm.errorMessage == nil { dismiss() }
                    }
                }
                .disabled(vm.isLoading || vm.isLoadingAssignments)
            }
        }
    }
    
    // MARK: - Helpers
    
    /// Format ETA in hours and minutes
    private func formatETA(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Format a UTC Date for display in IST.
    private func istString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM yyyy, hh:mm a"
        fmt.timeZone   = Self.istTimeZone
        fmt.locale     = Locale(identifier: "en_IN")
        return fmt.string(from: date)
    }
    
    private func clearAssignments() {
        selectedVehicleID = nil
        selectedDriverID  = nil
        vm.resetAssignmentOptions()
    }
    
    private func locationSelectionRow(
        title: String,
        value: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.body.weight(.semibold))
                    .foregroundColor(Color.TechBlue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(value.isEmpty ? "Tap to choose on map" : value)
                        .font(.body)
                        .foregroundStyle(value.isEmpty ? .secondary : .primary)
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
}

// MARK: - TripViewModel IST-aware date decoder extension
// Drop this anywhere in your project (or keep it here).
// Use this decoder whenever you fetch trips from Supabase so that
// timestamps stored as UTC strings are correctly converted to Date.
extension JSONDecoder {
    /// Returns a decoder that handles the timestamp formats Supabase uses,
    /// converting them from UTC to the system's local time (IST on Indian devices).
    static var supabaseDateDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self)
            
            // 1. ISO 8601 with fractional seconds (Supabase default)
            let isoFull = ISO8601DateFormatter()
            isoFull.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = isoFull.date(from: raw) { return date }
            
            // 2. ISO 8601 without fractional seconds
            let isoBasic = ISO8601DateFormatter()
            isoBasic.formatOptions = [.withInternetDateTime]
            if let date = isoBasic.date(from: raw) { return date }
            
            // 3. Plain timestamp without timezone offset (Supabase sometimes omits Z)
            //    Treat as UTC explicitly.
            let fmt = DateFormatter()
            fmt.locale   = Locale(identifier: "en_US_POSIX")
            fmt.timeZone = TimeZone(secondsFromGMT: 0) // UTC
            for format in [
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd'T'HH:mm:ssZ",
                "yyyy-MM-dd HH:mm:ss",
                "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            ] {
                fmt.dateFormat = format
                if let date = fmt.date(from: raw) { return date }
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date from: \(raw)"
            )
        }
        return decoder
    }
}

private enum LocationField: String, Identifiable {
    case origin
    case destination
    var id: String { rawValue }
}
