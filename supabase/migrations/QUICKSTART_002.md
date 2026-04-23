# Geofence Assignments Table Quick Start Guide

## Prerequisites

Before applying this migration, ensure:
- ✅ Migration 001 (geofences table) has been applied
- ✅ You have access to your Supabase project dashboard

## Apply the Migration

### Using Supabase Dashboard (Easiest)

1. Open your Supabase project: https://qisdvwaldlghndrudbvr.supabase.co
2. Go to **SQL Editor** in the left sidebar
3. Click **New Query**
4. Copy the contents of `supabase/migrations/002_create_geofence_assignments_table.sql`
5. Paste into the SQL editor
6. Click **Run** or press `Cmd/Ctrl + Enter`
7. Verify success message appears

### Using Supabase CLI

```bash
# If you have Supabase CLI installed
supabase db push

# Or execute specific file
supabase db execute --file supabase/migrations/002_create_geofence_assignments_table.sql
```

## Verify the Migration

Run the verification script to confirm the table was created correctly:

1. Open SQL Editor in Supabase Dashboard
2. Copy contents of `supabase/migrations/verify/002_verify_geofence_assignments.sql`
3. Run the query
4. Check that:
   - `table_exists` returns `TRUE`
   - 4 columns are present (assignment_id, geofence_id, vehicle_id, created_at)
   - Foreign key constraint exists on geofence_id with CASCADE delete
   - UNIQUE constraint exists on (geofence_id, vehicle_id)
   - 2 indexes exist (idx_assignments_geofence, idx_assignments_vehicle)

## Test the Table

To test that the table and constraints work correctly:

1. Open SQL Editor in Supabase Dashboard
2. Copy contents of `supabase/migrations/tests/002_test_geofence_assignments.sql`
3. Run the query
4. Verify all tests pass

The test suite will verify:
- ✅ Table structure is correct
- ✅ CASCADE delete works (deleting geofence removes assignments)
- ✅ UNIQUE constraint prevents duplicate assignments
- ✅ Indexes exist for performance

## Quick Test

Run this quick test to verify everything works:

```sql
-- Step 1: Create a test geofence
INSERT INTO geofences (geofence_id, name, latitude, longitude, radius, type)
VALUES ('11111111-1111-1111-1111-111111111111', 'Test Geofence', 37.7749, -122.4194, 500, 'depot');

-- Step 2: Create a test assignment
INSERT INTO geofence_assignments (geofence_id, vehicle_id)
VALUES ('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222');

-- Step 3: Verify assignment was created
SELECT * FROM geofence_assignments 
WHERE geofence_id = '11111111-1111-1111-1111-111111111111';

-- Step 4: Test CASCADE delete - delete geofence should remove assignment
DELETE FROM geofences WHERE geofence_id = '11111111-1111-1111-1111-111111111111';

-- Step 5: Verify assignment was automatically deleted
SELECT COUNT(*) FROM geofence_assignments 
WHERE geofence_id = '11111111-1111-1111-1111-111111111111';
-- Should return 0
```

## Common Issues

### Issue: Foreign key constraint violation
**Error**: `insert or update on table "geofence_assignments" violates foreign key constraint`

**Solution**: Ensure the geofence_id exists in the geofences table before creating an assignment.

```sql
-- Check if geofence exists
SELECT * FROM geofences WHERE geofence_id = 'your-geofence-uuid';
```

### Issue: Unique constraint violation
**Error**: `duplicate key value violates unique constraint "geofence_assignments_geofence_id_vehicle_id_key"`

**Solution**: This vehicle is already assigned to this geofence. Each vehicle can only be assigned to a geofence once.

```sql
-- Check existing assignments
SELECT * FROM geofence_assignments 
WHERE geofence_id = 'your-geofence-uuid' 
AND vehicle_id = 'your-vehicle-uuid';
```

### Issue: Table already exists
**Solution**: The migration uses `IF NOT EXISTS`, so it's safe to run multiple times.

