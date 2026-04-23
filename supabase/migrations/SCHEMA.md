# Geofencing Database Schema

## Overview

This document describes the database schema for the Geofencing Management feature. The schema consists of multiple tables that work together to manage geofences, vehicle assignments, and monitoring events.

## Tables

1. **geofences**: Stores geographic boundary definitions
2. **geofence_assignments**: Manages many-to-many relationships between geofences and vehicles
3. **geofence_events**: Stores entry/exit events with dwell time tracking

## Table Structure

### geofences

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| geofence_id | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique identifier for the geofence |
| name | VARCHAR(100) | NOT NULL | Geofence name (3-100 characters validated at application level) |
| latitude | DECIMAL(10, 8) | NOT NULL, CHECK (latitude >= -90 AND latitude <= 90) | Center latitude in degrees |
| longitude | DECIMAL(11, 8) | NOT NULL, CHECK (longitude >= -180 AND longitude <= 180) | Center longitude in degrees |
| radius | INTEGER | NOT NULL, CHECK (radius >= 50 AND radius <= 10000) | Radius in meters |
| type | VARCHAR(20) | NOT NULL, CHECK (type IN ('depot', 'delivery', 'restricted')) | Geofence type |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Timestamp when geofence was created |
| updated_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Timestamp when geofence was last updated |

## Indexes

1. **idx_geofences_type**: Index on `type` column for efficient filtering by geofence type
2. **idx_geofences_coordinates**: Composite index on `(latitude, longitude)` for spatial queries

## Constraints

### CHECK Constraints

1. **Latitude Range**: `latitude >= -90 AND latitude <= 90`
   - Ensures latitude values are within valid geographic range
   - Requirement: 1.3

2. **Longitude Range**: `longitude >= -180 AND longitude <= 180`
   - Ensures longitude values are within valid geographic range
   - Requirement: 1.4

3. **Radius Range**: `radius >= 50 AND radius <= 10000`
   - Minimum radius: 50 meters (prevents overly small geofences)
   - Maximum radius: 10,000 meters (10 km)
   - Requirement: 1.5

4. **Type Enum**: `type IN ('depot', 'delivery', 'restricted')`
   - Restricts type to three valid values
   - depot: Company depot or yard locations
   - delivery: Customer delivery locations
   - restricted: Compliance or safety-restricted areas
   - Requirement: 1.1

## Geofence Types

### depot
- **Purpose**: Company depot or yard locations
- **Use Case**: Track shift starts/ends, yard activity
- **Color**: Blue
- **Icon**: building.2.fill

### delivery
- **Purpose**: Customer delivery locations
- **Use Case**: Track customer arrivals, delivery confirmations
- **Color**: Green
- **Icon**: shippingbox.fill

### restricted
- **Purpose**: Compliance or safety-restricted areas
- **Use Case**: Compliance violations, safety alerts
- **Color**: Red
- **Icon**: exclamationmark.triangle.fill
- **Priority**: High-priority alerts (within 10 seconds)

## Performance Considerations

1. **Spatial Indexing**: The composite index on `(latitude, longitude)` enables efficient spatial queries for finding nearby geofences
2. **Type Filtering**: The index on `type` allows fast filtering by geofence type
3. **Query Optimization**: For distance calculations, use the haversine formula in application code or Edge Functions

## Example Queries

### Insert a new geofence
```sql
INSERT INTO geofences (name, latitude, longitude, radius, type)
VALUES ('Main Depot', 37.7749, -122.4194, 500, 'depot');
```

### Find all depot geofences
```sql
SELECT * FROM geofences WHERE type = 'depot';
```

### Find geofences near a location (requires haversine calculation)
```sql
-- This is a simplified example; actual implementation should use haversine formula
SELECT * FROM geofences
WHERE latitude BETWEEN 37.7 AND 37.8
  AND longitude BETWEEN -122.5 AND -122.4;
```

### Update a geofence
```sql
UPDATE geofences
SET name = 'Updated Depot', updated_at = NOW()
WHERE geofence_id = 'uuid-here';
```

### Delete a geofence
```sql
DELETE FROM geofences WHERE geofence_id = 'uuid-here';
```

## Related Tables (Future Migrations)

- **geofence_assignments**: Links geofences to vehicles
- **geofence_events**: Stores entry/exit events

