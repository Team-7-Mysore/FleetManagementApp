import Foundation

struct AppUser: Identifiable, Codable, Equatable {
    let id: UUID
    let fullName: String
    let email: String
    let role: AppUserRole
}

struct AppUserSession: Equatable {
    let user: AppUser
}
