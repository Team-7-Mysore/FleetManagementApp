import Foundation

// MARK: - Vehicle Status
enum VehicleStatus: String, Codable, CaseIterable, Identifiable {
    case available    = "Available"
    case inUse        = "In Use"
    case maintenance  = "In Maintenance"
    case outOfService = "Out of Service"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .available:    return "checkmark.circle.fill"
        case .inUse:        return "location.fill"
        case .maintenance:  return "wrench.fill"
        case .outOfService: return "xmark.circle.fill"
        }
    }
}

// MARK: - Fuel Type
enum FuelType: String, Codable, CaseIterable, Identifiable {
    case gasoline = "Gasoline"
    case diesel   = "Diesel"
    case electric = "Electric"
    case hybrid   = "Hybrid"
    case cng      = "CNG"

    var id: String { rawValue }
}

// MARK: - Vehicle
struct Vehicle: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var make: String
    var model: String
    var year: Int
    var vin: String
    var licensePlate: String
    var registrationNumber: String
    var status: VehicleStatus
    var mileage: Double
    var fuelLevel: Double              // 0.0 – 1.0
    var fuelType: FuelType
    var assignedDriverId: UUID?
    var lastMaintenanceDate: Date?
    var nextMaintenanceDate: Date?
    var imageSystemName: String        // SF Symbol name

    var displayTitle: String {
        "\(make) \(model)"
    }

    var fuelPercentage: Int {
        Int(fuelLevel * 100)
    }

    var formattedMileage: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: Int(mileage))) ?? "\(Int(mileage))") + " mi"
    }
}
