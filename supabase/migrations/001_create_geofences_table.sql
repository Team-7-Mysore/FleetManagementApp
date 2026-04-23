-- Migration: Create geofences table with validation constraints
-- Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 17.1

-- Create geofences table
CREATE TABLE IF NOT EXISTS geofences (
    geofence_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    latitude DECIMAL(10, 8) NOT NULL CHECK (latitude >= -90 AND latitude <= 90),
    longitude DECIMAL(11, 8) NOT NULL CHECK (longitude >= -180 AND longitude <= 180),
    radius INTEGER NOT NULL CHECK (radius >= 50 AND radius <= 10000),
    type VARCHAR(20) NOT NULL CHECK (type IN ('depot', 'delivery', 'restricted')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_geofences_type ON geofences(type);
CREATE INDEX IF NOT EXISTS idx_geofences_coordinates ON geofences(latitude, longitude);

-- Add comment to table
COMMENT ON TABLE geofences IS 'Stores geofence definitions with validation constraints for latitude, longitude, radius, and type';

-- Add comments to columns
COMMENT ON COLUMN geofences.geofence_id IS 'Unique identifier for the geofence';
COMMENT ON COLUMN geofences.name IS 'Geofence name (3-100 characters)';
COMMENT ON COLUMN geofences.latitude IS 'Center latitude in degrees (-90 to 90)';
COMMENT ON COLUMN geofences.longitude IS 'Center longitude in degrees (-180 to 180)';
COMMENT ON COLUMN geofences.radius IS 'Radius in meters (50 to 10000)';
COMMENT ON COLUMN geofences.type IS 'Geofence type: depot, delivery, or restricted';
COMMENT ON COLUMN geofences.created_at IS 'Timestamp when geofence was created';
COMMENT ON COLUMN geofences.updated_at IS 'Timestamp when geofence was last updated';
