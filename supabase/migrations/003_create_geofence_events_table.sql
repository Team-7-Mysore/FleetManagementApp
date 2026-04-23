-- Migration: Create geofence_events table
-- Requirements: 6.2, 6.3, 7.2, 7.3, 17.3
-- Task: 1.3 Create geofence_events table

-- Create geofence_events table
CREATE TABLE IF NOT EXISTS geofence_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    geofence_id UUID NOT NULL REFERENCES geofences(geofence_id) ON DELETE CASCADE,
    vehicle_id UUID NOT NULL,
    event_type VARCHAR(10) NOT NULL CHECK (event_type IN ('entry', 'exit')),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    latitude DECIMAL(10, 8) NOT NULL,
    longitude DECIMAL(11, 8) NOT NULL,
    dwell_time INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create indexes for performance optimization
CREATE INDEX IF NOT EXISTS idx_events_geofence ON geofence_events(geofence_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_events_vehicle ON geofence_events(vehicle_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_events_timestamp ON geofence_events(timestamp DESC);

-- Add comment to table
COMMENT ON TABLE geofence_events IS 'Stores all geofence entry and exit events for vehicles with event history and dwell time tracking';

-- Add comments to columns
COMMENT ON COLUMN geofence_events.event_id IS 'Unique identifier for the event';
COMMENT ON COLUMN geofence_events.geofence_id IS 'Foreign key to geofences table with CASCADE delete';
COMMENT ON COLUMN geofence_events.vehicle_id IS 'Foreign key to vehicles table';
COMMENT ON COLUMN geofence_events.event_type IS 'Type of event: entry or exit';
COMMENT ON COLUMN geofence_events.timestamp IS 'Timestamp when the event occurred';
COMMENT ON COLUMN geofence_events.latitude IS 'Vehicle latitude at time of event';
COMMENT ON COLUMN geofence_events.longitude IS 'Vehicle longitude at time of event';
COMMENT ON COLUMN geofence_events.dwell_time IS 'Duration in seconds between entry and exit (only for exit events)';
COMMENT ON COLUMN geofence_events.created_at IS 'Timestamp when event record was created';
