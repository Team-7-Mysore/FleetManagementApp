-- Verification: Check geofence_assignments table structure
-- Task: 1.2 Create geofence_assignments table

-- Verify table exists
SELECT 
    'geofence_assignments' AS table_name,
    EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_name = 'geofence_assignments'
    ) AS table_exists;

-- Verify columns
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_name = 'geofence_assignments'
ORDER BY ordinal_position;

-- Verify constraints
SELECT 
    constraint_name,
    constraint_type
FROM information_schema.table_constraints
WHERE table_name = 'geofence_assignments'
ORDER BY constraint_type, constraint_name;

-- Verify foreign key details
SELECT 
    tc.constraint_name,
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
WHERE tc.table_name = 'geofence_assignments' 
    AND tc.constraint_type = 'FOREIGN KEY';

-- Verify indexes
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'geofence_assignments'
ORDER BY indexname;

-- Verify unique constraint columns
SELECT 
    tc.constraint_name,
    string_agg(kcu.column_name, ', ' ORDER BY kcu.ordinal_position) AS columns
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
WHERE tc.table_name = 'geofence_assignments'
    AND tc.constraint_type = 'UNIQUE'
GROUP BY tc.constraint_name;