## Requirements Mapping

This table satisfies the following requirements:

- **1.1**: Create geofence with name, coordinates, radius, and type
- **1.2**: Name validation (3-100 characters) - enforced at application level
- **1.3**: Latitude validation (-90 to 90) - enforced by CHECK constraint
- **1.4**: Longitude validation (-180 to 180) - enforced by CHECK constraint
- **1.5**: Radius validation (50 to 10,000 meters) - enforced by CHECK constraint
- **17.1**: Data persistence in PostgreSQL with proper columns and indexes


---

## geofence_assignments Table

### Overview

The `geofence_assignments` table manages the many-to-many relationship between geofences and vehicles. It determines which vehicles are monitored for which geofences.

### Table Structure

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| assignment_id | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique identifier for the assignment |
| geofence_id | UUID | NOT NULL, REFERENCES geofences(geofence_id) ON DELETE CASCADE | Foreign key to geofences table |
| vehicle_id | UUID | NOT NULL | Foreign key to vehicles table |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Timestamp when assignment was created |

### Indexes

1. **idx_assignments_geofence**: Index on `geofence_id` for efficient lookup of vehicles assigned to a geofence
2. **idx_assignments_vehicle**: Index on `vehicle_id` for efficient lookup of geofences assigned to a vehicle

### Constraints

#### UNIQUE Constraint
- **UNIQUE(geofence_id, vehicle_id)**: Prevents duplicate assignments
  - Ensures a vehicle can only be assigned to a geofence once
  - Requirement: 5.2

#### Foreign Key Constraints

1. **geofence_id → geofences(geofence_id)**
   - ON DELETE CASCADE: When a geofence is deleted, all its assignments are automatically removed
   - Maintains referential integrity
   - Requirement: 3.4 (delete geofence removes assignments)

2. **vehicle_id**
   - References vehicles table (no explicit foreign key constraint)
   - Application layer handles vehicle validation
   - Provides flexibility for vehicle management system

### CASCADE Delete Behavior

When a geofence is deleted:
```sql
DELETE FROM geofences WHERE geofence_id = 'uuid-here';
-- All assignments with this geofence_id are automatically deleted
```

This ensures:
- No orphaned assignment records
- Clean data integrity
- Simplified deletion logic

### Example Queries

#### Assign a vehicle to a geofence
```sql
INSERT INTO geofence_assignments (geofence_id, vehicle_id)
VALUES ('geofence-uuid', 'vehicle-uuid');
```

#### Find all vehicles assigned to a geofence
```sql
SELECT vehicle_id 
FROM geofence_assignments 
WHERE geofence_id = 'geofence-uuid';
```

#### Find all geofences assigned to a vehicle
```sql
SELECT geofence_id 
FROM geofence_assignments 
WHERE vehicle_id = 'vehicle-uuid';
```

#### Remove a specific assignment
```sql
DELETE FROM geofence_assignments 
WHERE geofence_id = 'geofence-uuid' 
AND vehicle_id = 'vehicle-uuid';
```

#### Remove all assignments for a vehicle
```sql
DELETE FROM geofence_assignments 
WHERE vehicle_id = 'vehicle-uuid';
```

#### Get assignment details with geofence info
```sql
SELECT 
    ga.assignment_id,
    ga.vehicle_id,
    g.name AS geofence_name,
    g.type AS geofence_type,
    ga.created_at
FROM geofence_assignments ga
JOIN geofences g ON ga.geofence_id = g.geofence_id
WHERE ga.vehicle_id = 'vehicle-uuid';
```

### Performance Considerations

1. **Indexed Lookups**: Both `geofence_id` and `vehicle_id` are indexed for fast queries
2. **Unique Constraint**: Enforced at database level, preventing duplicate checks in application code
3. **CASCADE Delete**: Automatic cleanup reduces application complexity and ensures data integrity

### Requirements Mapping

This table satisfies the following requirements:

- **5.1**: Assign geofences to vehicles
- **5.2**: Store assignments in database
- **5.3**: View which vehicles are assigned to a geofence
- **5.4**: Remove vehicle assignments
- **17.2**: Assignment records with proper columns and indexes
- **3.4**: Delete geofence removes all associated assignments (CASCADE)


---

## geofence_events Table

### Overview

