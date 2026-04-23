-- Verification script for geofence_events table migration
-- Run this after applying the migration to verify it was successful
-- Task: 1.3 Create geofence_events table

-- Check if table exists
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'geofence_events'
) AS table_exists;

-- Check table structure
SELECT 
    column_name, 
    data_type, 
    character_maximum_length,
    numeric_precision,
    numeric_scale,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'geofence_events'
ORDER BY ordinal_position;

-- Check constraints
SELECT
    con.conname AS constraint_name,
    con.contype AS constraint_type,
    pg_get_constraintdef(con.oid) AS constraint_definition
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
WHERE rel.relname = 'geofence_events'
ORDER BY con.conname;

-- Check indexes
SELECT 
    indexname, 
    indexdef 
FROM pg_indexes 
WHERE tablename = 'geofence_events'
ORDER BY indexname;

-- Verify CHECK constraint on event_type
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'geofence_events'::regclass
AND contype = 'c'
ORDER BY conname;

-- Verify foreign key relationships
SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name,
    rc.delete_rule
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints AS rc
    ON tc.constraint_name = rc.constraint_name
WHERE tc.table_name = 'geofence_events'
AND tc.constraint_type = 'FOREIGN KEY';

-- Expected results:
-- 1. table_exists should return TRUE
-- 2. Should have 9 columns: event_id, geofence_id, vehicle_id, event_type, timestamp, latitude, longitude, dwell_time, created_at
-- 3. Should have CHECK constraint for event_type ('entry' or 'exit')
-- 4. Should have 3 indexes: idx_events_geofence, idx_events_vehicle, idx_events_timestamp
-- 5. Primary key should be on event_id
-- 6. Foreign key on geofence_id with CASCADE delete
-- 7. dwell_time should be nullable (for entry events)
