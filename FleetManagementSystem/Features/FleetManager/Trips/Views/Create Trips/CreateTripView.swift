import SwiftUI
import MapKit
import CoreLocation

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
    @State private var pickupDate = Date()
    @State private var expectedEndDate = Calendar.current.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
    @State private var selectedVehicleID: UUID?
    @State private var selectedDriverID: UUID?

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

    private enum FormField { case tripName, clientContact }
    private static let istTimeZone = TimeZone(identifier: "Asia/Kolkata")!

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
            .toolbar(.hidden, for: .tabBar)
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
                updateProjectedEndTime(newPickup: newPickup)
                autoRefreshAssignments()
            }
            .onChange(of: vm.calculatedETA) { _, _ in
                updateProjectedEndTime()
                autoRefreshAssignments()
            }
            .onChange(of: expectedEndDate) { _, _ in 
                autoRefreshAssignments()
            }
            .onChange(of: vm.isCalculatingRoute) { _, isCalculating in
                if !isCalculating,
                   let o = vm.originCoordinates,
                   let d = vm.destinationCoordinates {
                    Task { await fetchPolyline(from: o, waypoints: resolvedViaCoordinates, to: d) }
                }
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
                }

                // Delivery zone circle overlay — centered on destination and via points
                if enableDeliveryZone {
                    if let zc = destinationCoordinate {
                        MapCircle(center: zc, radius: deliveryZoneRadius)
                            .foregroundStyle(Color.TechBlue.opacity(0.12))
                            .stroke(Color.TechBlue, lineWidth: 2)
                    }
                    
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

    // MARK: - Trip Info Section

    private var tripInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Trip Info", icon: "doc.text")
            VStack(spacing: 0) {
                inputRow(icon: "tag", placeholder: "Route Name", text: $tripName, field: .tripName)
                Divider().padding(.leading, 44)
                inputRow(icon: "person.crop.circle", placeholder: "Client Contact", text: $clientContact, field: .clientContact)
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
                    .foregroundColor(.TechBlue)
            }
            .padding(.leading, 4)
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
                DatePicker("Pickup (IST)", selection: $pickupDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .environment(\.timeZone, Self.istTimeZone)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                Divider().padding(.leading, 16)
                DatePicker("End (IST)", selection: $expectedEndDate, in: pickupDate..., displayedComponents: [.date, .hourAndMinute])
                    .environment(\.timeZone, Self.istTimeZone)
                    .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal)
    }

    // MARK: - Assignment Section

    private var assignmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Assignment", icon: "person.badge.key")

            Button {
                selectedVehicleID = nil
                selectedDriverID = nil
                Task {
                    await vm.loadAssignmentOptions(
                        pickupLocation: origin,
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
            .disabled(vm.isLoadingAssignments || origin.isEmpty)

            if !vm.availableVehicles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Vehicles").font(.caption).foregroundStyle(.secondary).padding(.leading, 4)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(vm.availableVehicles) { v in
                                assignmentCard(title: v.displayName, subtitle: v.subtitle, icon: "car.fill",
                                               isSelected: selectedVehicleID == v.id) { selectedVehicleID = v.id }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }

            if !vm.availableDrivers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Drivers").font(.caption).foregroundStyle(.secondary).padding(.leading, 4)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(vm.availableDrivers) { d in
                                assignmentCard(title: d.name, subtitle: "", icon: "",
                                               isSelected: selectedDriverID == d.id) { selectedDriverID = d.id }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }

            if !vm.isLoadingAssignments && vm.availableVehicles.isEmpty && vm.availableDrivers.isEmpty && !origin.isEmpty {
                Text("Set route and schedule, then tap Find Available.")
                    .font(.footnote).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
        }
        .padding(.horizontal)
    }

    private func assignmentCard(title: String, subtitle: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if !icon.isEmpty {
                        Image(systemName: icon).font(.caption.weight(.semibold))
                            .foregroundColor(isSelected ? .white : .TechBlue)
                    }
                    Text(title).font(.subheadline.weight(.semibold))
                        .foregroundColor(isSelected ? .white : .primary).lineLimit(1)
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
                Label("Route Monitoring", systemImage: "point.topleft.down.curvedto.point.bottomright.up.curved.fill")
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

        // 2. Optionally create delivery zone geofences — completely separate from trips table
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

    private var canSave: Bool {
        !origin.isEmpty && !destination.isEmpty && selectedVehicleID != nil && selectedDriverID != nil
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
        .toolbar {
            if focusedField == field {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }.font(.subheadline.weight(.semibold))
                }
            }
        }
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
        let referencePickup = newPickup ?? pickupDate
        
        if let etaSeconds = vm.calculatedETA {
            // Buffer of 15 minutes for loading/unloading/parking
            let buffer: TimeInterval = 15 * 60 
            let totalInterval = etaSeconds + buffer
            
            withAnimation(.easeInOut) {
                expectedEndDate = referencePickup.addingTimeInterval(totalInterval)
            }
        } else {
            // If no ETA yet, just ensure End Time is at least 1 hour after Pickup
            if expectedEndDate <= referencePickup {
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
        
        // Only auto-refresh if we actually have a pickup location
        guard !origin.isEmpty else { return }
        
        Task {
            await vm.loadAssignmentOptions(
                pickupLocation: origin,
                pickupDate: pickupDate,
                expectedEndDate: expectedEndDate
            )
        }
    }
}

// MARK: - LocationField

private enum LocationField: String, Identifiable {
    case origin, destination, via
    var id: String { rawValue }
}
