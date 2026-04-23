//
//  GeofenceCreateEditView.swift
//  FleetManagementSystem
//

import SwiftUI
import MapKit
import CoreLocation
import Combine
import Supabase

// MARK: - GeofenceCreateEditView

struct GeofenceCreateEditView: View {
    @Environment(\.dismiss) private var dismiss
    var profile: UserProfile?
    @ObservedObject var viewModel: GeofenceViewModel

    // MARK: Form State
    @State private var name: String = ""
    @State private var latitude: Double = 0.0
    @State private var longitude: Double = 0.0
    @State private var radius: Double = 100.0
    @State private var type: GeofenceType = .depot
    @State private var selectedVehicles: Set<UUID> = []
    @State private var locationLabel: String = ""

    // MARK: UI State
    @State private var showingMapPicker: Bool = false
    @State private var isSaving: Bool = false
    @State private var validationError: String? = nil
    @State private var overlapWarning: String? = nil
    @State private var showingOverlapAlert: Bool = false
    @State private var availableVehicles: [Vehicle] = []
    @State private var isLoadingVehicles: Bool = false

    let mode: Mode
    let existingGeofence: Geofence?
    var prefilledLatitude: Double? = nil
    var prefilledLongitude: Double? = nil

    enum Mode { case create, edit }

