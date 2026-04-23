//
//  GeofenceViewModelTests.swift
//  FleetManagementSystemTests
//
//  Created by Kiro on 2025
//

import XCTest
@testable import FleetManagementSystem

@MainActor
final class GeofenceViewModelTests: XCTestCase {
    
    var viewModel: GeofenceViewModel!
    var mockService: MockGeofenceService!
    
    override func setUp() async throws {
        try await super.setUp()
        mockService = MockGeofenceService()
        viewModel = GeofenceViewModel(service: mockService)
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockService = nil
        try await super.tearDown()
    }
    
    // MARK: - Load Geofences Tests
    
    func testLoadGeofencesSuccess() async {
        // Given
        let expectedGeofences = [
            createMockGeofence(name: "Depot 1", type: .depot),
            createMockGeofence(name: "Delivery Zone", type: .delivery)
        ]
        mockService.mockGeofences = expectedGeofences
        
        // When
        await viewModel.loadGeofences()
        
        // Then
        XCTAssertEqual(viewModel.geofences.count, 2)
        XCTAssertEqual(viewModel.geofences[0].name, "Depot 1")
        XCTAssertEqual(viewModel.geofences[1].name, "Delivery Zone")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLoadGeofencesFailure() async {
        // Given
        mockService.shouldThrowError = true
        
        // When
        await viewModel.loadGeofences()
        
        // Then
        XCTAssertEqual(viewModel.geofences.count, 0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "Failed to load geofences. Please try again.")
    }
    
    // MARK: - Create Geofence Tests
    
    func testCreateGeofenceSuccess() async {
        // Given
        let name = "New Geofence"
        let latitude = 40.7128
        let longitude = -74.0060
        let radius = 500.0
        let type = GeofenceType.depot
        
        let expectedGeofence = createMockGeofence(
            name: name,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            type: type
        )
        mockService.mockCreatedGeofence = expectedGeofence
        
        // When
        await viewModel.createGeofence(
            name: name,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            type: type
        )
        
        // Then
        XCTAssertEqual(viewModel.geofences.count, 1)
        XCTAssertEqual(viewModel.geofences[0].name, name)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.successMessage, "Geofence 'New Geofence' created successfully")
    }
    
