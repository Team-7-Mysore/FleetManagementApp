import Foundation

// MARK: - Notification Type
enum NotificationType: String, Codable, CaseIterable {
    case tripAssigned    = "Trip Assigned"
    case maintenance     = "Maintenance"
    case message         = "Message"
    case alert           = "Alert"
    case inspectionDue   = "Inspection Due"
    case fuelReminder    = "Fuel Reminder"
    case general         = "General"

    var systemImage: String {
        switch self {
        case .tripAssigned:   return "truck.box.fill"
        case .maintenance:    return "wrench.and.screwdriver"
        case .message:        return "message.fill"
        case .alert:          return "exclamationmark.triangle.fill"
        case .inspectionDue:  return "checklist"
        case .fuelReminder:   return "fuelpump.fill"
        case .general:        return "bell.fill"
        }
    }
}

// MARK: - App Notification
struct AppNotification: Identifiable, Codable {
    let id: UUID
    var userId: UUID
    var title: String
    var body: String
    var type: NotificationType
    var isRead: Bool
    var timestamp: Date
    var relatedId: UUID?
}
