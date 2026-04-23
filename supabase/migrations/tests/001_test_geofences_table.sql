-- Test file for geofences table constraints
-- This file contains test cases to verify the table constraints work correctly

-- Test 1: Valid geofence insertion (should succeed)
INSERT INTO geofences (name, latitude, longitude, radius, type)
VALUES ('Test Depot', 37.7749, -122.4194, 100, 'depot');

-- Test 2: Invalid latitude - too low (should fail)
-- Expected error: new row for relation "geofences" violates check constraint
-- INSERT INTO geofences (name, latitude, longitude, radius, type)
-- VALUES ('Invalid Lat Low', -91.0, -122.4194, 100, 'depot');

-- Test 3: Invalid latitude - too high (should fail)
-- Expected error: new row for relation "geofences" violates check constraint
-- INSERT INTO geofences (name, latitude, longitude, radius, type)
-- VALUES ('Invalid Lat High', 91.0, -122.4194, 100, 'depot');

-- Test 4: Invalid longitude - too low (should fail)
-- Expected error: new row for relation "geofences" violates check constraint
-- INSERT INTO geofences (name, latitude, longitude, radius, type)
-- VALUES ('Invalid Lon Low', 37.7749, -181.0, 100, 'depot');

-- Test 5: Invalid longitude - too high (should fail)
-- Expected error: new row for relation "geofences" violates check constraint
-- INSERT INTO geofences (name, latitude, longitude, radius, type)
-- VALUES ('Invalid Lon High', 37.7749, 181.0, 100, 'depot');

-- Test 6: Invalid radius - too small (should fail)
-- Expected error: new row for relation "geofences" violates check constraint
-- INSERT INTO geofences (name, latitude, longitude, radius, type)
-- VALUES ('Invalid Radius Small', 37.7749, -122.4194, 49, 'depot');

-- Test 7: Invalid radius - too large (should fail)
-- Expected error: new row for relation "geofences" violates check constraint
-- INSERT INTO geofences (name, latitude, longitude, radius, type)
-- VALUES ('Invalid Radius Large', 37.7749, -122.4194, 10001, 'depot');

-- Test 8: Invalid type (should fail)
-- Expected error: new row for relation "geofences" violates check constraint
-- INSERT INTO geofences (name, latitude, longitude, radius, type)
-- VALUES ('Invalid Type', 37.7749, -122.4194, 100, 'invalid_type');

-- Test 9: Boundary values - minimum valid radius (should succeed)
INSERT INTO geofences (name, latitude, longitude, radius, type)
VALUES ('Min Radius', 37.7749, -122.4194, 50, 'delivery');

-- Test 10: Boundary values - maximum valid radius (should succeed)
INSERT INTO geofences (name, latitude, longitude, radius, type)
VALUES ('Max Radius', 37.7749, -122.4194, 10000, 'restricted');

-- Test 11: Boundary values - minimum valid latitude (should succeed)
INSERT INTO geofences (name, latitude, longitude, radius, type)
VALUES ('Min Latitude', -90.0, -122.4194, 100, 'depot');

-- Test 12: Boundary values - maximum valid latitude (should succeed)
INSERT INTO geofences (name, latitude, longitude, radius, type)
VALUES ('Max Latitude', 90.0, -122.4194, 100, 'depot');

-- Test 13: Boundary values - minimum valid longitude (should succeed)
INSERT INTO geofences (name, latitude, longitude, radius, type)
VALUES ('Min Longitude', 37.7749, -180.0, 100, 'depot');

-- Test 14: Boundary values - maximum valid longitude (should succeed)
INSERT INTO geofences (name, latitude, longitude, radius, type)
VALUES ('Max Longitude', 37.7749, 180.0, 100, 'depot');

-- Test 15: All three types (should succeed)
INSERT INTO geofences (name, latitude, longitude, radius, type)
VALUES 
    ('Depot Test', 37.7749, -122.4194, 200, 'depot'),
    ('Delivery Test', 37.7849, -122.4294, 150, 'delivery'),
    ('Restricted Test', 37.7949, -122.4394, 300, 'restricted');

-- Verify indexes exist
SELECT 
    tablename, 
    indexname, 
    indexdef 
FROM pg_indexes 
WHERE tablename = 'geofences'
ORDER BY indexname;

-- Verify table structure
SELECT 
    column_name, 
    data_type, 
    character_maximum_length,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'geofences'
ORDER BY ordinal_position;

-- Clean up test data
DELETE FROM geofences WHERE name LIKE '%Test%' OR name LIKE 'Min %' OR name LIKE 'Max %';
