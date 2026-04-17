import Foundation
import Combine

// MARK: - Fuel Log ViewModel
@MainActor
final class FuelLogViewModel: ObservableObject {
    @Published private(set) var logs: [FuelLog] = []
    @Published private(set) var totalSpent: Double = 0
    @Published private(set) var totalGallons: Double = 0
    @Published private(set) var averageCost: Double = 0
    @Published private(set) var estimatedMPG: Double?

    // New log form
    @Published var gallons: String = ""
    @Published var costPerGallon: String = ""
    @Published var location: String = ""
    @Published var showAddForm = false

    private let user: User
    private let fuelService = FuelService.shared
    private let vehicleService = VehicleService.shared

    init(user: User) {
        self.user = user
    }

    func loadData() {
        logs = fuelService.fetchLogs(forDriver: user.id)
        totalSpent = fuelService.totalSpent(forDriver: user.id)
        totalGallons = fuelService.totalGallons(forDriver: user.id)
        averageCost = fuelService.averageCostPerGallon(forDriver: user.id)

        if let vehicle = vehicleService.assignedVehicle(forDriver: user.id) {
            estimatedMPG = fuelService.estimatedMPG(forVehicle: vehicle.id)
        }
    }

    var canSubmit: Bool {
        guard let g = Double(gallons), let c = Double(costPerGallon) else { return false }
        return g > 0 && c > 0 && !location.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func addFuelLog() {
        guard let g = Double(gallons), let c = Double(costPerGallon),
              let vehicle = vehicleService.assignedVehicle(forDriver: user.id) else { return }

        let log = FuelLog(
            id: UUID(), vehicleId: vehicle.id, driverId: user.id,
            date: Date(), gallons: g, costPerGallon: c, totalCost: g * c,
            mileageAtFill: vehicle.mileage, location: location.trimmingCharacters(in: .whitespaces)
        )
        fuelService.addFuelLog(log)

        // Reset form
        gallons = ""
        costPerGallon = ""
        location = ""
        showAddForm = false
        loadData()
    }
}
