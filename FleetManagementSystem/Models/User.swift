import Foundation

// MARK: - User Role
enum UserRole: String, Codable, CaseIterable, Identifiable {
    case fleetManager  = "Fleet Manager"
    case driver        = "Driver"
    case maintenance   = "Maintenance"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .fleetManager: return "person.badge.shield.checkmark"
        case .driver:       return "steeringwheel"
        case .maintenance:  return "wrench.and.screwdriver"
        }
    }
}

// MARK: - User
struct User: Identifiable, Codable, Hashable {
    let id: UUID
    var firstName: String
    var lastName: String
    var email: String
    var role: UserRole
    var phone: String
    var isActive: Bool
    var joinDate: Date

    var fullName: String { "\(firstName) \(lastName)" }

    var initials: String {
        let f = firstName.prefix(1).uppercased()
        let l = lastName.prefix(1).uppercased()
        return "\(f)\(l)"
    }
}
