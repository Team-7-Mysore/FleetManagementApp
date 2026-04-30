import SwiftUI
import Combine
import Supabase
import MapKit
import Foundation

@MainActor
final class TripDetailViewModel: ObservableObject {
    
    @Published var trip: Trip
    @Published var fullTrip: TripDetail?
    @Published var vehicle: Vehicle?
    @Published var driver: DriverInfo?
    @Published var driverLocation: CLLocationCoordinate2D?
    @Published var geofences: [Geofence] = []
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Assignment options for editing
    @Published var availableVehicles: [VehicleAssignmentOption] = []
    @Published var availableDrivers: [DriverAssignmentOption] = []
    @Published var isLoadingAssignments = false
    
    // Route Deviation tracking (Session-based)
    @Published var isRouteDeviated = false
    @Published var deviationRadius: Double = 500.0 // Default 500 meters, adjustable in session
    @Published var isCurrentDeviationApproved = false
    
    private let geofenceService = GeofenceService()
    private var trackedVehicleId: UUID?
    private var trackedFleetManagerId: UUID?
    private var hasSentDeviationNotification = false
    
    private var locationPollingTask: Task<Void, Never>?
    private var realtimeChannel: RealtimeChannelV2?
    
    init(trip: Trip) {
        self.trip = trip
    }
    
    deinit {
        locationPollingTask?.cancel()
        // Note: Realtime channels are usually cleaned up automatically, 
        // but we should ideally call unsubscribe. However, in @MainActor 
        // deinit, we can't easily call async methods.
    }
    
    /// Loads available vehicles and drivers for the trip's time window.
    func loadAssignmentOptions(pickupDate: Date, expectedEndDate: Date) async {
        guard expectedEndDate > pickupDate else {
            errorMessage = "Expected end time must be after pickup time."
            return
        }

        isLoadingAssignments = true
        errorMessage = nil

        do {
            // Fetch all vehicles
            let vehicles: [VehicleAssignmentOption] = try await SupabaseManager.shared.client
                .from("vehicles")
                .select("vehicle_id, number_plate, vehicle_name, vehicle_type, status")
                .execute()
                .value

            // Fetch all trips to check for conflicts
            let trips: [AssignmentTripRecord] = try await SupabaseManager.shared.client
                .from("trips")
                .select("trip_id, vehicle_id, driver_id, route_id, status, start_time, end_time, pickup_time")
                .execute()
                .value

            // Filter out conflicting trips, EXCLUDING the current trip we are editing
            let conflictingTrips = trips.filter { t in
                t.trip_id != trip.id && // Don't conflict with itself
                blocksAvailability(status: t.status) && overlaps(
                    existingStart: parseDatabaseTimestamp(t.start_time) ?? parseDatabaseTimestamp(t.pickup_time),
                    existingEnd: parseDatabaseTimestamp(t.end_time),
                    requestedStart: pickupDate,
                    requestedEnd: expectedEndDate
                )
            }

            let busyVehicleIDs = Set(conflictingTrips.compactMap(\.vehicle_id))
            
            self.availableVehicles = vehicles
                .filter { v in
                    let s = v.status?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return s != "maintenance" && s != "inactive"
                }
                .filter { !busyVehicleIDs.contains($0.vehicle_id) || $0.vehicle_id == trip.vehicle_id }
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

            // Fetch all drivers
            let drivers: [TripDetailDriverRecord] = try await SupabaseManager.shared.client
                .from("drivers")
                .select("driver_id, user_id, license_no, license_expiry")
                .execute()
                .value

            // Fetch all users for names
            let users: [TripDetailUserRecord] = try await SupabaseManager.shared.client
                .from("users")
                .select("user_id, name, phone_no")
                .execute()
                .value

            let busyDriverIDs = Set(conflictingTrips.compactMap(\.driver_id))
            let usersByID = Dictionary(uniqueKeysWithValues: users.map { ($0.user_id, $0) })

            self.availableDrivers = drivers
                .filter { d in
                    guard let expiryDate = parseDatabaseDate(d.license_expiry) else { return false }
                    return expiryDate >= Calendar.current.startOfDay(for: pickupDate)
                }
                .filter { !busyDriverIDs.contains($0.driver_id) || $0.driver_id == trip.driver_id }
                .map { d in
                    let user = usersByID[d.user_id ?? UUID()]
                    return DriverAssignmentOption(
                        id: d.driver_id,
                        userID: d.user_id,
                        name: user?.name ?? "Driver \(d.driver_id.uuidString.prefix(4))",
                        licenseNumber: d.license_no,
                        licenseExpiry: d.license_expiry,
                        locationHint: nil,
                        routeExperienceCount: 0,
                        isRecommended: false
                    )
                }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        } catch {
            print("❌ Error loading assignment options: \(error)")
            errorMessage = "Failed to load available vehicles/drivers"
        }

        isLoadingAssignments = false
    }

