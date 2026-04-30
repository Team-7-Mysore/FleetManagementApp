import SwiftUI
import MapKit
import CoreLocation
import Supabase
internal import PostgREST
// MARK: - CreateTripView

struct CreateTripView: View {
    let fleetManagerId: UUID?

    @Environment(\.dismiss) var dismiss
    @StateObject private var vm = TripViewModel()
    @StateObject private var geofenceVM = GeofenceViewModel()

    // Form state
    @State private var tripName = ""
    @State private var clientContact = ""
    @State private var origin = ""
    @State private var destination = ""
    @State private var originCoordinate: CLLocationCoordinate2D?
    @State private var destinationCoordinate: CLLocationCoordinate2D?
    @State private var viaPoints: [String] = []
    @State private var viaCoordinates: [CLLocationCoordinate2D?] = []
    @State private var pickupDate: Date?
    @State private var expectedEndDate: Date?
    @State private var pickupDateDraft = Date()
    @State private var expectedEndDateDraft = Date()
    @State private var selectedVehicleID: UUID?
    @State private var selectedDriverID: UUID?
    @State private var showVehicleOptions = false
    @State private var showDriverOptions = false
    @State private var showPickupPicker = false
    @State private var showEndPicker = false

    // Delivery zone (geofence) — optional, never touches trips table
    @State private var enableDeliveryZone = false
    @State private var deliveryZoneRadius: Double = 300
    
    // Route Monitoring (deviation) - local session control
    @State private var enableRouteMonitoring = true
    @State private var routeMonitoringRadius: Double = 500

    // UI state
    @State private var activeLocationField: LocationField?
    @State private var routePolyline: MKPolyline?
    @State private var mapCameraPosition: MapCameraPosition = .automatic
    @FocusState private var focusedField: FormField?

    // Temporary bindings for via point picker
    @State private var pendingViaAddress = ""
    @State private var pendingViaCoordinate: CLLocationCoordinate2D?

    // Validation state
    @State private var tripNameWarning: String? = nil      // validation 9: duplicate name warning
    @State private var driverLicenseWarning: String? = nil // validation 10: license expiry warning

    private enum FormField { case tripName, clientContact }
    private static let istTimeZone = TimeZone(identifier: "Asia/Kolkata")!

    // MARK: - Validation

    /// All hard-block validation errors. Save is disabled when this is non-empty.
    private var validationErrors: [String] {
        var errors: [String] = []

        // 4. Trip name minimum 3 characters
        let trimmedName = tripName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty && trimmedName.count < 3 {
            errors.append("Trip name must be at least 3 characters")
        }

        // 3. Valid Indian mobile number (10 digits, starts with 6–9)
        if !clientContact.isEmpty {
            if clientContact.count == 10, let first = clientContact.first {
                let validStarts: Set<Character> = ["6", "7", "8", "9"]
                if !validStarts.contains(first) {
                    errors.append("Enter a valid 10-digit mobile number")
                }
            }
        }

        // 1. Origin ≠ Destination
        if !origin.isEmpty && !destination.isEmpty &&
           origin.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ==
           destination.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            errors.append("Origin and destination cannot be the same location")
        }

        // 2. Pickup at least 15 minutes from now
        if let pickupDate, pickupDate < Date().addingTimeInterval(15 * 60) {
            errors.append("Pickup time must be at least 15 minutes from now")
        }

        // 5. Minimum trip duration 30 minutes
        if let pickupDate, let expectedEndDate,
           expectedEndDate.timeIntervalSince(pickupDate) < 30 * 60 {
            errors.append("Trip duration must be at least 30 minutes")
        }

        // 6. Route must be calculated (coordinates resolved)
        if !origin.isEmpty && !destination.isEmpty {
            if originCoordinate == nil || destinationCoordinate == nil || vm.calculatedDistance == nil {
                errors.append("Route not calculated — set locations and wait for route to load")
            }
        }

        // 7. Selected vehicle still exists in the loaded list
        if let vid = selectedVehicleID,
           !vm.availableVehicles.isEmpty,
           !vm.availableVehicles.contains(where: { $0.vehicle_id == vid }) {
            errors.append("Selected vehicle is no longer available — please refresh")
        }