    func testCreateGeofenceValidationFailure() async {
        // Given - invalid name (too short)
        let name = "AB"
        let latitude = 40.7128
        let longitude = -74.0060
        let radius = 500.0
        let type = GeofenceType.depot
        
        // When
        await viewModel.createGeofence(
            name: name,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            type: type
        )
        
        // Then
        XCTAssertEqual(viewModel.geofences.count, 0)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "Geofence name must be at least 3 characters")
    }
    
    func testCreateGeofenceServiceFailure() async {
        // Given
        mockService.shouldThrowError = true
        
        // When
        await viewModel.createGeofence(
            name: "Valid Name",
            latitude: 40.7128,
            longitude: -74.0060,
            radius: 500.0,
            type: .depot
        )
        
        // Then
        XCTAssertEqual(viewModel.geofences.count, 0)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "Failed to create geofence. Please try again.")
    }
    
    // MARK: - Update Geofence Tests
    
    func testUpdateGeofenceSuccess() async {
        // Given
        let originalGeofence = createMockGeofence(name: "Original", type: .depot)
        viewModel.geofences = [originalGeofence]
        
        let updatedGeofence = Geofence(
            id: originalGeofence.id,
            name: "Updated",
            latitude: originalGeofence.latitude,
            longitude: originalGeofence.longitude,
            radius: originalGeofence.radius,
            type: originalGeofence.type,
            created_at: originalGeofence.created_at,
            updated_at: Date()
        )
        
        // When
        await viewModel.updateGeofence(updatedGeofence)
        
        // Then
        XCTAssertEqual(viewModel.geofences.count, 1)
        XCTAssertEqual(viewModel.geofences[0].name, "Updated")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.successMessage, "Geofence 'Updated' updated successfully")
    }
    
    func testUpdateGeofenceValidationFailure() async {
        // Given - invalid latitude
        let geofence = createMockGeofence(name: "Test", type: .depot)
        let invalidGeofence = Geofence(
            id: geofence.id,
            name: geofence.name,
            latitude: 91.0, // Invalid
            longitude: geofence.longitude,
            radius: geofence.radius,
            type: geofence.type,
            created_at: geofence.created_at,
            updated_at: Date()
        )
        
        // When
        await viewModel.updateGeofence(invalidGeofence)
        
        // Then
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "Latitude must be between -90 and 90 degrees")
    }
    
    // MARK: - Delete Geofence Tests
    
    func testDeleteGeofenceSuccess() async {
        // Given
        let geofence = createMockGeofence(name: "To Delete", type: .depot)
        viewModel.geofences = [geofence]
        
        // When
        await viewModel.deleteGeofence(geofence)
        
        // Then
        XCTAssertEqual(viewModel.geofences.count, 0)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.successMessage, "Geofence 'To Delete' deleted successfully")
    }
    
    func testDeleteGeofenceFailure() async {
        // Given
        let geofence = createMockGeofence(name: "To Delete", type: .depot)
        viewModel.geofences = [geofence]
        mockService.shouldThrowError = true
        
        // When
        await viewModel.deleteGeofence(geofence)
        
        // Then
        XCTAssertEqual(viewModel.geofences.count, 1) // Should not be removed
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "Failed to delete geofence. Please try again.")
    }
    
    // MARK: - Validation Tests
    
    func testValidateGeofenceNameTooShort() {
        // Given
        let name = "AB"
        
        // When
        let result = viewModel.validateGeofence(
            name: name,
            latitude: 40.7128,
            longitude: -74.0060,
            radius: 500
        )
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Geofence name must be at least 3 characters")
    }
    
    func testValidateGeofenceNameTooLong() {
        // Given
        let name = String(repeating: "A", count: 101)
        
        // When
        let result = viewModel.validateGeofence(
            name: name,
            latitude: 40.7128,
            longitude: -74.0060,
            radius: 500
        )
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Geofence name must be no more than 100 characters")
    }
    
    func testValidateGeofenceLatitudeTooLow() {
        // Given
        let latitude = -91.0
        
        // When
        let result = viewModel.validateGeofence(
            name: "Valid Name",
            latitude: latitude,
            longitude: -74.0060,
            radius: 500
        )
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Latitude must be between -90 and 90 degrees")
    }
    
    func testValidateGeofenceLatitudeTooHigh() {
        // Given
        let latitude = 91.0
        
        // When
        let result = viewModel.validateGeofence(
            name: "Valid Name",
            latitude: latitude,
            longitude: -74.0060,
            radius: 500
        )
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Latitude must be between -90 and 90 degrees")
    }
    
    func testValidateGeofenceLongitudeTooLow() {
        // Given
        let longitude = -181.0
        
        // When
        let result = viewModel.validateGeofence(
            name: "Valid Name",
            latitude: 40.7128,
            longitude: longitude,
            radius: 500
        )
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Longitude must be between -180 and 180 degrees")
    }
    
    func testValidateGeofenceLongitudeTooHigh() {
        // Given
        let longitude = 181.0
        
        // When
        let result = viewModel.validateGeofence(
            name: "Valid Name",
            latitude: 40.7128,
            longitude: longitude,
            radius: 500
        )
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Longitude must be between -180 and 180 degrees")
    }
    
    func testValidateGeofenceRadiusTooSmall() {
        // Given
        let radius = 49.0
        
        // When
        let result = viewModel.validateGeofence(
            name: "Valid Name",
            latitude: 40.7128,
            longitude: -74.0060,
            radius: radius
        )
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Radius must be at least 50 meters")
    }
    
    func testValidateGeofenceRadiusTooLarge() {
        // Given
        let radius = 10001.0
        
        // When
        let result = viewModel.validateGeofence(
            name: "Valid Name",
            latitude: 40.7128,
            longitude: -74.0060,
            radius: radius
        )
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errorMessage, "Radius must be no more than 10,000 meters")
    }
    
    func testValidateGeofenceValid() {
        // Given
        let name = "Valid Geofence"
        let latitude = 40.7128
        let longitude = -74.0060
        let radius = 500.0
        
        // When
        let result = viewModel.validateGeofence(
            name: name,
            latitude: latitude,
            longitude: longitude,
            radius: radius
        )
        
        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.errorMessage)
    }
    
    func testValidateGeofenceBoundaryValues() {
        // Test minimum valid values
        let minResult = viewModel.validateGeofence(
            name: "ABC",
            latitude: -90,
            longitude: -180,
            radius: 50
        )
        XCTAssertTrue(minResult.isValid)
        
        // Test maximum valid values
        let maxResult = viewModel.validateGeofence(
            name: String(repeating: "A", count: 100),
            latitude: 90,
            longitude: 180,
            radius: 10000
        )
        XCTAssertTrue(maxResult.isValid)
    }
    
    // MARK: - Overlap Detection Tests
    
    func testCheckOverlapsWithOverlap() async {
        // Given
        let overlappingGeofence = createMockGeofence(
            name: "Overlapping",
            latitude: 40.7138,
            longitude: -74.0060,
            radius: 1000,
            type: .depot
        )
        mockService.mockOverlappingGeofences = [overlappingGeofence]
        
        // When
        let overlaps = await viewModel.checkOverlaps(
            latitude: 40.7128,
            longitude: -74.0060,
            radius: 1000,
            excluding: nil
        )
        
        // Then
        XCTAssertEqual(overlaps.count, 1)
        XCTAssertEqual(overlaps[0].name, "Overlapping")
    }
    
    func testCheckOverlapsNoOverlap() async {
        // Given
        mockService.mockOverlappingGeofences = []
        
        // When
        let overlaps = await viewModel.checkOverlaps(
            latitude: 40.7128,
            longitude: -74.0060,
            radius: 100,
            excluding: nil
        )
        
        // Then
        XCTAssertEqual(overlaps.count, 0)
    }
    
    func testCheckOverlapsWithExclusion() async {
        // Given
        let excludedId = UUID()
        mockService.mockOverlappingGeofences = []
        
        // When
        let overlaps = await viewModel.checkOverlaps(
            latitude: 40.7128,
            longitude: -74.0060,
            radius: 1000,
            excluding: excludedId
        )
        
        // Then
        XCTAssertEqual(overlaps.count, 0)
    }
    
    // MARK: - Event Operations Tests
    
    func testLoadEventsSuccess() async {
        // Given
        let geofenceId = UUID()
        let expectedEvents = [
            createMockEvent(geofenceId: geofenceId, eventType: .entry),
            createMockEvent(geofenceId: geofenceId, eventType: .exit)
        ]
        mockService.mockEvents = expectedEvents
        
        // When
        await viewModel.loadEvents(for: geofenceId, dateRange: .last7Days)
        
        // Then
        XCTAssertEqual(viewModel.events.count, 2)
        XCTAssertEqual(viewModel.events[0].event_type, .entry)
        XCTAssertEqual(viewModel.events[1].event_type, .exit)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLoadEventsFailure() async {
        // Given
        mockService.shouldThrowError = true
        
        // When
        await viewModel.loadEvents(for: UUID(), dateRange: .last7Days)
        
        // Then
        XCTAssertEqual(viewModel.events.count, 0)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "Failed to load events. Please try again.")
    }
    
    func testLoadVehicleStatusSuccess() async {
        // Given
        let vehicleId = UUID()
        let expectedStatuses = [
            createMockStatus(vehicleId: vehicleId, geofenceName: "Depot 1")
        ]
        mockService.mockVehicleStatuses = expectedStatuses
        
        // When
        await viewModel.loadVehicleStatus(for: vehicleId)
        
        // Then
        XCTAssertEqual(viewModel.vehicleStatuses[vehicleId]?.count, 1)
        XCTAssertEqual(viewModel.vehicleStatuses[vehicleId]?[0].geofence_name, "Depot 1")
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLoadVehicleStatusFailure() async {
        // Given
        mockService.shouldThrowError = true
        
        // When
        await viewModel.loadVehicleStatus(for: UUID())
        
        // Then
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "Failed to load vehicle status. Please try again.")
    }
    
    // MARK: - CSV Export Tests
    
    func testExportEventsSuccess() {
        // Given
        let events = [
            createMockEvent(geofenceId: UUID(), eventType: .entry),
            createMockEvent(geofenceId: UUID(), eventType: .exit)
        ]
        
        // When
        let url = viewModel.exportEvents(events)
        
        // Then
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.path.contains(".csv"))
        
        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: url!.path))
        
        // Clean up
        try? FileManager.default.removeItem(at: url!)
    }
    
    func testExportEventsEmpty() {
        // Given
        let events: [GeofenceEvent] = []
        
        // When
        let url = viewModel.exportEvents(events)
        
        // Then
        XCTAssertNil(url)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "No events to export")
    }
    
    func testExportEventsCSVFormat() {
        // Given
        let geofenceId = UUID()
        let vehicleId = UUID()
        let timestamp = Date()
        let events = [
            GeofenceEvent(
                id: UUID(),
                geofence_id: geofenceId,
                vehicle_id: vehicleId,
                event_type: .entry,
                timestamp: timestamp,
                latitude: 40.7128,
                longitude: -74.0060,
                dwell_time: nil
            ),
            GeofenceEvent(
                id: UUID(),
                geofence_id: geofenceId,
                vehicle_id: vehicleId,
                event_type: .exit,
                timestamp: timestamp.addingTimeInterval(3600),
                latitude: 40.7128,
                longitude: -74.0060,
                dwell_time: 3600
            )
        ]
        
        // When
        let url = viewModel.exportEvents(events)
        
        // Then
        XCTAssertNotNil(url)
        
        // Read CSV content
        if let url = url,
           let content = try? String(contentsOf: url, encoding: .utf8) {
            // Verify headers
            XCTAssertTrue(content.contains("Event Type,Vehicle,Geofence,Timestamp,Latitude,Longitude,Dwell Time"))
            
            // Verify entry event
            XCTAssertTrue(content.contains("Entry"))
            
            // Verify exit event
            XCTAssertTrue(content.contains("Exit"))
            XCTAssertTrue(content.contains("1h 0m"))
            
            // Verify coordinates
            XCTAssertTrue(content.contains("40.712800"))
            XCTAssertTrue(content.contains("-74.006000"))
        }
        
        // Clean up
        if let url = url {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    // MARK: - Assignment Operations Tests
    
    func testAssignVehiclesSuccess() async {
        // Given
        let vehicleIds = [UUID(), UUID()]
        let geofenceId = UUID()
        
        // When
        await viewModel.assignVehicles(vehicleIds, to: geofenceId)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.successMessage, "Vehicles assigned successfully")
    }
    
    func testAssignVehiclesEmpty() async {
        // Given
        let vehicleIds: [UUID] = []
        let geofenceId = UUID()
        
        // When
        await viewModel.assignVehicles(vehicleIds, to: geofenceId)
        
        // Then
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "Please select at least one vehicle to assign")
    }
    
    func testAssignVehiclesFailure() async {
        // Given
        mockService.shouldThrowError = true
        let vehicleIds = [UUID()]
        let geofenceId = UUID()
        
        // When
        await viewModel.assignVehicles(vehicleIds, to: geofenceId)
        
        // Then
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "Failed to assign vehicles. Please try again.")
    }
    
    func testRemoveVehicleAssignmentSuccess() async {
        // Given
        let vehicleId = UUID()
        let geofenceId = UUID()
        
        // When
        await viewModel.removeVehicleAssignment(vehicleId: vehicleId, from: geofenceId)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.successMessage, "Vehicle assignment removed successfully")
    }
    
    func testRemoveVehicleAssignmentFailure() async {
        // Given
        mockService.shouldThrowError = true
        let vehicleId = UUID()
        let geofenceId = UUID()
        
        // When
        await viewModel.removeVehicleAssignment(vehicleId: vehicleId, from: geofenceId)
        
        // Then
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "Failed to remove vehicle assignment. Please try again.")
    }
    
    func testLoadAssignedVehiclesSuccess() async {
        // Given
        let geofenceId = UUID()
        let expectedVehicles = [
            createMockVehicle(id: UUID(), name: "Vehicle 1"),
            createMockVehicle(id: UUID(), name: "Vehicle 2")
        ]
        mockService.mockVehicles = expectedVehicles
        
        // When
        let vehicles = await viewModel.loadAssignedVehicles(for: geofenceId)
        
        // Then
        XCTAssertEqual(vehicles.count, 2)
        XCTAssertEqual(vehicles[0].name, "Vehicle 1")
        XCTAssertEqual(vehicles[1].name, "Vehicle 2")
    }
    
    func testLoadAssignedVehiclesFailure() async {
        // Given
        mockService.shouldThrowError = true
        
        // When
        let vehicles = await viewModel.loadAssignedVehicles(for: UUID())
        
        // Then
        XCTAssertEqual(vehicles.count, 0)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "Failed to load assigned vehicles. Please try again.")
    }
    
    // MARK: - Date Range Tests
    
    func testDateRangeLast7Days() {
        // Given
        let dateRange = DateRange.last7Days
        
        // When
        let (start, end) = dateRange.dates
        
        // Then
        let daysDifference = Calendar.current.dateComponents([.day], from: start, to: end).day
        XCTAssertEqual(daysDifference, 7)
        XCTAssertEqual(dateRange.displayName, "Last 7 Days")
    }
    
    func testDateRangeLast30Days() {
        // Given
        let dateRange = DateRange.last30Days
        
        // When
        let (start, end) = dateRange.dates
        
        // Then
        let daysDifference = Calendar.current.dateComponents([.day], from: start, to: end).day
        XCTAssertEqual(daysDifference, 30)
        XCTAssertEqual(dateRange.displayName, "Last 30 Days")
    }
    
    func testDateRangeLast90Days() {
        // Given
        let dateRange = DateRange.last90Days
        
        // When
        let (start, end) = dateRange.dates
        
        // Then
        let daysDifference = Calendar.current.dateComponents([.day], from: start, to: end).day
        XCTAssertEqual(daysDifference, 90)
        XCTAssertEqual(dateRange.displayName, "Last 90 Days")
    }
    
    func testDateRangeCustom() {
        // Given
        let startDate = Date().addingTimeInterval(-86400 * 14) // 14 days ago
        let endDate = Date()
        let dateRange = DateRange.custom(start: startDate, end: endDate)
        
        // When
        let (start, end) = dateRange.dates
        
        // Then
        XCTAssertEqual(start, startDate)
        XCTAssertEqual(end, endDate)
        XCTAssertEqual(dateRange.displayName, "Custom Range")
    }
    
    // MARK: - Helper Methods
    
    private func createMockGeofence(
        id: UUID = UUID(),
        name: String,
        latitude: Double = 40.7128,
        longitude: Double = -74.0060,
        radius: Double = 500,
        type: GeofenceType
    ) -> Geofence {
        return Geofence(
            id: id,
            name: name,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            type: type,
            created_at: Date(),
            updated_at: Date()
        )
    }
    
    private func createMockEvent(
        id: UUID = UUID(),
        geofenceId: UUID,
        vehicleId: UUID = UUID(),
        eventType: GeofenceEvent.EventType,
        timestamp: Date = Date()
    ) -> GeofenceEvent {
        return GeofenceEvent(
            id: id,
            geofence_id: geofenceId,
            vehicle_id: vehicleId,
            event_type: eventType,
            timestamp: timestamp,
            latitude: 40.7128,
            longitude: -74.0060,
            dwell_time: eventType == .exit ? 3600 : nil
        )
    }
    
    private func createMockStatus(
        vehicleId: UUID,
        geofenceId: UUID = UUID(),
        geofenceName: String
    ) -> GeofenceStatus {
        return GeofenceStatus(
            vehicle_id: vehicleId,
            geofence_id: geofenceId,
            geofence_name: geofenceName,
            entry_timestamp: Date(),
            is_inside: true
        )
    }
    
    private func createMockVehicle(
        id: UUID,
        name: String
    ) -> Vehicle {
        return Vehicle(
            id: id,
            name: name,
            registrationNumber: "ABC-123",
            vehicleType: "Truck"
        )
    }
}

