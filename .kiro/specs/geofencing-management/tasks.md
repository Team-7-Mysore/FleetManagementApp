# Implementation Plan: Geofencing Management

## Overview

This implementation plan breaks down the Geofencing Management feature into discrete coding tasks across four phases: Database and Backend setup, iOS Services and Models, iOS UI Components, and Integration and Testing. The feature enables fleet managers to create, manage, and monitor geographic boundaries (geofences) for vehicles using SwiftUI, MapKit, and Supabase Edge Functions.

## Tasks

- [x] 1. Set up database schema and tables
  - [x] 1.1 Create geofences table with validation constraints
    - Create table with columns: geofence_id, name, latitude, longitude, radius, type, created_at, updated_at
    - Add CHECK constraints for latitude (-90 to 90), longitude (-180 to 180), radius (50 to 10000), and type enum
    - Create indexes on type and coordinates columns
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 17.1_
  
  - [x] 1.2 Create geofence_assignments table
    - Create table with columns: assignment_id, geofence_id, vehicle_id, created_at
    - Add foreign key constraints with CASCADE delete
    - Add UNIQUE constraint on (geofence_id, vehicle_id)
    - Create indexes on geofence_id and vehicle_id
    - _Requirements: 5.2, 17.2_
  
  - [x] 1.3 Create geofence_events table
    - Create table with columns: event_id, geofence_id, vehicle_id, event_type, timestamp, latitude, longitude, dwell_time, created_at
    - Add CHECK constraint for event_type ('entry' or 'exit')
    - Create indexes on geofence_id, vehicle_id, and timestamp
    - _Requirements: 6.2, 6.3, 7.2, 7.3, 17.3_

- [x] 2. Implement Supabase Edge Functions
  - [x] 2.1 Create monitor-geofences Edge Function
    - Implement haversine distance calculation function
    - Fetch assigned geofences for vehicle from database
    - Calculate distances between vehicle location and geofence centers
    - Detect entry events (vehicle moves inside geofence boundary)
    - Detect exit events (vehicle moves outside geofence boundary)
    - Calculate dwell time for exit events
    - Insert event records into geofence_events table
    - _Requirements: 6.1, 6.2, 6.5, 7.1, 7.2, 7.5, 18.1_
  
  - [x] 2.2 Write unit tests for haversine formula
    - Test distance calculation accuracy with known coordinates
    - Test edge cases (poles, date line crossing)
    - Test performance with multiple calculations
  
  - [x] 2.3 Create send-geofence-notification Edge Function
    - Fetch geofence and vehicle details
    - Fetch all fleet managers from database
    - Format notification message based on event type and geofence type
    - Set priority to 'high' for restricted geofences, 'normal' for others
    - Insert notification records for each fleet manager
    - _Requirements: 8.1, 8.2, 9.1, 9.2, 10.1, 10.2, 11.1, 11.2, 12.1, 12.2_
  
  - [x] 2.4 Integrate notification calls into monitor-geofences
    - Call send-geofence-notification for entry events
    - Call send-geofence-notification for exit events with dwell time
    - Implement priority handling for restricted geofences
    - Add error handling and logging
    - _Requirements: 8.1, 9.1, 10.1, 11.1, 18.4_

- [x] 3. Set up database trigger for location monitoring
  - [x] 3.1 Create trigger function to invoke monitor-geofences
    - Create PostgreSQL function trigger_monitor_geofences()
    - Use net.http_post to invoke Edge Function asynchronously
    - Pass vehicle_id, latitude, longitude, timestamp in request body
    - _Requirements: 6.1, 7.1_
  
  - [x] 3.2 Create trigger on vehicle_locations table
    - Create AFTER INSERT OR UPDATE trigger
    - Execute trigger_monitor_geofences() for each row
    - _Requirements: 6.1, 6.4, 7.1, 7.4_