    private func blocksAvailability(status: String?) -> Bool {
        guard let s = status?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return ["assigned", "scheduled", "pending", "in_progress", "in progress", "in_transit", "in transit", "planned", "active"].contains(s)
    }

    private func overlaps(existingStart: Date?, existingEnd: Date?, requestedStart: Date, requestedEnd: Date) -> Bool {
        guard let start = existingStart else { return false }
        let end = existingEnd ?? Calendar.current.date(byAdding: .hour, value: 4, to: start) ?? start
        let bufferedEnd = end.addingTimeInterval(1800) // 30 min buffer
        return start < requestedEnd && bufferedEnd > requestedStart
    }

    func parseDatabaseTimestamp(_ value: String?) -> Date? {
        guard let v = value?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.timeZone = TimeZone(identifier: "UTC")
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: v) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: v)
    }

    private func parseDatabaseDate(_ value: String?) -> Date? {
        guard let v = value else { return nil }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: v)
    }
    
    /// Starts a polling loop that refreshes the vehicle location every 2 seconds.
    func startLocationPolling() {
        locationPollingTask?.cancel()
        locationPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshVehicleLocation()
                try? await Task.sleep(nanoseconds: 900_000_000_000)
            }
        }
    }
    
    func stopLocationPolling() {
        locationPollingTask?.cancel()
        locationPollingTask = nil
        
        if let channel = realtimeChannel {
            Task {
                await channel.unsubscribe()
            }
            realtimeChannel = nil
        }
    }
    
    /// Allows the manager to acknowledge a deviation (e.g. shortcut) for the current session.
    func approveCurrentDeviation() {
        isRouteDeviated = false
        isCurrentDeviationApproved = true
    }
    
    /// Fetches the single latest location for the trip's vehicle from vehicle_locations.
    func refreshVehicleLocation() async {
        guard let vehicleId = trackedVehicleId ?? vehicle?.id ?? trip.vehicle_id else {
            print("⚠️ refreshVehicleLocation skipped: no vehicle_id for trip \(trip.id.uuidString.lowercased())")
            return
        }
        let vehicleIdString = vehicleId.uuidString.lowercased()
        
        do {
            let locations: [TripDetailVehicleLocation] = try await SupabaseManager.shared.client
                .from("vehicle_locations")
                .select("vehicle_id, latitude, longitude, timestamp")
                .eq("vehicle_id", value: vehicleIdString)
                .order("timestamp", ascending: false)
                .limit(1)
                .execute()
                .value
            
            if let location = locations.first {
                print("📍 Trip \(trip.id.uuidString.lowercased()) fetched location for vehicle \(vehicleIdString): (\(location.latitude), \(location.longitude)) at \(location.timestamp)")
                updateDriverLocation(lat: location.latitude, lng: location.longitude)
            } else {
                print("⚠️ Trip \(trip.id.uuidString.lowercased()) found no vehicle_locations row for vehicle \(vehicleIdString) via authenticated session. Retrying with public anon read.")
                if let publicLocation = await fetchPublicVehicleLocation(vehicleIdString: vehicleIdString) {
                    print("📍 Public fallback fetched location for vehicle \(vehicleIdString): (\(publicLocation.latitude), \(publicLocation.longitude)) at \(publicLocation.timestamp)")
                    updateDriverLocation(lat: publicLocation.latitude, lng: publicLocation.longitude)
                } else {
                    print("⚠️ Public fallback also found no vehicle_locations row for vehicle \(vehicleIdString)")
                }
            }
        } catch {
            print("❌ Error refreshing vehicle location for vehicle \(vehicleIdString): \(error)")
        }
    }

    private func fetchPublicVehicleLocation(vehicleIdString: String) async -> TripDetailVehicleLocation? {
        guard var components = URLComponents(string: "\(SupabaseConfig.url.absoluteString)/rest/v1/vehicle_locations") else {
            return nil
        }

        components.queryItems = [
            URLQueryItem(name: "select", value: "vehicle_id,latitude,longitude,timestamp"),
            URLQueryItem(name: "vehicle_id", value: "eq.\(vehicleIdString)"),
            URLQueryItem(name: "order", value: "timestamp.desc"),
            URLQueryItem(name: "limit", value: "1")
        ]

        guard let url = components.url else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, 200..<300 ~= httpResponse.statusCode else {
                print("❌ Public vehicle location fallback failed with non-2xx response for vehicle \(vehicleIdString)")
                return nil
            }

            let locations = try JSONDecoder().decode([TripDetailVehicleLocation].self, from: data)
            return locations.first
        } catch {
            print("❌ Public vehicle location fallback failed for vehicle \(vehicleIdString): \(error)")
            return nil
        }
    }
    
    private func updateDriverLocation(lat: Double, lng: Double) {
        let newLocation = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        
        // Only update if coordinates changed significantly to avoid unnecessary UI jitter
        if let current = driverLocation {
            let threshold = 0.000001
            if abs(current.latitude - lat) < threshold && abs(current.longitude - lng) < threshold {
                return
            }
        }
        
        self.driverLocation = newLocation
        
        // Track route deviation if we have a route and the trip is active
        if !routeCoordinates.isEmpty {
            checkRouteDeviation(currentLocation: newLocation)
        }
    }
    
    /// Sets up a real-time listener for vehicle location changes.
    func setupRealtimeLocation() async {
        guard let vehicleId = trackedVehicleId ?? vehicle?.id ?? trip.vehicle_id else {
            print("⚠️ setupRealtimeLocation skipped: no vehicle_id for trip \(trip.id.uuidString.lowercased())")
            return
        }
        let trackedVehicleId = vehicleId.uuidString.lowercased()
        
        // Remove existing channel if any
        if let existingChannel = realtimeChannel {
            await existingChannel.unsubscribe()
        }
        
        let channelId = "vehicle-loc-\(vehicleId.uuidString)"
        let channel = SupabaseManager.shared.client.realtimeV2.channel(channelId)
        
        let insertionStream = channel.postgresChange(
            AnyAction.self,
            schema: "public",
            table: "vehicle_locations"
        )
        
        realtimeChannel = channel
        try? await channel.subscribeWithError()
        
        Task { [weak self] in
            for await change in insertionStream {
                guard let self = self else { break }
                
                var recordVehicleId: String?
                var lat: Double?
                var lng: Double?
                
                // Realtime V2 uses an enum for changes
                switch change {
                case .insert(let action):
                    recordVehicleId = action.record["vehicle_id"]?.stringValue?.lowercased()
                    lat = action.record["latitude"]?.doubleValue
                    lng = action.record["longitude"]?.doubleValue
                case .update(let action):
                    recordVehicleId = action.record["vehicle_id"]?.stringValue?.lowercased()
                    lat = action.record["latitude"]?.doubleValue
                    lng = action.record["longitude"]?.doubleValue
                default:
                    break
                }
                
                guard recordVehicleId == trackedVehicleId else { continue }
                
                if let lat = lat, let lng = lng {
                    await MainActor.run {
                        self.updateDriverLocation(lat: lat, lng: lng)
                    }
                }
            }
        }
    }
    
    /// Checks if the current location is outside the allowed radius from the intended route.
    private func checkRouteDeviation(currentLocation: CLLocationCoordinate2D) {
        // Only track deviation for active trips
        let s = trip.normalisedStatus
        guard s == .inTransit || s == .inProgress else {
            isRouteDeviated = false
            isCurrentDeviationApproved = false
            return
        }
        
        guard !routeCoordinates.isEmpty else { return }
        
        // Find the distance to the nearest point on the route
        var minDistance = Double.infinity
        let currentLoc = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
        
        // Sample the route 
        let step = max(1, routeCoordinates.count / 100) 
        
        for i in stride(from: 0, to: routeCoordinates.count, by: step) {
            let routePoint = routeCoordinates[i]
            let pointLoc = CLLocation(latitude: routePoint.latitude, longitude: routePoint.longitude)
            let dist = currentLoc.distance(from: pointLoc)
            if dist < minDistance {
                minDistance = dist
            }
        }
        
        // Update deviation status
        let isNowDeviated = minDistance > deviationRadius
        
        // If it was already approved, and we are still deviated, keep it approved (hide alert)
        // If we move BACK onto the route, reset approval so next deviation triggers again
        if !isNowDeviated {
            isCurrentDeviationApproved = false
            hasSentDeviationNotification = false
        }
        
        if isCurrentDeviationApproved {
            isRouteDeviated = false
        } else {
            isRouteDeviated = isNowDeviated
        }

        if isNowDeviated && !isCurrentDeviationApproved && !hasSentDeviationNotification {
            hasSentDeviationNotification = true
            Task {
                await sendRouteDeviationNotification(
                    currentLocation: currentLocation,
                    deviationDistance: minDistance
                )
            }
        }
    }
    
    /// Fetches the official MapKit route points for the intended trip path.
    func fetchIntendedRoute() async {
        guard let oLat = trip.origin_latitude, let oLng = trip.origin_longitude,
              let dLat = trip.destination_latitude, let dLng = trip.destination_longitude else {
            return
        }
        
        let origin = CLLocationCoordinate2D(latitude: oLat, longitude: oLng)
        let destination = CLLocationCoordinate2D(latitude: dLat, longitude: dLng)
        
        // For simplicity, we fetch the main route origin -> destination
        // In a full implementation, you'd chain via-points as well
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile
        
        do {
            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            if let firstRoute = response.routes.first {
                // Extract all points from the polyline
                var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: firstRoute.polyline.pointCount)
                firstRoute.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: firstRoute.polyline.pointCount))
                self.routeCoordinates = coords
                print("🏁 Intended route cached: \(coords.count) points")
            }
        } catch {
            print("❌ Failed to fetch intended route for deviation tracking: \(error)")
        }
    }
    
    func loadTripDetails() async {
        isLoading = true
        errorMessage = nil
        
        // Fetch intended route in the background
        Task { await fetchIntendedRoute() }
        
        do {
            // Fetch full trip details with vehicle_id and driver_id
            let tripIdString = trip.id.uuidString.lowercased()
            let fullTrip: TripDetail = try await SupabaseManager.shared.client
                .from("trips")
                .select()
                .eq("trip_id", value: tripIdString)
                .single()
                .execute()
                .value
            
            self.fullTrip = fullTrip
            trackedVehicleId = fullTrip.vehicle_id ?? trip.vehicle_id
            trackedFleetManagerId = fullTrip.fleet_manager_id ?? trip.fleet_manager_id
            print("🧭 Trip details loaded for trip \(tripIdString). passed vehicle_id=\(trip.vehicle_id?.uuidString.lowercased() ?? "nil"), full vehicle_id=\(fullTrip.vehicle_id?.uuidString.lowercased() ?? "nil"), tracked vehicle_id=\(trackedVehicleId?.uuidString.lowercased() ?? "nil")")
            
            await refreshVehicleLocation()
            
            // Fetch vehicle details if vehicle_id exists
            if let vehicleId = fullTrip.vehicle_id {
                await fetchVehicle(vehicleId: vehicleId)
            }
            
            // Fetch geofences (both assigned to vehicle and those at origin/destination)
            await fetchGeofences(vehicleId: fullTrip.vehicle_id)
            
            // Fetch driver details if driver_id exists
            if let driverId = fullTrip.driver_id {
                await fetchDriver(driverId: driverId)
            }
            
            isLoading = false
        } catch {
            print("❌ Error loading trip details: \(error)")
            errorMessage = "Failed to load trip details"
            isLoading = false
        }
    }

    private func fetchGeofences(vehicleId: UUID?) async {
        do {
            var allRelevantGeofences: [Geofence] = []
            
            // 1. Fetch geofences assigned to the vehicle
            if let vId = vehicleId {
                let vehicleGeofences = try await geofenceService.fetchGeofencesForVehicle(vId)
                allRelevantGeofences.append(contentsOf: vehicleGeofences)
            }
            
            // 2. Fetch geofences at origin and destination
            // We search within a small radius (e.g., 100m) to catch geofences that might be the source/destination
            if let oLat = trip.origin_latitude, let oLng = trip.origin_longitude {
                let nearOrigin = try await geofenceService.findOverlappingGeofences(latitude: oLat, longitude: oLng, radius: 100, excluding: nil)
                for g in nearOrigin {
                    if !allRelevantGeofences.contains(where: { $0.id == g.id }) {
                        allRelevantGeofences.append(g)
                    }
                }
            }
            
            if let dLat = trip.destination_latitude, let dLng = trip.destination_longitude {
                let nearDest = try await geofenceService.findOverlappingGeofences(latitude: dLat, longitude: dLng, radius: 100, excluding: nil)
                for g in nearDest {
                    if !allRelevantGeofences.contains(where: { $0.id == g.id }) {
                        allRelevantGeofences.append(g)
                    }
                }
            }
            
            self.geofences = allRelevantGeofences
            print("🗺️ Geofences loaded (Vehicle + Route): \(self.geofences.count)")
        } catch {
            print("❌ Error fetching geofences: \(error)")
        }
    }
    
    private func fetchVehicle(vehicleId: UUID) async {
        let vehicleIdString = vehicleId.uuidString.lowercased()
        do {
            let vehicleData: Vehicle = try await SupabaseManager.shared.client
                .from("vehicles")
                .select()
                .eq("vehicle_id", value: vehicleIdString)
                .single()
                .execute()
                .value
            
            vehicle = vehicleData
            trackedVehicleId = vehicleData.id
            print("✅ Vehicle loaded: \(vehicleData.name) (\(vehicleIdString))")
        } catch {
            print("❌ Error fetching vehicle \(vehicleIdString): \(error)")
        }
    }
    
    private func fetchDriver(driverId: UUID) async {
        let driverIdString = driverId.uuidString.lowercased()
        do {
            // Fetch driver record
            let driverRecord: TripDetailDriverRecord = try await SupabaseManager.shared.client
                .from("drivers")
                .select()
                .eq("driver_id", value: driverIdString)
                .single()
                .execute()
                .value
            
            // Fetch user details if user_id exists
            var userName = "Unknown Driver"
            var userPhone: String?
            
            if let userId = driverRecord.user_id {
                do {
                    let userRecord: TripDetailUserRecord = try await SupabaseManager.shared.client
                        .from("users")
                        .select()
                        .eq("user_id", value: userId.uuidString.lowercased())
                        .single()
                        .execute()
                        .value
                    
                    userName = userRecord.name
                    userPhone = userRecord.phone_no
                } catch {
                    print("❌ Error fetching user: \(error)")
                }
            }
            
            driver = DriverInfo(
                id: driverRecord.driver_id,
                name: userName,
                phone: userPhone,
                licenseNumber: driverRecord.license_no,
                licenseExpiry: driverRecord.license_expiry
            )
            
            // Fetch driver's current location
            await fetchDriverLocation(driverId: driverId)
            
            print("✅ Driver loaded: \(userName)")
        } catch {
            print("❌ Error fetching driver \(driverIdString): \(error)")
        }
    }
    
    private func fetchDriverLocation(driverId: UUID) async {
        await refreshVehicleLocation()
    }

    private func sendRouteDeviationNotification(
        currentLocation: CLLocationCoordinate2D,
        deviationDistance: Double
    ) async {
        guard let recipientId = trackedFleetManagerId ?? trip.fleet_manager_id else {
            print("⚠️ Route deviation notification skipped: no fleet_manager_id for trip \(trip.id.uuidString.lowercased())")
            return
        }

        let vehicleDisplayName = vehicle?.name ?? "Vehicle"
        let tripDisplayName = trip.tripNameText
        let distanceText = "\(Int(deviationDistance.rounded()))m"
        let coordinateText = String(format: "%.5f, %.5f", currentLocation.latitude, currentLocation.longitude)

        let payload = NotificationInsertDTO(
            recipient_id: recipientId,
            sender_id: nil,
            title: "Route deviation detected",
            message: "\(vehicleDisplayName) on \(tripDisplayName) deviated by about \(distanceText) near \(coordinateText).",
            type: NotificationType.alert.rawValue,
            related_entity_id: trip.id
        )

        do {
            try await SupabaseManager.shared.client
                .from("notifications")
                .insert(payload)
                .execute()
            print("🚨 Route deviation notification sent for trip \(trip.id.uuidString.lowercased()) to fleet manager \(recipientId.uuidString.lowercased())")
        } catch {
            hasSentDeviationNotification = false
            print("❌ Failed to send route deviation notification for trip \(trip.id.uuidString.lowercased()): \(error)")
        }
    }
}

