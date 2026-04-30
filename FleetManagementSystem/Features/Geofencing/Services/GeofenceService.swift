//
//  GeofenceService.swift
//  FleetManagementSystem
//
//  Created by Kiro on 2025
//

import Foundation
import Supabase
import CoreLocation

final class GeofenceService {
    private let client: SupabaseClient
    
    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }
    
    // MARK: - CRUD Operations
    
    /// Fetch all geofences from the database
    func fetchGeofences() async throws -> [Geofence] {
        let response: [Geofence] = try await client
            .from("geofences")
            .select()
            .execute()
            .value
        return response
    }
    
    /// Fetch a single geofence by ID
    func fetchGeofence(id: UUID) async throws -> Geofence {
        let response: [Geofence] = try await client
            .from("geofences")
            .select()
            .eq("geofence_id", value: id.uuidString)
            .execute()
            .value
        
        guard let geofence = response.first else {
            throw GeofenceServiceError.geofenceNotFound
        }
        return geofence
    }
    
    /// Create a new geofence
    func createGeofence(_ geofence: GeofenceInsert) async throws -> Geofence {
        let response: [Geofence] = try await client
            .from("geofences")
            .insert(geofence)
            .select()
            .execute()
            .value
        
        guard let createdGeofence = response.first else {
            throw GeofenceServiceError.creationFailed
        }
        return createdGeofence
    }
    
    /// Update an existing geofence
    func updateGeofence(id: UUID, _ update: GeofenceUpdate) async throws {
        try await client
            .from("geofences")
            .update(update)
            .eq("geofence_id", value: id.uuidString)
            .execute()
    }
    
    /// Delete a geofence
    func deleteGeofence(id: UUID) async throws {
        try await client
            .from("geofences")
            .delete()
            .eq("geofence_id", value: id.uuidString)
            .execute()
    }
    
    // MARK: - Assignment Operations
    
    /// Assign multiple vehicles to a geofence
    func assignVehicles(_ vehicleIds: [UUID], to geofenceId: UUID) async throws {
        let assignments = vehicleIds.map { vehicleId in
            GeofenceAssignmentInsert(geofence_id: geofenceId, vehicle_id: vehicleId)
        }
        
        try await client
            .from("geofence_assignments")
            .insert(assignments)
            .execute()
    }
    
    /// Remove a vehicle assignment from a geofence
    func removeAssignment(vehicleId: UUID, from geofenceId: UUID) async throws {
        try await client
            .from("geofence_assignments")
            .delete()
            .eq("geofence_id", value: geofenceId.uuidString)
            .eq("vehicle_id", value: vehicleId.uuidString)
            .execute()
    }
    
    /// Fetch all vehicles assigned to a geofence
    func fetchAssignedVehicles(for geofenceId: UUID) async throws -> [Vehicle] {
        // First fetch the assignments
        let assignments: [GeofenceAssignment] = try await client
            .from("geofence_assignments")
            .select()
            .eq("geofence_id", value: geofenceId.uuidString)
            .execute()
            .value
        
        // Extract vehicle IDs
        let vehicleIds = assignments.map { $0.vehicle_id }
        
        guard !vehicleIds.isEmpty else {
            return []
        }
        
        // Fetch vehicles
        let vehicles: [Vehicle] = try await client
            .from("vehicles")
            .select()
            .in("vehicle_id", values: vehicleIds.map { $0.uuidString })
            .execute()
            .value
        
        return vehicles
    }
    
    /// Fetch all geofences assigned to a vehicle
    func fetchGeofencesForVehicle(_ vehicleId: UUID) async throws -> [Geofence] {
        // First fetch the assignments
        let assignments: [GeofenceAssignment] = try await client
            .from("geofence_assignments")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .execute()
            .value
        
        // Extract geofence IDs
        let geofenceIds = assignments.map { $0.geofence_id }
        
        guard !geofenceIds.isEmpty else {
            return []
        }
        
        // Fetch geofences
        let geofences: [Geofence] = try await client
            .from("geofences")
            .select()
            .in("geofence_id", values: geofenceIds.map { $0.uuidString })
            .execute()
            .value
        
        return geofences
    }
    
    // MARK: - Event Operations
    
    /// Fetch events for a geofence within a date range
    func fetchEvents(for geofenceId: UUID, from startDate: Date, to endDate: Date) async throws -> [GeofenceEvent] {
        let response: [GeofenceEvent] = try await client
            .from("geofence_events")
            .select()
            .eq("geofence_id", value: geofenceId.uuidString)
            .gte("timestamp", value: startDate.ISO8601Format())
            .lte("timestamp", value: endDate.ISO8601Format())
            .order("timestamp", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    /// Fetch current geofence status for a vehicle
    func fetchVehicleStatus(for vehicleId: UUID) async throws -> [GeofenceStatus] {
        // Fetch the most recent entry events for this vehicle
        let entryEvents: [GeofenceEvent] = try await client
            .from("geofence_events")
            .select()
            .eq("vehicle_id", value: vehicleId.uuidString)
            .eq("event_type", value: "entry")
            .order("timestamp", ascending: false)
            .execute()
            .value
        
        // For each entry event, check if there's a corresponding exit event
        var statuses: [GeofenceStatus] = []
        
        for entryEvent in entryEvents {
            // Check if there's an exit event after this entry
            let exitEvents: [GeofenceEvent] = try await client
                .from("geofence_events")
                .select()
                .eq("vehicle_id", value: vehicleId.uuidString)
                .eq("geofence_id", value: entryEvent.geofence_id.uuidString)
                .eq("event_type", value: "exit")
                .gt("timestamp", value: entryEvent.timestamp.ISO8601Format())
                .order("timestamp", ascending: true)
                .limit(1)
                .execute()
                .value
            
            // If no exit event, vehicle is still inside
            if exitEvents.isEmpty {
                // Fetch geofence name
                let geofence = try await fetchGeofence(id: entryEvent.geofence_id)
                
                let status = GeofenceStatus(
                    vehicle_id: vehicleId,
                    geofence_id: entryEvent.geofence_id,
                    geofence_name: geofence.name,
                    entry_timestamp: entryEvent.timestamp,
                    is_inside: true
                )
                statuses.append(status)
            }
        }
        
        return statuses
    }
    
    struct VehicleLocationRow: Decodable {
        let vehicle_id: UUID
        let latitude: Double
        let longitude: Double
    }
    
    /// Fetch the latest location for all vehicles
    func fetchAllLatestVehicleLocations() async throws -> [UUID: CLLocationCoordinate2D] {
        let locations: [VehicleLocationRow] = try await client
            .from("vehicle_locations")
            .select("vehicle_id, latitude, longitude")
            .order("timestamp", ascending: false)
            .limit(500)
            .execute()
            .value
            
        var latestMap: [UUID: CLLocationCoordinate2D] = [:]
        // Since they are ordered by timestamp descending, the first one we encounter is the latest.
        for loc in locations {
            if latestMap[loc.vehicle_id] == nil {
                latestMap[loc.vehicle_id] = CLLocationCoordinate2D(latitude: loc.latitude, longitude: loc.longitude)
            }
        }
        return latestMap
    }
    
    // MARK: - Overlap Detection
    
    /// Find overlapping geofences using haversine formula
    func findOverlappingGeofences(latitude: Double, longitude: Double, radius: Double, excluding: UUID?) async throws -> [Geofence] {
        // Fetch all geofences
        var allGeofences = try await fetchGeofences()
        
        // Exclude the specified geofence if provided
        if let excludeId = excluding {
            allGeofences = allGeofences.filter { $0.id != excludeId }
        }
        
        // Calculate distances and find overlaps
        var overlappingGeofences: [Geofence] = []
        
        for geofence in allGeofences {
            let distance = haversineDistance(
                lat1: latitude,
                lon1: longitude,
                lat2: geofence.latitude,
                lon2: geofence.longitude
            )
            
            // Check if geofences overlap
            // Two circles overlap if distance between centers < sum of radii
            if distance < (radius + geofence.radius) {
                overlappingGeofences.append(geofence)
            }
        }
        
        return overlappingGeofences
    }
    
    // MARK: - Helper Methods
    
    /// Calculate distance between two coordinates using haversine formula
    private func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let R = 6371000.0 // Earth radius in meters
        let φ1 = lat1 * .pi / 180
        let φ2 = lat2 * .pi / 180
        let Δφ = (lat2 - lat1) * .pi / 180
        let Δλ = (lon2 - lon1) * .pi / 180
        
        let a = sin(Δφ / 2) * sin(Δφ / 2) +
                cos(φ1) * cos(φ2) *
                sin(Δλ / 2) * sin(Δλ / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return R * c // Distance in meters
    }
}

// MARK: - Supporting Types

struct GeofenceInsert: Codable {
    let name: String
    let latitude: Double
    let longitude: Double
    let radius: Double
    let type: GeofenceType
}

struct GeofenceUpdate: Codable {
    let name: String?
    let latitude: Double?
    let longitude: Double?
    let radius: Double?
    let type: GeofenceType?
    let updated_at: Date
    
    init(name: String? = nil, latitude: Double? = nil, longitude: Double? = nil, radius: Double? = nil, type: GeofenceType? = nil) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.type = type
        self.updated_at = Date()
    }
}

struct GeofenceAssignmentInsert: Codable {
    let geofence_id: UUID
    let vehicle_id: UUID
}

// MARK: - Errors

enum GeofenceServiceError: LocalizedError {
    case geofenceNotFound
    case creationFailed
    case updateFailed
    case deletionFailed
    case assignmentFailed
    
    var errorDescription: String? {
        switch self {
        case .geofenceNotFound:
            return "Geofence not found"
        case .creationFailed:
            return "Failed to create geofence"
        case .updateFailed:
            return "Failed to update geofence"
        case .deletionFailed:
            return "Failed to delete geofence"
        case .assignmentFailed:
            return "Failed to assign vehicles to geofence"
        }
    }
}