The `geofence_events` table stores all geofence entry and exit events for vehicles. It provides a complete audit trail of vehicle movements through geofences, including timestamps, coordinates, and dwell time calculations.

### Table Structure

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| event_id | UUID | PRIMARY KEY, DEFAULT gen_random_uuid() | Unique identifier for the event |
| geofence_id | UUID | NOT NULL, REFERENCES geofences(geofence_id) ON DELETE CASCADE | Foreign key to geofences table |
| vehicle_id | UUID | NOT NULL | Foreign key to vehicles table |
| event_type | VARCHAR(10) | NOT NULL, CHECK (event_type IN ('entry', 'exit')) | Type of event: entry or exit |
| timestamp | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Timestamp when the event occurred |
| latitude | DECIMAL(10, 8) | NOT NULL | Vehicle latitude at time of event |
| longitude | DECIMAL(11, 8) | NOT NULL | Vehicle longitude at time of event |
| dwell_time | INTEGER | NULL | Duration in seconds between entry and exit (only for exit events) |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW() | Timestamp when event record was created |

### Indexes

1. **idx_events_geofence**: Composite index on `(geofence_id, timestamp DESC)` for efficient event history queries by geofence
2. **idx_events_vehicle**: Composite index on `(vehicle_id, timestamp DESC)` for efficient event history queries by vehicle
3. **idx_events_timestamp**: Index on `(timestamp DESC)` for efficient time-based queries and recent event lookups

### Constraints

#### CHECK Constraint
- **event_type IN ('entry', 'exit')**: Restricts event type to two valid values
  - `entry`: Vehicle entered the geofence boundary
  - `exit`: Vehicle exited the geofence boundary
  - Requirements: 6.2, 7.2

#### Foreign Key Constraint
- **geofence_id → geofences(geofence_id)**
  - ON DELETE CASCADE: When a geofence is deleted, all its events are automatically removed
  - Maintains referential integrity
  - Requirement: 17.3

### Event Types

#### Entry Event
- **event_type**: `'entry'`
- **dwell_time**: NULL (not applicable for entry events)
- **Purpose**: Records when a vehicle crosses into a geofence boundary
- **Triggers**: Notifications based on geofence type (depot, delivery, restricted)
- **Requirements**: 6.1, 6.2, 6.3

#### Exit Event
- **event_type**: `'exit'`
- **dwell_time**: Duration in seconds between entry and exit
- **Purpose**: Records when a vehicle crosses out of a geofence boundary
- **Calculation**: `exit_timestamp - entry_timestamp`
- **Requirements**: 7.1, 7.2, 7.3, 7.5

### Dwell Time Calculation

Dwell time represents how long a vehicle stayed within a geofence:

```sql
-- Example: Calculate dwell time for an exit event
WITH entry_event AS (
    SELECT timestamp AS entry_time
    FROM geofence_events
    WHERE vehicle_id = 'vehicle-uuid'
      AND geofence_id = 'geofence-uuid'
      AND event_type = 'entry'
    ORDER BY timestamp DESC
    LIMIT 1
)
INSERT INTO geofence_events (geofence_id, vehicle_id, event_type, timestamp, latitude, longitude, dwell_time)
SELECT 
    'geofence-uuid',
    'vehicle-uuid',
    'exit',
    NOW(),
    40.7130,
    -74.0062,
    EXTRACT(EPOCH FROM (NOW() - entry_time))::INTEGER
FROM entry_event;
```

### CASCADE Delete Behavior

When a geofence is deleted:
```sql
DELETE FROM geofences WHERE geofence_id = 'uuid-here';
-- All events with this geofence_id are automatically deleted
```

This ensures:
- No orphaned event records
- Clean data integrity
- Historical data is removed with the geofence

### Example Queries

#### Insert an entry event
```sql
INSERT INTO geofence_events (geofence_id, vehicle_id, event_type, timestamp, latitude, longitude)
VALUES (
    'geofence-uuid',
    'vehicle-uuid',
    'entry',
    NOW(),
    40.7128,
    -74.0060
);
```

#### Insert an exit event with dwell time
```sql
INSERT INTO geofence_events (geofence_id, vehicle_id, event_type, timestamp, latitude, longitude, dwell_time)
VALUES (
    'geofence-uuid',
    'vehicle-uuid',
    'exit',
    NOW(),
    40.7130,
    -74.0062,
    3600  -- 1 hour in seconds
);
```

