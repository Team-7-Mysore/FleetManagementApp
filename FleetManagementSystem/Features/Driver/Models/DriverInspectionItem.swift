import Foundation

struct DriverInspectionItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let detail: String
    var isCompleted: Bool
}
