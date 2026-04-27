import SwiftUI
import Combine
import Supabase
import MapKit
import Foundation

@MainActor
final class TripDetailViewModel: ObservableObject {
    
    @Published var trip: Trip
    @Published var vehicle: Vehicle?
    @Published var driver: DriverInfo?
    @Published var driverLocation: CLLocationCoordinate2D?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Route Deviation tracking (Session-based)
    @Published var isRouteDeviated = false
    @Published var deviationRadius: Double = 500.0 // Default 500 meters, adjustable in session
    @Published var isCurrentDeviationApproved = false
    
    private var routeCoordinates: [CLLocationCoordinate2D] = []
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
    
    /// Starts a polling loop that refreshes the vehicle location every 2 seconds.
    func startLocationPolling() {
        locationPollingTask?.cancel()
        locationPollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshVehicleLocation()
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
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
            
            trackedVehicleId = fullTrip.vehicle_id ?? trip.vehicle_id
            trackedFleetManagerId = fullTrip.fleet_manager_id ?? trip.fleet_manager_id
            print("🧭 Trip details loaded for trip \(tripIdString). passed vehicle_id=\(trip.vehicle_id?.uuidString.lowercased() ?? "nil"), full vehicle_id=\(fullTrip.vehicle_id?.uuidString.lowercased() ?? "nil"), tracked vehicle_id=\(trackedVehicleId?.uuidString.lowercased() ?? "nil")")
            
            await refreshVehicleLocation()
            
            // Fetch vehicle details if vehicle_id exists
            if let vehicleId = fullTrip.vehicle_id {
                await fetchVehicle(vehicleId: vehicleId)
            }
            
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
