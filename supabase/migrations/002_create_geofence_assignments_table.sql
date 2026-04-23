-- Migration: Create geofence_assignments table
-- Requirements: 5.2, 17.2
-- Task: 1.2 Create geofence_assignments table

-- Create geofence_assignments table
CREATE TABLE IF NOT EXISTS geofence_assignments (
    assignment_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    geofence_id UUID NOT NULL REFERENCES geofences(geofence_id) ON DELETE CASCADE,
    vehicle_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(geofence_id, vehicle_id)
);

-- Create indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_assignments_geofence ON geofence_assignments(geofence_id);
CREATE INDEX IF NOT EXISTS idx_assignments_vehicle ON geofence_assignments(vehicle_id);

-- Add comment to table
COMMENT ON TABLE geofence_assignments IS 'Manages many-to-many relationship between geofences and vehicles with cascade delete';

-- Add comments to columns
COMMENT ON COLUMN geofence_assignments.assignment_id IS 'Unique identifier for the assignment';
COMMENT ON COLUMN geofence_assignments.geofence_id IS 'Foreign key to geofences table with CASCADE delete';
COMMENT ON COLUMN geofence_assignments.vehicle_id IS 'Foreign key to vehicles table';
COMMENT ON COLUMN geofence_assignments.created_at IS 'Timestamp when assignment was created';

-- Add constraint comment
COMMENT ON CONSTRAINT geofence_assignments_geofence_id_vehicle_id_key ON geofence_assignments IS 'Ensures a vehicle can only be assigned to a geofence once';
