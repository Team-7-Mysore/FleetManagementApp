-- Test: Verify geofence_events table structure and constraints
-- Task: 1.3 Create geofence_events table
-- Requirements: 6.2, 6.3, 7.2, 7.3, 17.3

BEGIN;

-- Test 1: Verify table exists
DO $
BEGIN
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'geofence_events'
    )), 'geofence_events table should exist';
END $;

-- Test 2: Verify columns exist with correct types
DO $
BEGIN
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'geofence_events' 
        AND column_name = 'event_id' 
        AND data_type = 'uuid'
    )), 'event_id column should exist with UUID type';
    
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'geofence_events' 
        AND column_name = 'geofence_id' 
        AND data_type = 'uuid'
    )), 'geofence_id column should exist with UUID type';
    
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'geofence_events' 
        AND column_name = 'vehicle_id' 
        AND data_type = 'uuid'
    )), 'vehicle_id column should exist with UUID type';
    
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'geofence_events' 
        AND column_name = 'event_type' 
        AND data_type = 'character varying'
    )), 'event_type column should exist with VARCHAR type';
    
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'geofence_events' 
        AND column_name = 'timestamp' 
        AND data_type = 'timestamp with time zone'
    )), 'timestamp column should exist with TIMESTAMPTZ type';
    
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'geofence_events' 
        AND column_name = 'latitude' 
        AND data_type = 'numeric'
    )), 'latitude column should exist with DECIMAL type';
    
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'geofence_events' 
        AND column_name = 'longitude' 
        AND data_type = 'numeric'
    )), 'longitude column should exist with DECIMAL type';
    
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'geofence_events' 
        AND column_name = 'dwell_time' 
        AND data_type = 'integer'
    )), 'dwell_time column should exist with INTEGER type';
    
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'geofence_events' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp with time zone'
    )), 'created_at column should exist with TIMESTAMPTZ type';
END $;

-- Test 3: Verify primary key constraint
DO $
BEGIN
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.table_constraints 
        WHERE table_name = 'geofence_events' 
        AND constraint_type = 'PRIMARY KEY'
        AND constraint_name = 'geofence_events_pkey'
    )), 'Primary key constraint should exist on event_id';
END $;

-- Test 4: Verify foreign key constraint on geofence_id with CASCADE delete
DO $
BEGIN
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.table_constraints tc
        JOIN information_schema.referential_constraints rc 
            ON tc.constraint_name = rc.constraint_name
        WHERE tc.table_name = 'geofence_events' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND rc.delete_rule = 'CASCADE'
        AND EXISTS (
            SELECT FROM information_schema.key_column_usage
            WHERE constraint_name = tc.constraint_name
            AND column_name = 'geofence_id'
        )
    )), 'Foreign key constraint with CASCADE delete should exist on geofence_id';
END $;

-- Test 5: Verify CHECK constraint on event_type
DO $
BEGIN
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.check_constraints 
        WHERE constraint_name IN (
            SELECT constraint_name 
            FROM information_schema.constraint_column_usage 
            WHERE table_name = 'geofence_events' 
            AND column_name = 'event_type'
        )
        AND check_clause LIKE '%entry%'
        AND check_clause LIKE '%exit%'
    )), 'CHECK constraint should exist on event_type for entry/exit values';
END $;

-- Test 6: Verify indexes exist
DO $
BEGIN
    ASSERT (SELECT EXISTS (
        SELECT FROM pg_indexes 
        WHERE tablename = 'geofence_events' 
        AND indexname = 'idx_events_geofence'
    )), 'Index on (geofence_id, timestamp DESC) should exist';
    
    ASSERT (SELECT EXISTS (
        SELECT FROM pg_indexes 
        WHERE tablename = 'geofence_events' 
        AND indexname = 'idx_events_vehicle'
    )), 'Index on (vehicle_id, timestamp DESC) should exist';
    
    ASSERT (SELECT EXISTS (
        SELECT FROM pg_indexes 
        WHERE tablename = 'geofence_events' 
        AND indexname = 'idx_events_timestamp'
    )), 'Index on (timestamp DESC) should exist';