- [ ] 4. Checkpoint - Test backend monitoring with sample data
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Create iOS data models
  - [x] 5.1 Create Geofence model
    - Define struct with id, name, latitude, longitude, radius, type, created_at, updated_at
    - Implement Codable with custom CodingKeys
    - _Requirements: 1.1, 17.1_
  
  - [x] 5.2 Create GeofenceType enum
    - Define cases: depot, delivery, restricted
    - Add displayName, icon, and color computed properties
    - Implement CaseIterable and Codable
    - _Requirements: 1.1_
  
  - [x] 5.3 Create GeofenceAssignment model
    - Define struct with id, geofence_id, vehicle_id, created_at
    - Implement Codable with custom CodingKeys
    - _Requirements: 5.2, 17.2_
  
  - [x] 5.4 Create GeofenceEvent model
    - Define struct with id, geofence_id, vehicle_id, event_type, timestamp, latitude, longitude, dwell_time
    - Define EventType enum (entry, exit)
    - Add formattedDwellTime computed property
    - Implement Codable with custom CodingKeys
    - _Requirements: 6.2, 7.2, 13.4, 17.3_
  
  - [x] 5.5 Create GeofenceStatus model
    - Define struct with vehicle_id, geofence_id, geofence_name, entry_timestamp, is_inside
    - Implement Codable
    - _Requirements: 14.1, 14.2_

- [x] 6. Implement GeofenceService
  - [x] 6.1 Create GeofenceService class with Supabase client
    - Initialize with SupabaseClient
    - _Requirements: 1.6, 17.1_
  
  - [x] 6.2 Implement CRUD operations
    - Implement fetchGeofences() to retrieve all geofences
    - Implement fetchGeofence(id:) to retrieve single geofence
    - Implement createGeofence(_:) to insert new geofence
    - Implement updateGeofence(id:_:) to update existing geofence
    - Implement deleteGeofence(id:) to delete geofence
    - _Requirements: 1.6, 2.3, 2.4, 3.3, 4.1_
  
  - [x] 6.3 Implement assignment operations
    - Implement assignVehicles(_:to:) to create assignments
    - Implement removeAssignment(vehicleId:from:) to delete assignment
    - Implement fetchAssignedVehicles(for:) to get vehicles for geofence
    - Implement fetchGeofencesForVehicle(_:) to get geofences for vehicle
    - _Requirements: 5.1, 5.2, 5.3, 5.4_
  
  - [x] 6.4 Implement event operations
    - Implement fetchEvents(for:from:to:) to retrieve events with date filtering
    - Implement fetchVehicleStatus(for:) to get current geofence status
    - _Requirements: 13.1, 13.2, 13.3, 14.1_
  
  - [x] 6.5 Implement overlap detection
    - Implement findOverlappingGeofences(latitude:longitude:radius:excluding:) using haversine formula
    - Query all geofences and calculate distances
    - Return geofences where distance < (radius1 + radius2)
    - _Requirements: 15.1, 15.2_
  
  - [x] 6.6 Write unit tests for GeofenceService
    - Mock Supabase client responses
    - Test CRUD operations
    - Test assignment operations
    - Test query construction
    - Test error handling

- [x] 7. Implement GeofenceViewModel
  - [x] 7.1 Create GeofenceViewModel class with published properties
    - Define @Published properties: geofences, events, vehicleStatuses, isLoading, errorMessage, successMessage
    - Initialize with GeofenceService
    - Mark class as @MainActor
    - _Requirements: 4.1, 13.1, 14.1_
  
  - [x] 7.2 Implement CRUD operations
    - Implement loadGeofences() to fetch and update geofences array
    - Implement createGeofence(name:latitude:longitude:radius:type:) with validation
    - Implement updateGeofence(_:) with validation
    - Implement deleteGeofence(_:) with confirmation
    - Handle errors and update errorMessage/successMessage
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.8, 2.1, 2.2, 2.3, 2.5, 3.1, 3.2, 3.3, 3.5_
  
  - [x] 7.3 Implement assignment operations
    - Implement assignVehicles(_:to:) to create assignments
    - Implement removeVehicleAssignment(vehicleId:from:) to delete assignment
    - Implement loadAssignedVehicles(for:) to fetch vehicles
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_
  
  - [x] 7.4 Implement event operations
    - Implement loadEvents(for:dateRange:) to fetch filtered events
    - Implement loadVehicleStatus(for:) to fetch current status
    - Implement exportEvents(_:) to generate CSV file
    - _Requirements: 13.1, 13.2, 13.3, 13.4, 13.5, 14.1, 14.2, 14.3_
  
  - [x] 7.5 Implement validation logic
    - Implement validateGeofence(name:latitude:longitude:radius:) with all validation rules
    - Return ValidationResult with specific error messages
    - Implement checkOverlaps(latitude:longitude:radius:excluding:) using service
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.8, 2.2, 15.1, 15.2_
  
  - [x] 7.6 Implement realtime subscriptions
    - Implement subscribeToGeofenceUpdates() to listen for database changes
    - Update geofences array when changes detected
    - Implement unsubscribe() to clean up subscriptions
    - _Requirements: 14.4_
  
  - [x] 7.7 Write unit tests for GeofenceViewModel
    - Test validation logic
    - Test overlap detection
    - Test event filtering
    - Test CSV export formatting
    - Test error message generation

