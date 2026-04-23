-- Verification script for geofences table migration
-- Run this after applying the migration to verify it was successful

-- Check if table exists
SELECT EXISTS (
    SELECT FROM information_schema.tables 
    WHERE table_schema = 'public' 
    AND table_name = 'geofences'
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
WHERE table_name = 'geofences'
ORDER BY ordinal_position;

-- Check constraints
SELECT
    con.conname AS constraint_name,
    con.contype AS constraint_type,
    pg_get_constraintdef(con.oid) AS constraint_definition
FROM pg_constraint con
JOIN pg_class rel ON rel.oid = con.conrelid
WHERE rel.relname = 'geofences'
ORDER BY con.conname;

-- Check indexes
SELECT 
    indexname, 
    indexdef 
FROM pg_indexes 
WHERE tablename = 'geofences'
ORDER BY indexname;

-- Verify CHECK constraints specifically
SELECT 
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS constraint_definition
FROM pg_constraint
WHERE conrelid = 'geofences'::regclass
AND contype = 'c'
ORDER BY conname;

-- Expected results:
-- 1. table_exists should return TRUE
-- 2. Should have 8 columns: geofence_id, name, latitude, longitude, radius, type, created_at, updated_at
-- 3. Should have CHECK constraints for latitude, longitude, radius, and type
-- 4. Should have 2 indexes: idx_geofences_type and idx_geofences_coordinates
-- 5. Primary key should be on geofence_id
