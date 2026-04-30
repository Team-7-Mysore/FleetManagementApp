import Foundation

// MARK: - Fuel Log
struct FuelLog: Identifiable, Codable {
    let id: UUID
    var vehicleId: UUID
    var driverId: UUID?
    var tripId: UUID?
    var date: Date
    var gallons: Double // Mapped to fuel_volume
    var totalCost: Double
    var mileageAtFill: Double?
    var location: String?
    var receiptImageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id = "fuel_log_id"
        case vehicleId = "vehicle_id"
        case driverId = "driver_id"
        case tripId = "trip_id"
        case date = "created_at"
        case gallons = "fuel_volume"
        case totalCost = "total_cost"
        case mileageAtFill = "odometer_reading"
        case location
        case receiptImageUrl = "receipt_image_url"
    }

    var formattedCost: String {
        String(format: "$%.2f", totalCost)
    }

    var formattedGallons: String {
        String(format: "%.1f gal", gallons)
    }
}
