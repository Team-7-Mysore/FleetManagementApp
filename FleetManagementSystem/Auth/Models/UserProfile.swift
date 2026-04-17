import Foundation

struct UserProfile: Codable {
    let userId: UUID
    let name: String
    let email: String
    let role: AppUserRole
    let phoneNumber: String?
    let createdAt: String?
    let createdBy: UUID?
    let username: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case email
        case role
        case phoneNumber = "phone_no"
        case createdAt = "created_at"
        case createdBy = "created_by"
        case username
    }
}
