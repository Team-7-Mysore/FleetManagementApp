import Foundation

// MARK: - Fuel Service
final class FuelService {
    static let shared = FuelService()
    private let store = MockDataStore.shared

    private init() {}

    func fetchLogs(forDriver driverId: UUID) -> [FuelLog] {
        store.fuelLogs
            .filter { $0.driverId == driverId }
            .sorted { $0.date > $1.date }
    }

    func fetchLogs(forVehicle vehicleId: UUID) -> [FuelLog] {
        store.fuelLogs
            .filter { $0.vehicleId == vehicleId }
            .sorted { $0.date > $1.date }
    }

    func addFuelLog(_ log: FuelLog) {
        store.fuelLogs.append(log)
    }

    func totalSpent(forDriver driverId: UUID) -> Double {
        store.fuelLogs
            .filter { $0.driverId == driverId }
            .reduce(0) { $0 + $1.totalCost }
    }

    func totalGallons(forDriver driverId: UUID) -> Double {
        store.fuelLogs
            .filter { $0.driverId == driverId }
            .reduce(0) { $0 + $1.gallons }
    }

    func averageCostPerGallon(forDriver driverId: UUID) -> Double {
        let logs = store.fuelLogs.filter { $0.driverId == driverId }
        guard !logs.isEmpty else { return 0 }
        return logs.reduce(0) { $0 + $1.costPerGallon } / Double(logs.count)
    }

    /// Heuristic fuel efficiency (miles per gallon) based on recent fill-ups
    func estimatedMPG(forVehicle vehicleId: UUID) -> Double? {
        let logs = store.fuelLogs
            .filter { $0.vehicleId == vehicleId }
            .sorted { $0.mileageAtFill < $1.mileageAtFill }
        guard logs.count >= 2 else { return nil }
        let milesDriven = logs.last!.mileageAtFill - logs.first!.mileageAtFill
        let totalGallons = logs.dropFirst().reduce(0) { $0 + $1.gallons }
        guard totalGallons > 0 else { return nil }
        return milesDriven / totalGallons
    }
}
