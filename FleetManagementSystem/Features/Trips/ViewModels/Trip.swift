//
//  Trip.swift
//  FleetManagementSystem
//
//  Created by harshwardhan patil on 16/04/26.
//

import Foundation

struct Trip: Codable, Identifiable {
    let id: UUID
    let vehicle_id: UUID?
    let driver_id: UUID?
    let trip_name: String?
    let origin: String?
    let destination: String?
    let pickup_time: String?
    let status: String?
    let trip_number: String?
    let distance_travelled: Double?
    let fuel_used: Double?
    let fleet_manager_id: UUID?
    let origin_latitude: Double?
    let origin_longitude: Double?
    let destination_latitude: Double?
    let destination_longitude: Double?
    let eta: Double?
    let created_at: String?

    enum CodingKeys: String, CodingKey {
        case id = "trip_id"
        case vehicle_id
        case driver_id
        case trip_name
        case origin
        case destination
        case pickup_time
        case status
        case trip_number
        case distance_travelled
        case fuel_used
        case fleet_manager_id
        case origin_latitude
        case origin_longitude
        case destination_latitude
        case destination_longitude
        case eta
        case created_at
    }
    var displayTripID: String {
        if let num = trip_number {
            return "#\(num)"
        }
        // Fallback: use first 4 chars of UUID
        let short = id.uuidString.prefix(4)
        return "#TR-\(short)"
    }

    var tripNameText: String {
        let trimmedValue = trip_name?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue?.isEmpty == false ? trimmedValue! : "Untitled Trip"
    }

    var originText: String {
        let trimmedValue = origin?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue?.isEmpty == false ? trimmedValue! : "Origin"
    }

    var destinationText: String {
        let trimmedValue = destination?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue?.isEmpty == false ? trimmedValue! : "Destination"
    }

    var routeText: String {
        "\(originText) to \(destinationText)"
    }

    /// Formatted pickup time for display
    var formattedPickupTime: String {
        guard let pickup = pickup_time else { return "" }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // Try ISO 8601 first
        if let date = iso.date(from: pickup) {
            return Trip.friendlyFormat(date)
        }

        // Try common Supabase timestamp format
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        ]

        for fmt in formats {
            formatter.dateFormat = fmt
            if let date = formatter.date(from: pickup) {
                return Trip.friendlyFormat(date)
            }
        }

        return pickup
    }

    /// Parse pickup_time into a Date
    private var parsedPickupDate: Date? {
        guard let pickup = pickup_time else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: pickup) { return date }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        ]
        for fmt in formats {
            formatter.dateFormat = fmt
            if let date = formatter.date(from: pickup) { return date }
        }
        return nil
    }

    /// Placed-by date formatted as "13 Oct, 2025"
    var formattedPlacedDate: String {
        guard let date = parsedPickupDate else { return pickup_time ?? "N/A" }
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM, yyyy"
        return fmt.string(from: date)
    }

    /// Estimated delivery date (pickup + 7 days) formatted as "28 Dec, 2025"
    var formattedEstimatedDate: String {
        guard let date = parsedPickupDate else { return "N/A" }
        let estimated = Calendar.current.date(byAdding: .day, value: 7, to: date) ?? date
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM, yyyy"
        return fmt.string(from: estimated)
    }

    private static func friendlyFormat(_ date: Date) -> String {
        let calendar = Calendar.current
        let display = DateFormatter()
        display.dateFormat = "hh:mm a"

        if calendar.isDateInToday(date) {
            return "Today, \(display.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday, \(display.string(from: date))"
        } else {
            let dayFmt = DateFormatter()
            dayFmt.dateFormat = "MMM d, yyyy"
            return "\(dayFmt.string(from: date)), \(display.string(from: date))"
        }
    }

    /// Normalised status for badge colouring
    var normalisedStatus: TripDisplayStatus {
        guard let s = status?.lowercased().trimmingCharacters(in: .whitespaces) else {
            return .unknown
        }
        switch s {
        case "in_transit", "in transit", "intransit":
            return .inTransit
        case "in_progress", "in progress", "inprogress", "active":
            return .inProgress
        case "completed", "complete":
            return .completed
        case "scheduled", "pending", "assigned":
            return .scheduled
        case "cancelled", "canceled":
            return .cancelled
        default:
            return .unknown
        }
    }

    func matchesSearch(_ query: String) -> Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return true }

        let normalizedQuery = trimmedQuery.lowercased()
        let searchableValues = [
            tripNameText,
            originText,
            destinationText,
            status ?? "",
            displayTripID,
            routeText
        ]

        return searchableValues.contains { value in
            value.lowercased().contains(normalizedQuery)
        }
    }
}

enum TripDisplayStatus {
    case inTransit, inProgress, completed, scheduled, cancelled, unknown

    var label: String {
        switch self {
        case .inTransit:  return "IN TRANSIT"
        case .inProgress: return "IN PROGRESS"
        case .completed:  return "COMPLETED"
        case .scheduled:  return "SCHEDULED"
        case .cancelled:  return "CANCELLED"
        case .unknown:    return "UNKNOWN"
        }
    }

    var displayTitle: String {
        switch self {
        case .inTransit:  return "In Transit"
        case .inProgress: return "In Progress"
        case .completed:  return "Delivered"
        case .scheduled:  return "Scheduled"
        case .cancelled:  return "Returned"
        case .unknown:    return "Unknown"
        }
    }

    var color: (bg: String, fg: String) {
        switch self {
        case .inTransit:  return ("inTransitBg",  "inTransitFg")
        case .inProgress: return ("inProgressBg", "inProgressFg")
        case .completed:  return ("completedBg",  "completedFg")
        case .scheduled:  return ("scheduledBg",  "scheduledFg")
        case .cancelled:  return ("cancelledBg",  "cancelledFg")
        case .unknown:    return ("unknownBg",    "unknownFg")
        }
    }
}
