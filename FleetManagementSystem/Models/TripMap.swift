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
struct TripMap: Identifiable, Codable, Hashable {
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
    var startCoordinate: Coordinate?
    var endCoordinate: Coordinate?

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

struct TripDTO: Decodable {
    let tripId: String
    let vehicleId: String?
    let driverId: String?
    let startLocation: String?
    let endLocation: String?
    let startTime: Date?
    let endTime: Date?
    let pickupTime: Date?
    let status: String
    let distanceTravelled: Double?
    let originLatitude: Double?
    let originLongitude: Double?
    let destinationLatitude: Double?
    let destinationLongitude: Double?

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case vehicleId = "vehicle_id"
        case driverId = "driver_id"
        case startLocation = "start_location"
        case endLocation = "end_location"
        case startTime = "start_time"
        case endTime = "end_time"
        case pickupTime = "pickup_time"
        case status
        case distanceTravelled = "distance_travelled"
        case originLatitude = "origin_latitude"
        case originLongitude = "origin_longitude"
        case destinationLatitude = "destination_latitude"
        case destinationLongitude = "destination_longitude"
    }
}

extension TripMap {
    init(dto: TripDTO) {
        self.id = UUID(uuidString: dto.tripId) ?? UUID()
        self.vehicleId = UUID(uuidString: dto.vehicleId ?? "") ?? UUID()
        self.driverId = UUID(uuidString: dto.driverId ?? "") ?? UUID()

        self.startLocation = dto.startLocation ?? "Unknown"
        self.endLocation = dto.endLocation ?? "Unknown"

        self.startTime = dto.startTime
        self.endTime = dto.endTime

        self.scheduledStartTime = dto.pickupTime ?? Date()

        self.distance = dto.distanceTravelled ?? 0
        self.estimatedDuration = 0

        self.fuelUsed = nil

        // 🔥 STATUS MAPPING (IMPORTANT)
        switch dto.status.lowercased() {
        case "assigned":
            self.status = .planned
        case "active":
            self.status = .inProgress
        case "completed":
            self.status = .completed
        case "cancelled":
            self.status = .cancelled
        default:
            self.status = .planned
        }

        self.notes = ""
        self.route = []
        
        if let oLat = dto.originLatitude, let oLng = dto.originLongitude {
            self.startCoordinate = Coordinate(latitude: oLat, longitude: oLng)
        } else {
            self.startCoordinate = nil
        }
        
        if let dLat = dto.destinationLatitude, let dLng = dto.destinationLongitude {
            self.endCoordinate = Coordinate(latitude: dLat, longitude: dLng)
        } else {
            self.endCoordinate = nil
        }
    }
}