// MARK: - Mock Geofence Service

class MockGeofenceService: GeofenceService {
    var mockGeofences: [Geofence] = []
    var mockCreatedGeofence: Geofence?
    var mockEvents: [GeofenceEvent] = []
    var mockVehicleStatuses: [GeofenceStatus] = []
    var mockVehicles: [Vehicle] = []
    var mockOverlappingGeofences: [Geofence] = []
    var shouldThrowError = false
    
    override func fetchGeofences() async throws -> [Geofence] {
        if shouldThrowError {
            throw GeofenceServiceError.geofenceNotFound
        }
        return mockGeofences
    }
    
    override func createGeofence(_ geofence: GeofenceInsert) async throws -> Geofence {
        if shouldThrowError {
            throw GeofenceServiceError.creationFailed
        }
        return mockCreatedGeofence ?? Geofence(
            id: UUID(),
            name: geofence.name,
            latitude: geofence.latitude,
            longitude: geofence.longitude,
            radius: geofence.radius,
            type: geofence.type,
            created_at: Date(),
            updated_at: Date()
        )
    }
    
    override func updateGeofence(id: UUID, _ update: GeofenceUpdate) async throws {
        if shouldThrowError {
            throw GeofenceServiceError.updateFailed
        }
    }
    
    override func deleteGeofence(id: UUID) async throws {
        if shouldThrowError {
            throw GeofenceServiceError.deletionFailed
        }
    }
    
