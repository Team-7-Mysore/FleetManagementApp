import Foundation

struct NotificationItem: Codable, Identifiable {
    let notificationId: UUID
    let inventoryId: UUID?
    let title: String
    let message: String
    var isRead: Bool?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case notificationId = "notification_id"
        case inventoryId = "inventory_id"
        case title
        case message
        case isRead = "is_read"
        case createdAt = "created_at"
    }
    
    // Satisfies Identifiable
    var id: UUID { notificationId }
}
