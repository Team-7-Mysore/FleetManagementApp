import Foundation

// MARK: - Inspection Type
enum InspectionType: String, Codable, CaseIterable, Identifiable {
    case preTrip  = "Pre-Trip"
    case postTrip = "Post-Trip"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .preTrip:  return "arrow.right.circle"
        case .postTrip: return "arrow.left.circle"
        }
    }
}

// MARK: - Inspection Item Status
enum InspectionItemStatus: String, Codable, CaseIterable {
    case pass    = "Pass"
    case fail    = "Fail"
    case pending = "Pending"
}

// MARK: - Inspection Item
struct InspectionItem: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var category: String
    var status: InspectionItemStatus
    var notes: String

    var systemImage: String {
        switch status {
        case .pass:    return "checkmark.circle.fill"
        case .fail:    return "exclamationmark.triangle.fill"
        case .pending: return "circle"
        }
    }
}

// MARK: - Inspection
struct Inspection: Identifiable, Codable {
    let id: UUID
    var vehicleId: UUID
    var driverId: UUID
    var type: InspectionType
    var date: Date
    var items: [InspectionItem]
    var overallNotes: String
    var isSubmitted: Bool

    var passCount: Int { items.filter { $0.status == .pass }.count }
    var failCount: Int { items.filter { $0.status == .fail }.count }
    var pendingCount: Int { items.filter { $0.status == .pending }.count }
    var completionPercentage: Double {
        guard !items.isEmpty else { return 0 }
        return Double(items.filter { $0.status != .pending }.count) / Double(items.count)
    }
    var overallStatus: String {
        if failCount > 0 { return "Issues Found" }
        if pendingCount > 0 { return "In Progress" }
        return "All Clear"
    }
}