#### Get all events for a geofence
```sql
SELECT 
    event_id,
    vehicle_id,
    event_type,
    timestamp,
    latitude,
    longitude,
    dwell_time
FROM geofence_events
WHERE geofence_id = 'geofence-uuid'
ORDER BY timestamp DESC;
```

#### Get all events for a vehicle
```sql
SELECT 
    event_id,
    geofence_id,
    event_type,
    timestamp,
    latitude,
    longitude,
    dwell_time
FROM geofence_events
WHERE vehicle_id = 'vehicle-uuid'
ORDER BY timestamp DESC;
```

#### Get events within a date range
```sql
SELECT *
FROM geofence_events
WHERE geofence_id = 'geofence-uuid'
  AND timestamp BETWEEN '2024-01-01' AND '2024-01-31'
ORDER BY timestamp DESC;
```

#### Get recent entry events for a vehicle
```sql
SELECT *
FROM geofence_events
WHERE vehicle_id = 'vehicle-uuid'
  AND event_type = 'entry'
ORDER BY timestamp DESC
LIMIT 10;
```

#### Calculate average dwell time for a geofence
```sql
SELECT 
    geofence_id,
    AVG(dwell_time) AS avg_dwell_seconds,
    AVG(dwell_time) / 60 AS avg_dwell_minutes,
    COUNT(*) AS exit_count
FROM geofence_events
WHERE geofence_id = 'geofence-uuid'
  AND event_type = 'exit'
  AND dwell_time IS NOT NULL
GROUP BY geofence_id;
```

#### Find vehicles currently inside a geofence
```sql
WITH latest_events AS (
    SELECT DISTINCT ON (vehicle_id)
        vehicle_id,
        event_type,
        timestamp
    FROM geofence_events
    WHERE geofence_id = 'geofence-uuid'
    ORDER BY vehicle_id, timestamp DESC
)
SELECT vehicle_id
FROM latest_events
WHERE event_type = 'entry';
```

#### Get event history with geofence details
```sql
SELECT 
    e.event_id,
    e.vehicle_id,
    e.event_type,
    e.timestamp,
    e.latitude,
    e.longitude,
    e.dwell_time,
    g.name AS geofence_name,
    g.type AS geofence_type
FROM geofence_events e
JOIN geofences g ON e.geofence_id = g.geofence_id
WHERE e.vehicle_id = 'vehicle-uuid'
ORDER BY e.timestamp DESC;
```

### Performance Considerations

1. **Composite Indexes**: 
   - `(geofence_id, timestamp DESC)` enables fast queries for geofence event history
   - `(vehicle_id, timestamp DESC)` enables fast queries for vehicle event history
   - Both indexes support efficient pagination and date range filtering

2. **Timestamp Index**: 
   - Standalone timestamp index supports system-wide recent event queries
   - Useful for monitoring dashboards and real-time feeds

3. **Query Optimization**:
   - Use `LIMIT` clauses for recent event queries
   - Use date range filters to reduce result sets
   - Leverage indexes by including indexed columns in WHERE clauses

4. **Data Volume**:
   - High-traffic geofences may generate thousands of events per day
   - Consider partitioning by timestamp for very large datasets
   - Implement data retention policies (e.g., archive events older than 1 year)

### Requirements Mapping

This table satisfies the following requirements:

- **6.2**: Create Entry_Event record with vehicle identifier, geofence identifier, timestamp, and coordinates
- **6.3**: Store Entry_Event in Supabase database
- **7.2**: Create Exit_Event record with vehicle identifier, geofence identifier, timestamp, and coordinates
- **7.3**: Store Exit_Event in Supabase database
- **7.5**: Calculate dwell time as duration between Entry_Event and Exit_Event
- **17.3**: Event records with proper columns and indexes for performance optimization
- **13.1-13.5**: Support for viewing and filtering geofence event history

### Integration with Monitoring System

The geofence_events table is populated by the Geofence Monitor Edge Function, which:

1. Listens for vehicle location updates
2. Calculates distances using haversine formula
3. Detects boundary crossings (entry/exit)
4. Inserts event records with appropriate data
5. Triggers notifications based on geofence type

See the design document for details on the monitoring implementation.
