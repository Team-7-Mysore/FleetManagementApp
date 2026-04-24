import SwiftUI
import Combine
import Supabase
import MapKit

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
    
    private var locationPollingTask: Task<Void, Never>?
    
    init(trip: Trip) {
        self.trip = trip
    }
    
    deinit {
        locationPollingTask?.cancel()
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
    }
    
    /// Allows the manager to acknowledge a deviation (e.g. shortcut) for the current session.
    func approveCurrentDeviation() {
        isRouteDeviated = false
        isCurrentDeviationApproved = true
    }
    
    /// Fetches the single latest location for the trip's vehicle from vehicle_locations.
    func refreshVehicleLocation() async {
        guard let vehicleId = vehicle?.id ?? trip.vehicle_id else {
            print("⚠️ No vehicle_id available for location fetch")
            return
        }
        
        let idString = vehicleId.uuidString.lowercased()
        
        do {
            let locations: [TripDetailVehicleLocation] = try await SupabaseManager.shared.client
                .from("vehicle_locations")
                .select()
                .eq("vehicle_id", value: idString)
                .order("timestamp", ascending: false)
                .limit(1)
                .execute()
                .value
            
            if let location = locations.first {
                let newLocation = CLLocationCoordinate2D(
                    latitude: location.latitude,
                    longitude: location.longitude
                )
                driverLocation = newLocation
                
                // Track route deviation if we have a route and the trip is active
                if !routeCoordinates.isEmpty {
                    checkRouteDeviation(currentLocation: newLocation)
                }
                
                print("✅ Vehicle location refreshed (2s): \(location.latitude), \(location.longitude) (Deviated: \(isRouteDeviated))")
            } else {
                print("⚠️ No location matching vehicle_id: \(idString)")
            }
        } catch {
            print("❌ Error refreshing vehicle location: \(error)")
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
        }
        
        if isCurrentDeviationApproved {
            isRouteDeviated = false
        } else {
            isRouteDeviated = isNowDeviated
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
            let fullTrip: TripDetail = try await SupabaseManager.shared.client
                .from("trips")
                .select()
                .eq("trip_id", value: trip.id)
                .single()
                .execute()
                .value
            
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
        do {
            let vehicleData: Vehicle = try await SupabaseManager.shared.client
                .from("vehicles")
                .select()
                .eq("vehicle_id", value: vehicleId)
                .single()
                .execute()
                .value
            
            vehicle = vehicleData
            print("✅ Vehicle loaded: \(vehicleData.name)")
        } catch {
            print("❌ Error fetching vehicle: \(error)")
        }
    }
    
    private func fetchDriver(driverId: UUID) async {
        do {
            // Fetch driver record
            let driverRecord: TripDetailDriverRecord = try await SupabaseManager.shared.client
                .from("drivers")
                .select()
                .eq("driver_id", value: driverId)
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
                        .eq("user_id", value: userId)
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
            print("❌ Error fetching driver: \(error)")
        }
    }
    
    private func fetchDriverLocation(driverId: UUID) async {
        await refreshVehicleLocation()
    }
}

// MARK: - Supporting Models

struct TripDetail: Codable {
    let trip_id: UUID
    let vehicle_id: UUID?
    let driver_id: UUID?
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
