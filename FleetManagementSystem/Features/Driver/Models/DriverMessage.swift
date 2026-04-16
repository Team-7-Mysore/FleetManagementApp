import Foundation

struct DriverMessage: Identifiable, Equatable {
    let id: UUID
    let sender: String
    let subject: String
    let preview: String
    let time: String
    let priority: DriverMessagePriority
}

enum DriverMessagePriority: String, Equatable {
    case normal
    case high

    var displayName: String {
        switch self {
        case .normal:
            "Normal"
        case .high:
            "High"
        }
    }
}
