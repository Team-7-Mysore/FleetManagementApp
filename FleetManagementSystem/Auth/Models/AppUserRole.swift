import Foundation

enum AppUserRole: String, Codable, CaseIterable, Identifiable {
    case driver = "driver"
    case maintenance = "maintenance"
    case fleetManager = "fleet_manager"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .driver:       return "Driver"
        case .maintenance:  return "Maintenance Staff"
        case .fleetManager: return "Fleet Manager"
        }
    }

    var icon: String {
        switch self {
        case .driver:       return "car.fill"
        case .maintenance:  return "wrench.and.screwdriver.fill"
        case .fleetManager: return "person.badge.key.fill"
        }
    }

    /// Alias for icon — used in profile views
    var systemImage: String { icon }
}
