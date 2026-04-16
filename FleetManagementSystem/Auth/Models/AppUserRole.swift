import Foundation

enum AppUserRole: String, Codable {
    case driver
    case fleetManager
    case maintenance

    var displayName: String {
        switch self {
        case .driver:
            "Driver"
        case .fleetManager:
            "Fleet Manager"
        case .maintenance:
            "Maintenance"
        }
    }
}
