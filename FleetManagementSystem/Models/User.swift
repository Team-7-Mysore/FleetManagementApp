import Foundation

// MARK: - User Role (Driver-side role model)
// NOTE: Uses AppUserRole from AppUserRole.swift for role definition
// This maps driver-domain role to the shared role enum

// MARK: - User
struct User: Identifiable, Codable, Hashable {
    let id: UUID
    var firstName: String
    var lastName: String
    var email: String
    var role: AppUserRole
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
