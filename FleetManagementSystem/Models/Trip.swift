import Foundation

// MARK: - Trip Status
enum TripStatus: String, Codable, CaseIterable, Identifiable {
    case planned    = "Planned"
    case inProgress = "In Progress"
    case completed  = "Completed"
    case cancelled  = "Cancelled"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .planned:    return "calendar.badge.clock"
        case .inProgress: return "location.fill"
        case .completed:  return "checkmark.circle.fill"
        case .cancelled:  return "xmark.circle.fill"
        }
    }

    var tintColor: String {
        switch self {
        case .planned:    return "info"
        case .inProgress: return "active"
        case .completed:  return "green"
        case .cancelled:  return "danger"
        }
    }
}

// MARK: - Coordinate
struct Coordinate: Codable, Hashable {
    let latitude: Double
    let longitude: Double
}

// MARK: - Trip
struct Trip: Identifiable, Codable, Hashable {
    let id: UUID
    var vehicleId: UUID
    var driverId: UUID
    var startLocation: String
    var endLocation: String
    var startTime: Date?
    var endTime: Date?
    var scheduledStartTime: Date
    var distance: Double          // miles
    var estimatedDuration: TimeInterval // seconds
    var fuelUsed: Double?         // gallons
    var status: TripStatus
    var notes: String
    var route: [Coordinate]

    var isActive: Bool { status == .inProgress }

    var formattedDistance: String {
        String(format: "%.0f mi", distance)
    }

    var formattedETA: String {
        let hours = Int(estimatedDuration) / 3600
        let minutes = (Int(estimatedDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var formattedDuration: String {
        guard let start = startTime, let end = endTime else { return "—" }
        let interval = end.timeIntervalSince(start)
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
