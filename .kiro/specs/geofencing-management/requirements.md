# Requirements Document

## Introduction

The Geofencing Management feature enables fleet managers to create, manage, and monitor geographic boundaries (geofences) for vehicles in the Fleet Management System. The system automatically detects vehicle entry and exit events for three primary use cases: depot/yard management, customer delivery zones, and restricted/compliance zones. This feature provides automated shift logging, delivery notifications, and compliance alerts to improve operational efficiency and safety.

**Scope Note:** This phase focuses exclusively on Fleet Manager functionality. Driver features (driver assignments, driver notifications, driver views) are explicitly out of scope and will be implemented in a future phase.

## Glossary

- **Geofence**: A virtual geographic boundary defined by a center point (latitude, longitude) and radius in meters
- **Geofence_Manager**: The iOS SwiftUI application component responsible for creating, editing, and deleting geofences (Fleet Manager role only)
- **Geofence_Monitor**: The backend service that continuously monitors vehicle locations against active geofences
- **Entry_Event**: A detected occurrence when a vehicle's location enters a geofence boundary
- **Exit_Event**: A detected occurrence when a vehicle's location exits a geofence boundary
- **Depot_Geofence**: A geofence type used for company depot or yard locations
- **Delivery_Geofence**: A geofence type used for customer delivery locations
- **Restricted_Geofence**: A geofence type used for compliance or safety-restricted areas
- **Vehicle_Location_Service**: The existing system component that tracks and stores vehicle GPS coordinates
- **Notification_Service**: The system component that sends alerts to fleet managers
- **Geofence_Assignment**: The association between a geofence and one or more vehicles
- **Fleet_Manager**: A user with the fleet manager role who has permission to manage geofences
- **Driver**: Out of scope for this phase - driver features will be implemented in a future phase

## Requirements

### Requirement 1: Create Geofence

**User Story:** As a fleet manager, I want to create geofences with specific locations and radii, so that I can monitor vehicle activity in important areas.

#### Acceptance Criteria

1. THE Geofence_Manager SHALL allow the Fleet_Manager to create a geofence by specifying a name, center coordinates (latitude and longitude), radius in meters, and type (depot, delivery, or restricted)
2. WHEN a Fleet_Manager creates a geofence, THE Geofence_Manager SHALL validate that the name is between 3 and 100 characters
3. WHEN a Fleet_Manager creates a geofence, THE Geofence_Manager SHALL validate that the latitude is between -90 and 90 degrees
4. WHEN a Fleet_Manager creates a geofence, THE Geofence_Manager SHALL validate that the longitude is between -180 and 180 degrees
5. WHEN a Fleet_Manager creates a geofence, THE Geofence_Manager SHALL validate that the radius is between 50 and 10000 meters
6. WHEN a Fleet_Manager creates a geofence, THE Geofence_Manager SHALL store the geofence in the Supabase database with a unique identifier
7. WHEN a Fleet_Manager creates a geofence, THE Geofence_Manager SHALL display a visual representation of the geofence boundary on a map
8. IF geofence creation fails due to invalid input, THEN THE Geofence_Manager SHALL display a descriptive error message

### Requirement 2: Edit Geofence

**User Story:** As a fleet manager, I want to edit existing geofences, so that I can adjust boundaries when locations or requirements change.

#### Acceptance Criteria

1. THE Geofence_Manager SHALL allow the Fleet_Manager to modify the name, center coordinates, radius, and type of an existing geofence
2. WHEN a Fleet_Manager edits a geofence, THE Geofence_Manager SHALL apply the same validation rules as geofence creation
3. WHEN a Fleet_Manager edits a geofence, THE Geofence_Manager SHALL update the geofence in the Supabase database
4. WHEN a Fleet_Manager edits a geofence, THE Geofence_Manager SHALL preserve the geofence identifier and creation timestamp
5. IF geofence editing fails, THEN THE Geofence_Manager SHALL display a descriptive error message and retain the previous geofence state

### Requirement 3: Delete Geofence

**User Story:** As a fleet manager, I want to delete geofences that are no longer needed, so that I can keep the system organized and reduce unnecessary monitoring.

#### Acceptance Criteria

1. THE Geofence_Manager SHALL allow the Fleet_Manager to delete an existing geofence
2. WHEN a Fleet_Manager deletes a geofence, THE Geofence_Manager SHALL prompt for confirmation before deletion
3. WHEN a Fleet_Manager confirms geofence deletion, THE Geofence_Manager SHALL remove the geofence from the Supabase database
4. WHEN a Fleet_Manager confirms geofence deletion, THE Geofence_Manager SHALL remove all associated geofence assignments
5. WHEN a Fleet_Manager confirms geofence deletion, THE Geofence_Monitor SHALL stop monitoring that geofence for all vehicles

### Requirement 4: List Geofences

**User Story:** As a fleet manager, I want to view all geofences in a list, so that I can quickly see what geofences exist and their key properties.

#### Acceptance Criteria

