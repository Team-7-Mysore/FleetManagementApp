import Foundation

// MARK: - Maintenance Type
enum MaintenanceType: String, Codable, CaseIterable, Identifiable {
    case oilChange    = "Oil Change"
    case tireRotation = "Tire Rotation"
    case brakeService = "Brake Service"
    case batteryCheck = "Battery Check"
    case inspection   = "Inspection"
    case engineTune   = "Engine Tune-Up"
    case fluidTop     = "Fluid Top-Off"
    case other        = "Other"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .oilChange:    return "drop.fill"
        case .tireRotation: return "tire"
        case .brakeService: return "bolt.car"
        case .batteryCheck: return "battery.100percent"
        case .inspection:   return "checklist"
        case .engineTune:   return "engine.combustion"
        case .fluidTop:     return "humidity.fill"
        case .other:        return "wrench.and.screwdriver.fill"
        }
    }
}

// MARK: - Maintenance Status
enum MaintenanceStatus: String, Codable, CaseIterable, Identifiable {
    case scheduled  = "assigned"
    case inProgress = "In Progress"
    case completed  = "Completed"
    case overdue    = "Overdue"

    var id: String { rawValue }
}

// MARK: - Priority Level
enum PriorityLevel: String, Codable, CaseIterable, Identifiable {
    case low      = "Low"
    case medium   = "Medium"
    case high     = "High"
    case critical = "Critical"

    var id: String { rawValue }
}

// MARK: - Maintenance Task
struct MaintenanceTask: Identifiable, Codable {
    let id: UUID
    var vehicleId: UUID
    var type: MaintenanceType
    var description: String
    var scheduledDate: Date
    var completedDate: Date?
    var status: MaintenanceStatus
    var assignedPersonnelId: UUID?
    var priority: PriorityLevel
    var cost: Double?
    var partsUsed: [String]
    var laborHours: Double?
    var notes: String
}
