import SwiftUI
import MapKit
import Supabase
// MARK: - Active Trip View
struct ActiveTripView: View {
    let trip: TripMap
    let user: User
    @EnvironmentObject private var router: AppRouter

    @State private var elapsedTime: TimeInterval = 0
    @State private var showEndTripConfirmation = false
    @State private var showReportIssue = false
    @State private var timer: Timer?

    // SOS State
    @State private var showSOSConfirmation = false

    // MapKit State
    @State private var route: MKRoute?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @StateObject private var locationManager = LocationManager()
    @State private var distance: Double = 0
    @State private var eta: Double = 0
    @State private var geofences: [Geofence] = []

    // Route persistence — tracks the routes table row for this trip
    @State private var savedRouteId: UUID?

    // Database points with fallbacks to demonstration points
    var startPoint: CLLocationCoordinate2D {
        if let coord = trip.startCoordinate {
            return CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
        }
        return CLLocationCoordinate2D(latitude: 12.3060, longitude: 76.6547)
    }

    var endPoint: CLLocationCoordinate2D {
        if let coord = trip.endCoordinate {
            return CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
        }
        return CLLocationCoordinate2D(latitude: 12.9716, longitude: 77.5946)
    }

    private var formattedDistance: String {
        guard distance > 0 else { return "--" }
        return String(format: "%.1f km", distance / 1000)
    }

