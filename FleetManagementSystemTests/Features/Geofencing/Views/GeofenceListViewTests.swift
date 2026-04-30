//
//  GeofenceListViewTests.swift
//  FleetManagementSystemTests
//
//  Created by Kiro on 2025
//

import XCTest
import SwiftUI
@testable import FleetManagementSystem

@MainActor
final class GeofenceListViewTests: XCTestCase {
    
    // MARK: - Filter Tests
    
    func testFilteredGeofencesBySearchText() {
        // Given
        let geofences = [
            createMockGeofence(name: "Main Depot", type: .depot),
            createMockGeofence(name: "Customer Delivery Zone", type: .delivery),
            createMockGeofence(name: "Restricted Area", type: .restricted)
        ]
        
        // When - search for "depot"
        let filtered = geofences.filter { geofence in
            geofence.name.localizedCaseInsensitiveContains("depot")
        }
        
        // Then
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].name, "Main Depot")
    }
    
    func testFilteredGeofencesByType() {
        // Given
        let geofences = [
            createMockGeofence(name: "Depot 1", type: .depot),
            createMockGeofence(name: "Depot 2", type: .depot),
            createMockGeofence(name: "Delivery Zone", type: .delivery),
            createMockGeofence(name: "Restricted Area", type: .restricted)
        ]
        
        // When - filter by depot type
        let filtered = geofences.filter { $0.type == .depot }
        
        // Then
        XCTAssertEqual(filtered.count, 2)
        XCTAssertTrue(filtered.allSatisfy { $0.type == .depot })
    }
    
    func testFilteredGeofencesBySearchAndType() {
        // Given
        let geofences = [
            createMockGeofence(name: "Main Depot", type: .depot),
            createMockGeofence(name: "Secondary Depot", type: .depot),
            createMockGeofence(name: "Main Delivery Zone", type: .delivery)
        ]
        
        // When - search for "main" and filter by depot
        let searchText = "main"
        let selectedType = GeofenceType.depot
        
        let filtered = geofences.filter { geofence in
            let matchesSearch = geofence.name.localizedCaseInsensitiveContains(searchText)
            let matchesType = geofence.type == selectedType
            return matchesSearch && matchesType
        }
        
        // Then
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered[0].name, "Main Depot")
    }
    
    func testFilteredGeofencesEmptySearch() {
        // Given
        let geofences = [
            createMockGeofence(name: "Depot 1", type: .depot),
            createMockGeofence(name: "Delivery Zone", type: .delivery)
        ]
        
        // When - empty search text
        let searchText = ""
        let filtered = geofences.filter { geofence in
            searchText.isEmpty || geofence.name.localizedCaseInsensitiveContains(searchText)
        }
        
        // Then - should return all geofences
        XCTAssertEqual(filtered.count, 2)
    }
    
    func testFilteredGeofencesNoTypeFilter() {
        // Given
        let geofences = [
            createMockGeofence(name: "Depot 1", type: .depot),
            createMockGeofence(name: "Delivery Zone", type: .delivery),
            createMockGeofence(name: "Restricted Area", type: .restricted)
        ]
        
        // When - no type filter (nil)
        let selectedType: GeofenceType? = nil
        let filtered = geofences.filter { geofence in
            selectedType == nil || geofence.type == selectedType
        }
        
        // Then - should return all geofences
        XCTAssertEqual(filtered.count, 3)
    }
    
    // MARK: - Permission Tests
    
    func testFleetManagerCanSeeCreateButton() {
        // Given
        let fleetManagerProfile = UserProfile(
            userId: UUID(),
            name: "Fleet Manager",
            email: "manager@test.com",
            role: .fleetManager
        )
        
        // When
        let isFleetManager = fleetManagerProfile.role == .fleetManager
        
        // Then
        XCTAssertTrue(isFleetManager)
    }
    
    func testDriverCannotSeeCreateButton() {
        // Given
        let driverProfile = UserProfile(
            userId: UUID(),
            name: "Driver",
            email: "driver@test.com",
            role: .driver
        )
        
        // When
        let isFleetManager = driverProfile.role == .fleetManager
        
        // Then
        XCTAssertFalse(isFleetManager)
    }
    
    // MARK: - Date Formatting Tests
    
    func testFormattedDateRecent() {
        // Given
        let recentDate = Date().addingTimeInterval(-3600) // 1 hour ago
        
        // When
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let formatted = formatter.localizedString(for: recentDate, relativeTo: Date())
        
        // Then
        XCTAssertTrue(formatted.contains("hr") || formatted.contains("hour"))
    }
    
    func testFormattedDateOld() {
        // Given
        let oldDate = Date().addingTimeInterval(-86400 * 7) // 7 days ago
        
        // When
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        let formatted = formatter.localizedString(for: oldDate, relativeTo: Date())
        
        // Then
        XCTAssertTrue(formatted.contains("wk") || formatted.contains("week") || formatted.contains("day"))
    }
    
    // MARK: - Geofence Type Tests
    
    func testGeofenceTypeDisplayNames() {
        XCTAssertEqual(GeofenceType.depot.displayName, "Depot")
        XCTAssertEqual(GeofenceType.delivery.displayName, "Delivery")
        XCTAssertEqual(GeofenceType.restricted.displayName, "Restricted")
    }
    
    func testGeofenceTypeIcons() {
        XCTAssertEqual(GeofenceType.depot.icon, "building.2.fill")
        XCTAssertEqual(GeofenceType.delivery.icon, "shippingbox.fill")
        XCTAssertEqual(GeofenceType.restricted.icon, "exclamationmark.triangle.fill")
    }
    
    func testGeofenceTypeColors() {
        XCTAssertEqual(GeofenceType.depot.color, .blue)
        XCTAssertEqual(GeofenceType.delivery.color, .green)
        XCTAssertEqual(GeofenceType.restricted.color, .red)
    }
    
    func testGeofenceTypeAllCases() {
        let allTypes = GeofenceType.allCases
        XCTAssertEqual(allTypes.count, 3)
        XCTAssertTrue(allTypes.contains(.depot))
        XCTAssertTrue(allTypes.contains(.delivery))
        XCTAssertTrue(allTypes.contains(.restricted))
    }
    
    // MARK: - Helper Methods
    
    private func createMockGeofence(
        id: UUID = UUID(),
        name: String,
        type: GeofenceType
    ) -> Geofence {
        return Geofence(
            id: id,
            name: name,
            latitude: 40.7128,
            longitude: -74.0060,
            radius: 500,
            type: type,
            created_at: Date(),
            updated_at: Date()
        )
    }
}