// MARK: - Supporting Models

struct TripDetail: Codable {
    let trip_id: UUID
    let vehicle_id: UUID?
    let driver_id: UUID?
    let fleet_manager_id: UUID?
    let trip_name: String?
    let origin: String?
    let destination: String?
    let pickup_time: String?
    let start_time: String?
    let end_time: String?
    let status: String?
    let client_contact: String?
    let fuel_used: Double?
    // via_points is stored as jsonb – decode flexibly to avoid crashes
    let via_points: [String]?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        trip_id        = try c.decode(UUID.self,   forKey: .trip_id)
        vehicle_id     = try c.decodeIfPresent(UUID.self,   forKey: .vehicle_id)
        driver_id      = try c.decodeIfPresent(UUID.self,   forKey: .driver_id)
        fleet_manager_id = try c.decodeIfPresent(UUID.self, forKey: .fleet_manager_id)
        trip_name      = try c.decodeIfPresent(String.self, forKey: .trip_name)
        origin         = try c.decodeIfPresent(String.self, forKey: .origin)
        destination    = try c.decodeIfPresent(String.self, forKey: .destination)
        pickup_time    = try c.decodeIfPresent(String.self, forKey: .pickup_time)
        start_time     = try c.decodeIfPresent(String.self, forKey: .start_time)
        end_time       = try c.decodeIfPresent(String.self, forKey: .end_time)
        status         = try c.decodeIfPresent(String.self, forKey: .status)
        client_contact = try c.decodeIfPresent(String.self, forKey: .client_contact)
        fuel_used      = try c.decodeIfPresent(Double.self, forKey: .fuel_used)
        // Try [String] first; if the jsonb contains objects just treat as empty.
        via_points     = (try? c.decodeIfPresent([String].self, forKey: .via_points)) ?? []
    }
}

struct TripDetailDriverRecord: Codable {
    let driver_id: UUID
    let user_id: UUID?
    let license_no: String
    let license_expiry: String
}

struct TripDetailUserRecord: Codable {
    let user_id: UUID
    let name: String
    let phone_no: String?
}

struct TripDetailVehicleLocation: Codable {
    let vehicle_id: UUID?
    let latitude: Double
    let longitude: Double
    let timestamp: String
}

struct DriverInfo: Identifiable {
    let id: UUID
    let name: String
    let phone: String?
    let licenseNumber: String
    let licenseExpiry: String
}
