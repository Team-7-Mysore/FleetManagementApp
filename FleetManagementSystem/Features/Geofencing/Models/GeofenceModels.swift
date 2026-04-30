//
//  GeofenceModels.swift
//  FleetManagementSystem
//
//  Created by Kiro on 2025
//

import Foundation
import SwiftUI

// MARK: - Geofence Type Enum
enum GeofenceType: String, Codable, CaseIterable {
    case depot
    case delivery
    case restricted
    
    var displayName: String {
        switch self {
        case .depot: return "Depot"
        case .delivery: return "Delivery"
        case .restricted: return "Restricted"
        }
    }
    
    var icon: String {
        switch self {
        case .depot: return "building.2.fill"
        case .delivery: return "shippingbox.fill"
        case .restricted: return "exclamationmark.triangle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .depot: return .blue
        case .delivery: return .green
        case .restricted: return .red
        }
    }
}

// MARK: - Geofence Model
struct Geofence: Codable, Identifiable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let radius: Double
    let type: GeofenceType
    let created_at: Date
    let updated_at: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "geofence_id"
        case name
        case latitude
        case longitude
        case radius
        case type
        case created_at
        case updated_at
    }
}

// MARK: - Geofence Assignment Model
struct GeofenceAssignment: Codable, Identifiable {
    let id: UUID
    let geofence_id: UUID
    let vehicle_id: UUID
    let created_at: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "assignment_id"
        case geofence_id
        case vehicle_id
        case created_at
    }
}

// MARK: - Geofence Event Model
struct GeofenceEvent: Codable, Identifiable {
    let id: UUID
    let geofence_id: UUID
    let vehicle_id: UUID
    let event_type: EventType
    let timestamp: Date
    let latitude: Double
    let longitude: Double
    let dwell_time: TimeInterval?
    
    enum CodingKeys: String, CodingKey {
        case id = "event_id"
        case geofence_id
        case vehicle_id
        case event_type
        case timestamp
        case latitude
        case longitude
        case dwell_time
    }
    
    enum EventType: String, Codable {
        case entry
        case exit
    }
    
    var formattedDwellTime: String? {
        guard let dwell = dwell_time else { return nil }
        let hours = Int(dwell) / 3600
        let minutes = (Int(dwell) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Geofence Status Model
struct GeofenceStatus: Codable {
    let vehicle_id: UUID
    let geofence_id: UUID
    let geofence_name: String
    let entry_timestamp: Date
    let is_inside: Bool
}
