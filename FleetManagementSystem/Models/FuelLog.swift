import Foundation

// MARK: - Fuel Log
struct FuelLog: Identifiable, Codable {
    let id: UUID
    var vehicleId: UUID
    var driverId: UUID
    var date: Date
    var gallons: Double
    var costPerGallon: Double
    var totalCost: Double
    var mileageAtFill: Double
    var location: String

    var formattedCost: String {
        String(format: "$%.2f", totalCost)
    }

    var formattedGallons: String {
        String(format: "%.1f gal", gallons)
    }
}