- [x] 8. Checkpoint - Ensure services and view models are working
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Implement GeofenceListView
  - [x] 9.1 Create GeofenceListView with search and filter
    - Create SwiftUI view with @StateObject viewModel
    - Add search bar with @State searchText binding
    - Add filter picker for GeofenceType with @State selectedType
    - Display list of geofences with name, type icon, and creation date
    - Implement search filtering on name
    - Implement type filtering
    - _Requirements: 4.1, 4.2, 4.3_
  
  - [x] 9.2 Add navigation and create sheet
    - Add NavigationLink to GeofenceDetailView on row tap
    - Add toolbar button to present create geofence sheet
    - Add @State showingCreateSheet binding
    - _Requirements: 4.4_
  
  - [x] 9.3 Add permission enforcement
    - Check user role before showing create button
    - Display access denied message for non-fleet managers
    - _Requirements: 16.1, 16.5_

- [x] 10. Implement GeofenceMapView
  - [x] 10.1 Create GeofenceMapView with MapKit integration
    - Create SwiftUI view with Map component
    - Add @StateObject viewModel
    - Add @State region for map region
    - Display geofence overlays as circles with color based on type
    - Display vehicle markers
    - _Requirements: 1.7, 4.4_
  
  - [x] 10.2 Add tap-to-create geofence interaction
    - Add tap gesture recognizer to map
    - Add @State isCreatingGeofence binding
    - Show temporary circle overlay at tap location
    - Present GeofenceCreateEditView with pre-filled coordinates
    - _Requirements: 1.1, 1.7_
  
  - [x] 10.3 Add geofence selection and detail display
    - Add @State selectedGeofence binding
    - Show annotation callout on geofence tap
    - Navigate to GeofenceDetailView on callout tap
    - _Requirements: 4.4_

- [x] 11. Implement GeofenceCreateEditView
  - [x] 11.1 Create form with input fields
    - Create SwiftUI view with Form
    - Add @State properties: name, latitude, longitude, radius, type, selectedVehicles
    - Add text fields for name, latitude, longitude
    - Add slider for radius with visual feedback (50-10000 meters)
    - Add picker for type
    - Add multi-select list for vehicle assignment
    - _Requirements: 1.1, 2.1, 5.1_
  
  - [x] 11.2 Add map picker for location selection
    - Add @State showingMapPicker binding
    - Present map view to select coordinates
    - Update latitude/longitude when location selected
    - _Requirements: 1.1, 1.7_
  
  - [x] 11.3 Implement validation and save
    - Call viewModel.validateGeofence() on save button tap
    - Display validation errors inline
    - Call viewModel.createGeofence() or updateGeofence() on valid input
    - Call viewModel.checkOverlaps() and display warning if overlaps exist
    - Dismiss view on success
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.6, 1.8, 2.2, 2.3, 2.5, 15.1, 15.2, 15.3_
  
  - [x] 11.4 Add permission enforcement
    - Check user role before allowing save
    - Display access denied message for non-fleet managers
    - _Requirements: 16.1, 16.2, 16.4, 16.5_

