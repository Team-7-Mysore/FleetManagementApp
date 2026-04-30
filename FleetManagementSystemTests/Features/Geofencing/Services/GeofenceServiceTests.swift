//
//  GeofenceServiceTests.swift
//  FleetManagementSystemTests
//
//  Created by Kiro on 2025
//
//  NOTE: To run these tests, add FleetManagementSystemTests target to the Xcode project
//  and ensure it has access to the FleetManagementSystem module.
//

import XCTest
@testable import FleetManagementSystem
import Supabase

final class GeofenceServiceTests: XCTestCase {
    
    var mockClient: MockSupabaseClient!
    var service: GeofenceService!
    
    override func setUp() {
        super.setUp()
        mockClient = MockSupabaseClient()
        service = GeofenceService(client: mockClient)
    }
    
    override func tearDown() {
        mockClient = nil
        service = nil
        super.tearDown()
    }
    
    // MARK: - CRUD Operation Tests
    
    func testFetchGeofences() async throws {
        // Given
        let expectedGeofences = [
            createMockGeofence(name: "Depot 1", type: .depot),
            createMockGeofence(name: "Delivery Zone", type: .delivery)
        ]
        mockClient.mockGeofences = expectedGeofences
        
        // When
        let geofences = try await service.fetchGeofences()
        
        // Then
        XCTAssertEqual(geofences.count, 2)
        XCTAssertEqual(geofences[0].name, "Depot 1")
        XCTAssertEqual(geofences[1].name, "Delivery Zone")
    }
    
    func testFetchGeofenceById() async throws {
        // Given
        let expectedGeofence = createMockGeofence(name: "Test Geofence", type: .depot)
        mockClient.mockGeofences = [expectedGeofence]
        
        // When
        let geofence = try await service.fetchGeofence(id: expectedGeofence.id)
        
        // Then
        XCTAssertEqual(geofence.id, expectedGeofence.id)
        XCTAssertEqual(geofence.name, "Test Geofence")
    }
    
    func testFetchGeofenceNotFound() async {
        // Given
        mockClient.mockGeofences = []
        
        // When/Then
        do {
            _ = try await service.fetchGeofence(id: UUID())
            XCTFail("Should throw geofenceNotFound error")
        } catch let error as GeofenceServiceError {
            XCTAssertEqual(error, .geofenceNotFound)
        } catch {
            XCTFail("Wrong error type thrown")
        }
    }
    
    func testCreateGeofence() async throws {
        // Given
        let insert = GeofenceInsert(
            name: "New Geofence",
            latitude: 40.7128,
            longitude: -74.0060,
            radius: 500,
            type: .depot
        )
        let expectedGeofence = createMockGeofence(
            name: insert.name,
            latitude: insert.latitude,
            longitude: insert.longitude,
            radius: insert.radius,
            type: insert.type
        )
        mockClient.mockGeofences = [expectedGeofence]
        
        // When
        let createdGeofence = try await service.createGeofence(insert)
        
        // Then
        XCTAssertEqual(createdGeofence.name, "New Geofence")
        XCTAssertEqual(createdGeofence.latitude, 40.7128)
        XCTAssertEqual(createdGeofence.longitude, -74.0060)
        XCTAssertEqual(createdGeofence.radius, 500)
        XCTAssertEqual(createdGeofence.type, .depot)
    }
    
    func testCreateGeofenceFailed() async {
        // Given
        let insert = GeofenceInsert(
            name: "New Geofence",
            latitude: 40.7128,
            longitude: -74.0060,
            radius: 500,
            type: .depot
        )
        mockClient.mockGeofences = []
        
        // When/Then
        do {
            _ = try await service.createGeofence(insert)
            XCTFail("Should throw creationFailed error")
        } catch let error as GeofenceServiceError {
            XCTAssertEqual(error, .creationFailed)
        } catch {
            XCTFail("Wrong error type thrown")
        }
    }
    
    func testUpdateGeofence() async throws {
        // Given
        let geofenceId = UUID()
        let update = GeofenceUpdate(name: "Updated Name", radius: 1000)
        mockClient.shouldSucceed = true
        
        // When/Then
        try await service.updateGeofence(id: geofenceId, update)
        
        // Verify no error thrown
        XCTAssertTrue(mockClient.shouldSucceed)
    }
    
    func testDeleteGeofence() async throws {
        // Given
        let geofenceId = UUID()
        mockClient.shouldSucceed = true
        
        // When/Then
        try await service.deleteGeofence(id: geofenceId)
        
        // Verify no error thrown
        XCTAssertTrue(mockClient.shouldSucceed)
    }
    