END $;

-- Test 7: Test valid entry event insertion
-- Create test geofence
INSERT INTO geofences (geofence_id, name, latitude, longitude, radius, type)
VALUES ('10000000-0000-0000-0000-000000000001', 'Test Event Geofence', 40.7128, -74.0060, 500, 'depot');

-- Insert valid entry event
INSERT INTO geofence_events (event_id, geofence_id, vehicle_id, event_type, timestamp, latitude, longitude)
VALUES (
    '20000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    'entry',
    NOW(),
    40.7128,
    -74.0060
);

-- Verify entry event exists
DO $
BEGIN
    ASSERT (SELECT COUNT(*) FROM geofence_events WHERE event_id = '20000000-0000-0000-0000-000000000001') = 1,
        'Entry event should be inserted successfully';
END $;

-- Test 8: Test valid exit event insertion with dwell_time
INSERT INTO geofence_events (event_id, geofence_id, vehicle_id, event_type, timestamp, latitude, longitude, dwell_time)
VALUES (
    '20000000-0000-0000-0000-000000000002',
    '10000000-0000-0000-0000-000000000001',
    '30000000-0000-0000-0000-000000000001',
    'exit',
    NOW() + INTERVAL '1 hour',
    40.7130,
    -74.0062,
    3600
);

-- Verify exit event exists with dwell_time
DO $
BEGIN
    ASSERT (SELECT COUNT(*) FROM geofence_events 
            WHERE event_id = '20000000-0000-0000-0000-000000000002' 
            AND dwell_time = 3600) = 1,
        'Exit event with dwell_time should be inserted successfully';
END $;

-- Test 9: Test invalid event_type (should fail)
DO $
BEGIN
    BEGIN
        INSERT INTO geofence_events (geofence_id, vehicle_id, event_type, timestamp, latitude, longitude)
        VALUES (
            '10000000-0000-0000-0000-000000000001',
            '30000000-0000-0000-0000-000000000001',
            'invalid_type',
            NOW(),
            40.7128,
            -74.0060
        );
        
        RAISE EXCEPTION 'Invalid event_type should have been rejected';
    EXCEPTION
        WHEN check_violation THEN
            -- Expected behavior
            NULL;
    END;
END $;

-- Test 10: Test CASCADE delete behavior
-- Verify events exist before deletion
DO $
BEGIN
    ASSERT (SELECT COUNT(*) FROM geofence_events WHERE geofence_id = '10000000-0000-0000-0000-000000000001') = 2,
        'Two events should exist before geofence deletion';
END $;

-- Delete geofence (should cascade to events)
DELETE FROM geofences WHERE geofence_id = '10000000-0000-0000-0000-000000000001';

-- Verify events were deleted
DO $
BEGIN
    ASSERT (SELECT COUNT(*) FROM geofence_events WHERE geofence_id = '10000000-0000-0000-0000-000000000001') = 0,
        'Events should be deleted when geofence is deleted (CASCADE)';
END $;

-- Test 11: Test entry event without dwell_time (should succeed)
INSERT INTO geofences (geofence_id, name, latitude, longitude, radius, type)
VALUES ('10000000-0000-0000-0000-000000000002', 'Test Event Geofence 2', 40.7128, -74.0060, 500, 'delivery');

INSERT INTO geofence_events (geofence_id, vehicle_id, event_type, timestamp, latitude, longitude)
VALUES (
    '10000000-0000-0000-0000-000000000002',
    '30000000-0000-0000-0000-000000000002',
    'entry',
    NOW(),
    40.7128,
    -74.0060
);

-- Verify entry event has NULL dwell_time
DO $
BEGIN
    ASSERT (SELECT dwell_time IS NULL FROM geofence_events 
            WHERE geofence_id = '10000000-0000-0000-0000-000000000002' 
            AND event_type = 'entry') = TRUE,
        'Entry event should have NULL dwell_time';
END $;

-- Cleanup
DELETE FROM geofences WHERE geofence_id = '10000000-0000-0000-0000-000000000002';

ROLLBACK;

-- Success message
SELECT 'All geofence_events table tests passed!' AS result;
