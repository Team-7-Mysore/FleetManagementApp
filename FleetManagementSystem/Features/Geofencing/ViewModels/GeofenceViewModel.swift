//
//  GeofenceViewModel.swift
//  FleetManagementSystem
//
//  Created by Kiro on 2025
//

import Foundation
import SwiftUI
import Combine
import CoreLocation

@MainActor
final class GeofenceViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published private(set) var geofences: [Geofence] = []
    @Published private(set) var events: [GeofenceEvent] = []
    @Published private(set) var vehicleStatuses: [UUID: [GeofenceStatus]] = [:]
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // MARK: - Private Properties
    
    private let service: GeofenceService
    private var realtimeSubscription: Task<Void, Never>?
    
    // MARK: - Initialization
    
    nonisolated init(service: GeofenceService) {
        self.service = service
    }
    
    convenience init() {
        self.init(service: GeofenceService())
    }
    
    deinit {
        realtimeSubscription?.cancel()
    }
    
    // MARK: - CRUD Operations
    
    /// Load all geofences from the database
    func loadGeofences() async {
        isLoading = true
        errorMessage = nil
        
        do {
            geofences = try await service.fetchGeofences()
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to load geofences. Please try again."
            print("❌ Error loading geofences: \(error)")
        }
    }
    
    /// Create a new geofence with validation
    func createGeofence(
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        type: GeofenceType
    ) async {
        // Validate input
        let validationResult = validateGeofence(
            name: name,
            latitude: latitude,
            longitude: longitude,
            radius: radius
        )
        
        guard validationResult.isValid else {
            errorMessage = validationResult.errorMessage
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let insert = GeofenceInsert(
                name: name,
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                type: type
            )
            
            let newGeofence = try await service.createGeofence(insert)
            geofences.append(newGeofence)
            successMessage = "Geofence '\(name)' created successfully"
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to create geofence. Please try again."
            print("❌ Error creating geofence: \(error)")
        }
    }
    
    /// Update an existing geofence with validation
    func updateGeofence(_ geofence: Geofence) async {
        // Validate input
        let validationResult = validateGeofence(
            name: geofence.name,
            latitude: geofence.latitude,
            longitude: geofence.longitude,
            radius: geofence.radius
        )
        
        guard validationResult.isValid else {
            errorMessage = validationResult.errorMessage
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let update = GeofenceUpdate(
                name: geofence.name,
                latitude: geofence.latitude,
                longitude: geofence.longitude,
                radius: geofence.radius,
                type: geofence.type
            )
            
            try await service.updateGeofence(id: geofence.id, update)
            
            // Update local array
            if let index = geofences.firstIndex(where: { $0.id == geofence.id }) {
                geofences[index] = geofence
            }
            
            successMessage = "Geofence '\(geofence.name)' updated successfully"
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to update geofence. Please try again."
            print("❌ Error updating geofence: \(error)")
        }
    }
    
    /// Delete a geofence with confirmation
    func deleteGeofence(_ geofence: Geofence) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            try await service.deleteGeofence(id: geofence.id)
            
            // Remove from local array
            geofences.removeAll { $0.id == geofence.id }
            
            successMessage = "Geofence '\(geofence.name)' deleted successfully"
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to delete geofence. Please try again."
            print("❌ Error deleting geofence: \(error)")
        }
    }
    
    // MARK: - Assignment Operations
    
    /// Assign vehicles to a geofence
    func assignVehicles(_ vehicleIds: [UUID], to geofenceId: UUID) async {
        guard !vehicleIds.isEmpty else {
            errorMessage = "Please select at least one vehicle to assign"
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            try await service.assignVehicles(vehicleIds, to: geofenceId)
            successMessage = "Vehicles assigned successfully"
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to assign vehicles. Please try again."
            print("❌ Error assigning vehicles: \(error)")
        }
    }
    
    /// Remove a vehicle assignment from a geofence
    func removeVehicleAssignment(vehicleId: UUID, from geofenceId: UUID) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            try await service.removeAssignment(vehicleId: vehicleId, from: geofenceId)
            successMessage = "Vehicle assignment removed successfully"
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to remove vehicle assignment. Please try again."
            print("❌ Error removing vehicle assignment: \(error)")
        }
    }
    
    /// Load assigned vehicles for a geofence
    func loadAssignedVehicles(for geofenceId: UUID) async -> [Vehicle] {
        do {
            return try await service.fetchAssignedVehicles(for: geofenceId)
        } catch {
            errorMessage = "Failed to load assigned vehicles. Please try again."
            print("❌ Error loading assigned vehicles: \(error)")
            return []
        }
    }
    
    // MARK: - Event Operations
    
    /// Load events for a geofence with date filtering
    func loadEvents(for geofenceId: UUID, dateRange: DateRange) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let (startDate, endDate) = dateRange.dates
            events = try await service.fetchEvents(for: geofenceId, from: startDate, to: endDate)
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to load events. Please try again."
            print("❌ Error loading events: \(error)")
        }
    }
    
    @Published private(set) var vehicleLocations: [UUID: CLLocationCoordinate2D] = [:]

    /// Load vehicle status for a specific vehicle
    func loadVehicleStatus(for vehicleId: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let statuses = try await service.fetchVehicleStatus(for: vehicleId)
            vehicleStatuses[vehicleId] = statuses
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Failed to load vehicle status. Please try again."
            print("❌ Error loading vehicle status: \(error)")
        }
    }
    
    /// Load latest vehicle locations for the map
    func loadVehicleLocations() async {
        do {
            let locations = try await service.fetchAllLatestVehicleLocations()
            self.vehicleLocations = locations
        } catch {
            print("❌ Error loading vehicle locations: \(error)")
        }
    }
    
    /// Export events to CSV format
    func exportEvents(_ events: [GeofenceEvent]) -> URL? {
        guard !events.isEmpty else {
            errorMessage = "No events to export"
            return nil
        }
        
        // Create CSV content
        var csvContent = "Event Type,Vehicle,Geofence,Timestamp,Latitude,Longitude,Dwell Time\n"
        
        for event in events {
            let eventType = event.event_type == .entry ? "Entry" : "Exit"
            let vehicleId = event.vehicle_id.uuidString
            let geofenceId = event.geofence_id.uuidString
            let timestamp = ISO8601DateFormatter().string(from: event.timestamp)
            let latitude = String(format: "%.6f", event.latitude)
            let longitude = String(format: "%.6f", event.longitude)
            let dwellTime = event.formattedDwellTime ?? "N/A"
            
            csvContent += "\(eventType),\(vehicleId),\(geofenceId),\(timestamp),\(latitude),\(longitude),\(dwellTime)\n"
        }
        
        // Write to temporary file
        let fileName = "geofence_events_\(Date().timeIntervalSince1970).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        do {
            try csvContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            errorMessage = "Failed to export events. Please try again."
            print("❌ Error exporting events: \(error)")
            return nil
        }
    }
    
    // MARK: - Validation
    
    /// Validate geofence input parameters
    func validateGeofence(
        name: String,
        latitude: Double,
        longitude: Double,
        radius: Double
    ) -> ValidationResult {
        // Validate name length (3-100 characters)
        if name.count < 3 {
            return ValidationResult(isValid: false, errorMessage: "Geofence name must be at least 3 characters")
        }
        
        if name.count > 100 {
            return ValidationResult(isValid: false, errorMessage: "Geofence name must be no more than 100 characters")
        }
        
        // Validate latitude range (-90 to 90)
        if latitude < -90 || latitude > 90 {
            return ValidationResult(isValid: false, errorMessage: "Latitude must be between -90 and 90 degrees")
        }
        
        // Validate longitude range (-180 to 180)
        if longitude < -180 || longitude > 180 {
            return ValidationResult(isValid: false, errorMessage: "Longitude must be between -180 and 180 degrees")
        }
        
        // Validate radius range (50-10000 meters)
        if radius < 50 {
            return ValidationResult(isValid: false, errorMessage: "Radius must be at least 50 meters")
        }
        
        if radius > 10000 {
            return ValidationResult(isValid: false, errorMessage: "Radius must be no more than 10,000 meters")
        }
        
        return ValidationResult(isValid: true, errorMessage: nil)
    }
    
    /// Check for overlapping geofences
    func checkOverlaps(
        latitude: Double,
        longitude: Double,
        radius: Double,
        excluding: UUID?
    ) async -> [Geofence] {
        do {
            return try await service.findOverlappingGeofences(
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                excluding: excluding
            )
        } catch {
            errorMessage = "Failed to check for overlaps. Please try again."
            print("❌ Error checking overlaps: \(error)")
            return []
        }
    }
    
    // MARK: - Realtime Subscriptions
    
    /// Subscribe to geofence updates from the database
    func subscribeToGeofenceUpdates() {
        // Note: Supabase realtime subscriptions would be implemented here
        // For now, this is a placeholder for future implementation
        realtimeSubscription = Task {
            // Implement realtime subscription logic
            // This would listen to changes in the geofences table
            // and update the local geofences array accordingly
        }
    }
    
    /// Unsubscribe from realtime updates
    func unsubscribe() {
        realtimeSubscription?.cancel()
        realtimeSubscription = nil
    }
}

// MARK: - Supporting Types

/// Validation result for geofence input
struct ValidationResult {
    let isValid: Bool
    let errorMessage: String?
}

/// Date range options for event filtering
enum DateRange: Equatable {
    case last7Days
    case last30Days
    case last90Days
    case custom(start: Date, end: Date)
    
    var dates: (start: Date, end: Date) {
        let now = Date()
        let calendar = Calendar.current
        
        switch self {
        case .last7Days:
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            return (start, now)
        case .last30Days:
            let start = calendar.date(byAdding: .day, value: -30, to: now) ?? now
            return (start, now)
        case .last90Days:
            let start = calendar.date(byAdding: .day, value: -90, to: now) ?? now
            return (start, now)
        case .custom(let start, let end):
            return (start, end)
        }
    }
    
    var displayName: String {
        switch self {
        case .last7Days:
            return "Last 7 Days"
        case .last30Days:
            return "Last 30 Days"
        case .last90Days:
            return "Last 90 Days"
        case .custom:
            return "Custom Range"
        }
    }
}