        // 8. Via points must all have resolved coordinates
        for (i, coord) in viaCoordinates.enumerated() {
            if coord == nil {
                errors.append("Via point \(i + 1) could not be located on the map")
            }
        }

        // 11. Maximum 5 via points
        if viaPoints.count > 5 {
            errors.append("Maximum 5 via points allowed")
        }

        return errors
    }

    private var canSave: Bool {
        let trimmedName = tripName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.count >= 3 &&
               clientContact.count == 10 &&
               !origin.isEmpty &&
               !destination.isEmpty &&
               selectedVehicleID != nil &&
               selectedDriverID != nil &&
               validationErrors.isEmpty
    }

    /// Check for a duplicate trip name on the same date (soft warning, doesn't block save)
    private func checkDuplicateTripName() async {
        let trimmed = tripName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { tripNameWarning = nil; return }

        do {
        guard let pickupDate else {
            tripNameWarning = nil
            return
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: pickupDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            formatter.timeZone = TimeZone(identifier: "UTC")

            let existing: [Trip] = try await SupabaseManager.shared.client
                .from("trips")
                .select("trip_id, trip_name, pickup_time")
                .ilike("trip_name", value: trimmed)
                .gte("pickup_time", value: formatter.string(from: startOfDay))
                .lt("pickup_time", value: formatter.string(from: endOfDay))
                .execute()
                .value

            tripNameWarning = existing.isEmpty ? nil :
                "A trip named '\(trimmed)' already exists on this date"
        } catch {
            tripNameWarning = nil
        }
    }

    /// Check if the selected driver's license expires before the trip ends (soft warning)
    private func checkDriverLicenseExpiry() {
        guard let driverId = selectedDriverID,
              let driver = vm.availableDrivers.first(where: { $0.id == driverId }) else {
            driverLicenseWarning = nil
            return
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        guard let expiryDate = formatter.date(from: driver.licenseExpiry) else {
            driverLicenseWarning = nil
            return
        }

        guard let expectedEndDate else {
            driverLicenseWarning = nil
            return
        }

        if expiryDate < expectedEndDate {
            let display = DateFormatter()
            display.dateStyle = .medium
            driverLicenseWarning = "Driver's license expires \(display.string(from: expiryDate)) — before trip ends"
        } else {
            driverLicenseWarning = nil
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 0) {
                        mapPreview
                        contentStack
                    }
                }
            }
            .navigationTitle("Create Trip")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await saveAll() }
                    } label: {
                        if vm.isLoading || geofenceVM.isLoading {
                            ProgressView()
                        } else {
                            Text("Save").font(.body.weight(.semibold))
                        }
                    }
                    .disabled(!canSave || vm.isLoading || geofenceVM.isLoading)
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
                case .via:
                    LocationPickerView(
                        selectedAddress: $pendingViaAddress,
                        selectedCoordinate: $pendingViaCoordinate,
                        title: "Select Via Point"
                    )
                }
            }
            .onChange(of: activeLocationField) { old, new in
                // When via picker is dismissed (field becomes nil), commit the result
                if old == .via, new == nil, !pendingViaAddress.isEmpty {
                    viaPoints.append(pendingViaAddress)
                    viaCoordinates.append(pendingViaCoordinate)
                    pendingViaAddress = ""
                    pendingViaCoordinate = nil
                    clearAssignments()
                    triggerRoute()
                }
            }
            .onChange(of: origin)      { _, _ in clearAssignments(); triggerRoute() }
            .onChange(of: destination) { _, _ in clearAssignments(); triggerRoute() }
            .onChange(of: pickupDate) { _, newPickup in
                if let newPickup {
                    updateProjectedEndTime(newPickup: newPickup)
                    autoRefreshAssignments()
                }
            }
            .onChange(of: vm.calculatedETA) { _, _ in
                updateProjectedEndTime()
                autoRefreshAssignments()
            }
            .onChange(of: expectedEndDate) { _, newValue in
                if newValue != nil {
                    autoRefreshAssignments()
                }
            }
            .onChange(of: vm.isCalculatingRoute) { _, isCalculating in
                if !isCalculating,
                   let o = vm.originCoordinates,
                   let d = vm.destinationCoordinates {
                    Task { await fetchPolyline(from: o, waypoints: resolvedViaCoordinates, to: d) }
                }
            }
            .onChange(of: clientContact) { _, newValue in
                // Only allow numbers and max 10 characters
                let filtered = newValue.filter { $0.isNumber }
                if filtered.count > 10 {
                    clientContact = String(filtered.prefix(10))
                } else {
                    clientContact = filtered
                }
            }
            // Validation 9: check duplicate trip name when name or date changes
            .onChange(of: tripName) { _, _ in
                Task { await checkDuplicateTripName() }
            }
            .onChange(of: pickupDate) { _, _ in
                Task { await checkDuplicateTripName() }
            }
            // Validation 10: check driver license expiry when driver or end date changes
            .onChange(of: selectedDriverID) { _, _ in
                checkDriverLicenseExpiry()
            }
            .onChange(of: expectedEndDate) { _, _ in
                checkDriverLicenseExpiry()
            }
        }
    }

    // MARK: - Map Preview

    private var mapPreview: some View {
        ZStack(alignment: .bottom) {
            Map(position: $mapCameraPosition) {
                if let polyline = routePolyline {
                    MapPolyline(polyline)
                        .stroke(Color.TechBlue, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                }

                if let o = originCoordinate {
                    Annotation("", coordinate: o) {
                        ZStack {
                            Circle().fill(.green).frame(width: 18, height: 18)
                                .overlay(Circle().stroke(.white, lineWidth: 2.5))
                            Circle().fill(.white).frame(width: 7, height: 7)
                        }
                    }
                    
                    // Always show 3km geofence for source
                    MapCircle(center: o, radius: 3000)
                        .foregroundStyle(Color.green.opacity(0.1))
                        .stroke(Color.green, lineWidth: 1.5)
                }

                ForEach(resolvedViaCoordinates.indices, id: \.self) { i in
                    Annotation("", coordinate: resolvedViaCoordinates[i]) {
                        ZStack {
                            Circle().fill(Color.orange).frame(width: 14, height: 14)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                            Text("\(i + 1)")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }

                if let d = destinationCoordinate {
                    Annotation("", coordinate: d) {
                        ZStack {
                            Circle().fill(.red).frame(width: 18, height: 18)
                                .overlay(Circle().stroke(.white, lineWidth: 2.5))
                            Image(systemName: "flag.fill")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // Destination geofence circle - always visible if destination set
                    // If enableDeliveryZone is false, we show a preview circle
                    MapCircle(center: d, radius: deliveryZoneRadius)
                        .foregroundStyle(Color.TechBlue.opacity(enableDeliveryZone ? 0.12 : 0.05))
                        .stroke(Color.TechBlue.opacity(enableDeliveryZone ? 1.0 : 0.3), lineWidth: enableDeliveryZone ? 2 : 1)
                }

                // Additional via point circles if enabled
                if enableDeliveryZone {
                    ForEach(resolvedViaCoordinates.indices, id: \.self) { i in
                        MapCircle(center: resolvedViaCoordinates[i], radius: deliveryZoneRadius)
                            .foregroundStyle(Color.TechBlue.opacity(0.12))
                            .stroke(Color.TechBlue, lineWidth: 2)
                    }
                }
            }
            .frame(height: UIScreen.main.bounds.height * 0.42)
            .mapControls {
                MapScaleView()
                MapCompass()
            }

            if let distance = vm.calculatedDistance, let eta = vm.calculatedETA {
                routeInfoStrip(distance: distance, eta: eta)
            } else if vm.isCalculatingRoute {
                calculatingStrip
            }
        }
    }

    private var resolvedViaCoordinates: [CLLocationCoordinate2D] {
        viaCoordinates.compactMap { $0 }
    }

    private func routeInfoStrip(distance: Double, eta: TimeInterval) -> some View {
        HStack(spacing: 0) {
            routeStatCell(icon: "road.lanes", value: String(format: "%.1f km", distance), label: "Distance")
            Divider().frame(height: 28)
            routeStatCell(icon: "clock", value: formatETA(eta), label: "ETA")
            Divider().frame(height: 28)
            routeStatCell(icon: "mappin.and.ellipse", value: "\(viaPoints.count)", label: "Stops")
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private var calculatingStrip: some View {
        HStack(spacing: 8) {
            ProgressView().scaleEffect(0.8)
            Text("Calculating route…").font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private func routeStatCell(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.caption).foregroundColor(.TechBlue)
                Text(value).font(.subheadline.weight(.semibold))
            }
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Content Stack

    private var contentStack: some View {
        VStack(spacing: 20) {
            tripInfoSection
            routeSection
            scheduleSection
            assignmentSection
            deliveryZoneSection
            routeMonitoringSection

            // Soft warnings (don't block save)
            if let warning = tripNameWarning {
                warningBanner(warning, icon: "exclamationmark.triangle")
            }
            if let warning = driverLicenseWarning {
                warningBanner(warning, icon: "creditcard.trianglebadge.exclamationmark")
            }

            // Hard validation errors (block save)
            if !validationErrors.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(validationErrors, id: \.self) { error in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.top, 1)
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal)
            }

            // Legacy error from ViewModel
            if let error = vm.errorMessage ?? geofenceVM.errorMessage {
                Text(error)
                    .font(.footnote).foregroundColor(.red)
                    .padding(.horizontal)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Color.clear.frame(height: 20)
        }
        .padding(.top, 20)
    }

    private func warningBanner(_ message: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .font(.caption)
                .padding(.top, 1)
            Text(message)
                .font(.footnote)
                .foregroundColor(.orange)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

    // MARK: - Trip Info Section

    private var tripInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Trip Info", icon: "doc.text")
            VStack(spacing: 0) {
                inputRow(icon: "tag", placeholder: "Route Name", text: $tripName, field: .tripName)
                Divider().padding(.leading, 44)
                inputRow(icon: "person.crop.circle", placeholder: "Client Contact (10 digits)", text: $clientContact, field: .clientContact)
                    .keyboardType(.phonePad)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal)
    }

    // MARK: - Route Section

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Route", icon: "map")

            VStack(spacing: 0) {
                // Origin
                locationRow(icon: "circle.fill", iconColor: .green,
                            label: "Pickup / Origin", value: origin) {
                    activeLocationField = .origin
                }

                routeConnector

                // Via points
                ForEach(viaPoints.indices, id: \.self) { i in
                    viaRow(index: i)
                    routeConnector
                }

                // Destination
                locationRow(icon: "mappin.circle.fill", iconColor: .red,
                            label: "Destination", value: destination) {
                    activeLocationField = .destination
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Add via point button
            Button {
                pendingViaAddress = ""
                pendingViaCoordinate = nil
                activeLocationField = .via
            } label: {
                Label("Add Via Point", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundColor(viaPoints.count >= 5 ? .secondary : .TechBlue)
            }
            .padding(.leading, 4)
            .disabled(viaPoints.count >= 5)
        }
        .padding(.horizontal)
    }

    private func viaRow(index: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.orange).frame(width: 22, height: 22)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                Text("\(index + 1)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("Via \(index + 1)")
                    .font(.caption).foregroundStyle(.secondary)
                Text(viaPoints[index])
                    .font(.subheadline).foregroundColor(.primary)
                    .lineLimit(2)
            }

            Spacer()

            // Re-pick button
            Button {
                pendingViaAddress = viaPoints[index]
                pendingViaCoordinate = viaCoordinates.indices.contains(index) ? viaCoordinates[index] : nil
                // We'll replace on dismiss
                activeLocationField = .via
                // Remove old entry so onChange can re-insert
                viaPoints.remove(at: index)
                if viaCoordinates.indices.contains(index) {
                    viaCoordinates.remove(at: index)
                }
            } label: {
                Image(systemName: "pencil.circle")
                    .foregroundColor(.TechBlue)
            }

            Button {
                viaPoints.remove(at: index)
                if viaCoordinates.indices.contains(index) {
                    viaCoordinates.remove(at: index)
                }
                clearAssignments()
                triggerRoute()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var routeConnector: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(width: 1.5, height: 18)
                .padding(.leading, 35)
            Spacer()
        }
    }

    private func locationRow(icon: String, iconColor: Color, label: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.body).foregroundColor(iconColor).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.caption).foregroundStyle(.secondary)
                    Text(value.isEmpty ? "Tap to select on map" : value)
                        .font(.subheadline)
                        .foregroundColor(value.isEmpty ? .secondary : .primary)
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Schedule", icon: "calendar")
            VStack(spacing: 0) {
                Button {
                    pickupDateDraft = pickupDate ?? Date()
                    showPickupPicker = true
                } label: {
                    scheduleRow(title: "Pickup (IST)", value: pickupDate)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 16)
                Button {
                    expectedEndDateDraft = expectedEndDate ?? pickupDateDraft
                    showEndPicker = true
                } label: {
                    scheduleRow(title: "End (IST)", value: expectedEndDate)
                }
                .buttonStyle(.plain)
                .disabled(pickupDate == nil)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal)
        .sheet(isPresented: $showPickupPicker) {
            NavigationStack {
                VStack {
                    DatePicker(
                        "Pickup (IST)",
                        selection: $pickupDateDraft,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .environment(\.timeZone, Self.istTimeZone)
                    .datePickerStyle(.graphical)
                    .padding()
                }
                .navigationTitle("Pickup (IST)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showPickupPicker = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            pickupDate = pickupDateDraft
                            updateProjectedEndTime(newPickup: pickupDateDraft)
                            showPickupPicker = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showEndPicker) {
            NavigationStack {
                VStack {
                    DatePicker(
                        "End (IST)",
                        selection: $expectedEndDateDraft,
                        in: (pickupDate ?? Date())...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .environment(\.timeZone, Self.istTimeZone)
                    .datePickerStyle(.graphical)
                    .padding()
                }
                .navigationTitle("End (IST)")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showEndPicker = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            expectedEndDate = expectedEndDateDraft
                            showEndPicker = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - Assignment Section

    private var assignmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Assignment", icon: "person.badge.key")

            Button {
                selectedVehicleID = nil
                selectedDriverID = nil
                Task {
                    guard let pickupDate, let expectedEndDate else {
                        vm.errorMessage = "Select pickup and end times."
                        return
                    }
                    await vm.loadAssignmentOptions(
                        pickupLocation: origin,
                        destination: destination,
                        pickupDate: pickupDate,
                        expectedEndDate: expectedEndDate
                    )
                }
            } label: {
                HStack {
                    if vm.isLoadingAssignments {
                        ProgressView().scaleEffect(0.85)
                        Text("Checking availability…").font(.subheadline)
                    } else {
                        Image(systemName: "arrow.clockwise.circle.fill").foregroundColor(.TechBlue)
                        Text("Find Available Vehicle & Driver")
                            .font(.subheadline.weight(.semibold)).foregroundColor(.TechBlue)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(vm.isLoadingAssignments || origin.isEmpty || destination.isEmpty || pickupDate == nil || expectedEndDate == nil)

            if !vm.availableVehicles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vehicles").font(.caption).foregroundStyle(.secondary).padding(.leading, 4)
                    DisclosureGroup(isExpanded: $showVehicleOptions) {
                        VStack(spacing: 10) {
                            ForEach(vm.availableVehicles) { v in
                                assignmentCard(title: v.displayName, subtitle: v.subtitle, icon: "car.fill",
                                               isSelected: selectedVehicleID == v.id) {
                                    var transaction = Transaction()
                                    transaction.animation = nil
                                    withTransaction(transaction) {
                                        selectedVehicleID = v.id
                                        showVehicleOptions = false
                                    }
                                }
                                .animation(nil, value: selectedVehicleID)
                            }
                        }
                        .padding(.top, 8)
                        .transaction { $0.animation = nil }
                    } label: {
                        HStack(spacing: 8) {
                            Text(selectedVehicleID.flatMap { id in
                                vm.availableVehicles.first(where: { $0.id == id })?.displayName
                            } ?? "Select Vehicle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(showVehicleOptions ? 180 : 0))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .animation(.easeInOut(duration: 0.2), value: showVehicleOptions)
                }
            }

            if !vm.availableDrivers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Drivers").font(.caption).foregroundStyle(.secondary).padding(.leading, 4)
                    DisclosureGroup(isExpanded: $showDriverOptions) {
                        VStack(spacing: 10) {
                            ForEach(vm.availableDrivers) { d in
                                assignmentCard(title: d.name, subtitle: d.subtitle, icon: "",
                                               isSelected: selectedDriverID == d.id,
                                               isRecommended: d.isRecommended) {
                                    var transaction = Transaction()
                                    transaction.animation = nil
                                    withTransaction(transaction) {
                                        selectedDriverID = d.id
                                        showDriverOptions = false
                                    }
                                }
                                .animation(nil, value: selectedDriverID)
                            }
                        }
                        .padding(.top, 8)
                        .transaction { $0.animation = nil }
                    } label: {
                        HStack(spacing: 8) {
                            Text(selectedDriverID.flatMap { id in
                                vm.availableDrivers.first(where: { $0.id == id })?.name
                            } ?? "Select Driver")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .rotationEffect(.degrees(showDriverOptions ? 180 : 0))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .animation(.easeInOut(duration: 0.2), value: showDriverOptions)
                }
            }

            if !vm.isLoadingAssignments && vm.availableVehicles.isEmpty && vm.availableDrivers.isEmpty && !origin.isEmpty {
                Text("Set route and schedule, then tap Find Available.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
        }
        .padding(.horizontal)
    }

    private func assignmentCard(title: String, subtitle: String, icon: String, isSelected: Bool, isRecommended: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if !icon.isEmpty {
                        Image(systemName: icon).font(.caption.weight(.semibold))
                            .foregroundColor(isSelected ? .white : .TechBlue)
                    }
                    Text(title).font(.subheadline.weight(.semibold))
                        .foregroundColor(isSelected ? .white : .primary).lineLimit(1)
                    Spacer(minLength: 6)
                    if isRecommended {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption.weight(.semibold))
                            Text("Recommended")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundColor(isSelected ? .white : .TechBlue)
                        .accessibilityLabel("Recommended")
                    }
                }
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.85) : .secondary).lineLimit(2)
                }
                if isSelected {
                    Image(systemName: "checkmark.circle.fill").font(.caption).foregroundColor(.white)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .frame(minWidth: 130, alignment: .leading)
            .background(isSelected ? Color.TechBlue : Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.TechBlue : Color(.systemGray4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Delivery Zone Section

    private var deliveryZoneSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Delivery Zone", systemImage: "mappin.and.ellipse.circle.fill")
                    .font(.headline).foregroundColor(.primary)
                Spacer()
                Toggle("", isOn: $enableDeliveryZone)
                    .labelsHidden()
                    .tint(.TechBlue)
            }

            if enableDeliveryZone {
                VStack(spacing: 0) {
                    // Radius slider only
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "circle.dashed").font(.body).foregroundColor(.TechBlue).frame(width: 28)
                            Text("Radius").font(.subheadline)
                            Spacer()
                            Text(deliveryZoneRadius >= 1000
                                 ? String(format: "%.1f km", deliveryZoneRadius / 1000)
                                 : String(format: "%.0f m", deliveryZoneRadius))
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.TechBlue)
                        }
                        Slider(value: $deliveryZoneRadius, in: 50...10000, step: 50)
                            .tint(.TechBlue)
                            .padding(.leading, 40)
                        HStack {
                            Spacer().frame(width: 40)
                            Text("50 m").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("10 km").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                HStack(spacing: 6) {
                    Image(systemName: destinationCoordinate != nil ? "checkmark.circle.fill" : "info.circle")
                        .foregroundColor(destinationCoordinate != nil ? .green : .secondary)
                        .font(.caption)
                    Text(destinationCoordinate != nil
                         ? "Zone centered on destination · visible on map"
                         : "Set a destination first — the zone will be centered there")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Route Monitoring Section

    private var routeMonitoringSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Route Monitoring", systemImage: "road.lanes.curved.right")
                    .font(.headline).foregroundColor(.primary)
                Spacer()
                Toggle("", isOn: $enableRouteMonitoring)
                    .labelsHidden()
                    .tint(.TechBlue)
            }

            if enableRouteMonitoring {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "road.lanes").font(.body).foregroundColor(.TechBlue).frame(width: 28)
                            Text("Drift Radius").font(.subheadline)
                            Spacer()
                            Text("\(Int(routeMonitoringRadius)) meters")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.TechBlue)
                        }
                        Slider(value: $routeMonitoringRadius, in: 100...5000, step: 100)
                            .tint(.TechBlue)
                            .padding(.leading, 40)
                        HStack {
                            Spacer().frame(width: 40)
                            Text("100 m").font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("5 km").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Text("Alerts you if the vehicle drifts more than \(Int(routeMonitoringRadius))m from the intended route.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Save All

    private func saveAll() async {
        guard let pickupDate, let expectedEndDate else {
            vm.errorMessage = "Select pickup and end times."
            return
        }
        // 1. Create the trip (trips table only)
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

        guard vm.errorMessage == nil else { return }

        // 2. Always create source geofence (3km)
        if let originCoord = originCoordinate, let vehicleID = selectedVehicleID {
            let autoName = origin.components(separatedBy: ",").first?
                .trimmingCharacters(in: .whitespaces) ?? "Source Depot"
            
            await geofenceVM.createGeofence(
                name: "\(autoName) (Source)",
                latitude: originCoord.latitude,
                longitude: originCoord.longitude,
                radius: 3000,
                type: .depot
            )
            
            if geofenceVM.errorMessage == nil,
               let newGeofence = geofenceVM.geofences.last(where: {
                   $0.latitude == originCoord.latitude && $0.longitude == originCoord.longitude
               }) {
                await geofenceVM.assignVehicles([vehicleID], to: newGeofence.id)
            }
        }

        // 3. Optionally create delivery zone geofences — completely separate from trips table
        if enableDeliveryZone {
            // Create geofence for destination
            if let coord = destinationCoordinate {
                let autoName = destination.components(separatedBy: ",").first?
                    .trimmingCharacters(in: .whitespaces) ?? "Delivery Zone"

                await geofenceVM.createGeofence(
                    name: autoName.isEmpty ? "Delivery Zone" : autoName,
                    latitude: coord.latitude,
                    longitude: coord.longitude,
                    radius: deliveryZoneRadius,
                    type: .delivery
                )

                if geofenceVM.errorMessage == nil,
                   let vehicleID = selectedVehicleID,
                   let newGeofence = geofenceVM.geofences.last(where: {
                       $0.latitude == coord.latitude && $0.longitude == coord.longitude
                   }) {
                    await geofenceVM.assignVehicles([vehicleID], to: newGeofence.id)
                }
            }
            
            // Create geofences for via points
            for (index, viaAddr) in viaPoints.enumerated() {
                if index < viaCoordinates.count, let coord = viaCoordinates[index] {
                    let viaName = viaAddr.components(separatedBy: ",").first?
                        .trimmingCharacters(in: .whitespaces) ?? "Via Point \(index + 1)"
                    
                    await geofenceVM.createGeofence(
                        name: viaName.isEmpty ? "Via Point \(index + 1)" : viaName,
                        latitude: coord.latitude,
                        longitude: coord.longitude,
                        radius: deliveryZoneRadius,
                        type: .delivery
                    )
                    
                    if geofenceVM.errorMessage == nil,
                       let vehicleID = selectedVehicleID,
                       let newGeofence = geofenceVM.geofences.last(where: {
                           $0.latitude == coord.latitude && $0.longitude == coord.longitude
                       }) {
                        await geofenceVM.assignVehicles([vehicleID], to: newGeofence.id)
                    }
                }
            }
        }

        dismiss()
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).font(.headline).foregroundColor(.primary)
    }

    private func inputRow(icon: String, placeholder: String, text: Binding<String>, field: FormField) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.body).foregroundColor(.TechBlue).frame(width: 28)
            TextField(placeholder, text: text)
                .font(.subheadline)
                .focused($focusedField, equals: field)
                .onSubmit {
                    focusedField = field == .tripName ? .clientContact : nil
                }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private func triggerRoute() {
        guard !origin.isEmpty, !destination.isEmpty else { return }
        routePolyline = nil
        Task {
            await vm.calculateRoute(
                origin: origin,
                originCoord: originCoordinate,
                destination: destination,
                destinationCoord: destinationCoordinate,
                waypoints: resolvedViaCoordinates
            )
        }
    }

    private func fetchPolyline(from origin: CLLocationCoordinate2D,
                                waypoints: [CLLocationCoordinate2D],
                                to destination: CLLocationCoordinate2D) async {
        // MKDirections supports up to 1 intermediate waypoint natively.
        // For multiple via points we chain segments and merge polylines.
        var allPoints: [CLLocationCoordinate2D] = [origin] + waypoints + [destination]
        var combinedCoords: [CLLocationCoordinate2D] = []

        for i in 0..<(allPoints.count - 1) {
            let req = MKDirections.Request()
            req.source = MKMapItem(placemark: MKPlacemark(coordinate: allPoints[i]))
            req.destination = MKMapItem(placemark: MKPlacemark(coordinate: allPoints[i + 1]))
            req.transportType = .automobile
            if let route = try? await MKDirections(request: req).calculate().routes.first {
                var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid,
                                                      count: route.polyline.pointCount)
                route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: route.polyline.pointCount))
                combinedCoords.append(contentsOf: coords)
            }
        }

        guard !combinedCoords.isEmpty else { return }
        let merged = MKPolyline(coordinates: combinedCoords, count: combinedCoords.count)
        routePolyline = merged
        let rect = merged.boundingMapRect
        mapCameraPosition = .rect(rect.insetBy(dx: -rect.size.width * 0.2, dy: -rect.size.height * 0.2))
    }

    private func clearAssignments() {
        selectedVehicleID = nil
        selectedDriverID = nil
        vm.resetAssignmentOptions()
    }

    private func formatETA(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func updateProjectedEndTime(newPickup: Date? = nil) {
        guard let referencePickup = newPickup ?? pickupDate else { return }
        
        if let etaSeconds = vm.calculatedETA {
            // Buffer of 15 minutes for loading/unloading/parking
            let buffer: TimeInterval = 15 * 60 
            let totalInterval = etaSeconds + buffer
            
            withAnimation(.easeInOut) {
                expectedEndDate = referencePickup.addingTimeInterval(totalInterval)
            }
        } else {
            // If no ETA yet, just ensure End Time is at least 1 hour after Pickup
            if expectedEndDate == nil || expectedEndDate! <= referencePickup {
                withAnimation {
                    expectedEndDate = Calendar.current.date(byAdding: .hour, value: 1, to: referencePickup) ?? referencePickup
                }
            }
        }
    }

    private func autoRefreshAssignments() {
        // Deselect previous picks but keep the list visible if possible
        selectedVehicleID = nil
        selectedDriverID = nil
        
        // Only auto-refresh if we have a full route
        guard !origin.isEmpty, !destination.isEmpty,
              let pickupDate, let expectedEndDate else { return }
        
        Task {
            await vm.loadAssignmentOptions(
                pickupLocation: origin,
                destination: destination,
                pickupDate: pickupDate,
                expectedEndDate: expectedEndDate
            )
        }
    }

    private func scheduleRow(title: String, value: Date?) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            Text(value.map(formatISTDateTime) ?? "--")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(value == nil ? .secondary : .primary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private func formatISTDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = Self.istTimeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - LocationField

private enum LocationField: String, Identifiable {
    case origin, destination, via
    var id: String { rawValue }
}
