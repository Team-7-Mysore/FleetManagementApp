import Foundation
import Combine
import Supabase

// MARK: - Driver Dashboard ViewModel
@MainActor
final class DriverDashboardViewModel: ObservableObject {
    @Published private(set) var assignedVehicle: Vehicle?
    @Published private(set) var activeTrip: Trip?
    @Published private(set) var upcomingTrips: [Trip] = []
    @Published private(set) var currentInspection: Inspection?
    @Published private(set) var notifications: [AppNotification] = []
    @Published private(set) var unreadNotificationCount = 0
    @Published private(set) var totalMiles: Double = 0
    @Published private(set) var totalTrips: Int = 0
    @Published private(set) var fuelEfficiency: Double?

    private let user: User
    private let vehicleService = VehicleService.shared
    private let tripService = TripService.shared
    private let inspectionService = InspectionService.shared
    private let notificationService = NotificationService.shared
    private let fuelService = FuelService.shared

    init(user: User) {
        self.user = user
    }

    func loadData() {
        print("🚀 loadData called")

        Task {
            do {
                let driverResponse = try await SupabaseManager.shared.client
                    .from("drivers")
                    .select("driver_id")
                    .eq("user_id", value: user.id)
                    .single()
                    .execute()

                let driverData = try JSONDecoder().decode([String: String].self, from: driverResponse.data)
                let driverId = driverData["driver_id"]!
                
                
                let response = try await SupabaseManager.shared.client
                    .from("trips")
                    .select("*")
                    .eq("driver_id", value: driverId) // IMPORTANT
                    .execute()

                print("📦 RAW RESPONSE:", String(data: response.data, encoding: .utf8)!)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateStr = try container.decode(String.self)

                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                    formatter.timeZone = TimeZone(secondsFromGMT: 0)

                    if let date = formatter.date(from: dateStr) {
                        return date
                    }

                    throw DecodingError.dataCorruptedError(in: container,
                        debugDescription: "Invalid date format: \(dateStr)")
                }
                let dtoTrips = try decoder.decode([TripDTO].self, from: response.data)

                let trips = dtoTrips.map { Trip(dto: $0) }

                print("✅ Final Trips:", trips)

                // ✅ Correct filtering (enum-based now)
                self.upcomingTrips = trips
                    .filter { $0.status == .planned }
                    .sorted { $0.scheduledStartTime < $1.scheduledStartTime }

                self.activeTrip = trips.first { $0.status == .inProgress }

            } catch {
                print("❌ FETCH ERROR:", error)
            }
        }

        // Keep other data (vehicle etc.)
        assignedVehicle = vehicleService.assignedVehicle(forDriver: user.id)
    }

    func startTrip(_ trip: Trip) {
        tripService.startTrip(id: trip.id)
        loadData()
    }
}
