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
// MARK: - Vehicle DTO init
extension Vehicle {
    init(dto: VehicleDTO) {
        self.id               = UUID(uuidString: dto.vehicleId) ?? UUID()
        self.name             = dto.vehicleName ?? "Unknown Vehicle"
        self.make             = dto.brand ?? dto.manufacturer ?? "Unknown"
        self.model            = dto.model ?? "Unknown"
        self.year             = dto.modelYear ?? 0
        self.vin              = ""
        self.licensePlate     = dto.numberPlate ?? "—"
        self.registrationNumber = dto.numberPlate ?? "—"
        self.status           = {
            switch dto.status?.lowercased() {
            case "active":       return .available
            case "in_use":       return .inUse
            case "maintenance":  return .maintenance
            default:             return .available
            }
        }()
        self.mileage          = 0
        self.fuelLevel        = 0
        self.fuelType         = {
            switch dto.fuelType?.lowercased() {
            case "diesel":   return .diesel
            case "electric": return .electric
            case "hybrid":   return .hybrid
            case "cng":      return .cng
            default:         return .gasoline
            }
        }()
        self.assignedDriverId    = nil
        self.lastMaintenanceDate = nil
        self.nextMaintenanceDate = nil
        self.imageSystemName     = {
            switch dto.vehicleType?.lowercased() {
            case "truck":  return "truck.box.fill"
            case "bus":    return "bus.fill"
            case "van":    return "van.fill"
            default:       return "car.fill"
            }
        }()
    }
}