    override func assignVehicles(_ vehicleIds: [UUID], to geofenceId: UUID) async throws {
        if shouldThrowError {
            throw GeofenceServiceError.assignmentFailed
        }
    }
    
    override func removeAssignment(vehicleId: UUID, from geofenceId: UUID) async throws {
        if shouldThrowError {
            throw GeofenceServiceError.assignmentFailed
        }
    }
    
    override func fetchAssignedVehicles(for geofenceId: UUID) async throws -> [Vehicle] {
        if shouldThrowError {
            throw GeofenceServiceError.geofenceNotFound
        }
        return mockVehicles
    }
    
    override func fetchEvents(for geofenceId: UUID, from startDate: Date, to endDate: Date) async throws -> [GeofenceEvent] {
        if shouldThrowError {
            throw GeofenceServiceError.geofenceNotFound
        }
        return mockEvents
    }
    
    override func fetchVehicleStatus(for vehicleId: UUID) async throws -> [GeofenceStatus] {
        if shouldThrowError {
            throw GeofenceServiceError.geofenceNotFound
        }
        return mockVehicleStatuses
    }
    
    override func findOverlappingGeofences(latitude: Double, longitude: Double, radius: Double, excluding: UUID?) async throws -> [Geofence] {
        if shouldThrowError {
            throw GeofenceServiceError.geofenceNotFound
        }
        return mockOverlappingGeofences
    }
}
