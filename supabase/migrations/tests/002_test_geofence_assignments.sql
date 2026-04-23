-- Test: Verify geofence_assignments table structure and constraints
-- Task: 1.2 Create geofence_assignments table

BEGIN;

-- Test 1: Verify table exists
DO $$
BEGIN
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'geofence_assignments'
    )), 'geofence_assignments table should exist';
END $$;

-- Test 2: Verify columns exist with correct types
DO $$
BEGIN
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'geofence_assignments' 
        AND column_name = 'assignment_id' 
        AND data_type = 'uuid'
    )), 'assignment_id column should exist with UUID type';
    
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'geofence_assignments' 
        AND column_name = 'geofence_id' 
        AND data_type = 'uuid'
    )), 'geofence_id column should exist with UUID type';
    
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'geofence_assignments' 
        AND column_name = 'vehicle_id' 
        AND data_type = 'uuid'
    )), 'vehicle_id column should exist with UUID type';
    
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.columns 
        WHERE table_name = 'geofence_assignments' 
        AND column_name = 'created_at' 
        AND data_type = 'timestamp with time zone'
    )), 'created_at column should exist with TIMESTAMPTZ type';
END $$;

-- Test 3: Verify primary key constraint
DO $$
BEGIN
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.table_constraints 
        WHERE table_name = 'geofence_assignments' 
        AND constraint_type = 'PRIMARY KEY'
        AND constraint_name = 'geofence_assignments_pkey'
    )), 'Primary key constraint should exist on assignment_id';
END $$;

-- Test 4: Verify foreign key constraint on geofence_id with CASCADE delete
DO $$
BEGIN
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.table_constraints tc
        JOIN information_schema.referential_constraints rc 
            ON tc.constraint_name = rc.constraint_name
        WHERE tc.table_name = 'geofence_assignments' 
        AND tc.constraint_type = 'FOREIGN KEY'
        AND rc.delete_rule = 'CASCADE'
        AND EXISTS (
            SELECT FROM information_schema.key_column_usage
            WHERE constraint_name = tc.constraint_name
            AND column_name = 'geofence_id'
        )
    )), 'Foreign key constraint with CASCADE delete should exist on geofence_id';
END $$;

-- Test 5: Verify UNIQUE constraint on (geofence_id, vehicle_id)
DO $$
BEGIN
    ASSERT (SELECT EXISTS (
        SELECT FROM information_schema.table_constraints 
        WHERE table_name = 'geofence_assignments' 
        AND constraint_type = 'UNIQUE'
        AND constraint_name = 'geofence_assignments_geofence_id_vehicle_id_key'
    )), 'UNIQUE constraint should exist on (geofence_id, vehicle_id)';
END $$;

-- Test 6: Verify indexes exist
DO $$
BEGIN
    ASSERT (SELECT EXISTS (
        SELECT FROM pg_indexes 
        WHERE tablename = 'geofence_assignments' 
        AND indexname = 'idx_assignments_geofence'
    )), 'Index on geofence_id should exist';
    
    ASSERT (SELECT EXISTS (
        SELECT FROM pg_indexes 
        WHERE tablename = 'geofence_assignments' 
        AND indexname = 'idx_assignments_vehicle'
    )), 'Index on vehicle_id should exist';
END $$;

-- Test 7: Test CASCADE delete behavior
-- Create test geofence
INSERT INTO geofences (geofence_id, name, latitude, longitude, radius, type)
VALUES ('00000000-0000-0000-0000-000000000001', 'Test Geofence', 40.7128, -74.0060, 500, 'depot');

-- Create test assignment
INSERT INTO geofence_assignments (assignment_id, geofence_id, vehicle_id)
VALUES ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003');

-- Verify assignment exists
DO $$
BEGIN
    ASSERT (SELECT COUNT(*) FROM geofence_assignments WHERE assignment_id = '00000000-0000-0000-0000-000000000002') = 1,
        'Test assignment should exist';
END $$;

-- Delete geofence (should cascade to assignment)
DELETE FROM geofences WHERE geofence_id = '00000000-0000-0000-0000-000000000001';

-- Verify assignment was deleted
DO $$
BEGIN
    ASSERT (SELECT COUNT(*) FROM geofence_assignments WHERE assignment_id = '00000000-0000-0000-0000-000000000002') = 0,
        'Assignment should be deleted when geofence is deleted (CASCADE)';
END $$;

-- Test 8: Test UNIQUE constraint
-- Create test geofence
INSERT INTO geofences (geofence_id, name, latitude, longitude, radius, type)
VALUES ('00000000-0000-0000-0000-000000000004', 'Test Geofence 2', 40.7128, -74.0060, 500, 'depot');

-- Create first assignment
INSERT INTO geofence_assignments (geofence_id, vehicle_id)
VALUES ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000005');

-- Try to create duplicate assignment (should fail)
DO $$
BEGIN
    BEGIN
        INSERT INTO geofence_assignments (geofence_id, vehicle_id)
        VALUES ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000005');
        
        RAISE EXCEPTION 'Duplicate assignment should have been rejected';
    EXCEPTION
        WHEN unique_violation THEN
            -- Expected behavior
            NULL;
    END;
END $$;

-- Cleanup
DELETE FROM geofences WHERE geofence_id = '00000000-0000-0000-0000-000000000004';

ROLLBACK;

-- Success message
SELECT 'All geofence_assignments table tests passed!' AS result;
