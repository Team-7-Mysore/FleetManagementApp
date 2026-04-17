import Foundation

// MARK: - Vehicle Service
final class VehicleService {
    static let shared = VehicleService()
    private let store = MockDataStore.shared

    private init() {}

    func fetchVehicles() -> [Vehicle] {
        store.vehicles
    }

    func vehicle(byId id: UUID) -> Vehicle? {
        store.vehicles.first { $0.id == id }
    }

    func assignedVehicle(forDriver driverId: UUID) -> Vehicle? {
        store.vehicles.first { $0.assignedDriverId == driverId }
    }

    func updateFuelLevel(vehicleId: UUID, level: Double) {
        guard let idx = store.vehicles.firstIndex(where: { $0.id == vehicleId }) else { return }
        store.vehicles[idx].fuelLevel = level
    }

    func updateMileage(vehicleId: UUID, mileage: Double) {
        guard let idx = store.vehicles.firstIndex(where: { $0.id == vehicleId }) else { return }
        store.vehicles[idx].mileage = mileage
    }
}