1. THE Geofence_Manager SHALL display a list of all geofences with name, type, and creation date
2. THE Geofence_Manager SHALL allow the Fleet_Manager to filter geofences by type (depot, delivery, or restricted)
3. THE Geofence_Manager SHALL allow the Fleet_Manager to search geofences by name
4. WHEN a Fleet_Manager selects a geofence from the list, THE Geofence_Manager SHALL display the geofence details and boundary on a map

### Requirement 5: Assign Geofence to Vehicles

**User Story:** As a fleet manager, I want to assign geofences to specific vehicles, so that only relevant vehicles are monitored for those geofences.

#### Acceptance Criteria

1. THE Geofence_Manager SHALL allow the Fleet_Manager to assign a geofence to one or more vehicles
2. WHEN a Fleet_Manager assigns a geofence to vehicles, THE Geofence_Manager SHALL store the assignments in the Supabase database
3. THE Geofence_Manager SHALL allow the Fleet_Manager to view which vehicles are assigned to a geofence
4. THE Geofence_Manager SHALL allow the Fleet_Manager to remove vehicle assignments from a geofence
5. WHEN a vehicle is assigned to a geofence, THE Geofence_Monitor SHALL begin monitoring that vehicle for entry and exit events

### Requirement 6: Monitor Vehicle Entry Events

**User Story:** As a fleet manager, I want the system to automatically detect when vehicles enter geofences, so that I can track vehicle activity without manual updates.

#### Acceptance Criteria

1. WHEN the Vehicle_Location_Service updates a vehicle location, THE Geofence_Monitor SHALL check if the vehicle has entered any assigned geofences
2. WHEN a vehicle enters an assigned geofence, THE Geofence_Monitor SHALL create an Entry_Event record with vehicle identifier, geofence identifier, timestamp, and coordinates
3. WHEN a vehicle enters an assigned geofence, THE Geofence_Monitor SHALL store the Entry_Event in the Supabase database
4. THE Geofence_Monitor SHALL detect entry events within 30 seconds of the vehicle crossing the geofence boundary
5. THE Geofence_Monitor SHALL use the haversine formula to calculate distance between vehicle coordinates and geofence center

### Requirement 7: Monitor Vehicle Exit Events

**User Story:** As a fleet manager, I want the system to automatically detect when vehicles exit geofences, so that I can track vehicle departures and calculate dwell time.

#### Acceptance Criteria

1. WHEN the Vehicle_Location_Service updates a vehicle location, THE Geofence_Monitor SHALL check if the vehicle has exited any assigned geofences
2. WHEN a vehicle exits an assigned geofence, THE Geofence_Monitor SHALL create an Exit_Event record with vehicle identifier, geofence identifier, timestamp, and coordinates
3. WHEN a vehicle exits an assigned geofence, THE Geofence_Monitor SHALL store the Exit_Event in the Supabase database
4. THE Geofence_Monitor SHALL detect exit events within 30 seconds of the vehicle crossing the geofence boundary
5. THE Geofence_Monitor SHALL calculate dwell time as the duration between the most recent Entry_Event and Exit_Event for the same vehicle and geofence

### Requirement 8: Depot Entry Notifications

**User Story:** As a fleet manager, I want to receive notifications when vehicles enter depot geofences, so that I can track shift starts and yard activity.

#### Acceptance Criteria

1. WHEN a vehicle enters a Depot_Geofence, THE Notification_Service SHALL send a notification to the Fleet_Manager
2. THE Notification_Service SHALL include the vehicle identifier, geofence name, and entry timestamp in the notification
3. WHERE the geofence is configured for shift logging, WHEN a vehicle enters a Depot_Geofence, THE Geofence_Monitor SHALL create a shift start record

### Requirement 9: Depot Exit Notifications

**User Story:** As a fleet manager, I want to receive notifications when vehicles exit depot geofences, so that I can track shift ends and vehicle departures.

#### Acceptance Criteria

1. WHEN a vehicle exits a Depot_Geofence, THE Notification_Service SHALL send a notification to the Fleet_Manager
2. THE Notification_Service SHALL include the vehicle identifier, geofence name, exit timestamp, and dwell time in the notification
3. WHERE the geofence is configured for shift logging, WHEN a vehicle exits a Depot_Geofence, THE Geofence_Monitor SHALL create a shift end record

### Requirement 10: Delivery Zone Entry Notifications

**User Story:** As a fleet manager, I want to receive notifications when vehicles enter delivery zone geofences, so that I can track customer arrivals.

#### Acceptance Criteria

1. WHEN a vehicle enters a Delivery_Geofence, THE Notification_Service SHALL send a notification to the Fleet_Manager
2. THE Notification_Service SHALL include the vehicle identifier, geofence name, and entry timestamp in the notification
3. WHERE the geofence is associated with a trip, WHEN a vehicle enters a Delivery_Geofence, THE Geofence_Monitor SHALL update the trip status to indicate arrival

### Requirement 11: Restricted Zone Entry Alerts

**User Story:** As a fleet manager, I want to receive immediate alerts when vehicles enter restricted geofences, so that I can respond to compliance violations or safety concerns.

#### Acceptance Criteria