    private var formattedETA: String {
        guard eta > 0 else { return "--" }

        let minutes = Int(eta / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Map
            Map(position: $cameraPosition) {
                UserAnnotation()

                Marker("Start", coordinate: startPoint)
                    .tint(.green)

                Marker("Destination", coordinate: endPoint)
                    .tint(.red)

                if let route = route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 5)
                }

                ForEach(geofences) { geofence in
                    MapCircle(
                        center: CLLocationCoordinate2D(latitude: geofence.latitude, longitude: geofence.longitude),
                        radius: geofence.radius
                    )
                    .foregroundStyle(geofence.type.color.opacity(0.12))
                    .stroke(geofence.type.color, lineWidth: 2)
                }
            }
            .mapControls {
                MapUserLocationButton()
            }
            .frame(maxHeight: .infinity)
            .overlay(alignment: .bottomTrailing) {
                SOSButton {
                    showSOSConfirmation = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }

            // MARK: - Bottom Panel
            VStack(spacing: 16) {
                // Trip info bar
                HStack(spacing: 24) {
                    tripInfoItem(value: formattedDistance, label: "Distance")
                    Divider().frame(height: 36)
                    tripInfoItem(value: formattedETA, label: "ETA")
                    Divider().frame(height: 36)
                    tripInfoItem(value: formattedElapsed, label: "Elapsed")
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Action buttons
                VStack(spacing: 12) {
                    // Navigate Button
                    Button { openInMaps() } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                            Text("Start Navigation")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }


                    HStack(spacing: 12) {
                        Button { showReportIssue = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle")
                                Text("Report Issue")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.statusDanger)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(AppTheme.statusDanger.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        Button { showEndTripConfirmation = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "stop.fill")
                                Text("End Trip")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(AppTheme.primaryGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal)

                // Destination bar
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(AppTheme.primaryGreen)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Destination")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(trip.endLocation)
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle("Active Trip")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .alert("End Trip", isPresented: $showEndTripConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("End Trip", role: .destructive) {
                router.path.append(AppRoute.vehicleInspection(trip, type: .postTrip))
            }
        } message: {
            Text("Are you sure you want to end this trip?")
        }
        .alert("Call Emergency Services?", isPresented: $showSOSConfirmation) {
            Button("Call Now", role: .destructive) {
                callEmergency()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will immediately dial emergency contact. Only proceed in a genuine emergency.")
        }
        .sheet(isPresented: $showReportIssue) {
            let tripVehicle = Vehicle(
                id: trip.vehicleId,
                name: trip.startLocation,
                registrationNumber: "",
                vehicleType: "unknown"
            )
            ReportIssueView(user: user, vehicle: tripVehicle, activeTripId: trip.id)
        }
        .onAppear {
            // Seed emergency contact (replace with user-configurable value later)
            UserDefaults.standard.set("+918408880436", forKey: "emergency_contact")
            savedRouteId = trip.routeId   // carry any already-stored route_id
            startTimer()
            createRoute()
            locationManager.requestLocation()
            
            Task {
                await fetchGeofences()
            }
        }
        .onDisappear { stopTimer() }
    }

    private func fetchGeofences() async {
        let geofenceService = GeofenceService()
        do {
            // 1. Fetch geofences assigned to the vehicle
            var allRelevantGeofences = try await geofenceService.fetchGeofencesForVehicle(trip.vehicleId)
            
            // 2. Fetch geofences at origin and destination
            // We search within a small radius (e.g., 100m) to catch geofences that might be the source/destination
            if let startCoord = trip.startCoordinate {
                let nearOrigin = try await geofenceService.findOverlappingGeofences(
                    latitude: startCoord.latitude,
                    longitude: startCoord.longitude,
                    radius: 100,
                    excluding: nil
                )
                for g in nearOrigin {
                    if !allRelevantGeofences.contains(where: { $0.id == g.id }) {
                        allRelevantGeofences.append(g)
                    }
                }
            }
            
            if let endCoord = trip.endCoordinate {
                let nearDest = try await geofenceService.findOverlappingGeofences(
                    latitude: endCoord.latitude,
                    longitude: endCoord.longitude,
                    radius: 100,
                    excluding: nil
                )
                for g in nearDest {
                    if !allRelevantGeofences.contains(where: { $0.id == g.id }) {
                        allRelevantGeofences.append(g)
                    }
                }
            }
            
            self.geofences = allRelevantGeofences
            print("🗺️ ActiveTripView: Geofences loaded (Vehicle + Route): \(geofences.count)")
        } catch {
            print("❌ ActiveTripView: Failed to load geofences: \(error)")
        }
    }

    private func tripInfoItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var formattedElapsed: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startTimer() {
        if let startTime = trip.startTime {
            elapsedTime = Date().timeIntervalSince(startTime)
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if let startTime = trip.startTime {
                elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Map Logic
    private func createRoute() {
        let sourcePlacemark = MKPlacemark(coordinate: startPoint)
        let destPlacemark = MKPlacemark(coordinate: endPoint)

        let sourceItem = MKMapItem(placemark: sourcePlacemark)
        let destItem = MKMapItem(placemark: destPlacemark)

        let request = MKDirections.Request()
        request.source = sourceItem
        request.destination = destItem
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        directions.calculate { response, error in

            if let error = error {
                print("Error getting route: \(error.localizedDescription)")
                return
            }

            guard let response = response else {
                print("No response received")
                return
            }

            guard let route = response.routes.first else {
                print("No routes found")
                return
            }

            DispatchQueue.main.async {
                self.route = route
                self.distance = route.distance
                self.eta = route.expectedTravelTime
                let rect = route.polyline.boundingMapRect
                let paddedRect = rect.insetBy(dx: -rect.size.width * 0.12,
                                              dy: -rect.size.height * 0.12)
                let region = MKCoordinateRegion(paddedRect)
                self.cameraPosition = .region(region)

                // Persist the calculated route to Supabase (always latest optimized route)
                let currentRouteId = self.savedRouteId
                Task {
                    await self.saveRoute(mkRoute: route, existingRouteId: currentRouteId)
                }
            }
        }
    }

    private func openInMaps() {
        let destinationPlacemark = MKPlacemark(coordinate: endPoint)
        let destinationItem = MKMapItem(placemark: destinationPlacemark)
        destinationItem.name = trip.endLocation

        destinationItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    // MARK: - Route Persistence

    /// Encodes the MKDirections result and upserts it into the `routes` table.
    /// INSERT path: trip has no route_id yet → creates a new row and links it back to the trip.
    /// UPDATE path: trip already has a route_id → overwrites with the latest optimized polyline.
    @MainActor
    private func saveRoute(mkRoute: MKRoute, existingRouteId: UUID?) async {
        // 1. Encode polyline into a JSON [[lat, lng]] string
        let pointCount = mkRoute.polyline.pointCount
        var rawCoords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: pointCount)
        mkRoute.polyline.getCoordinates(&rawCoords, range: NSRange(location: 0, length: pointCount))
        let coordPairs = rawCoords.map { [$0.latitude, $0.longitude] }
        guard
            let jsonData = try? JSONSerialization.data(withJSONObject: coordPairs),
            let polylineString = String(data: jsonData, encoding: .utf8)
        else {
            print("❌ saveRoute: failed to encode polyline")
            return
        }

        let distanceMeters = mkRoute.distance
        let etaSeconds     = mkRoute.expectedTravelTime

        do {
            if let existingRouteId {
                // UPDATE the existing routes row with fresh optimized data
                struct RouteUpdate: Encodable {
                    let distance: Double
                    let estimated_time: Double
                    let polyline_data: String
                }
                try await SupabaseManager.shared.client
                    .from("routes")
                    .update(RouteUpdate(
                        distance: distanceMeters,
                        estimated_time: etaSeconds,
                        polyline_data: polylineString
                    ))
                    .eq("route_id", value: existingRouteId.uuidString)
                    .execute()
                print("✅ saveRoute: updated route \(existingRouteId)")

            } else {
                // INSERT a new routes row, then link it back to the trip
                struct RouteInsert: Encodable {
                    let start_location: String
                    let end_location: String
                    let distance: Double
                    let estimated_time: Double
                    let polyline_data: String
                }
                struct RouteResponse: Decodable {
                    let route_id: UUID
                }

                let inserted: [RouteResponse] = try await SupabaseManager.shared.client
                    .from("routes")
                    .insert(RouteInsert(
                        start_location: trip.startLocation,
                        end_location: trip.endLocation,
                        distance: distanceMeters,
                        estimated_time: etaSeconds,
                        polyline_data: polylineString
                    ))
                    .select("route_id")
                    .execute()
                    .value

                guard let newRouteId = inserted.first?.route_id else {
                    print("❌ saveRoute: no route_id returned from insert")
                    return
                }

                // Link the new route to this trip
                try await SupabaseManager.shared.client
                    .from("trips")
                    .update(["route_id": newRouteId.uuidString])
                    .eq("trip_id", value: trip.id.uuidString)
                    .execute()

                // Update local state so subsequent opens take the UPDATE path
                savedRouteId = newRouteId
                print("✅ saveRoute: created route \(newRouteId) and linked to trip \(trip.id)")
            }
        } catch {
            print("❌ saveRoute error: \(error)")
        }
    }

    private func callEmergency() {
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.error)

        // READ the stored number (set() stores, string(forKey:) reads)
        let rawNumber = UserDefaults.standard.string(forKey: "emergency_contact") ?? "112"

        // Percent-encode so '+91...' doesn't break URL(string:)
        let encoded = rawNumber.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "112"

        // Use tel: (not tel://) — correct RFC scheme for phone calls
        guard let url = URL(string: "tel:\(encoded)") else { return }

        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - SOS Button
struct SOSButton: View {
    let onConfirmed: () -> Void

    @State private var isHolding = false
    @State private var progress: CGFloat = 0
    @State private var holdTask: Task<Void, Never>? = nil

    private let holdDuration: Double = 1.8

    var body: some View {
        ZStack {
            // Progress ring (while holding)
            if isHolding {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color(red: 1, green: 0.23, blue: 0.19),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 68, height: 68)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: holdDuration), value: progress)
            }

            // Static button
            Circle()
                .fill(Color(red: 1, green: 0.23, blue: 0.19))
                .frame(width: 60, height: 60)
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                .overlay {
                    Text("SOS")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                        .tracking(1.5)
                }
                .scaleEffect(isHolding ? 1.08 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHolding)
        }
        .accessibilityLabel("Emergency SOS button")
        .accessibilityHint("Hold for 2 seconds to call emergency services")
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isHolding { startHold() }
                }
                .onEnded { _ in
                    cancelHold()
                }
        )
    }

    private func startHold() {
        isHolding = true
        progress = 0
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.linear(duration: holdDuration)) {
            progress = 1.0
        }
        holdTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(holdDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                isHolding = false
                progress = 0
                onConfirmed()
            }
        }
    }

    private func cancelHold() {
        guard isHolding else { return }
        holdTask?.cancel()
        holdTask = nil
        withAnimation(.easeOut(duration: 0.2)) { progress = 0 }
        isHolding = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}

// MARK: - LocationManager
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {

    private let manager = CLLocationManager()

    @Published var userLocation: CLLocationCoordinate2D?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {

        switch manager.authorizationStatus {

        case .notDetermined:
            manager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            print("✅ Authorized")
            manager.startUpdatingLocation()

        case .denied, .restricted:
            print("❌ Permission denied")

        default:
            break
        }
    }

    // Delegate method (this is where updates come)
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("📍 didUpdateLocations called")
        guard let location = locations.last else { return }

        DispatchQueue.main.async {
            print("📍 New location:", location.coordinate)
            self.userLocation = location.coordinate
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}