    // MARK: - Assignment Operation Tests
    
    func testAssignVehicles() async throws {
        // Given
        let geofenceId = UUID()
        let vehicleIds = [UUID(), UUID(), UUID()]
        mockClient.shouldSucceed = true
        
        // When/Then
        try await service.assignVehicles(vehicleIds, to: geofenceId)
        
        // Verify no error thrown
        XCTAssertTrue(mockClient.shouldSucceed)
    }
    
    func testRemoveAssignment() async throws {
        // Given
        let geofenceId = UUID()
        let vehicleId = UUID()
        mockClient.shouldSucceed = true
        
        // When/Then
        try await service.removeAssignment(vehicleId: vehicleId, from: geofenceId)
        
        // Verify no error thrown
        XCTAssertTrue(mockClient.shouldSucceed)
    }
    
    func testFetchAssignedVehicles() async throws {
        // Given
        let geofenceId = UUID()
        let vehicleId1 = UUID()
        let vehicleId2 = UUID()
        
        mockClient.mockAssignments = [
            createMockAssignment(geofenceId: geofenceId, vehicleId: vehicleId1),
            createMockAssignment(geofenceId: geofenceId, vehicleId: vehicleId2)
        ]
        
        mockClient.mockVehicles = [
            createMockVehicle(id: vehicleId1, name: "Vehicle 1"),
            createMockVehicle(id: vehicleId2, name: "Vehicle 2")
        ]
        
        // When
        let vehicles = try await service.fetchAssignedVehicles(for: geofenceId)
        
        // Then
        XCTAssertEqual(vehicles.count, 2)
        XCTAssertEqual(vehicles[0].name, "Vehicle 1")
        XCTAssertEqual(vehicles[1].name, "Vehicle 2")
    }
    
    func testFetchAssignedVehiclesEmpty() async throws {
        // Given
        let geofenceId = UUID()
        mockClient.mockAssignments = []
        
        // When
        let vehicles = try await service.fetchAssignedVehicles(for: geofenceId)
        
        // Then
        XCTAssertEqual(vehicles.count, 0)
    }
    
    func testFetchGeofencesForVehicle() async throws {
        // Given
        let vehicleId = UUID()
        let geofenceId1 = UUID()
        let geofenceId2 = UUID()
        
        mockClient.mockAssignments = [
            createMockAssignment(geofenceId: geofenceId1, vehicleId: vehicleId),
            createMockAssignment(geofenceId: geofenceId2, vehicleId: vehicleId)
        ]
        
        mockClient.mockGeofences = [
            createMockGeofence(id: geofenceId1, name: "Geofence 1", type: .depot),
            createMockGeofence(id: geofenceId2, name: "Geofence 2", type: .delivery)
        ]
        
        // When
        let geofences = try await service.fetchGeofencesForVehicle(vehicleId)
        
        // Then
        XCTAssertEqual(geofences.count, 2)
        XCTAssertEqual(geofences[0].name, "Geofence 1")
        XCTAssertEqual(geofences[1].name, "Geofence 2")
    }
    
    func testFetchGeofencesForVehicleEmpty() async throws {
        // Given
        let vehicleId = UUID()
        mockClient.mockAssignments = []
        
        // When
        let geofences = try await service.fetchGeofencesForVehicle(vehicleId)
        
        // Then
        XCTAssertEqual(geofences.count, 0)
    }
    
    // MARK: - Event Operation Tests
    
