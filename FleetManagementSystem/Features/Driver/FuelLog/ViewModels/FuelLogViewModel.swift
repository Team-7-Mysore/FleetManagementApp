import Foundation
import Combine
import Supabase

// MARK: - Fuel Log ViewModel
@MainActor
final class FuelLogViewModel: ObservableObject {
    @Published private(set) var logs: [FuelLog] = []
    @Published private(set) var totalSpent: Double = 0
    @Published private(set) var totalGallons: Double = 0
    @Published private(set) var averageCost: Double = 0
    @Published private(set) var estimatedMPG: Double?

    @Published var gallons: String = ""
    @Published var costPerGallon: String = ""
    @Published var location: String = ""
    @Published var showAddForm = false

    private let user: User
    private let fuelService = FuelService.shared
    private var resolvedVehicleId: UUID?

    init(user: User) {
        self.user = user
    }

    func loadData() {
        logs = fuelService.fetchLogs(forDriver: user.id)
        totalSpent = fuelService.totalSpent(forDriver: user.id)
        totalGallons = fuelService.totalGallons(forDriver: user.id)
        averageCost = fuelService.averageCostPerGallon(forDriver: user.id)

        Task { await resolveVehicle() }
    }

    private func resolveVehicle() async {
        guard resolvedVehicleId == nil else {
            if let vid = resolvedVehicleId {
                estimatedMPG = fuelService.estimatedMPG(forVehicle: vid)
            }
            return
        }

        do {
            let driverRes = try await SupabaseManager.shared.client
                .from("drivers")
                .select("driver_id")
                .eq("user_id", value: user.id)
                .single()
                .execute()

            let driverData = try JSONDecoder().decode([String: String].self, from: driverRes.data)
            guard let driverId = driverData["driver_id"] else { return }

            let tripRes = try await SupabaseManager.shared.client
                .from("trips")
                .select("vehicle_id")
                .eq("driver_id", value: driverId)
                .in("status", values: ["assigned", "in_progress"])
                .limit(1)
                .execute()

            struct VehicleIdOnly: Decodable { let vehicle_id: String? }
            let rows = try JSONDecoder().decode([VehicleIdOnly].self, from: tripRes.data)

            if let vidStr = rows.first?.vehicle_id, let vid = UUID(uuidString: vidStr) {
                resolvedVehicleId = vid
                estimatedMPG = fuelService.estimatedMPG(forVehicle: vid)
            }
        } catch {
            print("❌ FuelLogViewModel resolveVehicle error:", error)
        }
    }

    var canSubmit: Bool {
        guard let g = Double(gallons), let c = Double(costPerGallon) else { return false }
        return g > 0 && c > 0 && !location.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func addFuelLog() {
        guard let g = Double(gallons), let c = Double(costPerGallon) else { return }
        let vehicleId = resolvedVehicleId ?? UUID()

        let log = FuelLog(
            id: UUID(), vehicleId: vehicleId, driverId: user.id,
            date: Date(), gallons: g, costPerGallon: c, totalCost: g * c,
            mileageAtFill: 0, location: location.trimmingCharacters(in: .whitespaces)
        )
        fuelService.addFuelLog(log)

        gallons = ""
        costPerGallon = ""
        location = ""
        showAddForm = false
        loadData()
    }
}
