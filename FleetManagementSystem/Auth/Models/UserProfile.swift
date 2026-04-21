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
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        userId = try container.decode(UUID.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        email = try container.decode(String.self, forKey: .email)
        
        // Handle role decoding with better error messages
        let roleString = try container.decode(String.self, forKey: .role)
        print("📋 Decoding role string: '\(roleString)'")
        
        guard let decodedRole = AppUserRole(rawValue: roleString) else {
            print("❌ Invalid role value: '\(roleString)'")
            print("❌ Valid roles are: \(AppUserRole.allCases.map { $0.rawValue }.joined(separator: ", "))")
            throw DecodingError.dataCorruptedError(
                forKey: .role,
                in: container,
                debugDescription: "Invalid role value: '\(roleString)'. Expected one of: \(AppUserRole.allCases.map { $0.rawValue }.joined(separator: ", "))"
            )
        }
        role = decodedRole
        print("✅ Role decoded successfully: \(decodedRole.rawValue)")
        
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        createdBy = try container.decodeIfPresent(UUID.self, forKey: .createdBy)
        username = try container.decodeIfPresent(String.self, forKey: .username)
    }
    
    // Manual initializer for creating UserProfile instances
    init(
        userId: UUID,
        name: String,
        email: String,
        role: AppUserRole,
        phoneNumber: String? = nil,
        createdAt: String? = nil,
        createdBy: UUID? = nil,
        username: String? = nil
    ) {
        self.userId = userId
        self.name = name
        self.email = email
        self.role = role
        self.phoneNumber = phoneNumber
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.username = username
    }
}