    private var isFleetManager: Bool { profile?.role == .fleetManager }
    private var title: String { mode == .create ? "Create Geofence" : "Edit Geofence" }
    private var hasLocation: Bool { latitude != 0.0 || longitude != 0.0 }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if !isFleetManager {
                    accessDeniedView
                } else {
                    formView
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                if isFleetManager {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") { Task { await handleSave() } }
                            .font(.body.weight(.semibold))
                            .disabled(isSaving)
                    }
                }
            }
            .sheet(isPresented: $showingMapPicker) {
                GeofenceLocationPickerView(
                    latitude: $latitude,
                    longitude: $longitude,
                    locationLabel: $locationLabel
                )
            }
            .alert("Overlapping Geofences", isPresented: $showingOverlapAlert) {
                Button("Proceed Anyway", role: .destructive) { Task { await performSave() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(overlapWarning ?? "")
            }
            .task {
                populateForEdit()
                await loadAvailableVehicles()
            }
        }
    }

    // MARK: - Form

    private var formView: some View {
        Form {
            // Details
            Section {
                TextField("Geofence Name", text: $name)
                    .autocorrectionDisabled()
                Picker("Type", selection: $type) {
                    ForEach(GeofenceType.allCases, id: \.self) { t in
                        Label(t.displayName, systemImage: t.icon).tag(t)
                    }
                }
            } header: {
                Text("Details")
            } footer: {
                if let error = validationError {
                    Text(error).foregroundColor(.red).font(.caption)
                }
            }

            // Location — map picker only, no manual text fields
            Section {
                Button { showingMapPicker = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: hasLocation ? "mappin.circle.fill" : "map.fill")
                            .font(.title3)
                            .foregroundColor(hasLocation ? type.color : AppTheme.primaryGreen)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(hasLocation
                                 ? (locationLabel.isEmpty ? "Location selected" : locationLabel)
                                 : "Pick Location on Map")
                                .font(.subheadline)
                                .foregroundColor(hasLocation ? .primary : AppTheme.primaryGreen)
                                .lineLimit(2)

                            if hasLocation {
                                Text(String(format: "%.5f, %.5f", latitude, longitude))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            } header: {
                Text("Location")
            } footer: {
                if !hasLocation {
                    Text("Required — open the map, pan to your desired spot, then tap Confirm")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            // Radius
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Radius")
                        Spacer()
                        Text(radiusLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppTheme.primaryGreen)
                    }
                    Slider(value: $radius, in: 50...10000, step: 50)
                        .tint(AppTheme.primaryGreen)
                    HStack {
                        Text("50 m").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("10 km").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                radiusPreviewRow
            } header: { Text("Radius") }

            // Vehicle Assignment
            Section {
                if isLoadingVehicles {
                    HStack {
                        ProgressView().padding(.trailing, 8)
                        Text("Loading vehicles…").foregroundStyle(.secondary)
                    }
                } else if availableVehicles.isEmpty {
                    Text("No vehicles available").foregroundStyle(.secondary)
                } else {
                    ForEach(availableVehicles) { vehicle in
                        VehicleSelectionRow(
                            vehicle: vehicle,
                            isSelected: selectedVehicles.contains(vehicle.id)
                        ) {
                            if selectedVehicles.contains(vehicle.id) {
                                selectedVehicles.remove(vehicle.id)
                            } else {
                                selectedVehicles.insert(vehicle.id)
                            }
                        }
                    }
                }
            } header: {
                Text("Assign Vehicles (\(selectedVehicles.count) selected)")
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var radiusLabel: String {
        radius >= 1000
            ? String(format: "%.1f km", radius / 1000)
            : String(format: "%.0f m", radius)
    }

    private var radiusPreviewRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().stroke(type.color.opacity(0.4), lineWidth: 1.5).frame(width: 44, height: 44)
                Circle().fill(type.color.opacity(0.15)).frame(width: 44, height: 44)
                Image(systemName: type.icon).font(.caption).foregroundColor(type.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "Geofence" : name)
                    .font(.subheadline.weight(.medium)).lineLimit(1)
                Text("\(type.displayName) · \(radiusLabel) radius")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var accessDeniedView: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.statusDanger)
            Text("Access Denied").font(.title2.weight(.bold))
            Text("Only fleet managers can create and edit geofences.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Button("Dismiss") { dismiss() }
                .buttonStyle(SecondaryButtonStyle()).padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Actions

    private func populateForEdit() {
        guard mode == .edit, let geofence = existingGeofence else {
            if let lat = prefilledLatitude { latitude = lat }
            if let lon = prefilledLongitude { longitude = lon }
            return
        }
        name = geofence.name
        latitude = geofence.latitude
        longitude = geofence.longitude
        radius = geofence.radius
        type = geofence.type
        locationLabel = String(format: "%.5f, %.5f", latitude, longitude)
    }

    private func loadAvailableVehicles() async {
        isLoadingVehicles = true
        if mode == .edit, let geofence = existingGeofence {
            let assigned = await viewModel.loadAssignedVehicles(for: geofence.id)
            selectedVehicles = Set(assigned.map { $0.id })
        }
        do {
            availableVehicles = try await fetchAllVehicles()
        } catch {}
        isLoadingVehicles = false
    }

    private func fetchAllVehicles() async throws -> [Vehicle] {
        try await SupabaseManager.shared.client
            .from("vehicles").select().execute().value
    }

    private func handleSave() async {
        guard isFleetManager else { return }
        let result = viewModel.validateGeofence(name: name, latitude: latitude, longitude: longitude, radius: radius)
        guard result.isValid else { validationError = result.errorMessage; return }
        validationError = nil

        let overlaps = await viewModel.checkOverlaps(latitude: latitude, longitude: longitude, radius: radius, excluding: existingGeofence?.id)
        if !overlaps.isEmpty {
            let names = overlaps.prefix(3).map { $0.name }.joined(separator: ", ")
            let suffix = overlaps.count > 3 ? " and \(overlaps.count - 3) more" : ""
            overlapWarning = "This geofence overlaps with: \(names)\(suffix). Do you want to proceed?"
            showingOverlapAlert = true
            return
        }
        await performSave()
    }

    private func performSave() async {
        isSaving = true
        if mode == .create {
            await viewModel.createGeofence(name: name, latitude: latitude, longitude: longitude, radius: radius, type: type)
            if !selectedVehicles.isEmpty,
               let newGeofence = viewModel.geofences.last(where: { $0.name == name }) {
                await viewModel.assignVehicles(Array(selectedVehicles), to: newGeofence.id)
            }
        } else if let geofence = existingGeofence {
            let updated = Geofence(id: geofence.id, name: name, latitude: latitude, longitude: longitude,
                                   radius: radius, type: type, created_at: geofence.created_at, updated_at: Date())
            await viewModel.updateGeofence(updated)
            if !selectedVehicles.isEmpty {
                await viewModel.assignVehicles(Array(selectedVehicles), to: geofence.id)
            }
        }
        isSaving = false
        if viewModel.errorMessage == nil { dismiss() }
    }
}

// MARK: - Vehicle Selection Row

private struct VehicleSelectionRow: View {
    let vehicle: Vehicle
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: vehicle.imageSystemName)
                    .font(.title3)
                    .foregroundColor(AppTheme.primaryGreen)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(AppTheme.lightGreen))

                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle.name).font(.subheadline.weight(.medium)).foregroundColor(.primary)
                    Text(vehicle.registrationNumber).font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? AppTheme.primaryGreen : .secondary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Location Picker View

struct GeofenceLocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var latitude: Double
    @Binding var longitude: Double
    @Binding var locationLabel: String

    @StateObject private var locationManager = PickerLocationManager()

    // Camera starts at a default; jumps to user location once available
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629), // India center fallback
            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
        )
    )
    // The coordinate at the center of the map (updated as user pans)
    @State private var centerCoordinate: CLLocationCoordinate2D? = nil
    @State private var isReverseGeocoding: Bool = false
    @State private var didCenterOnUser: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Full-screen interactive map — native gestures (pinch, pan, rotate) work out of the box
                MapReader { proxy in
                    Map(position: $cameraPosition) {
                        // Blue dot for user location
                        UserAnnotation()
                    }
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                        MapScaleView()
                    }
                    .ignoresSafeArea(edges: .bottom)
                    // Track center coordinate as camera moves
                    .onMapCameraChange(frequency: .onEnd) { context in
                        centerCoordinate = context.region.center
                        reverseGeocode(context.region.center)
                    }
                }

                // Fixed crosshair pin at screen center
                VStack(spacing: 0) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.primaryGreen)
                        .shadow(radius: 4)
                    // Pin shadow dot
                    Ellipse()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 12, height: 4)
                }
                .allowsHitTesting(false) // don't block map gestures

                // Bottom info card
                VStack {
                    Spacer()
                    VStack(spacing: 6) {
                        if isReverseGeocoding {
                            HStack(spacing: 8) {
                                ProgressView().scaleEffect(0.8)
                                Text("Finding address…")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        } else if !locationLabel.isEmpty {
                            Text(locationLabel)
                                .font(.subheadline.weight(.medium))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        } else {
                            Text("Pan the map to position the pin")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let coord = centerCoordinate {
                            Text(String(format: "%.5f, %.5f", coord.latitude, coord.longitude))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground).opacity(0.95))
                            .shadow(radius: 8)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
                .allowsHitTesting(false)
            }
            .navigationTitle("Pick Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Confirm") {
                        if let coord = centerCoordinate {
                            latitude = coord.latitude
                            longitude = coord.longitude
                        }
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .disabled(centerCoordinate == nil)
                }
            }
            .onAppear {
                locationManager.requestPermission()
            }
            .onReceive(locationManager.$userLocation) { loc in
                guard let loc, !didCenterOnUser else { return }
                // If no existing coordinates, jump to user's current location
                let shouldUseUser = (latitude == 0.0 && longitude == 0.0)
                let center = shouldUseUser
                    ? loc.coordinate
                    : CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                cameraPosition = .region(MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
                centerCoordinate = center
                didCenterOnUser = true
                reverseGeocode(center)
            }
            .task {
                // If editing with existing coords, center there immediately
                if latitude != 0.0 || longitude != 0.0 {
                    let coord = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    cameraPosition = .region(MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                    centerCoordinate = coord
                    didCenterOnUser = true
                    reverseGeocode(coord)
                }
            }
        }
    }

    private func reverseGeocode(_ coord: CLLocationCoordinate2D) {
        isReverseGeocoding = true
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        geocoder.reverseGeocodeLocation(location) { placemarks, _ in
            isReverseGeocoding = false
            if let p = placemarks?.first {
                var parts: [String] = []
                if let name = p.name { parts.append(name) }
                if let area = p.subLocality ?? p.locality { parts.append(area) }
                locationLabel = parts.joined(separator: ", ")
            } else {
                locationLabel = String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
            }
        }
    }
}

// MARK: - Location Manager for Picker

final class PickerLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userLocation: CLLocation? = nil
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

// MARK: - Preview

#Preview {
    GeofenceCreateEditView(viewModel: GeofenceViewModel(), mode: .create, existingGeofence: nil)
}
