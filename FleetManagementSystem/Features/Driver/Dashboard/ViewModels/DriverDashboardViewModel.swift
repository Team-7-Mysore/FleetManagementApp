import Foundation
import Combine
import Supabase

// MARK: - Vehicle DTO
struct VehicleDTO: Decodable {
    let vehicleId: String
    let vehicleName: String?
    let brand: String?
    let model: String?
    let modelYear: Int?
    let numberPlate: String?
    let status: String?
    let fuelType: String?
    let vehicleType: String?
    let manufacturer: String?

    enum CodingKeys: String, CodingKey {
        case vehicleId    = "vehicle_id"
        case vehicleName  = "vehicle_name"
        case brand
        case model
        case modelYear    = "model_year"
        case numberPlate  = "number_plate"
        case status
        case fuelType     = "fuel_type"
        case vehicleType  = "vehicle_type"
        case manufacturer
    }
}

// MARK: - Driver Dashboard ViewModel
@MainActor
final class DriverDashboardViewModel: ObservableObject {
    @Published private(set) var assignedVehicle: Vehicle?
    @Published private(set) var activeTrip: TripMap?
    @Published private(set) var upcomingTrips: [TripMap] = []
    @Published private(set) var currentInspection: Inspection?
    @Published private(set) var notifications: [AppNotification] = []
    @Published private(set) var unreadNotificationCount = 0
    @Published private(set) var totalMiles: Double = 0
    @Published private(set) var totalTrips: Int = 0
    @Published private(set) var fuelEfficiency: Double?
    @Published private(set) var hasLoadedData: Bool = false

    private let user: User
    private var isLoading = false
    private var refreshTimer: Timer?

    init(user: User) {
        self.user = user
    }

    func loadData(forceRefresh: Bool = false) {
        guard !isLoading else { return }
        if !forceRefresh && hasLoadedData { return }
        isLoading = true
        print("🚀 loadData called")

        Task {
            defer { isLoading = false }
            do {
                // Step 1: Get driver_id
                let driverResponse = try await SupabaseManager.shared.client
                    .from("drivers")
                    .select("driver_id")
                    .eq("user_id", value: user.id)
                    .execute()

                let driverDataList = try JSONDecoder().decode(
                    [[String: String]].self,
                    from: driverResponse.data
                )
                
                guard let driverId = driverDataList.first?["driver_id"] else {
                    print("⚠️ No driver record found for user_id: \(user.id). User might not be fully onboarded as a driver.")
                    self.assignedVehicle = nil
                    self.upcomingTrips = []
                    self.activeTrip = nil
                    return
                }

                // Step 2: Fetch trips
                let response = try await SupabaseManager.shared.client
                    .from("trips")
                    .select("*")
                    .eq("driver_id", value: driverId)
                    .execute()

                print("📦 RAW TRIPS:", String(data: response.data, encoding: .utf8) ?? "")

                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom { decoder in
                    let container = try decoder.singleValueContainer()
                    let dateStr = try container.decode(String.self)
                    if let date = BackendDateParser.parse(dateStr) { return date }
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "Invalid date format: \(dateStr)"
                    )
                }

                let dtoTrips = try decoder.decode([TripDTO].self, from: response.data)
                let trips = dtoTrips.map { TripMap(dto: $0) }

                print("✅ Final Trips:", trips)

                self.upcomingTrips = trips
                    .filter { $0.status == .planned }
                    .sorted { $0.scheduledStartTime < $1.scheduledStartTime }

                self.activeTrip = trips.first { $0.status == .inProgress }

                self.totalTrips = trips.filter { $0.status == .completed }.count
                self.totalMiles = trips
                    .filter { $0.status == .completed }
                    .reduce(0) { $0 + $1.distance }

                // Step 3: Resolve assigned vehicle only from active/upcoming mapped trips.
                let activeOrUpcomingTripIDs = Set(
                    trips
                        .filter { $0.status == .inProgress || $0.status == .planned }
                        .map(\.id)
                )

                let currentAssignment = dtoTrips.first { dto in
                    guard let id = UUID(uuidString: dto.tripId) else { return false }
                    return activeOrUpcomingTripIDs.contains(id)
                }

                if let vehicleId = currentAssignment?.vehicleId, !vehicleId.isEmpty {
                    await fetchVehicle(vehicleId: vehicleId)
                } else {
                    self.assignedVehicle = nil
                    print("⚠️ No vehicle_id found in trips")
                }

                self.hasLoadedData = true
            } catch {
                self.assignedVehicle = nil
                print("❌ FETCH ERROR:", error)
            }
        }
    }

    func startAutoRefresh(interval: TimeInterval = 60) {
        guard refreshTimer == nil else { return }
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.loadData(forceRefresh: true)
            }
        }
        timer.tolerance = 1.0
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    deinit {
        refreshTimer?.invalidate()
    }

    private func fetchVehicle(vehicleId: String) async {
        do {
            let response = try await SupabaseManager.shared.client
                .from("vehicles")
                .select("*")
                .eq("vehicle_id", value: vehicleId)
                .single()
                .execute()

            print("📦 RAW VEHICLE:", String(data: response.data, encoding: .utf8) ?? "")

            let decoder = JSONDecoder()
            let dto = try decoder.decode(VehicleDTO.self, from: response.data)
            self.assignedVehicle = Vehicle(dto: dto)

            print("✅ Vehicle loaded:", self.assignedVehicle as Any)
        } catch {
            self.assignedVehicle = nil
            print("❌ VEHICLE FETCH ERROR:", error)
        }
    }

    func startTrip(_ trip: TripMap) {
        Task {
            do {
                try await SupabaseManager.shared.client
                    .from("trips")
                    .update(["status": "in_progress"])
                    .eq("trip_id", value: trip.id.uuidString)
                    .execute()
                loadData()
            } catch {
                print("❌ START TRIP ERROR:", error)
            }
        }
    }
}