1. WHEN a vehicle enters a Restricted_Geofence, THE Notification_Service SHALL send a high-priority alert to the Fleet_Manager within 10 seconds
2. THE Notification_Service SHALL include the vehicle identifier, geofence name, entry timestamp, and alert severity in the notification
3. WHEN a vehicle enters a Restricted_Geofence, THE Geofence_Monitor SHALL create a compliance violation record

### Requirement 12: Restricted Zone Exit Alerts

**User Story:** As a fleet manager, I want to receive alerts when vehicles exit assigned zone geofences unexpectedly, so that I can detect route deviations.

#### Acceptance Criteria

1. WHERE a vehicle is assigned to remain within a geofence, WHEN the vehicle exits that geofence, THE Notification_Service SHALL send a high-priority alert to the Fleet_Manager within 10 seconds
2. THE Notification_Service SHALL include the vehicle identifier, geofence name, exit timestamp, and alert severity in the notification

### Requirement 13: View Geofence Event History

**User Story:** As a fleet manager, I want to view historical geofence events, so that I can analyze vehicle patterns and verify compliance.

#### Acceptance Criteria

1. THE Geofence_Manager SHALL display a list of all Entry_Event and Exit_Event records for a selected geofence
2. THE Geofence_Manager SHALL allow the Fleet_Manager to filter events by date range
3. THE Geofence_Manager SHALL allow the Fleet_Manager to filter events by vehicle
4. THE Geofence_Manager SHALL display event type (entry or exit), vehicle identifier, timestamp, and dwell time for each event
5. THE Geofence_Manager SHALL allow the Fleet_Manager to export event history as a CSV file

### Requirement 14: View Vehicle Geofence Status

**User Story:** As a fleet manager, I want to see which geofences each vehicle is currently inside, so that I can quickly understand vehicle locations.

#### Acceptance Criteria

1. THE Geofence_Manager SHALL display the current geofence status for each vehicle
2. WHEN a vehicle is inside one or more geofences, THE Geofence_Manager SHALL display the geofence names and entry timestamps
3. WHEN a vehicle is not inside any geofences, THE Geofence_Manager SHALL display an appropriate status message
4. THE Geofence_Manager SHALL update the vehicle geofence status within 30 seconds of an entry or exit event

### Requirement 15: Geofence Overlap Detection

**User Story:** As a fleet manager, I want to be warned when creating overlapping geofences, so that I can avoid ambiguous monitoring scenarios.

#### Acceptance Criteria

1. WHEN a Fleet_Manager creates or edits a geofence, THE Geofence_Manager SHALL check for overlaps with existing geofences
2. WHEN a geofence overlaps with one or more existing geofences, THE Geofence_Manager SHALL display a warning message listing the overlapping geofences
3. THE Geofence_Manager SHALL allow the Fleet_Manager to proceed with creating or editing the geofence despite the overlap warning

### Requirement 16: Geofence Permission Enforcement

**User Story:** As a system administrator, I want to ensure only fleet managers can create and manage geofences, so that drivers cannot modify monitoring boundaries.

#### Acceptance Criteria

1. THE Geofence_Manager SHALL verify that the user has the Fleet_Manager role before allowing geofence creation
2. THE Geofence_Manager SHALL verify that the user has the Fleet_Manager role before allowing geofence editing
3. THE Geofence_Manager SHALL verify that the user has the Fleet_Manager role before allowing geofence deletion
4. THE Geofence_Manager SHALL verify that the user has the Fleet_Manager role before allowing geofence assignment
5. IF a user without the Fleet_Manager role attempts to manage geofences, THEN THE Geofence_Manager SHALL display an access denied message

### Requirement 17: Geofence Data Persistence

**User Story:** As a system administrator, I want geofence data to be reliably stored and retrievable, so that the system maintains accurate monitoring over time.

#### Acceptance Criteria

1. THE Geofence_Manager SHALL store geofence records in a Supabase PostgreSQL table with columns for identifier, name, latitude, longitude, radius, type, created_at, and updated_at
2. THE Geofence_Manager SHALL store geofence assignment records in a Supabase PostgreSQL table with columns for identifier, geofence_id, vehicle_id, and created_at
3. THE Geofence_Monitor SHALL store Entry_Event and Exit_Event records in a Supabase PostgreSQL table with columns for identifier, geofence_id, vehicle_id, event_type, timestamp, latitude, longitude, and dwell_time
4. THE Geofence_Manager SHALL create database indexes on geofence_id and vehicle_id columns to optimize query performance

### Requirement 18: Geofence Monitoring Performance

**User Story:** As a fleet manager, I want geofence monitoring to operate efficiently, so that the system can handle multiple vehicles without delays.

#### Acceptance Criteria

1. THE Geofence_Monitor SHALL process vehicle location updates and check geofence boundaries within 5 seconds per vehicle
2. THE Geofence_Monitor SHALL support monitoring at least 100 vehicles simultaneously
3. THE Geofence_Monitor SHALL support monitoring at least 500 active geofences simultaneously
4. WHEN the system experiences high load, THE Geofence_Monitor SHALL prioritize Restricted_Geofence monitoring over other geofence types
