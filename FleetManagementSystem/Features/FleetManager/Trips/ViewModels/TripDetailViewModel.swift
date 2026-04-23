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
    
    init(trip: Trip) {
        self.trip = trip
    }
    
    func loadTripDetails() async {
        isLoading = true
        errorMessage = nil
        
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
        do {
            // Fetch the most recent vehicle location for this trip's vehicle
            if let vehicleId = vehicle?.id {
                let locations: [TripDetailVehicleLocation] = try await SupabaseManager.shared.client
                    .from("vehicle_locations")
                    .select()
                    .eq("vehicle_id", value: vehicleId)
                    .order("timestamp", ascending: false)
                    .limit(1)
                    .execute()
                    .value
                
                if let location = locations.first {
                    driverLocation = CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                    )
                    print("✅ Driver location loaded: \(location.latitude), \(location.longitude)")
                }
            }
        } catch {
            print("❌ Error fetching driver location: \(error)")
        }
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
    let via_points: [String]?
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
