import Foundation

// MARK: - 1. Notification Type Enum
enum NotificationType: String, Codable, CaseIterable {
    case tripAssigned   = "Trip Assigned"
    case taskAssigned   = "Task Assigned"
    case maintenance    = "Maintenance"
    case message        = "Message"
    case alert          = "Alert"
    case general        = "General"
    case driverReport   = "Driver Report"
    case unknown        = "Unknown"
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = NotificationType(rawValue: rawValue) ?? .unknown
    }
    
    var systemImage: String {
        switch self {
        case .tripAssigned: return "truck.box.fill"
        case .taskAssigned: return "wrench.and.screwdriver.fill"
        case .maintenance:  return "exclamationmark.transmission"
        case .message:      return "envelope.fill"
        case .alert:        return "exclamationmark.triangle.fill"
        case .general:      return "bell"
        case .driverReport: return "person.text.rectangle.fill"
        case .unknown:      return "bell.circle"
        }
    }
}

// MARK: - 2. The Model for FETCHING Notifications (Displaying in UI)
struct AppNotification: Identifiable, Codable {
    let id: UUID
    var recipientId: UUID
    var senderId: UUID?
    var title: String
    var message: String
    var type: NotificationType
    var isRead: Bool
    var relatedEntityId: UUID?
    var createdAt: Date
    
    // Maps Swift's clean camelCase to Supabase's snake_case
    enum CodingKeys: String, CodingKey {
        case id
        case recipientId = "recipient_id"
        case senderId = "sender_id"
        case title
        case message
        case type
        case isRead = "is_read"
        case relatedEntityId = "related_entity_id"
        case createdAt = "created_at"
    }
}

// MARK: - 3. The Model for SENDING Notifications (Inserting to DB)
struct NotificationInsertDTO: Encodable {
    let recipient_id: UUID
    let sender_id: UUID?
    let title: String
    let message: String
    let type: String
    let related_entity_id: UUID?
}
