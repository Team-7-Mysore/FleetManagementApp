import Foundation

enum BackendDateParser {
    static func parse(_ raw: String) -> Date? {
        // Handle microsecond precision from Supabase (e.g. 2026-04-29T08:50:03.123456+00:00)
        var cleanRaw = raw
        if let dotIndex = raw.lastIndex(of: ".") {
            let substring = raw[dotIndex...]
            if let tzIndex = substring.firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
                let fractionLength = raw.distance(from: raw.index(after: dotIndex), to: tzIndex)
                if fractionLength > 3 {
                    // Truncate to 3 digits for ISO8601DateFormatter
                    let startToRemove = raw.index(dotIndex, offsetBy: 4)
                    cleanRaw.removeSubrange(startToRemove..<tzIndex)
                }
            }
        }
        
        let isoWithFractional = ISO8601DateFormatter()
        isoWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoWithFractional.date(from: cleanRaw) {
            return date
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: cleanRaw) {
            return date
        }

        let formatterWithMillis = DateFormatter()
        formatterWithMillis.locale = Locale(identifier: "en_US_POSIX")
        formatterWithMillis.timeZone = TimeZone(secondsFromGMT: 0)
        formatterWithMillis.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let date = formatterWithMillis.date(from: cleanRaw) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: cleanRaw)
    }
}

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
    var distance: Double          // kilometers
    var estimatedDuration: TimeInterval // seconds
    var fuelUsed: Double?         // gallons
    var status: TripStatus
    var notes: String
    var route: [Coordinate]
    var startCoordinate: Coordinate?
    var endCoordinate: Coordinate?
    var routeId: UUID?

    var isActive: Bool { status == .inProgress }

    var formattedDistance: String {
        String(format: "%.0f km", distance)
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
    let routeId: String?

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
        case routeId = "route_id"
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
        case "assigned", "planned", "upcoming", "scheduled":
            self.status = .planned

        case "active", "in_progress", "inprogress", "started":

            self.status = .inProgress
        case "completed", "done":
            self.status = .completed
        case "cancelled", "canceled":
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

        self.routeId = dto.routeId.flatMap { UUID(uuidString: $0) }
    }
}