- [x] 12. Implement GeofenceDetailView
  - [x] 12.1 Create detail view with geofence information
    - Create SwiftUI view displaying geofence properties
    - Show name, type, coordinates, radius, creation date
    - Display map with geofence overlay
    - Show list of assigned vehicles
    - _Requirements: 4.4, 5.3_
  
  - [x] 12.2 Add event history section
    - Display list of GeofenceEvent records
    - Show event type icon, vehicle name, timestamp, dwell time
    - Add @State selectedDateRange binding
    - Add date range picker (last 7 days, last 30 days, custom)
    - Call viewModel.loadEvents(for:dateRange:) on date range change
    - _Requirements: 13.1, 13.2, 13.3, 13.4_
  
  - [x] 12.3 Add CSV export functionality
    - Add toolbar button for export
    - Call viewModel.exportEvents(_:) to generate CSV
    - Present share sheet with CSV file
    - _Requirements: 13.5_
  
  - [x] 12.4 Add edit and delete actions
    - Add @State showingEditSheet binding
    - Add toolbar button to present edit sheet
    - Add @State showingDeleteAlert binding
    - Add toolbar button to show delete confirmation alert
    - Call viewModel.deleteGeofence(_:) on confirmation
    - Navigate back on successful deletion
    - _Requirements: 2.1, 2.5, 3.1, 3.2, 3.3, 3.4, 3.5_
  
  - [x] 12.5 Add permission enforcement
    - Check user role before showing edit/delete buttons
    - Display access denied message for non-fleet managers
    - _Requirements: 16.2, 16.3, 16.5_

- [x] 13. Implement VehicleGeofenceStatusView
  - [x] 13.1 Create status view for vehicle
    - Create SwiftUI view with vehicleId parameter
    - Add @StateObject viewModel
    - Call viewModel.loadVehicleStatus(for:) on appear
    - Display list of geofences vehicle is currently inside
    - Show geofence name and entry timestamp for each
    - Display "Not inside any geofences" when empty
    - _Requirements: 14.1, 14.2, 14.3_
  
  - [x] 13.2 Add realtime updates
    - Subscribe to geofence event updates on appear
    - Update status when new events detected
    - Unsubscribe on disappear
    - _Requirements: 14.4_

- [ ] 14. Checkpoint - Test UI components with backend
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 15. Integrate with existing notification system
  - [ ] 15.1 Update notification models to support geofence events
    - Add geofence_event notification type
    - Add data fields: geofence_id, vehicle_id, event_type
    - _Requirements: 8.1, 8.2, 9.1, 9.2, 10.1, 10.2, 11.1, 11.2, 12.1, 12.2_
  
  - [ ] 15.2 Add geofence notification handling in NotificationListView
    - Parse geofence event data from notification
    - Display appropriate icon and message
    - Add navigation to GeofenceDetailView on tap
    - _Requirements: 8.1, 9.1, 10.1, 11.1_

- [x] 16. Add geofence management to FleetManagerTabView
  - [x] 16.1 Add Geofences tab to FleetManagerTabView
    - Add tab item with icon and label
    - Set GeofenceListView as tab contentThread 1: Fatal error: No ObservableObject of type AppSession found. A View.environmentObject(_:) for AppSession may be missing as an ancestor of this view
    - _Requirements: 4.1, 16.1_

- [ ] 17. Implement CSV export functionality
  - [ ] 17.1 Create CSV formatter for GeofenceEvent
    - Implement function to convert array of events to CSV string
    - Include headers: Event Type, Vehicle, Geofence, Timestamp, Latitude, Longitude, Dwell Time
    - Format timestamp and dwell time appropriately
    - _Requirements: 13.5_
  
  - [ ] 17.2 Implement file writing and sharing
    - Write CSV string to temporary file
    - Return file URL from viewModel.exportEvents(_:)
    - Present UIActivityViewController in GeofenceDetailView
    - _Requirements: 13.5_

- [ ] 18. Write integration tests
  - Test geofence CRUD operations with real Supabase instance
  - Test cascade deletes (geofence → assignments → events)
  - Test unique constraints on assignments
  - Test Edge Function entry/exit detection
  - Test notification triggering

- [ ] 19. Write UI tests
  - Test GeofenceListView search and filtering
  - Test GeofenceMapView tap-to-create flow
  - Test GeofenceCreateEditView validation
  - Test GeofenceDetailView event history and export
  - Test VehicleGeofenceStatusView realtime updates

- [ ] 20. Performance testing and optimization
  - Test Edge Function execution time with 100 vehicles
  - Test map rendering with 500 geofence overlays
  - Test event history loading with 10,000+ events
  - Optimize queries with EXPLAIN ANALYZE
  - Add database indexes if needed

- [ ] 21. Final checkpoint - Ensure all features working end-to-end
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at key milestones
- The implementation follows the existing Fleet Management System architecture patterns
- All geofence management features are Fleet Manager-only (driver features out of scope)
- Edge Functions handle monitoring to ensure scalability and real-time processing
- MapKit provides native iOS map visualization and interaction