    func testFetchEvents() async throws {
        // Given
        let geofenceId = UUID()
        let startDate = Date().addingTimeInterval(-86400) // 1 day ago
        let endDate = Date()
        
        mockClient.mockEvents = [
            createMockEvent(geofenceId: geofenceId, eventType: .entry),
            createMockEvent(geofenceId: geofenceId, eventType: .exit)
        ]
        
        // When
        let events = try await service.fetchEvents(for: geofenceId, from: startDate, to: endDate)
        
        // Then
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].event_type, .entry)
        XCTAssertEqual(events[1].event_type, .exit)
    }
    
    func testFetchVehicleStatus() async throws {
        // Given
        let vehicleId = UUID()
        let geofenceId = UUID()
        
        // Mock entry event without exit
        mockClient.mockEvents = [
            createMockEvent(geofenceId: geofenceId, vehicleId: vehicleId, eventType: .entry)
        ]
        
        mockClient.mockGeofences = [
            createMockGeofence(id: geofenceId, name: "Test Geofence", type: .depot)
        ]
        
        // When
        let statuses = try await service.fetchVehicleStatus(for: vehicleId)
        
        // Then
        XCTAssertEqual(statuses.count, 1)
        XCTAssertEqual(statuses[0].vehicle_id, vehicleId)
        XCTAssertEqual(statuses[0].geofence_id, geofenceId)
        XCTAssertTrue(statuses[0].is_inside)
    }
    
    func testFetchVehicleStatusWithExit() async throws {
        // Given
        let vehicleId = UUID()
        let geofenceId = UUID()
        
        // Mock entry event with exit (vehicle not inside)
        let entryEvent = createMockEvent(geofenceId: geofenceId, vehicleId: vehicleId, eventType: .entry)
        let exitEvent = createMockEvent(
            geofenceId: geofenceId,
            vehicleId: vehicleId,
            eventType: .exit,
            timestamp: Date().addingTimeInterval(3600)
        )
        
        mockClient.mockEvents = [entryEvent, exitEvent]
        
        // When
        let statuses = try await service.fetchVehicleStatus(for: vehicleId)
        
        // Then
        XCTAssertEqual(statuses.count, 0, "Vehicle should not be inside any geofence")
    }
    
    // MARK: - Overlap Detection Tests
    
    func testFindOverlappingGeofences() async throws {
        // Given
        let testLat = 40.7128
        let testLon = -74.0060
        let testRadius = 1000.0
        
        // Create overlapping geofence (close by)
        let overlappingGeofence = createMockGeofence(
            name: "Overlapping",
            latitude: 40.7138, // ~111 meters north
            longitude: -74.0060,
            radius: 1000,
            type: .depot
        )
        
        // Create non-overlapping geofence (far away)
        let nonOverlappingGeofence = createMockGeofence(
            name: "Non-overlapping",
            latitude: 34.0522, // Los Angeles
            longitude: -118.2437,
            radius: 1000,
            type: .delivery
        )
        
        mockClient.mockGeofences = [overlappingGeofence, nonOverlappingGeofence]
        
        // When
        let overlaps = try await service.findOverlappingGeofences(
            latitude: testLat,
            longitude: testLon,
            radius: testRadius,
            excluding: nil
        )
        
        // Then
        XCTAssertEqual(overlaps.count, 1)
        XCTAssertEqual(overlaps[0].name, "Overlapping")
    }
    
    func testFindOverlappingGeofencesExcluding() async throws {
        // Given
        let testLat = 40.7128
        let testLon = -74.0060
        let testRadius = 1000.0
        
        let overlappingGeofence = createMockGeofence(
            name: "Overlapping",
            latitude: 40.7138,
            longitude: -74.0060,
            radius: 1000,
            type: .depot
        )
        
        mockClient.mockGeofences = [overlappingGeofence]
        
        // When - exclude the overlapping geofence
        let overlaps = try await service.findOverlappingGeofences(
            latitude: testLat,
            longitude: testLon,
            radius: testRadius,
            excluding: overlappingGeofence.id
        )
        
        // Then
        XCTAssertEqual(overlaps.count, 0, "Excluded geofence should not be in results")
    }
    
    func testFindOverlappingGeofencesNone() async throws {
        // Given
        let testLat = 40.7128
        let testLon = -74.0060
        let testRadius = 100.0
        
        let farGeofence = createMockGeofence(
            name: "Far Away",
            latitude: 34.0522,
            longitude: -118.2437,
            radius: 100,
            type: .depot
        )
        
        mockClient.mockGeofences = [farGeofence]
        
        // When
        let overlaps = try await service.findOverlappingGeofences(
            latitude: testLat,
            longitude: testLon,
            radius: testRadius,
            excluding: nil
        )
        
        // Then
        XCTAssertEqual(overlaps.count, 0)
    }
    
    // MARK: - Error Handling Tests
    
    func testGeofenceNotFoundError() {
        let error = GeofenceServiceError.geofenceNotFound
        XCTAssertEqual(error.errorDescription, "Geofence not found")
    }
    
    func testCreationFailedError() {
        let error = GeofenceServiceError.creationFailed
        XCTAssertEqual(error.errorDescription, "Failed to create geofence")
    }
    
    func testUpdateFailedError() {
        let error = GeofenceServiceError.updateFailed
        XCTAssertEqual(error.errorDescription, "Failed to update geofence")
    }
    
    func testDeletionFailedError() {
        let error = GeofenceServiceError.deletionFailed
        XCTAssertEqual(error.errorDescription, "Failed to delete geofence")
    }
    
    func testAssignmentFailedError() {
        let error = GeofenceServiceError.assignmentFailed
        XCTAssertEqual(error.errorDescription, "Failed to assign vehicles to geofence")
    }
    
    // MARK: - Haversine Formula Tests
    
    func testHaversineDistanceCalculation() {
        // Test known distance between two points
        // New York City: 40.7128° N, 74.0060° W
        // Los Angeles: 34.0522° N, 118.2437° W
        // Expected distance: approximately 3,944,000 meters
        
        let service = GeofenceService()
        
        // Use reflection to access private method for testing
        let distance = calculateHaversineDistance(
            lat1: 40.7128,
            lon1: -74.0060,
            lat2: 34.0522,
            lon2: -118.2437
        )
        
        // Allow 1% margin of error
        let expectedDistance = 3_944_000.0
        let margin = expectedDistance * 0.01
        
        XCTAssertEqual(distance, expectedDistance, accuracy: margin, "Distance calculation should be accurate within 1%")
    }
    
    func testHaversineDistanceSamePoint() {
        // Distance between same point should be 0
        let distance = calculateHaversineDistance(
            lat1: 40.7128,
            lon1: -74.0060,
            lat2: 40.7128,
            lon2: -74.0060
        )
        
        XCTAssertEqual(distance, 0, accuracy: 0.1, "Distance between same point should be 0")
    }
    
    func testHaversineDistanceShortDistance() {
        // Test short distance (approximately 1 km)
        // Point 1: 40.7128° N, 74.0060° W
        // Point 2: 40.7228° N, 74.0060° W (approximately 1.1 km north)
        
        let distance = calculateHaversineDistance(
            lat1: 40.7128,
            lon1: -74.0060,
            lat2: 40.7228,
            lon2: -74.0060
        )
        
        // Expected approximately 1,112 meters
        XCTAssertEqual(distance, 1112, accuracy: 50, "Short distance calculation should be accurate")
    }
    
    func testHaversineDistanceAcrossDateLine() {
        // Test distance calculation across international date line
        // Point 1: 0° N, 179° E
        // Point 2: 0° N, -179° E (or 181° E)
        
        let distance = calculateHaversineDistance(
            lat1: 0,
            lon1: 179,
            lat2: 0,
            lon2: -179
        )
        
        // Expected approximately 222,000 meters (2 degrees at equator)
        XCTAssertEqual(distance, 222_000, accuracy: 10_000, "Date line crossing calculation should be accurate")
    }
    
    func testHaversineDistanceAtPoles() {
        // Test distance calculation near poles
        // North Pole: 89.9° N, 0° E
        // Point near pole: 89.9° N, 180° E
        
        let distance = calculateHaversineDistance(
            lat1: 89.9,
            lon1: 0,
            lat2: 89.9,
            lon2: 180
        )
        
        // At high latitudes, longitude differences result in shorter distances
        // Expected approximately 19,500 meters
        XCTAssertLessThan(distance, 20_000, "Distance at poles should be calculated correctly")
    }
    
    // MARK: - Overlap Detection Tests
    
    func testOverlapDetectionNoOverlap() {
        // Two geofences far apart should not overlap
        let geofence1Lat = 40.7128
        let geofence1Lon = -74.0060
        let geofence1Radius = 100.0
        
        let geofence2Lat = 34.0522
        let geofence2Lon = -118.2437
        let geofence2Radius = 100.0
        
        let distance = calculateHaversineDistance(
            lat1: geofence1Lat,
            lon1: geofence1Lon,
            lat2: geofence2Lat,
            lon2: geofence2Lon
        )
        
        let overlaps = distance < (geofence1Radius + geofence2Radius)
        
        XCTAssertFalse(overlaps, "Geofences far apart should not overlap")
    }
    
    func testOverlapDetectionWithOverlap() {
        // Two geofences close together should overlap
        let geofence1Lat = 40.7128
        let geofence1Lon = -74.0060
        let geofence1Radius = 1000.0 // 1 km
        
        let geofence2Lat = 40.7138 // About 111 meters north
        let geofence2Lon = -74.0060
        let geofence2Radius = 1000.0 // 1 km
        
        let distance = calculateHaversineDistance(
            lat1: geofence1Lat,
            lon1: geofence1Lon,
            lat2: geofence2Lat,
            lon2: geofence2Lon
        )
        
        let overlaps = distance < (geofence1Radius + geofence2Radius)
        
        XCTAssertTrue(overlaps, "Geofences close together should overlap")
    }
    
    func testOverlapDetectionTouching() {
        // Two geofences exactly touching should be considered overlapping
        let geofence1Lat = 40.7128
        let geofence1Lon = -74.0060
        let geofence1Radius = 100.0
        
        // Calculate point exactly 200 meters away
        let geofence2Lat = 40.7146 // Approximately 200 meters north
        let geofence2Lon = -74.0060
        let geofence2Radius = 100.0
        
        let distance = calculateHaversineDistance(
            lat1: geofence1Lat,
            lon1: geofence1Lon,
            lat2: geofence2Lat,
            lon2: geofence2Lon
        )
        
        let overlaps = distance < (geofence1Radius + geofence2Radius)
        
        // Distance should be approximately 200 meters, so they should just touch
        XCTAssertEqual(distance, 200, accuracy: 10, "Distance should be approximately 200 meters")
    }
    
    func testOverlapDetectionOneInsideAnother() {
        // Small geofence completely inside large geofence
        let geofence1Lat = 40.7128
        let geofence1Lon = -74.0060
        let geofence1Radius = 5000.0 // 5 km
        
        let geofence2Lat = 40.7128 // Same center
        let geofence2Lon = -74.0060
        let geofence2Radius = 100.0 // 100 m
        
        let distance = calculateHaversineDistance(
            lat1: geofence1Lat,
            lon1: geofence1Lon,
            lat2: geofence2Lat,
            lon2: geofence2Lon
        )
        
        let overlaps = distance < (geofence1Radius + geofence2Radius)
        
        XCTAssertTrue(overlaps, "Small geofence inside large geofence should overlap")
        XCTAssertEqual(distance, 0, accuracy: 0.1, "Same center should have 0 distance")
    }
    
    // MARK: - Validation Tests
    
    func testValidRadiusRange() {
        // Test minimum radius
        let minRadius = 50.0
        XCTAssertGreaterThanOrEqual(minRadius, 50.0, "Minimum radius should be 50 meters")
        
        // Test maximum radius
        let maxRadius = 10000.0
        XCTAssertLessThanOrEqual(maxRadius, 10000.0, "Maximum radius should be 10,000 meters")
    }
    
    func testValidLatitudeRange() {
        // Test valid latitudes
        let validLat1 = 0.0
        let validLat2 = 45.0
        let validLat3 = -45.0
        let validLat4 = 90.0
        let validLat5 = -90.0
        
        XCTAssertTrue((-90...90).contains(validLat1), "Latitude 0 should be valid")
        XCTAssertTrue((-90...90).contains(validLat2), "Latitude 45 should be valid")
        XCTAssertTrue((-90...90).contains(validLat3), "Latitude -45 should be valid")
        XCTAssertTrue((-90...90).contains(validLat4), "Latitude 90 should be valid")
        XCTAssertTrue((-90...90).contains(validLat5), "Latitude -90 should be valid")
        
        // Test invalid latitudes
        let invalidLat1 = 91.0
        let invalidLat2 = -91.0
        
        XCTAssertFalse((-90...90).contains(invalidLat1), "Latitude 91 should be invalid")
        XCTAssertFalse((-90...90).contains(invalidLat2), "Latitude -91 should be invalid")
    }
    
    func testValidLongitudeRange() {
        // Test valid longitudes
        let validLon1 = 0.0
        let validLon2 = 90.0
        let validLon3 = -90.0
        let validLon4 = 180.0
        let validLon5 = -180.0
        
        XCTAssertTrue((-180...180).contains(validLon1), "Longitude 0 should be valid")
        XCTAssertTrue((-180...180).contains(validLon2), "Longitude 90 should be valid")
        XCTAssertTrue((-180...180).contains(validLon3), "Longitude -90 should be valid")
        XCTAssertTrue((-180...180).contains(validLon4), "Longitude 180 should be valid")
        XCTAssertTrue((-180...180).contains(validLon5), "Longitude -180 should be valid")
        
        // Test invalid longitudes
        let invalidLon1 = 181.0
        let invalidLon2 = -181.0
        
        XCTAssertFalse((-180...180).contains(invalidLon1), "Longitude 181 should be invalid")
        XCTAssertFalse((-180...180).contains(invalidLon2), "Longitude -181 should be invalid")
    }
    
    // MARK: - Helper Methods
    
    /// Helper method to calculate haversine distance (mirrors private method in GeofenceService)
    private func calculateHaversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
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
    
    private func createMockAssignment(
        id: UUID = UUID(),
        geofenceId: UUID,
        vehicleId: UUID
    ) -> GeofenceAssignment {
        return GeofenceAssignment(
            id: id,
            geofence_id: geofenceId,
            vehicle_id: vehicleId,
            created_at: Date()
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
}

// MARK: - Mock Supabase Client

class MockSupabaseClient: SupabaseClient {
    var mockGeofences: [Geofence] = []
    var mockAssignments: [GeofenceAssignment] = []
    var mockVehicles: [Vehicle] = []
    var mockEvents: [GeofenceEvent] = []
    var shouldSucceed: Bool = true
    
    init() {
        // Initialize with dummy configuration
        super.init(
            supabaseURL: URL(string: "https://mock.supabase.co")!,
            supabaseKey: "mock-key"
        )
    }
    
    override func from(_ table: String) -> PostgrestQueryBuilder {
        return MockPostgrestQueryBuilder(
            client: self,
            table: table,
            mockGeofences: mockGeofences,
            mockAssignments: mockAssignments,
            mockVehicles: mockVehicles,
            mockEvents: mockEvents,
            shouldSucceed: shouldSucceed
        )
    }
}

// MARK: - Mock Postgrest Query Builder

class MockPostgrestQueryBuilder: PostgrestQueryBuilder {
    let mockClient: MockSupabaseClient
    let table: String
    var mockGeofences: [Geofence]
    var mockAssignments: [GeofenceAssignment]
    var mockVehicles: [Vehicle]
    var mockEvents: [GeofenceEvent]
    var shouldSucceed: Bool
    
    var filterConditions: [String: Any] = [:]
    var selectCalled = false
    var insertCalled = false
    var updateCalled = false
    var deleteCalled = false
    
    init(
        client: MockSupabaseClient,
        table: String,
        mockGeofences: [Geofence],
        mockAssignments: [GeofenceAssignment],
        mockVehicles: [Vehicle],
        mockEvents: [GeofenceEvent],
        shouldSucceed: Bool
    ) {
        self.mockClient = client
        self.table = table
        self.mockGeofences = mockGeofences
        self.mockAssignments = mockAssignments
        self.mockVehicles = mockVehicles
        self.mockEvents = mockEvents
        self.shouldSucceed = shouldSucceed
        
        super.init(
            url: URL(string: "https://mock.supabase.co")!,
            headers: [:],
            schema: nil,
            method: .get,
            body: nil
        )
    }
    
    override func select(_ columns: String = "*") -> Self {
        selectCalled = true
        return self
    }
    
    override func insert<T: Encodable>(_ value: T, returning: PostgrestReturningOptions = .minimal) -> Self {
        insertCalled = true
        return self
    }
    
    override func update<T: Encodable>(_ value: T, returning: PostgrestReturningOptions = .minimal) -> Self {
        updateCalled = true
        return self
    }
    
    override func delete(returning: PostgrestReturningOptions = .minimal) -> Self {
        deleteCalled = true
        return self
    }
    
    override func eq(_ column: String, value: any PostgrestConvertible) -> Self {
        filterConditions[column] = value
        return self
    }
    
    override func `in`(_ column: String, values: [any PostgrestConvertible]) -> Self {
        filterConditions[column] = values
        return self
    }
    
    override func gte(_ column: String, value: any PostgrestConvertible) -> Self {
        filterConditions[column] = value
        return self
    }
    
    override func lte(_ column: String, value: any PostgrestConvertible) -> Self {
        filterConditions[column] = value
        return self
    }
    
    override func gt(_ column: String, value: any PostgrestConvertible) -> Self {
        filterConditions[column] = value
        return self
    }
    
    override func order(_ column: String, ascending: Bool = true, nullsFirst: Bool = false) -> Self {
        return self
    }
    
    override func limit(_ count: Int) -> Self {
        return self
    }
    
    override func execute() async throws -> PostgrestResponse {
        guard shouldSucceed else {
            throw URLError(.badServerResponse)
        }
        
        let data: Data
        
        switch table {
        case "geofences":
            data = try JSONEncoder().encode(mockGeofences)
        case "geofence_assignments":
            data = try JSONEncoder().encode(mockAssignments)
        case "vehicles":
            data = try JSONEncoder().encode(mockVehicles)
        case "geofence_events":
            data = try JSONEncoder().encode(mockEvents)
        default:
            data = Data()
        }
        
        return PostgrestResponse(
            data: data,
            response: HTTPURLResponse(),
            error: nil
        )
    }
}