## Usage Examples

### Assign multiple vehicles to a geofence
```sql
INSERT INTO geofence_assignments (geofence_id, vehicle_id)
VALUES 
    ('geofence-uuid', 'vehicle-1-uuid'),
    ('geofence-uuid', 'vehicle-2-uuid'),
    ('geofence-uuid', 'vehicle-3-uuid');
```

### Find all vehicles assigned to a geofence
```sql
SELECT vehicle_id, created_at
FROM geofence_assignments
WHERE geofence_id = 'your-geofence-uuid'
ORDER BY created_at DESC;
```

### Find all geofences assigned to a vehicle
```sql
SELECT 
    ga.geofence_id,
    g.name AS geofence_name,
    g.type AS geofence_type,
    ga.created_at AS assigned_at
FROM geofence_assignments ga
JOIN geofences g ON ga.geofence_id = g.geofence_id
WHERE ga.vehicle_id = 'your-vehicle-uuid'
ORDER BY ga.created_at DESC;
```

### Remove a specific assignment
```sql
DELETE FROM geofence_assignments
WHERE geofence_id = 'your-geofence-uuid'
AND vehicle_id = 'your-vehicle-uuid';
```

### Count assignments per geofence
```sql
SELECT 
    g.name,
    g.type,
    COUNT(ga.vehicle_id) AS vehicle_count
FROM geofences g
LEFT JOIN geofence_assignments ga ON g.geofence_id = ga.geofence_id
GROUP BY g.geofence_id, g.name, g.type
ORDER BY vehicle_count DESC;
```

## Next Steps

After applying this migration:

1. ✅ Geofences table is ready (migration 001)
2. ✅ Geofence assignments table is ready (migration 002)
3. ⏭️ Apply migration 003 for geofence_events table (coming next)
4. ⏭️ Set up Edge Functions for monitoring (coming next)
5. ⏭️ Implement GeofenceService in Swift for CRUD operations

## Swift Integration

Once the table is created, you can use it in your Swift code:

```swift
// Model
struct GeofenceAssignment: Codable, Identifiable {
    let id: UUID
    let geofence_id: UUID
    let vehicle_id: UUID
    let created_at: Date
    
    enum CodingKeys: String, CodingKey {
        case id = "assignment_id"
        case geofence_id
        case vehicle_id
        case created_at
    }
}

// Example: Assign vehicles to a geofence
let assignments = [
    ["geofence_id": geofenceId.uuidString, "vehicle_id": vehicleId1.uuidString],
    ["geofence_id": geofenceId.uuidString, "vehicle_id": vehicleId2.uuidString]
]

try await supabase
    .from("geofence_assignments")
    .insert(assignments)
    .execute()

// Example: Fetch vehicles assigned to a geofence
let assignments: [GeofenceAssignment] = try await supabase
    .from("geofence_assignments")
    .select()
    .eq("geofence_id", value: geofenceId.uuidString)
    .execute()
    .value

// Example: Remove an assignment
try await supabase
    .from("geofence_assignments")
    .delete()
    .eq("geofence_id", value: geofenceId.uuidString)
    .eq("vehicle_id", value: vehicleId.uuidString)
    .execute()
```

## Performance Notes

- Both `geofence_id` and `vehicle_id` are indexed for fast lookups
- The UNIQUE constraint on (geofence_id, vehicle_id) is also an index
- CASCADE delete ensures automatic cleanup when geofences are removed
- No N+1 query issues when joining with geofences table

## Support

If you encounter issues:
1. Check the verification script output
2. Review the SCHEMA.md for detailed table structure
3. Run the test script to identify specific constraint issues
4. Check Supabase logs in the Dashboard under **Database** → **Logs**

## Related Documentation

- `TASK_1.2_SUMMARY.md` - Detailed implementation summary
- `SCHEMA.md` - Complete schema documentation
- `README.md` - General migration information
